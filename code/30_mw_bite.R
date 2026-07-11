# =============================================================================
# File:    30_mw_bite.R
# Purpose: PLAN.md §A.1 — the within-California minimum-wage-bite test, the
#          first "Threats to identification" exhibit (§C). Asks whether the
#          full-time decline is concentrated where the *CalEITC* bites or
#          where the *minimum wage* bites, using cross-county variation
#          inside CA only (immune to the college-counterfactual critique).
#
#          Part 1 — county exposure measures (pre-period 2012-2014 ACS,
#          panel sample filter, aggregated to the SDID county units incl.
#          the pooled unbalanced unit county_fips 0):
#            bite_mw  — weighted share of employed with implied real hourly
#                       wage below the incoming statewide minimum ($10.50,
#                       Jan-2017, the highest step in the sample window;
#                       2019 USD via cpi99). Implied wage = incearn_real /
#                       (weeks_worked_y * hours_worked_y), trimmed to
#                       [$1, $200] 2019 USD.
#            kaitz    — incoming minimum / county weighted-median implied
#                       wage (robustness variant of bite).
#            exposure — weighted share of mothers (qc_ct >= 1) with
#                       incearn_real in (0, max_income(qc_ct)], TY2015
#                       FTB 3514 schedule (config/caleitc_ftb3514.yaml;
#                       qc1 $9,880, qc2+ $13,870; 2019 USD via cpi99).
#          Both z-scored (pop-weighted) across the 35 CA units.
#
#          Part 2 — within-CA county-year DiD (fixest): outcome regressed on
#          post x bite_z and post x exposure_z (each alone, horse race,
#          kaitz variant), county + year FE, pop-weighted, county-clustered.
#          Outcomes: {full_time, part_time, employed}_y_diff (the triple
#          margin) and full_time_y (QC-present level). 35 units x 2010-2017.
#
#          Part 3 — city-ordinance drop: re-estimate the weighted SDID
#          triple spec excluding the treated counties with local minimum-
#          wage ordinances in the sample window. drop3 = the plan's named
#          three: Los Angeles (037), San Francisco (075), Santa Clara/San
#          Jose (085); drop4 adds Alameda (001; Oakland/Berkeley/Emeryville
#          ordinances from 2015). Unit bootstrap B = 500, seeds
#          params$seed + 301.. (disjoint from stages 13/15).
#
#          Defaults flagged for author review: the $10.50 incoming-minimum
#          choice, the [$1,$200] wage trim, mothers-only exposure, and the
#          drop3/drop4 county sets.
#
# Inputs:  data/final/acs_working_file_r.rds,
#          data/interim/sdid_county_panel_r.rds (stage 10),
#          the synthdid_weights fork (Part 3).
# Output:  data/tmp/mw_bite_measures.csv (county measures),
#          data/tmp/mw_bite_reg.csv (Part-2 coefficients),
#          data/tmp/mw_bite_sdid_drop.csv (Part-3 fits), + combined .rds.
#
# Usage:   Rscript code/30_mw_bite.R  (cluster: stage16_mw_bite.sbatch;
#          needs ~64G for the working-file load)
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
})


## Constants --------------------------------------------------------------------
cpi99 <- params$prices$cpi99
to2019 <- function(x, yr) x * cpi99[[as.character(yr)]] / cpi99[["2019"]]

MW_INCOMING  <- to2019(10.50, 2017)         # Jan-2017 statewide step, 2019 USD
WAGE_TRIM    <- c(1, 200)                    # implied-wage validity, 2019 USD
# TY2015 CalEITC max earned income by QC count (caleitc_ftb3514.yaml), 2019 USD
EXP_MAX <- c(to2019(9880, 2015), rep(to2019(13870, 2015), 8))  # qc 1..9
DROP3 <- c(37, 75, 85)                       # LA, SF, Santa Clara (San Jose)
DROP4 <- c(1, DROP3)                         # + Alameda (Oakland/Berkeley)
PRE_YEARS <- 2012:2014

## Panel + CA unit set (county_fips incl. pooled 0) ------------------------------
panel <- readRDS(path_data("interim", "sdid_county_panel_r.rds"))
ca_units <- sort(unique(panel$county_fips[panel$state_fips == 6]))
message("CA units: ", length(ca_units))

## Part 1: county measures from the 2012-14 working file -------------------------
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
ca <- wf |>
  filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
         citizen_test == 1, education < 4, state_fips == 6,
         year %in% PRE_YEARS) |>
  mutate(county_fips = ifelse(county_fips %in% ca_units, county_fips, 0)) |>
  select(year, county_fips, weight, qc_ct, qc_present, employed_y,
         hours_worked_y, weeks_worked_y, incearn_real)
rm(wf); invisible(gc())
message("CA 2012-14 sample rows: ", nrow(ca))

ca <- ca |>
  mutate(impl_wage = ifelse(
    employed_y == 1 & !is.na(hours_worked_y) & !is.na(weeks_worked_y) &
      hours_worked_y > 0 & weeks_worked_y > 0 & incearn_real > 0,
    incearn_real / (weeks_worked_y * hours_worked_y), NA_real_),
    impl_wage = ifelse(!is.na(impl_wage) & impl_wage >= WAGE_TRIM[1] &
                         impl_wage <= WAGE_TRIM[2], impl_wage, NA_real_),
    # pmax(..., 1): zero-indexing drops elements in R; qc_ct == 0 rows are
    # excluded by the qc_ct >= 1 condition, the placeholder threshold is inert
    exp_elig = as.integer(qc_ct >= 1 & incearn_real > 0 &
                            incearn_real <= EXP_MAX[pmax(pmin(qc_ct, 9), 1)]))

