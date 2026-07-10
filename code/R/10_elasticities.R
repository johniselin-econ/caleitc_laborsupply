# =============================================================================
# File:    10_elasticities.R
# Purpose: Phase 4a — participation and mobility elasticities, ported from
#          02_elasticities.do. Straight mechanical port (NOT a deliberate-break
#          port): the participation elasticities use taxsim_sim3_atr_st (the
#          audit-verified sim-3 ATR) and the DiD fits reuse run_triple_diff;
#          the mobility elasticity uses caleitc_params.txt kink points (audit-
#          verified) + a 32-scenario TAXSIM run. Both validated in-run against
#          the committed Stata golden (logs.zip 02_elasticities_2026-03-07).
#
#          Participation elasticity (extensive margin), per 02_elasticities.do
#          Section 3-5:
#            E = (beta / P_base) / [ delta(1-ATR) / (1-ATR) ]
#          beta = triple-diff coef on part-time (spec 4: FEs + demographic +
#          economic controls); ATR change = triple-diff coef on the sim-3 ATR
#          (spec 1: FEs only); P_base and the pre-period ATR are treated-group
#          (CA x QC x pre) weighted means. Adjusted variants net the full-time
#          coefficient (FT->PT) or the full-time-in-$27k-bin coefficient.
#
#          Mobility elasticity (Section 6): ln(P+beta)-ln(P) over the log net-
#          of-tax earnings differential between the CalEITC kink and three
#          alternative work levels (FT at the 2017 minimum wage, the 2014
#          full-time-mother median 30,655, and mean 36,413), for 2014 vs 2017,
#          weighted by the 2017 California QC-count distribution. Uses TAXSIM
#          with dependent ages set to 6 (age1/2/3 in the Stata script), so the
#          call sets dep13=dep17=dep18=depx alongside run_taxsim35's variables.
#
# Inputs:  data/final/acs_working_file_r.rds,
#          data/eitc_parameters/caleitc_params.txt, ~/ado/plus/t/taxsim35.exe
# Output:  data/tmp/elasticities_r.rds, data/tmp/elast_participation_r.csv,
#          data/tmp/elast_mobility_r.csv, data/tmp/elast_qc_shares_r.csv
#
# Usage:   Rscript code/R/10_elasticities.R  (cluster: stage21_elasticities.sbatch)
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
source(file.path("code", "R", "utils", "estimation.R"))
suppressPackageStartupMessages({library(dplyr); library(readr); library(tidyr)})

wmean <- function(x, w) { ok <- !is.na(x) & !is.na(w); sum(x[ok]*w[ok])/sum(w[ok]) }
bcoef <- function(fit) as.numeric(coef(fit)["treated"])

## Load baseline sample (02_elasticities.do:76-96; education<=3 == education<4)
message("Loading working file ...")
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
base <- wf |>
  filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
         citizen_test == 1, education < 4, state_status > 0,
         year >= 2012, year <= 2017) |>
  select(weight, year, state_fips, state_status, qc_ct, qc_present,
         part_time_y, full_time_y, taxsim_sim3_atr_st, incearn_real,
         education, age_bracket, minage_qc, race_group, hispanic, hh_adult_ct,
         state_unemp, mean_st_mw)
message("Elasticities sample: N = ", nrow(base))
base <- setup_did_vars(base) |>            # ca, post = year>2014, treated
  mutate(ft_27k = as.integer(full_time_y == 1 &
                             incearn_real >= 24000 & incearn_real < 30000))

# =============================================================================
# PARTICIPATION ELASTICITY
# =============================================================================
tg <- base |> filter(qc_present == 1, ca == 1, post == 0)   # treated, pre-period
atr_pre    <- wmean(tg$taxsim_sim3_atr_st, tg$weight)
netoftax   <- 1 - atr_pre
P_base     <- wmean(tg$part_time_y, tg$weight)

spec4 <- function(out) run_triple_diff(out, base, controls = CONTROLS,
                        unempvar = "state_unemp", minwagevar = "mean_st_mw",
                        qcvar = "qc_ct")
delta_atr <- bcoef(run_triple_diff("taxsim_sim3_atr_st", base))  # spec 1, no controls
denom     <- (-delta_atr) / netoftax
beta_pt   <- bcoef(spec4("part_time_y"))
beta_ft   <- bcoef(spec4("full_time_y"))
beta_ft27 <- bcoef(spec4("ft_27k"))

