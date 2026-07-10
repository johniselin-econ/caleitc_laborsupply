# =============================================================================
# File:    51_mvpf.R
# Purpose: Phase 4b — Marginal Value of Public Funds, ported from 02_mvpf.do
#          (the project's largest single file). DELIBERATE reformulation of the
#          behavioral-group assignment: 02_mvpf.do assigns marginal part-time
#          workers to the FT->PT / NW->PT channels with an UNSEEDED runiform()
#          (a Monte Carlo draw that cannot be reproduced across RNGs). Because
#          the draw is independent of worker characteristics, the expectation of
#          the random subset-sum equals a deterministic fractional-weight
#          assignment: each treated PT worker contributes weight * effect to
#          each channel. This R port computes that expected value — fully
#          reproducible, no seed dependence (author decision 2026-07-10).
#
#          Pipeline (per 02_mvpf.do sections 2-5):
#            (a) For each spec, regress full_time_y and part_time_y on the
#                treatment (by heterogeneity) with the triple- or quad-diff FEs
#                and controls; the predicted treatment gap pred_gap = fitted(on)
#                - fitted(off) gives per-het-group effects effect_f, effect_p.
#            (b) effect1 = min(effect_f, effect_p) (FT->PT), effect2 =
#                max(0, effect_p - effect_f) (NW->PT); effect1+effect2=effect_p.
#            (c) Treated CalEITC-eligible PT workers (CA, qc_present, 2015-2017,
#                sim1_steitc>=0) are run through TAXSIM at CalEITC-max income
#                (treated) and at counterfactual incomes (0 for NW->PT; the FT
#                counterfactual — min wage / median / mean — for FT->PT).
#            (d) Fiscal externality = sum over workers of weight * effect *
#                (liability_tr - liability_cf), per component/option, in real
#                2017 USD; add hardcoded direct CalEITC costs; MVPF = WTP /
#                net-fiscal-cost (four nested denominators; mvpf_4 headline).
#          TAXSIM liabilities depend only on (year, age, qc_ct, income), so they
#          are computed ONCE for the broadest treated pool at all income levels
#          and reused across the 9-deep spec grid.
#
#          Validation (Monte-Carlo tolerance against 02_mvpf_log_2026-03-07):
#          preferred mvpf_4 ~ 0.835, quad ~ 0.905, median-CF ~ 0.613, overall
#          mean ~ 0.70. Schedule from caleitc_params.txt (audit-verified);
#          direct costs are hardcoded FTB actuals — the superseded eitc_california
#          block does not feed this port.
#
# Inputs:  data/final/acs_working_file_r.rds,
#          data/eitc_parameters/caleitc_params.txt
# Output:  results/mvpf/mvpf_models_job<JID>.csv (all spec-level MVPFs),
#          results/mvpf/mvpf_summary_job<JID>.csv (by-dimension means),
#          data/tmp/mvpf_r.rds
#
# Usage:   Rscript code/51_mvpf.R  (cluster: stage22_mvpf.sbatch)
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
source(file.path("code", "lib", "estimation.R"))
source(file.path("code", "lib", "taxsim.R"))
suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr); library(fixest)
})

# --- Constants (02_mvpf.do sections 1, 4) ------------------------------------
CPI <- c("2015" = 245.121/237.002, "2016" = 245.121/240.005,
         "2017" = 245.121/245.121, "2018" = 245.121/251.100,
         "2019" = 245.121/255.653)
DIRECT_COSTS <- c("2015" = 200000000, "2016" = 201000000, "2017" = 348451029,
                  "2018" = 401578130, "2019" = 743740147)
POST_YEARS <- 2015:2017                                # p_sta=2012, p_end=2017
NOEITC_KEEP <- setdiff(0:56, c(2, 8, 9, 10, 11, 15, 17, 18, 19, 23, 24, 25,
                               26, 27, 30, 31, 34, 35, 39, 40, 41, 44, 45, 49,
                               50, 51, 55))
