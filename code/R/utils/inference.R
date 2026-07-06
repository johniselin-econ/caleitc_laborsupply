# =============================================================================
# File:    inference.R
# Purpose: R ports of the Appendix E alternative-inference battery
#          (04_appE_inference.do / 04_appE_inference_programs.do, as fixed in
#          Phase 0 and re-run under the +1 convention — SLURM job 17058169 is
#          the golden benchmark).
#
#          Methods:
#            appE_crve_p — CRVE p-value (t on G-1 = 27 dof, reghdfe e(df_r))
#            appE_wcbs   — wild cluster bootstrap via fwildclusterboot
#                          (upgrade path per PLAN.md §B; Stata used the
#                          built-in `wildbootstrap` on the areg variant)
#            appE_fp     — Ferman-Pinto (2019) block bootstrap, with and
#                          without the heteroskedasticity correction
#            appE_riwb   — randomization-inference wild bootstrap
#                          (MacKinnon-Webb 2019/2020)
#
#          Conventions locked in from the Phase 0 fixes:
#          - p-values use (1 + #exceed)/(1 + B or S) (Phipson-Smyth 2010),
#            weak inequality, so p is never exactly zero;
#          - RIWB reference distribution is placebo draws only (j >= 1);
#            j = 0 wild draws are kept for diagnostics;
#          - placebo refits keep CA in the sample as an untreated unit with
#            the identical design (MacKinnon-Webb 2020); only the placebo
#            ASSIGNMENT set excludes it;
#          - FP finite-sample correction follows the PARALLEL program
#            semantics (two sequential replaces, 04_appE_inference_programs
#            .do:104-105), which produced the golden run.
#
#          RNG note: R draws cannot reproduce Stata's uniform() streams.
#          Deterministic layers (refits, FP state-level table) validate
#          exactly against the stage-11 Stata dumps; resampling p-values
#          validate within Monte-Carlo bands against the golden tables
#          (see code/R/validate/validate_inference_det.R).
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
})
# estimation.R must be sourced first (SSC_REGHDFE, DID_BASE, CONTROLS)

N_CLUSTERS <- 28  # control-pool states + CA; CRVE dof = G - 1 = 27

# -----------------------------------------------------------------------------
# Sample and specifications (04_appE_inference.do:442-519)
# -----------------------------------------------------------------------------

appE_sample <- function(wf, start_year = 2012, end_year = 2017) {
  wf |>
    filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
           citizen_test == 1, state_status > 0, education < 4,
           year >= start_year, year <= end_year) |>
    mutate(employed_y  = 100 * employed_y,
           full_time_y = 100 * full_time_y,
           part_time_y = 100 * part_time_y,
           ca          = as.integer(state_fips == 6),
           treated     = as.integer(state_fips == 6 & qc_present == 1 &
                                      year >= 2015),
           post        = as.integer(year >= 2015),
           hh_adult_ct = pmin(hh_adult_ct, 3),
           minwage     = mean_st_mw,
           pot_treat   = as.integer(qc_present == 1 & year >= 2015),
           grp_state_year = as.integer(interaction(state_fips, year,
                                                   drop = TRUE)),
           grp_state_qc   = as.integer(interaction(state_fips, qc_ct,
                                                   drop = TRUE)),
           grp_year_qc    = as.integer(interaction(year, qc_ct, drop = TRUE)))
}

# Spec k -> which pieces enter (mirrors did1-did4/unemp/controls locals)
appE_spec <- function(spec) {
  list(controls = if (spec >= 2) CONTROLS else NULL,
       unemp    = if (spec >= 3) "state_unemp" else NULL,
       minwage  = if (spec >= 4) "minwage" else NULL)
}

