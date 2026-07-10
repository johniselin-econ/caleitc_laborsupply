# =============================================================================
# File:    38_quad_oster.R
# Purpose: PLAN.md par A / C — two coefficient-stability robustness tests that
#          address the college-placebo concern (a CA-specific trend in mothers'
#          employment), ported from 03_tab_quad_diff.do + 03_tab_oster_bounds.do.
#          One working-file load serves both.
#
#          Part A (quad-diff, 03_tab_quad_diff.do) — expands the sample to
#          college + non-college women and adds education as a fourth
#          difference dimension. Treatment is the 4-way interaction
#          noncollege x ca x post x qc_present; saturated 3-way FEs
#          (state#year#qc, state#year#noncollege, state#qc#noncollege,
#          year#qc#noncollege) subsume all lower-order interactions and absorb
#          the economic controls, so only 2 specs are needed (FEs only; FEs +
#          demographic controls). Outcomes employed/FT/PT (x100 -> pp) and
#          earnings (dollars). The 4-way term nets out any CA x post x QC
#          confounder common to both education groups.
#
#          Part B (Oster 2019 bounds, 03_tab_oster_bounds.do) — on the baseline
#          non-college sample, compares the restricted (spec 1, FEs only) and
#          full (spec 4, FEs + demographic + economic controls) triple-diff
#          treated coefficients and adjusted R-squareds to compute the
#          proportional selection delta* that would drive the coefficient to
#          zero, and the bias-adjusted beta at delta = 1, at Rmax = 1.3*R2_F
#          and Rmax = min(2*R2_F, 1). beta_R/beta_F reuse run_triple_diff
#          (validated in validate_tab_main.R); the only new quantity is
#          reghdfe's e(r2_a), matched here via fixest r2(fit, "ar2").
#
#          A GOLDEN block validates every quantity against the committed Stata
#          outputs (results/tables/tab_quad_diff_*.tex, tab_oster_bounds.tex;
#          reghdfe display values recovered from logs.zip 2026-03-06/07).
#
# Inputs:  data/final/acs_working_file_r.rds
# Output:  data/tmp/quad_diff_r.csv, data/tmp/oster_bounds_r.csv,
#          data/tmp/quad_oster_r.rds
#
# Usage:   Rscript code/38_quad_oster.R  (cluster: stage19_quad_oster.sbatch;
#          the full college+non-college sample is ~760k rows with 4-way FEs)
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
source(file.path("code", "lib", "estimation.R"))
suppressPackageStartupMessages(library(dplyr))

OUTS <- c("employed_y", "full_time_y", "part_time_y")

# reghdfe e(r2_a): adjusted R-squared counting the absorbed-FE degrees of
# freedom. fixest computes the same from the overall R2 and its collinearity-
# adjusted parameter count; expose it directly for validation.
r2a <- function(fit) as.numeric(fixest::r2(fit, "ar2"))

## Load working file once ----------------------------------------------------------
message("Loading working file ...")
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))

sel <- c("weight", "year", "state_fips", "state_status", "qc_ct", "qc_present",
         "employed_y", "full_time_y", "part_time_y", "incearn_real",
         "education", "age_bracket", "minage_qc", "race_group", "hispanic",
         "hh_adult_ct", "female", "married", "in_school", "age_sample_20_49",
         "citizen_test", "state_unemp", "mean_st_mw")

common <- function(d) {
  filter(d, female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
         citizen_test == 1, state_status > 0,
         year >= params$years$analysis_start,
         year <= params$years$analysis_end)
}

# Part A sample: full (college + non-college); Part B: baseline (education < 4)
quad <- wf |> select(all_of(sel)) |> common()
base <- quad |> filter(education < 4)
rm(wf); invisible(gc())
message("Quad-diff sample (all education): N = ", nrow(quad))
message("Baseline sample (non-college):    N = ", nrow(base))

# =============================================================================
# PART A — Quadruple-difference (03_tab_quad_diff.do)
# =============================================================================
quad <- setup_did_vars(quad) |>          # ca, post, hh_adult_ct cap (treated unused)
  mutate(noncollege    = as.integer(education < 4),
         quad_treated  = as.integer(noncollege == 1 & ca == 1 &
                                    post == 1 & qc_present == 1)) |>
  mutate(across(all_of(OUTS), ~ .x * 100),
         incearn_real = ifelse(is.na(incearn_real), 0, incearn_real))