e_part      <- (beta_pt / P_base) / denom
beta_adj    <- max(beta_pt + beta_ft, 0)
e_part_adj  <- (beta_adj / P_base) / denom
beta_adj27  <- max(beta_pt + beta_ft27, 0)
e_part_27k  <- (beta_adj27 / P_base) / denom

part <- data.frame(
  atr_pre = atr_pre, netoftax = netoftax, delta_atr = delta_atr, denom = denom,
  P_base = P_base, beta_pt = beta_pt, beta_ft = beta_ft, beta_ft27 = beta_ft27,
  e_part = e_part, e_part_adj = e_part_adj, e_part_27k = e_part_27k)
write.csv(part, path_data("tmp", "elast_participation_r.csv"), row.names = FALSE)
message("\n=== Participation elasticity ===")
print(t(round(part, 5)))

# =============================================================================
# MOBILITY ELASTICITY  (Section 6)
# =============================================================================
# QC-count distribution: 2017 California, qc>0 (02_elasticities.do:324-344)
qc_sh <- base |>
  filter(year == 2017, state_fips == 6, qc_ct > 0) |>
  group_by(depx = qc_ct) |> summarise(ct = sum(weight), .groups = "drop") |>
  mutate(share = ct / sum(ct)) |> select(depx, share)
write.csv(qc_sh, path_data("tmp", "elast_qc_shares_r.csv"), row.names = FALSE)
message("\nQC shares (2017 CA, qc>0):"); print(qc_sh)

# CalEITC kink points (caleitc_params.txt), 2014 (pre) + 2017 (post)
kp <- read_delim(path_data("eitc_parameters", "caleitc_params.txt"),
                 delim = "\t", show_col_types = FALSE) |>
  transmute(year = tax_year, depx = qc_ct,
            pwages = suppressWarnings(as.numeric(pwages)),
            pwages_unadj = suppressWarnings(as.numeric(pwages_unadj))) |>
  filter(year %in% c(2014, 2017))

FT_MINWAGE <- 10.50 * 40 * 52   # 21,840 (02_elasticities.do:400)
scen <- tidyr::expand_grid(depx = 0:3, year = c(2014, 2017), work = 1:4) |>
  left_join(kp, by = c("year", "depx")) |>
  mutate(pw = case_when(
    work == 1 & year == 2014 ~ pwages_unadj,
    work == 1 & year == 2017 ~ pwages,
    work == 2 ~ FT_MINWAGE,
    work == 3 ~ 30655,           # 2014 FT-mother median (02_elasticities.do:404)
    work == 4 ~ 36413)) |>       # 2014 FT-mother mean   (:407)
  mutate(taxsimid = row_number(),
         state = 5, mstat = 1, page = 30, sage = 0,   # CA=5 (TAXSIM SOI code), single
         depx_kids = depx, dep13 = depx, dep17 = depx, dep18 = depx,  # kids age 6
         swages = 0, intrec = 0, otherprop = 0, psemp = 0, ssemp = 0,
         pwages = pw)

# TAXSIM call with dependent ages (age1/2/3=6 in Stata -> dep13/17/18 = depx).
# Mirrors run_taxsim35's send format but adds the dep-age columns.
run_taxsim_ages <- function(df, exe = path.expand("~/ado/plus/t/taxsim35.exe")) {
  vars <- c("taxsimid","year","state","mstat","page","sage","depx",
            "dep13","dep17","dep18","pwages","swages","intrec","otherprop",
            "psemp","ssemp")
  send <- df |> mutate(mtr = 85, idtl = 2) |>
    mutate(idtl = ifelse(row_number() == n(), 12L, idtl)) |>
    select(mtr, idtl, all_of(vars))
  inf <- tempfile(fileext = ".raw"); outf <- tempfile(fileext = ".raw")
  readr::write_csv(send, inf)
  st <- system2(exe, stdin = inf, stdout = outf, stderr = FALSE)
  if (st != 0) stop("taxsim35 exited ", st)
  suppressWarnings(readr::read_csv(outf, show_col_types = FALSE, guess_max = 1e6)) |>
    mutate(taxsimid = suppressWarnings(as.numeric(taxsimid))) |>
    filter(!is.na(taxsimid))
}
res <- run_taxsim_ages(scen) |>
  transmute(taxsimid = as.integer(taxsimid),
            gross = v10, total_tax = fiitax + siitax + fica) |>
  mutate(net = gross - total_tax)