MEDICAID_KEEP <- c(4, 5, 6, 8, 9, 10, 11, 15, 17, 19, 21, 24, 25, 26, 27, 32,
                   33, 34, 35, 36, 38, 39, 41, 44, 50, 53, 54)
COMPONENTS <- c(fed_liab = "fiitax", st_liab = "siitax", pay_liab = "fica",
                fedeitc = "v25", caleitc = "v39")     # ctc, st_nocal derived

# --- CalEITC-max income by (year, qc_ct) (02_mvpf.do:33-48) ------------------
calmax <- read_delim(path_data("eitc_parameters", "caleitc_params.txt"),
                     delim = "\t", show_col_types = FALSE) |>
  transmute(year = tax_year, qc_ct,
            pwages = suppressWarnings(as.numeric(pwages)),
            pwages_unadj = suppressWarnings(as.numeric(pwages_unadj))) |>
  mutate(pwages_calmax = ifelse(is.na(pwages), pwages_unadj, pwages)) |>
  select(year, qc_ct, pwages_calmax)

# --- Load broad sample (female single non-student citizen, 20-64) ------------
message("Loading working file ...")
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
base <- wf |>
  filter(female == 1, married == 0, in_school == 0, citizen_test == 1,
         age >= 20, age <= 64, year >= 2012, year <= 2017) |>
  select(weight, year, state_fips, state_status, age, education, qc_ct,
         qc_present, part_time_y, full_time_y, taxsim_sim1_steitc, mean_st_mw,
         state_unemp, age_bracket, minage_qc, race_group, hispanic,
         hh_adult_ct) |>
  mutate(hh_adult_ct = pmin(hh_adult_ct, 3),
         ca = as.integer(state_fips == 6),
         noncollege = as.integer(education < 4),
         treated = as.integer(state_fips == 6 & qc_present == 1 & year >= 2015),
         quad_treated = as.integer(noncollege == 1 & ca == 1 &
                                     qc_present == 1 & year >= 2015)) |>
  left_join(calmax, by = c("year", "qc_ct"))
rm(wf); invisible(gc())
message("Broad sample: N = ", nrow(base))

# =============================================================================
# Precompute TAXSIM liabilities for the treated PT-worker pool at all incomes
# =============================================================================
# Treated CalEITC-eligible set (broadest: 20-64, all education); the impacted
# pool is the part-time subset, but the assignment fraction (effect) applies to
# the TOTAL treated group weight (02_mvpf.do:359, max_weight over all work
# statuses), so each PT worker's impacted weight is scaled by total/PT weight.
treated_all <- base |>
  filter(ca == 1, qc_present == 1, year %in% POST_YEARS, taxsim_sim1_steitc >= 0)
pool0 <- treated_all |> filter(part_time_y == 1)
pool0$wid <- seq_len(nrow(pool0))
message("Treated PT-worker pool (broadest): ", nrow(pool0))

# Income levels: 1=calmax(tr), 2=zero, 3=FTminwage, 4=median 30655, 5=mean 36413
LEVELS <- list(calmax = pool0$pwages_calmax, zero = rep(0, nrow(pool0)),
               ftmw = pool0$mean_st_mw * 40 * 52,
               med = rep(30655, nrow(pool0)), mean = rep(36413, nrow(pool0)))
taxin <- bind_rows(lapply(names(LEVELS), function(l) {
  data.frame(wid = pool0$wid, lvl = l, year = pool0$year,
             state = 5L, mstat = 1L, page = pool0$age, sage = 0L,
             depx = pool0$qc_ct, pwages = LEVELS[[l]],
             swages = 0, intrec = 0, otherprop = 0, psemp = 0, ssemp = 0)
})) |>
  mutate(taxsimid = row_number())
message("TAXSIM rows: ", nrow(taxin))

tx <- run_taxsim35(taxin |> select(all_of(TAXSIM_VARS))) |>
  transmute(taxsimid = as.integer(taxsimid),
            fiitax, siitax, fica, v25, v39, ctc = v22 + v23)