# reghdfe-equivalent fit for the appE design. include_treat = FALSE gives the
# null model (used for FP/RIWB residuals); treatvar lets the RIWB swap in
# placebo assignments. Reuses the run_triple_diff conventions (ref = max qc
# level for the interacted state-year controls, nested ssc, tight fixef.tol).
appE_fit <- function(outcome, data, spec, include_treat = TRUE,
                     treatvar = "treated") {
  sp <- appE_spec(spec)
  rhs <- if (include_treat) treatvar else NULL
  for (v in c(sp$unemp, sp$minwage)) {
    ref <- max(data$qc_ct, na.rm = TRUE)
    rhs <- c(rhs, paste0("i(qc_ct, ", v, ", ref = ", ref, ")"))
  }
  fml <- as.formula(paste(
    outcome, "~", if (length(rhs)) paste(rhs, collapse = " + ") else "1",
    "|", paste(c(DID_BASE, sp$controls), collapse = " + ")))
  feols(fml, data = data, weights = ~weight, cluster = ~state_fips,
        ssc = SSC_REGHDFE, fixef.tol = 1e-10)
}

# Extract (beta, se, t) for a treatment regressor
fit_stats <- function(fit, param) {
  ct <- coeftable(fit)
  c(b = ct[param, "Estimate"], se = ct[param, "Std. Error"],
    t = ct[param, "Estimate"] / ct[param, "Std. Error"])
}

# CRVE p-value: 2 * ttail(e(df_r), |t|), reghdfe df_r = G - 1 under
# vce(cluster) with nested FEs
appE_crve_p <- function(t_stat, G = N_CLUSTERS) {
  2 * pt(abs(t_stat), df = G - 1, lower.tail = FALSE)
}

# -----------------------------------------------------------------------------
# Wild cluster bootstrap (04_appE_inference.do:551-563)
# Stata ran `wildbootstrap areg ... absorb(grp_state_year)` with explicit
# dummies for the remaining FEs; we mirror that design (WCR, Rademacher,
# null imposed) via fwildclusterboot on the equivalent fixest fit.
# -----------------------------------------------------------------------------

appE_wcbs <- function(outcome, data, spec, B = 1000, seed) {
  sp <- appE_spec(spec)
  rhs <- "treated"
  for (v in c(sp$unemp, sp$minwage)) {
    ref <- max(data$qc_ct, na.rm = TRUE)
    rhs <- c(rhs, paste0("i(qc_ct, ", v, ", ref = ", ref, ")"))
  }
  rhs <- c(rhs, "factor(state_fips)", "factor(qc_ct)", "factor(year)",
           "factor(grp_state_qc)", "factor(grp_year_qc)",
           paste0("factor(", sp$controls, ")"))
  fml <- as.formula(paste(outcome, "~", paste(rhs, collapse = " + "),
                          "| grp_state_year"))
  fit <- feols(fml, data = data, weights = ~weight, cluster = ~state_fips,
               ssc = SSC_REGHDFE)
  bt <- suppressWarnings(fwildclusterboot::boottest(
    fit, param = "treated", clustid = "state_fips", B = B,
    type = "rademacher", impose_null = TRUE, fe = "grp_state_year",
    seed = seed))
  list(p = bt$p_val, boot = bt)
}

# -----------------------------------------------------------------------------
# Ferman-Pinto (2019) block bootstrap
# (04_appE_inference_programs.do:21-255; cells are state x year x qc_present)
# -----------------------------------------------------------------------------

