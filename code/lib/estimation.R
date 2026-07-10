# =============================================================================
# File:    estimation.R
# Purpose: R ports of the Stata estimation helpers in code/utils/programs.do.
#          Phase 2 scope: setup_did_vars + run_triple_diff (reghdfe ->
#          fixest::feols). Validated coefficient-by-coefficient against the
#          committed tab_main_* golden values (code/validate/
#          validate_tab_main.R).
#
#          Standard-error convention: reghdfe with vce(cluster ...) treats
#          FEs nested in the cluster as redundant for the dof correction —
#          fixest replicates this with ssc(fixef.K = "nested",
#          cluster.adj = TRUE), exported below as SSC_REGHDFE.
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
})

SSC_REGHDFE <- ssc(adj = TRUE, fixef.K = "nested", cluster.adj = TRUE)

# Baseline triple-diff fixed effects (globals.do: $did_base)
DID_BASE <- c("qc_ct", "year", "state_fips",
              "state_fips^year", "state_fips^qc_ct", "year^qc_ct")

# Demographic controls (globals.do: $controls) — absorbed, as in reghdfe
CONTROLS <- c("education", "age_bracket", "minage_qc", "race_group",
              "hispanic", "hh_adult_ct")

# setup_did_vars (programs.do:990-1027): ca, post, treated, hh_adult_ct cap
setup_did_vars <- function(df, post_year = 2014, eventstudy = FALSE) {
  df <- df |>
    mutate(
      ca          = as.integer(state_fips == 6),
      post        = as.integer(year > post_year),
      treated     = as.integer(qc_present == 1 & ca == 1 & post == 1),
      hh_adult_ct = pmin(hh_adult_ct, 3)
    )
  if (eventstudy) {
    df <- df |>
      mutate(childXyearXca = ifelse(qc_present == 1 & ca == 1, year, post_year))
  }
  df
}

# run_triple_diff (programs.do:191-258): reghdfe outcome treated
#   [+ c.unemp#i.qcvar + c.minwage#i.qcvar] [aw=weight],
#   absorb(fes + controls) vce(cluster clustervar)
#
# Collinearity note: with state_fips^year absorbed and a state-year-level x
# (unemployment, minimum wage), the full slope set {x * 1[qc = k]} sums to x,
# which lies in the absorbed span — one slope must drop. reghdfe omits the
# HIGHEST qc level (log: "3.qc_ct#c.state_unemp omitted"); we mirror that
# with ref = max level so the design matrix matches column-for-column
# (validated SEs then agree to display precision instead of drifting with
# whichever column the solver happens to drop).
run_triple_diff <- function(outcome, data,
                            treatvar = "treated",
                            controls = NULL,
                            unempvar = NULL,
                            minwagevar = NULL,
                            fes = DID_BASE,
                            weightvar = "weight",
                            clustervar = "state_fips",
                            qcvar = NULL) {

  rhs <- treatvar
  for (v in c(unempvar, minwagevar)) {
    if (!is.null(qcvar)) {
      ref <- max(data[[qcvar]], na.rm = TRUE)
      rhs <- paste0(rhs, " + i(", qcvar, ", ", v, ", ref = ", ref, ")")
    } else {
      rhs <- paste(rhs, "+", v)
    }
  }

  fml <- as.formula(paste(outcome, "~", rhs, "|",
                          paste(c(fes, controls), collapse = " + ")))

  # fixef.tol 1e-10: validation-grade demeaning precision (reghdfe uses 1e-8;
  # fixest default 1e-6 leaves SEs drifting at ~1e-3 in the interaction specs)
  feols(fml, data = data,
        weights = as.formula(paste0("~", weightvar)),
        cluster = as.formula(paste0("~", clustervar)),
        ssc = SSC_REGHDFE,
        fixef.tol = 1e-10)
}

# run_event_study (programs.do:267-318): as run_triple_diff but the treatment
# term is b<baseyear>.<eventvar> — year-specific effects with the base year
# as reference. Same collinearity mirroring for the qc-interacted controls.
run_event_study <- function(outcome, data,
                            eventvar = "childXyearXca",
                            baseyear = 2014,
                            controls = NULL,
                            unempvar = NULL,
                            minwagevar = NULL,
                            fes = DID_BASE,
                            weightvar = "weight",
                            clustervar = "state_fips",
                            qcvar = NULL) {

  rhs <- paste0("i(", eventvar, ", ref = ", baseyear, ")")
  for (v in c(unempvar, minwagevar)) {
    if (!is.null(qcvar)) {
      ref <- max(data[[qcvar]], na.rm = TRUE)
      rhs <- paste0(rhs, " + i(", qcvar, ", ", v, ", ref = ", ref, ")")
    } else {
      rhs <- paste(rhs, "+", v)
    }
  }

  fml <- as.formula(paste(outcome, "~", rhs, "|",
                          paste(c(fes, controls), collapse = " + ")))

  feols(fml, data = data,
        weights = as.formula(paste0("~", weightvar)),
        cluster = as.formula(paste0("~", clustervar)),
        ssc = SSC_REGHDFE,
        fixef.tol = 1e-10)
}