liab <- taxin |> select(taxsimid, wid, lvl) |>
  left_join(tx, by = "taxsimid") |>
  transmute(wid, lvl,
            fed_liab = fiitax, st_liab = siitax, pay_liab = fica,
            fedeitc = v25, caleitc = v39, ctc = ctc,
            st_nocal_liab = siitax + v39)
COMPS <- c("fed_liab", "st_liab", "pay_liab", "fedeitc", "ctc", "caleitc",
           "st_nocal_liab")
# Wide per worker: <comp>_<lvl>
liab_w <- liab |>
  pivot_wider(id_cols = wid, names_from = lvl,
              values_from = all_of(COMPS), names_sep = ".")
pool <- pool0 |> left_join(liab_w, by = "wid")
message("Precompute complete.")

# =============================================================================
# Regression + MVPF for one specification
# =============================================================================
# FE strings
fe_triple <- c("qc_ct", "year", "state_fips", "state_fips^year",
               "state_fips^qc_ct", "year^qc_ct")
fe_quad <- c("state_fips^year^qc_ct", "state_fips^year^noncollege",
             "state_fips^qc_ct^noncollege", "year^qc_ct^noncollege")
CTRL_T <- c("education", "age_bracket", "minage_qc", "race_group", "hispanic",
            "hh_adult_ct")
CTRL_Q <- setdiff(CTRL_T, "education")                 # education absorbed

fit_gap <- function(outcome, dat, treatvar, hetero, design,
                    spec_d, spec_u, spec_m) {
  fes <- if (design == 1) fe_quad else fe_triple
  ctrl <- if (spec_d == 1) (if (design == 1) CTRL_Q else CTRL_T) else character(0)
  treat <- switch(as.character(hetero),
    "0" = treatvar,
    "1" = sprintf("i(year, %s, ref = 2014)", treatvar),
    "2" = sprintf("i(qc_ct, %s, ref = 0)", treatvar),
    "3" = sprintf("i(hh_adult_ct, %s, ref = 0)", treatvar))
  slopes <- character(0)
  if (design == 0 && spec_u == 1)
    slopes <- c(slopes, "i(qc_ct, state_unemp, ref = 3)")
  if (design == 0 && spec_m == 1)
    slopes <- c(slopes, "i(qc_ct, mean_st_mw, ref = 3)")
  rhs <- paste(c(treat, slopes), collapse = " + ")
  fml <- as.formula(sprintf("%s ~ %s | %s", outcome, rhs,
                            paste(c(fes, ctrl), collapse = " + ")))
  feols(fml, data = dat, weights = ~weight, cluster = ~state_fips,
        ssc = SSC_REGHDFE, fixef.tol = 1e-10, warn = FALSE, notes = FALSE)
}

# Per-het-group effect: |weighted mean of pred_gap| over the treated pool,
# taking abs of the mean (as 02_mvpf.do does, `abs(r(mean))`), NA-robust
# (age_bracket is NA for 56-64, dropped from the demographic-control fit).
group_effects <- function(fit, pooldat, treatvar, het_var) {
  on  <- pooldat
  off <- pooldat; off[[treatvar]] <- 0L
  gap <- predict(fit, newdata = on) - predict(fit, newdata = off)
  tibble(g = pooldat[[het_var]], w = pooldat$weight, gap = gap) |>
    group_by(g) |>
    summarise(eff = abs(weighted.mean(gap, w, na.rm = TRUE)), .groups = "drop")
}