# Saturated 3-way FEs (03_tab_quad_diff.do:78) + demographic controls
# (:34 — education excluded, absorbed by the noncollege interactions).
QUAD_FES      <- c("state_fips^year^qc_ct", "state_fips^year^noncollege",
                   "state_fips^qc_ct^noncollege", "year^qc_ct^noncollege")
QUAD_CONTROLS <- c("age_bracket", "minage_qc", "race_group", "hispanic",
                   "hh_adult_ct")
n_treated <- sum(quad$quad_treated == 1)   # unweighted count (Stata: count if)

run_quad <- function(outcome, controls = NULL) {
  fml <- as.formula(paste(outcome, "~ quad_treated |",
                          paste(c(QUAD_FES, controls), collapse = " + ")))
  feols(fml, data = quad, weights = ~weight, cluster = ~state_fips,
        ssc = SSC_REGHDFE, fixef.tol = 1e-10)
}
# Pre-period treated-group (non-college, CA, with QC) weighted outcome mean
ymean_quad <- function(outcome) {
  d <- quad |> filter(post == 0, ca == 1, qc_present == 1, noncollege == 1)
  weighted.mean(d[[outcome]], d$weight)
}

quad_rows <- list()
for (out in c(OUTS, "incearn_real")) {
  is_earn <- out == "incearn_real"
  for (s in 1:2) {
    fit <- run_quad(out, controls = if (s == 2) QUAD_CONTROLS else NULL)
    ct  <- coeftable(fit)["quad_treated", ]
    quad_rows[[paste(out, s)]] <- data.frame(
      outcome = out, spec = s, b = ct[1], se = ct[2], p = ct[4],
      n = nobs(fit), r2a = r2a(fit), ymean = ymean_quad(out),
      # Implied effect (employment only, undo the x100 scaling): n_treated * b/100
      C = if (is_earn) NA_real_ else n_treated * ct[1] / 100)
  }
}
quad_df <- bind_rows(quad_rows)
write.csv(quad_df, path_data("tmp", "quad_diff_r.csv"), row.names = FALSE)
message("\n=== Part A: quad-diff (quad_treated), by outcome x spec ===")
print(quad_df |> mutate(across(c(b, se, p, r2a, ymean, C), \(x) round(x, 3))),
      row.names = FALSE)

# =============================================================================
# PART B — Oster (2019) bounds (03_tab_oster_bounds.do)
# =============================================================================
base <- setup_did_vars(base) |>
  mutate(across(all_of(OUTS), ~ .x * 100),
         incearn_real = ifelse(is.na(incearn_real), 0, incearn_real))

oster_one <- function(outcome) {
  # Restricted (spec 1): FEs only.  Full (spec 4): FEs + demographic + economic.
  restr <- run_triple_diff(outcome, base)
  full  <- run_triple_diff(outcome, base, controls = CONTROLS,
                           unempvar = "state_unemp", minwagevar = "mean_st_mw",
                           qcvar = "qc_ct")
  beta_R <- coef(restr)["treated"]; R2_R <- r2a(restr)
  beta_F <- coef(full)["treated"];  R2_F <- r2a(full)

  Rmax_13 <- min(1.3 * R2_F, 1)
  Rmax_2R <- min(2   * R2_F, 1)
  denom   <- (beta_R - beta_F) * (R2_F - R2_R)      # 03_tab_oster_bounds.do:113
  R2_diff <- R2_F - R2_R

  delta_13 <- if (abs(denom)   > 1e-10) beta_F * (Rmax_13 - R2_F) / denom else NA
  delta_2R <- if (abs(denom)   > 1e-10) beta_F * (Rmax_2R - R2_F) / denom else NA
  badj_13  <- if (abs(R2_diff) > 1e-10)
                beta_F - (beta_R - beta_F) * (Rmax_13 - R2_F) / R2_diff else beta_F
  badj_2R  <- if (abs(R2_diff) > 1e-10)
                beta_F - (beta_R - beta_F) * (Rmax_2R - R2_F) / R2_diff else beta_F

  data.frame(outcome = outcome, beta_R = beta_R, beta_F = beta_F,
             R2_R = R2_R, R2_F = R2_F, delta_13 = delta_13, beta_adj_13 = badj_13,
             delta_2R = delta_2R, beta_adj_2R = badj_2R, row.names = NULL)
}