# Deterministic prep: state-level W, q, P, var_M, W_normalized + alpha_hat.
# Validated exactly against the stage-11 Stata dump.
appE_fp_prep <- function(outcome, data, spec) {
  main <- appE_fit(outcome, data, spec, include_treat = TRUE)
  null <- appE_fit(outcome, data, spec, include_treat = FALSE)
  stopifnot(main$nobs == nrow(data), null$nobs == nrow(data))
  alpha_hat <- unname(coeftable(main)["treated", "Estimate"])

  df <- data |>
    mutate(eta = as.numeric(resid(null)),
           post = as.integer(year >= 2015))

  cells <- df |>
    group_by(state_fips, year, qc_present) |>
    summarise(ca = first(ca), post = first(post),
              P = sum(weight),
              eta_qjt = sum(eta * weight) / sum(weight),
              omega2 = sum(weight^2), .groups = "drop")

  # Pr_q1t: CA's year share of CA post-period-p x QC-group weight
  ca_tot <- cells |>
    filter(ca == 1) |>
    group_by(qc_present, post) |>
    summarise(P_q1p = sum(P), .groups = "drop")
  pr <- cells |>
    filter(ca == 1) |>
    left_join(ca_tot, by = c("qc_present", "post")) |>
    transmute(year, qc_present, Pr_q1t = P / P_q1p)

  cells <- cells |>
    left_join(pr, by = c("year", "qc_present")) |>
    mutate(sign = ifelse(post == qc_present, 1, -1),
           W_comp = sign * Pr_q1t * eta_qjt,
           q = Pr_q1t^2 * omega2 / P^2)

  state <- cells |>
    group_by(state_fips) |>
    summarise(ca = mean(ca), W = sum(W_comp), q = sum(q), P = sum(P),
              .groups = "drop") |>
    arrange(state_fips)

  # var(W | M): WLS of centered-squared W on q, weights P
  wbar <- weighted.mean(state$W, state$P)
  vfit <- lm(I((W - wbar)^2) ~ q, data = state, weights = P)
  var_M <- unname(fitted(vfit))
  # Finite-sample correction — PARALLEL program semantics (two sequential
  # replaces; the second overwrites if both slopes are negative)
  if (min(var_M) < 0) {
    if (coef(vfit)[["q"]] < 0) var_M <- rep(1, nrow(state))
    if (coef(vfit)[["(Intercept)"]] < 0) var_M <- state$q
  }
  state$var_M <- var_M
  state$W_normalized <- state$W / sqrt(var_M)
  state$alpha_hat <- alpha_hat

  state
}

appE_fp <- function(outcome, data, spec, B = 1000, seed, state = NULL) {
  if (is.null(state)) state <- appE_fp_prep(outcome, data, spec)
  alpha_hat <- state$alpha_hat[1]
  n <- nrow(state)
  treated_pos <- which(state$ca == 1)
  ctrl <- state$ca == 0
  sumPc <- sum(state$P[ctrl])

  set.seed(seed)
  alpha1 <- numeric(B)
  alpha2 <- numeric(B)
  for (b in seq_len(B)) {
    idx <- sample.int(n, n, replace = TRUE)
    W_tilde <- state$W[idx]
    # corrected draw: resampled normalized W, rescaled by the POSITION's var_M
    W_corr <- state$W_normalized[idx] * sqrt(state$var_M)
    alpha1[b] <- mean(W_tilde[treated_pos]) -
      sum(W_tilde[ctrl] * state$P[ctrl]) / sumPc
    alpha2[b] <- mean(W_corr[treated_pos]) -
      sum(W_corr[ctrl] * state$P[ctrl]) / sumPc
  }

  a2 <- alpha_hat^2
  list(p_without = (1 + sum(alpha1^2 >= a2)) / (1 + B),
       p_with    = (1 + sum(alpha2^2 >= a2)) / (1 + B),
       alpha_hat = alpha_hat, state = state,
       draws = data.frame(b = seq_len(B), alpha1 = alpha1, alpha2 = alpha2))
}

# -----------------------------------------------------------------------------
# Randomization-inference wild bootstrap (MacKinnon-Webb)
# (04_appE_inference_programs.do:265-428)
# -----------------------------------------------------------------------------