# net-of-tax earnings per (depx, year, work); differentials vs kink (work 1)
netw <- scen |> select(taxsimid, depx, year, work) |>
  left_join(res, by = "taxsimid") |>
  select(depx, year, work, net) |>
  pivot_wider(names_from = c(year, work), values_from = net,
              names_prefix = "n")
d <- netw |>
  transmute(depx,
    diff_ft_2017   = abs(n2017_1 - n2017_2), diff_ft_2014   = abs(n2014_1 - n2014_2),
    diff_med_2017  = abs(n2017_1 - n2017_3), diff_med_2014  = abs(n2014_1 - n2014_3),
    diff_mean_2017 = abs(n2017_1 - n2017_4), diff_mean_2014 = abs(n2014_1 - n2014_4)) |>
  mutate(log_denom_ft   = log(diff_ft_2017)   - log(diff_ft_2014),
         log_denom_med  = log(diff_med_2017)  - log(diff_med_2014),
         log_denom_mean = log(diff_mean_2017) - log(diff_mean_2014),
         log_numer = log(P_base + beta_pt) - log(P_base),
         e_mob_ft   = log_numer / log_denom_ft,
         e_mob_med  = log_numer / log_denom_med,
         e_mob_mean = log_numer / log_denom_mean) |>
  left_join(qc_sh, by = "depx")

mob <- d |> filter(!is.na(share)) |>
  summarise(across(c(e_mob_ft, e_mob_med, e_mob_mean), ~ wmean(.x, share)))
write.csv(d, path_data("tmp", "elast_mobility_r.csv"), row.names = FALSE)
message("\n=== Mobility elasticity (per depx) ===")
print(d |> select(depx, e_mob_ft, e_mob_med, e_mob_mean, share) |>
        mutate(across(-depx, \(x) round(x, 4))))
message("Weighted: FT-minwage ", round(mob$e_mob_ft, 3),
        " | median ", round(mob$e_mob_med, 3),
        " | mean ", round(mob$e_mob_mean, 3))

saveRDS(list(participation = part, mobility = d, mob_wt = mob, qc = qc_sh),
        path_data("tmp", "elasticities_r.rds"))

# =============================================================================
# GOLDEN validation (logs.zip 02_elasticities_2026-03-07)
# =============================================================================
report <- function(label, got, want, tol) {
  ok <- is.finite(got) && abs(got - want) <= tol
  message(sprintf("  [%s] %-26s got %10.4f  want %10.4f (tol %.4g)",
                  if (ok) "OK" else "XX", label, got, want, tol)); ok
}
message("\n=== GOLDEN validation ===")
pass <- c(
  report("N",             nrow(base), 461616,   0),
  report("atr_pre",       atr_pre,    -0.2124,  5e-4),
  report("delta_atr",     delta_atr,  -0.18330, 5e-5),
  report("denom",         denom,       0.15118, 5e-5),
  report("P_base",        P_base,      0.2036,  5e-4),
  report("beta_pt",       beta_pt,     0.03768, 5e-5),
  report("beta_ft",       beta_ft,    -0.04062, 5e-5),
  report("beta_ft27",     beta_ft27,  -0.00454, 5e-5),
  report("e_part",        e_part,      1.225,   1e-3),
  report("e_part_adj",    e_part_adj,  0.000,   1e-3),
  report("e_part_27k",    e_part_27k,  1.077,   1e-3),
  report("mob_ft (wt)",   mob$e_mob_ft,   -1.217, 5e-3),
  report("mob_med (wt)",  mob$e_mob_med,  -1.652, 5e-3),
  report("mob_mean (wt)", mob$e_mob_mean, -1.922, 5e-3))
# per-depx mobility (golden table)
gm <- list("1" = c(-1.573096, -2.159069, -2.506963),
           "2" = c(-0.9414788, -1.243091, -1.463422),
           "3" = c(-0.8886511, -1.209579, -1.389724))
for (k in names(gm)) {
  r <- d[d$depx == as.integer(k), ]
  pass <- c(pass,
    report(paste0("mob_ft depx",k),   r$e_mob_ft,   gm[[k]][1], 5e-3),
    report(paste0("mob_med depx",k),  r$e_mob_med,  gm[[k]][2], 5e-3),
    report(paste0("mob_mean depx",k), r$e_mob_mean, gm[[k]][3], 5e-3))
}
message(sprintf("\n=== VALIDATION: %d/%d checks passed ===", sum(pass), length(pass)))
message("ELASTICITIES STAGE COMPLETE")
