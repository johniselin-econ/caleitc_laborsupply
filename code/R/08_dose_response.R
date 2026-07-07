# =============================================================================
# File:    08_dose_response.R
# Purpose: PLAN.md par A.2 — dose-response within non-college mothers,
#          implemented as the exposure-design DiD of
#          PLAN_siminstrument_note.md (rec. 2): discretize the simulated
#          CalEITC exposure into dose groups and estimate group-specific
#          DiDs against the zero-exposure group, with event studies by dose
#          group. Stays entirely inside the baseline (non-college single
#          women) sample.
#
#          Exposure: the Simulation-2 cell-mean simulated CalEITC
#          (taxsim_sim2_steitc; 2014 frozen population reflated through each
#          year's law), taken from CALIFORNIA cells averaged over the
#          2015-2017 law years, and assigned to individuals in ALL states by
#          demographic cell (qc_ct x education x age_bracket; the sample is
#          all single women, so female/mstat are fixed). A fixed cell trait:
#          "what would someone with these traits get under CalEITC".
#          Dose groups: G0 = zero exposure (mostly non-mothers, the
#          within-sample control group), T1-T3 = person-weighted terciles of
#          positive exposure.
#
#          Estimation (generalizes eq1, qc_present -> dose group): outcome on
#          CA x year x dose-group tokens (ref: 2014 and G0), absorbing
#          state^year, group^year, state^group [+ demographic controls;
#          + unemp/minwage x group in the third spec], person weights,
#          state-clustered. Post-ATT version: beta_g per tercile plus the
#          T3 - T1 gradient; event-study version: beta_gt, base 2014 —
#          CGS-style "flat pre-trends at every dose, effects increasing in
#          dose" evidence.
#
#          Inference: state-placebo RI mirroring 03b conventions (author
#          decisions 2026-07-07): each control state relabeled pseudo-CA
#          with CA kept in the pool as untreated, exhaustive over states,
#          placebo-only reference distribution, two-sided +1 p-values on
#          beta_g and the gradient (spec 2). No RNG anywhere.
#
#          Defaults flagged for author review: exposure = CA-cell sim2
#          steitc averaged over 2015-2017 law years (alt: TY2015 only);
#          person-weighted terciles; spec-2 (demographic controls) as the
#          RI/event-study spec.
#
# Inputs:  data/final/acs_working_file_r.rds
# Output:  data/tmp/dose_cells.csv (cell exposure map),
#          dose_post.csv (beta_g x 3 specs + gradient),
#          dose_es.csv (beta_gt, spec 2), dose_ri.csv (RI p-values),
#          + combined dose_response.rds
#
# Usage:   Rscript code/R/08_dose_response.R  (cluster:
#          stage18_dose_response.sbatch; ~64G load, ~90 feols fits)
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
source(file.path("code", "R", "utils", "estimation.R"))

LAW_YEARS <- 2015:2017                 # CA cell-exposure law years (default)
OUTS <- c("employed_y", "full_time_y", "part_time_y")

## Load + baseline sample --------------------------------------------------------
message("Loading working file ...")
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
df <- wf |>
  filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
         citizen_test == 1, education < 4, state_status > 0,
         year >= params$years$analysis_start,
         year <= params$years$analysis_end) |>
  select(weight, year, state_fips, qc_ct, qc_present,
         employed_y, full_time_y, part_time_y,
         education, age_bracket, minage_qc, race_group, hispanic,
         hh_adult_ct, state_unemp, mean_st_mw, taxsim_sim2_steitc)
rm(wf); invisible(gc())
message("Baseline sample: N = ", nrow(df))

df <- setup_did_vars(df) |>
  mutate(across(all_of(OUTS), ~ .x * 100))

## Exposure map from CA cells ------------------------------------------------------
cells <- df |>
  filter(ca == 1, year %in% LAW_YEARS) |>
  distinct(year, qc_ct, education, age_bracket, taxsim_sim2_steitc) |>
  group_by(qc_ct, education, age_bracket) |>
  summarise(exposure = mean(taxsim_sim2_steitc, na.rm = TRUE),
            n_law_years = sum(!is.na(taxsim_sim2_steitc)), .groups = "drop")
stopifnot(nrow(cells) > 0)
message("Cells: ", nrow(cells), " (", sum(cells$exposure > 0, na.rm = TRUE),
        " with positive exposure; ", sum(is.na(cells$exposure)),
        " NA, dropped)")

df <- df |>
  left_join(cells |> select(-n_law_years),
            by = c("qc_ct", "education", "age_bracket"))
n_na <- sum(is.na(df$exposure))
message("Individuals in unmapped cells (dropped): ", n_na,
        " (", round(100 * n_na / nrow(df), 3), "%)")
df <- df |> filter(!is.na(exposure))

# Dose groups: G0 zero, T1-T3 person-weighted terciles of positive exposure
pos <- df |> filter(exposure > 0)
qs <- with(pos[order(pos$exposure), ],
           exposure[findInterval(c(1, 2) / 3 * sum(weight),
                                 cumsum(weight)) + 1])
df <- df |>
  mutate(dose_g = case_when(exposure <= 0 ~ 0L,
                            exposure <= qs[1] ~ 1L,
                            exposure <= qs[2] ~ 2L,
                            .default = 3L))