# (a) Regression + per-worker channel effects for a spec (independent of the
#     FT-PT counterfactual, so cached across ft_pt_cf).
effects_for_spec <- function(sample, contrs, spec_d, spec_u, spec_m, hetero,
                             design) {
  if (design == 1) {
    reg <- base |> filter(age <= (if (sample %in% c(0, 1)) 49 else 64))
  } else {
    reg <- switch(as.character(sample),
      "0" = base |> filter(age <= 49),
      "1" = base |> filter(education < 4, age <= 49),
      "2" = base,
      "3" = base |> filter(education < 4))
  }
  reg <- switch(as.character(contrs),
    "0" = reg |> filter(state_status > 0),
    "1" = reg |> filter(state_status > 0, state_fips %in% NOEITC_KEEP),
    "2" = reg |> filter(state_status > 0, state_fips %in% MEDICAID_KEEP))

  treatvar <- if (design == 1) "quad_treated" else "treated"
  het_var  <- c("placeholder", "year", "qc_ct", "hh_adult_ct")[hetero + 1]
  if (hetero == 0) reg$placeholder <- 1L

  ft <- fit_gap("full_time_y", reg, treatvar, hetero, design, spec_d, spec_u, spec_m)
  pt <- fit_gap("part_time_y", reg, treatvar, hetero, design, spec_d, spec_u, spec_m)

  agehi <- if (sample %in% c(0, 1)) 49 else 64
  sub <- function(d) {
    d <- d |> filter(age <= agehi)
    if (design == 1) d <- d |> filter(noncollege == 1) else
      if (sample %in% c(1, 3)) d <- d |> filter(education < 4)
    if (hetero == 0) d$placeholder <- 1L
    d
  }
  p  <- sub(pool)
  ta <- sub(treated_all)                     # for the total/PT weight scale

  ef <- group_effects(ft, p, treatvar, het_var) |> rename(effect_f = eff)
  ep <- group_effects(pt, p, treatvar, het_var) |> rename(effect_p = eff)
  sc <- ta |> group_by(g = .data[[het_var]]) |>
    summarise(scale = sum(weight) / sum(weight[part_time_y == 1]),
              .groups = "drop")
  eff <- full_join(ef, ep, by = "g") |> left_join(sc, by = "g") |>
    mutate(effect_f = coalesce(effect_f, 0), effect_p = coalesce(effect_p, 0),
           effect1 = pmin(effect_f, effect_p),
           effect2 = pmax(0, effect_p - effect_f))
  p |> mutate(g = .data[[het_var]]) |> left_join(eff, by = "g")
}

# (b) MVPF from a pool-with-effects, given the FT-PT counterfactual income.
DIRECT_REAL <- sum(DIRECT_COSTS[as.character(POST_YEARS)] *
                   CPI[as.character(POST_YEARS)]) / 1e6
mvpf_from_pool <- function(p, ft_pt_cf, meta) {
  ftcf <- c("ftmw", "med", "mean")[ft_pt_cf]
  cpi_y <- CPI[as.character(p$year)]; w <- p$weight * p$scale
  opt3 <- function(comp) sum(w * (p$effect1 * (p[[paste0(comp, ".calmax")]] -
                                               p[[paste0(comp, ".", ftcf)]]) +
                                  p$effect2 * (p[[paste0(comp, ".calmax")]] -
                                               p[[paste0(comp, ".zero")]])) *
                             cpi_y) / 1e6
  E <- sapply(COMPS, opt3)
  numerator <- DIRECT_REAL - E["caleitc"]
  d1 <- DIRECT_REAL; d2 <- d1 - E["fed_liab"]; d3 <- d2 - E["pay_liab"]
  d4 <- d3 - E["st_nocal_liab"]
  comps <- as.list(E); names(comps) <- paste0("eff_", COMPS)   # opt3 real $M
  data.frame(as.list(meta), ft_pt_cf,
             numerator, denom1 = d1, denom2 = d2, denom3 = d3, denom4 = d4,
             mvpf_1 = numerator/d1, mvpf_2 = numerator/d2,
             mvpf_3 = numerator/d3, mvpf_4 = numerator/d4,
             comps, direct_real = DIRECT_REAL, row.names = NULL)
}