wmedian <- function(x, w) {
  ok <- !is.na(x); x <- x[ok]; w <- w[ok]
  o <- order(x); x <- x[o]; w <- w[o]
  x[which(cumsum(w) >= sum(w) / 2)[1]]
}

meas <- ca |>
  group_by(county_fips) |>
  summarise(
    bite_mw  = weighted.mean(impl_wage < MW_INCOMING, weight, na.rm = TRUE),
    kaitz    = MW_INCOMING / wmedian(impl_wage, weight),
    exposure = weighted.mean(exp_elig[qc_ct >= 1], weight[qc_ct >= 1]),
    n_wage   = sum(!is.na(impl_wage)),
    n_mother = sum(qc_ct >= 1),
    popw     = sum(weight), .groups = "drop")
stopifnot(nrow(meas) == length(ca_units), !anyNA(meas$bite_mw),
          !anyNA(meas$exposure))

wz <- function(x, w) (x - weighted.mean(x, w)) /
  sqrt(weighted.mean((x - weighted.mean(x, w))^2, w))
meas <- meas |>
  mutate(bite_z = wz(bite_mw, popw), kaitz_z = wz(kaitz, popw),
         exposure_z = wz(exposure, popw))
write.csv(meas, path_data("tmp", "mw_bite_measures.csv"), row.names = FALSE)
message("Measures: bite ", paste(round(range(meas$bite_mw), 2), collapse = "-"),
        ", exposure ", paste(round(range(meas$exposure), 2), collapse = "-"),
        " | corr(bite, exposure) = ",
        round(with(meas, cov.wt(cbind(bite_mw, exposure), popw,
                                cor = TRUE)$cor[1, 2]), 3))

## Part 2: within-CA county-year DiD ---------------------------------------------
cap <- panel |>
  filter(state_fips == 6) |>
  left_join(meas, by = "county_fips") |>
  mutate(post = as.integer(year >= 2015),
         post_bite = post * bite_z, post_kaitz = post * kaitz_z,
         post_exp = post * exposure_z)

OUTS <- c("full_time_y_diff", "part_time_y_diff", "employed_y_diff",
          "full_time_y")
MODELS <- list(bite  = ~ post_bite,
               exp   = ~ post_exp,
               horse = ~ post_bite + post_exp,
               kaitz = ~ post_kaitz + post_exp)
reg <- list()
for (y in OUTS) for (m in names(MODELS)) {
  f <- as.formula(paste(y, "~", paste(all.vars(MODELS[[m]]), collapse = " + "),
                        "| county_fips + year"))
  fit <- feols(f, data = cap, weights = ~pop, cluster = ~county_fips)
  ct <- as.data.frame(coeftable(fit))
  reg[[paste(y, m)]] <- data.frame(outcome = y, model = m,
                                   term = rownames(ct), est = ct[, 1],
                                   se = ct[, 2], p = ct[, 4],
                                   n = fit$nobs, row.names = NULL)
}
reg <- bind_rows(reg)
write.csv(reg, path_data("tmp", "mw_bite_reg.csv"), row.names = FALSE)
message("\n=== Part 2: post x measure coefficients (per 1 SD) ===")
print(reg |> filter(model == "horse") |>
        mutate(across(c(est, se, p), \(x) round(x, 3))) |>
        select(outcome, term, est, se, p), row.names = FALSE)

## Part 3: ordinance-county drop SDID --------------------------------------------
synthdid_dir <- cfg$synthdid_dir %||% file.path(dirname(repo_root),
                                                "synthdid_weights")
invisible(lapply(list.files(file.path(synthdid_dir, "R"),
                            pattern = "[.][Rr]$", full.names = TRUE), source))
source(file.path("code", "lib", "sdid_setup.R"))

B_SDID <- 500
drop_res <- list()
fit_i <- 0
for (dv in c("drop3", "drop4")) {
  drop_set <- if (dv == "drop3") DROP3 else DROP4
  pdrop <- panel |> filter(!(state_fips == 6 & county_fips %in% drop_set))
  for (out in c("employed_y", "full_time_y", "part_time_y")) {
    fit_i <- fit_i + 1
    s <- make_setup(pdrop, paste0(out, "_diff"))
    est <- synthdid_estimate_weighted(s$setup$Y, s$setup$N0, s$setup$T0,
                                      treated.weights = s$treated.weights)
    seed_i <- params$seed + 300 + fit_i
    set.seed(seed_i)
    se <- sqrt(vcov(est, method = "bootstrap", replications = B_SDID))
    drop_res[[fit_i]] <- data.frame(
      variant = dv, outcome = out, spec = "triple",
      N1 = nrow(s$setup$Y) - s$setup$N0,
      att = as.numeric(est), se = as.numeric(se), B = B_SDID, seed = seed_i)
    message(sprintf("  %s %-11s ATT %7.3f (SE %.3f)", dv, out,
                    as.numeric(est), as.numeric(se)))
  }
}
drop_res <- bind_rows(drop_res)
write.csv(drop_res, path_data("tmp", "mw_bite_sdid_drop.csv"),
          row.names = FALSE)

saveRDS(list(measures = meas, reg = reg, sdid_drop = drop_res,
             constants = list(mw_incoming_2019usd = MW_INCOMING,
                              wage_trim = WAGE_TRIM, exp_max_2019usd = EXP_MAX,
                              drop3 = DROP3, drop4 = DROP4)),
        path_data("tmp", "mw_bite.rds"))
message("MW BITE TEST COMPLETE")