message("Tercile cuts ($): ", paste(round(qs, 2), collapse = ", "))
grp <- df |> count(dose_g, wt = weight) |> mutate(sh = round(n / sum(n), 3))
print(as.data.frame(grp), row.names = FALSE)
cells <- cells |>
  mutate(dose_g = case_when(is.na(exposure) ~ NA_integer_,
                            exposure <= 0 ~ 0L,
                            exposure <= qs[1] ~ 1L,
                            exposure <= qs[2] ~ 2L,
                            .default = 3L))
write.csv(cells, path_data("tmp", "dose_cells.csv"), row.names = FALSE)

## Estimation machinery ------------------------------------------------------------
DOSE_FES <- c("state_fips^year", "dose_g^year", "state_fips^dose_g")

# Post-ATT / event-study tokens for an arbitrary treated state (RI reuse)
add_tokens <- function(data, treat_fips) {
  data |>
    mutate(tr = as.integer(state_fips == treat_fips),
           tok_post = ifelse(tr == 1 & dose_g > 0 & post == 1,
                             paste0("g", dose_g), "ref"),
           tok_es   = ifelse(tr == 1 & dose_g > 0 & year != 2014,
                             paste0("g", dose_g, "_", year), "ref"))
}

fit_dose <- function(outcome, data, token, spec = 2) {
  ctrl <- switch(spec, NULL, CONTROLS, CONTROLS)
  rhs <- paste0("i(", token, ", ref = 'ref')")
  if (spec == 3)
    rhs <- paste0(rhs, " + i(dose_g, state_unemp, ref = 0)",
                  " + i(dose_g, mean_st_mw, ref = 0)")
  fml <- as.formula(paste(outcome, "~", rhs, "|",
                          paste(c(DOSE_FES, ctrl), collapse = " + ")))
  feols(fml, data = data, weights = ~weight, cluster = ~state_fips,
        ssc = SSC_REGHDFE, fixef.tol = 1e-10)
}

grab <- function(fit, token) {
  ct <- as.data.frame(coeftable(fit))
  keep <- grepl(paste0("^", token, "::g"), rownames(ct))
  data.frame(term = sub(paste0(token, "::"), "", rownames(ct)[keep]),
             b = ct[keep, 1], se = ct[keep, 2], p = ct[keep, 4],
             n = nobs(fit))
}

## Main estimates -------------------------------------------------------------------
df <- add_tokens(df, 6)

post_res <- list(); es_res <- list()
for (y in OUTS) {
  for (s in 1:3) {
    g <- grab(fit_dose(y, df, "tok_post", s), "tok_post") |>
      mutate(outcome = y, spec = s, .before = 1)
    g <- bind_rows(g, data.frame(
      outcome = y, spec = s, term = "g3_minus_g1",
      b = g$b[g$term == "g3"] - g$b[g$term == "g1"],
      se = NA_real_, p = NA_real_, n = g$n[1]))
    post_res[[paste(y, s)]] <- g
  }
  es_res[[y]] <- grab(fit_dose(y, df, "tok_es", 2), "tok_es") |>
    mutate(outcome = y, spec = 2, .before = 1)
}
post_res <- bind_rows(post_res); es_res <- bind_rows(es_res)
write.csv(post_res, path_data("tmp", "dose_post.csv"), row.names = FALSE)
write.csv(es_res, path_data("tmp", "dose_es.csv"), row.names = FALSE)
message("\n=== Dose post-ATTs (spec 2) ===")
print(post_res |> filter(spec == 2) |>
        mutate(across(c(b, se, p), \(x) round(x, 3))), row.names = FALSE)

## State-placebo RI (spec 2) --------------------------------------------------------
donors <- setdiff(sort(unique(df$state_fips)), 6)
message("\nRI over ", length(donors), " placebo states ...")
ri <- list()
for (s in donors) {
  dfp <- add_tokens(df, s)
  for (y in OUTS) {
    g <- grab(fit_dose(y, dfp, "tok_post", 2), "tok_post")
    ri[[paste(s, y)]] <- data.frame(
      state = s, outcome = y,
      g1 = g$b[g$term == "g1"], g2 = g$b[g$term == "g2"],
      g3 = g$b[g$term == "g3"],
      grad = g$b[g$term == "g3"] - g$b[g$term == "g1"])
  }
  message("  placebo state ", s, " done")
}
ri <- bind_rows(ri)

actual <- post_res |> filter(spec == 2)
ri_p <- lapply(OUTS, function(y) {
  a <- actual |> filter(outcome == y)
  pl <- ri |> filter(outcome == y)
  stat <- c(g1 = a$b[a$term == "g1"], g2 = a$b[a$term == "g2"],
            g3 = a$b[a$term == "g3"], grad = a$b[a$term == "g3_minus_g1"])
  data.frame(outcome = y, term = names(stat), b = unname(stat),
             p_ri = sapply(names(stat), function(k)
               (1 + sum(abs(pl[[k]]) >= abs(stat[[k]]))) /
                 (length(donors) + 1)),
             S = length(donors))
}) |> bind_rows()
write.csv(ri_p, path_data("tmp", "dose_ri.csv"), row.names = FALSE)
message("\n=== RI p-values (spec 2, two-sided, +1) ===")
print(ri_p |> mutate(across(c(b, p_ri), \(x) round(x, 3))), row.names = FALSE)

saveRDS(list(cells = cells, post = post_res, es = es_res,
             ri_placebo = ri, ri_p = ri_p,
             constants = list(law_years = LAW_YEARS, tercile_cuts = qs,
                              n_unmapped = n_na)),
        path_data("tmp", "dose_response.rds"))
message("DOSE RESPONSE STAGE COMPLETE")