# =============================================================================
# Spec grid (02_mvpf.do:653-725): cache the regression across ft_pt_cf.
# =============================================================================
regkeys <- list()
for (s in 0:3) for (c in 0:2) for (d in 0:1) for (g in 0:1) {
  u_max <- if (g == 1) 0 else 1; m_max <- if (g == 1) 0 else 1
  for (u in 0:u_max) for (m in 0:m_max) for (h in 0:2)
    regkeys[[length(regkeys) + 1]] <-
      c(sample = s, contrs = c, spec_d = d, spec_u = u, spec_m = m,
        hetero = h, design = g)
}
message("Regression keys: ", length(regkeys), " (x3 CF = ",
        length(regkeys) * 3, " models)")

res <- list()
for (k in seq_along(regkeys)) {
  a <- regkeys[[k]]
  out <- tryCatch({
    p <- effects_for_spec(a["sample"], a["contrs"], a["spec_d"], a["spec_u"],
                          a["spec_m"], a["hetero"], a["design"])
    lapply(1:3, function(i) mvpf_from_pool(p, i, a))
  }, error = function(e) {
    message("  regkey ", k, " FAILED: ", conditionMessage(e)); NULL })
  if (!is.null(out)) res <- c(res, out)
  if (k %% 30 == 0) message("  ", k, "/", length(regkeys))
}
models <- bind_rows(res)
message("Completed ", nrow(models), " models")

for (d in c("results/mvpf")) dir.create(d, showWarnings = FALSE, recursive = TRUE)
write.csv(models, path_data("tmp", "mvpf_models_r.csv"), row.names = FALSE)
saveRDS(models, path_data("tmp", "mvpf_r.rds"))

# --- Named specs + validation (golden 02_mvpf_log_2026-03-07) ----------------
pick <- function(df, ...) { f <- list(...); r <- df
  for (nm in names(f)) r <- r[r[[nm]] == f[[nm]], ]; r$mvpf_4 }
pref <- pick(models, sample=1, spec_d=1, spec_u=1, spec_m=1, contrs=0,
             hetero=2, ft_pt_cf=1, design=0)
quad <- pick(models, sample=1, spec_d=1, spec_u=0, spec_m=0, contrs=0,
             hetero=2, ft_pt_cf=1, design=1)   # design=1 forces spec_u/m=0
pref2 <- pick(models, sample=1, spec_d=1, spec_u=1, spec_m=1, contrs=0,
              hetero=2, ft_pt_cf=2, design=0)
message("\n=== MVPF results (deterministic; golden = unseeded MC draw) ===")
report <- function(label, got, want, tol) {
  ok <- length(got) == 1 && is.finite(got) && abs(got - want) <= tol
  message(sprintf("  [%s] %-24s got %8.4f  golden %8.4f (MC tol %.2f)",
                  if (ok) "OK" else "~~", label, got, want, tol)); ok }
pass <- c(
  report("preferred (triple)", pref,  0.8348, 0.06),
  report("quad-diff",          quad,  0.9052, 0.06),
  report("preferred (median)", pref2, 0.6130, 0.06),
  report("overall mean",       mean(models$mvpf_4), 0.7005, 0.05),
  report("overall min",        min(models$mvpf_4),  0.4320, 0.10),
  report("overall max",        max(models$mvpf_4),  0.9190, 0.10))
message(sprintf("Overall mvpf_4: mean %.3f sd %.3f min %.3f max %.3f (n=%d)",
                mean(models$mvpf_4), sd(models$mvpf_4), min(models$mvpf_4),
                max(models$mvpf_4), nrow(models)))
message(sprintf("\n=== VALIDATION: %d/%d within MC tolerance ===",
                sum(pass), length(pass)))

# By-dimension summary (02_mvpf.do:987-1017)
summ <- bind_rows(lapply(c("sample", "contrs", "hetero", "design"), function(v)
  models |> group_by(dim = v, level = .data[[v]]) |>
    summarise(mvpf_mean = mean(mvpf_4), mvpf_sd = sd(mvpf_4), n = n(),
              .groups = "drop")))
write.csv(summ, path_data("tmp", "mvpf_summary_r.csv"), row.names = FALSE)
print(as.data.frame(summ), row.names = FALSE)
message("MVPF STAGE COMPLETE")