# Deterministic layer: actual fit (j = 0) + placebo refits (j = 1..n, dense
# rank of sorted non-CA state fips). Validated against the stage-11 dump.
appE_ri_refits <- function(outcome, data, spec) {
  placebo_states <- sort(unique(data$state_fips[data$state_fips != 6]))
  out <- vector("list", length(placebo_states) + 1)

  s0 <- fit_stats(appE_fit(outcome, data, spec), "treated")
  out[[1]] <- data.frame(j = 0, state_fips = 6, b = s0[["b"]], t = s0[["t"]])

  for (j in seq_along(placebo_states)) {
    data$ptreat <- as.integer(data$state_fips == placebo_states[j] &
                                data$pot_treat == 1)
    sj <- fit_stats(appE_fit(outcome, data, spec, treatvar = "ptreat"),
                    "ptreat")
    out[[j + 1]] <- data.frame(j = j, state_fips = placebo_states[j],
                               b = sj[["b"]], t = sj[["t"]])
  }
  do.call(rbind, out)
}

# -----------------------------------------------------------------------------
# Conley-Taber (2011) confidence intervals — NEW in Phase 3, not a port
# (PLAN.md §B: the canonical single-treated-state method).
# Uses the placebo-refit estimates as the empirical distribution of the
# common shock: CI = [b0 - Q(1-a/2), b0 - Q(a/2)] over the placebo b_j
# (Conley-Taber 2011 §IV; same machinery as the RIWB deterministic layer).
# With 27 placebo states the empirical quantiles are coarse — inverse-ECDF
# (type 1) quantiles, no interpolation; convention flagged for author review.
# Also returns the implied RI p-value on b (equals the RIWB beta p-value's
# refit-only analogue): (1 + #{|b_j| >= |b0|}) / (1 + n_placebo).
# -----------------------------------------------------------------------------

conley_taber <- function(refits, level = 0.90) {
  b0 <- refits$b[refits$j == 0]
  placebo <- refits$b[refits$j >= 1]
  a <- 1 - level
  qs <- quantile(placebo, c(a / 2, 1 - a / 2), type = 1, names = FALSE)
  list(att = b0, level = level,
       lower = b0 - qs[2], upper = b0 - qs[1],
       p_ri = (1 + sum(abs(placebo) >= abs(b0))) / (1 + length(placebo)),
       n_placebo = length(placebo))
}

appE_riwb <- function(outcome, data, spec, B = 100, seed,
                      refits = NULL, progress = interactive()) {
  if (is.null(refits)) refits <- appE_ri_refits(outcome, data, spec)
  b0 <- refits$b[refits$j == 0]
  t0 <- refits$t[refits$j == 0]

  null <- appE_fit(outcome, data, spec, include_treat = FALSE)
  stopifnot(null$nobs == nrow(data))  # resid/fitted must align row-for-row
  er <- as.numeric(resid(null))
  xbr <- as.numeric(fitted(null))

  states <- sort(unique(data$state_fips))
  state_idx <- match(data$state_fips, states)
  n_placebo <- max(refits$j)

  set.seed(seed)
  draws <- vector("list", (n_placebo + 1) * B)
  row <- 1
  for (j in 0:n_placebo) {
    if (progress) message("RI permutation ", j, " of ", n_placebo)
    pstate <- refits$state_fips[refits$j == j]
    data$ptreat <- as.integer(data$state_fips == pstate &
                                data$pot_treat == 1)
    for (b in seq_len(B)) {
      s <- (2 * (runif(length(states)) < 0.5) - 1)  # Rademacher by cluster
      data$ywild <- xbr + s[state_idx] * er
      st <- fit_stats(appE_fit("ywild", data, spec, treatvar = "ptreat"),
                      "ptreat")
      draws[[row]] <- data.frame(j = j, b = b, t = st[["t"]],
                                 beta = st[["b"]])
      row <- row + 1
    }
  }
  draws <- do.call(rbind, draws)

  # Placebo-only reference distribution, +1 convention
  plc <- draws[draws$j >= 1, ]
  S <- nrow(plc)
  list(p_t    = (1 + sum(abs(plc$t) >= abs(t0))) / (1 + S),
       p_beta = (1 + sum(abs(plc$beta) >= abs(b0))) / (1 + S),
       t_0 = t0, beta_0 = b0, refits = refits, draws = draws)
}
