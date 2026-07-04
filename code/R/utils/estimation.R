# =============================================================================
# File:    estimation.R
# Purpose: R ports of the Stata estimation helpers in code/utils/programs.do.
#          Phase 2 scope: setup_did_vars + run_triple_diff (reghdfe ->
#          fixest::feols). Validated coefficient-by-coefficient against the
#          committed tab_main_* golden values (code/R/validate/
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
# In fixest, c.x#i.g (all-level slopes, no reference) is i(g, x); the treated
# coefficient is invariant to the slope parameterization.
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
    rhs <- if (!is.null(qcvar)) paste0(rhs, " + i(", qcvar, ", ", v, ")")
           else paste(rhs, "+", v)
  }

  fml <- as.formula(paste(outcome, "~", rhs, "|",
                          paste(c(fes, controls), collapse = " + ")))

  feols(fml, data = data,
        weights = as.formula(paste0("~", weightvar)),
        cluster = as.formula(paste0("~", clustervar)),
        ssc = SSC_REGHDFE)
}