oster_df <- bind_rows(lapply(c(OUTS, "incearn_real"), oster_one))
write.csv(oster_df, path_data("tmp", "oster_bounds_r.csv"), row.names = FALSE)
message("\n=== Part B: Oster (2019) bounds ===")
print(oster_df |> mutate(across(-outcome, \(x) round(x, 3))), row.names = FALSE)

saveRDS(list(quad = quad_df, oster = oster_df, n_treated = n_treated),
        path_data("tmp", "quad_oster_r.rds"))

# =============================================================================
# GOLDEN validation — committed Stata outputs (tab_quad_diff_*.tex,
# tab_oster_bounds.tex) + reghdfe display values from logs.zip 2026-03-06/07.
# =============================================================================
report <- function(label, got, want, tol) {
  ok <- is.finite(got) && is.finite(want) && abs(got - want) <= tol
  message(sprintf("  [%s] %-28s got %12.4f  want %12.4f  (tol %.4g)",
                  if (ok) "OK" else "XX", label, got, want, tol))
  ok
}
message("\n=== GOLDEN validation ===")
pass <- logical(0)

# Quad-diff: (outcome, spec) -> c(b, se, r2a) ; N = 761,195 all cells
g_quad <- list(
  "employed_y 1"  = c(1.824254, 0.3793469, 0.0628),
  "employed_y 2"  = c(1.592066, 0.3598176, 0.0784),
  "full_time_y 1" = c(-0.0799746, 0.6662648, 0.0795),
  "full_time_y 2" = c(-0.1762789, 0.6507362, 0.1026),
  "part_time_y 1" = c(1.904228, 0.5634992, 0.0135),
  "part_time_y 2" = c(1.768345, 0.5821093, 0.0353),
  "incearn_real 1" = c(-410.9, 463.7, 0.156),
  "incearn_real 2" = c(-256.0, 416.5, 0.212))
for (k in names(g_quad)) {
  r <- quad_df[paste(quad_df$outcome, quad_df$spec) == k, ]
  w <- g_quad[[k]]
  is_earn <- startsWith(k, "incearn")
  pass <- c(pass,
    report(paste0("quad b  ", k), r$b,   w[1], if (is_earn) 0.1 else 1e-3),
    report(paste0("quad se ", k), r$se,  w[2], if (is_earn) 0.1 else 1e-3),
    report(paste0("quad r2a ", k), r$r2a, w[3], 5e-4))
  pass <- c(pass, report(paste0("quad N  ", k), r$n, 761195, 0))
}

# Oster: golden matrix from tab_oster_bounds.tex (+ 4-dp R2 from the log)
g_ost <- list(
  employed_y   = c(0.828, -0.335, 0.0088, 0.0742, -0.10, -0.730, -0.33, -1.653),
  full_time_y  = c(-2.223, -4.077, 0.0077, 0.0669, -0.75, -4.705, -2.49, -6.172),
  part_time_y  = c(3.051, 3.742, 0.0030, 0.0270, -1.84, 3.977, -6.14, 4.525),
  incearn_real = c(-598.8, -1509.4, 0.0110, 0.0990, -0.56, -1817.7, -1.87, -2536.9))
onm <- c("beta_R", "beta_F", "R2_R", "R2_F",
         "delta_13", "beta_adj_13", "delta_2R", "beta_adj_2R")
for (o in names(g_ost)) {
  r <- oster_df[oster_df$outcome == o, ]
  w <- g_ost[[o]]
  is_earn <- o == "incearn_real"
  btol <- if (is_earn) 0.1 else 1e-3       # coefficients
  for (j in seq_along(onm)) {
    tol <- if (j %in% c(3, 4)) 5e-4        # R2 (4-dp golden)
           else if (j %in% c(5, 7)) 5e-3   # delta* (2-dp golden)
           else if (j %in% c(6, 8)) (if (is_earn) 0.1 else 1e-2)  # beta_adj (3-dp)
           else btol
    pass <- c(pass, report(paste0("oster ", onm[j], " ", o), r[[onm[j]]], w[j], tol))
  }
}

n_ok <- sum(pass); n_tot <- length(pass)
message(sprintf("\n=== VALIDATION: %d/%d checks passed ===", n_ok, n_tot))
if (n_ok < n_tot) message("  (mismatches above — inspect before staging)")
message("QUAD + OSTER STAGE COMPLETE")
