# =============================================================================
# File:    validate_taxsim_year.R
# Purpose: Row-for-row validation of the TAXSIM port (sims 1 and 3) against
#          the Stata per-year files data/final/acs_<y>_clean.dta.
#
#          Reruns the cleaning port + taxsim_inputs + sims 1/3 with the same
#          local taxsim35 binary, joins on (serial, pernum), and compares
#          taxsim_sim1_fedeitc, taxsim_sim1_steitc, taxsim_sim3_atr_st.
#          Tolerances allow for the Stata files' float storage (EITC values
#          <= ~6.5k stored to ~4e-4; ATR ~0.1 stored to ~1e-8) plus
#          import-precision slack on the ATR inputs.
#
# Usage:   Rscript code/validate/validate_taxsim_year.R  (sbatch; ~30 GB)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
source(file.path("code", "lib", "qc_assignment.R"))
source(file.path("code", "lib", "clean_steps.R"))
source(file.path("code", "lib", "taxsim.R"))

suppressPackageStartupMessages(library(haven))

aux <- load_aux_data()
cpi99_2019 <- params$prices$cpi99[["2019"]]
caleitc_params <- load_caleitc_params()
cpi_2015 <- float_round(params$prices$cpi99[["2015"]])

check <- function(cmp, v, tol_rel, tol_abs) {
  g <- cmp[[paste0(v, "_g")]]; r <- cmp[[paste0(v, "_r")]]
  bad <- (is.na(g) != is.na(r)) |
    (!is.na(g) & !is.na(r) &
       abs(g - r) > pmax(abs(g) * tol_rel, tol_abs))
  if (sum(bad) > 0) {
    message("  MISMATCH ", v, ": ", sum(bad), " rows; e.g.")
    print(head(cmp[bad, c("serial", "pernum", paste0(v, "_g"),
                          paste0(v, "_r"))], 8))
    return(v)
  }
  message("  OK ", v, " (", sum(!is.na(g)), " non-missing rows)")
  NULL
}

for (y in c(2012, 2015)) {

  message("===== Validating TAXSIM port for ", y, " =====")

  ported <- clean_acs_year(y, aux, cpi99_2019 = cpi99_2019) |>
    rename(weight = perwt) |>
    taxsim_inputs() |>
    taxsim_sim1() |>
    taxsim_sim3(caleitc_params, cpi_2015)

  golden <- read_dta(
    path_data("final", paste0("acs_", y, "_clean.dta")),
    col_select = c(serial, pernum, taxsim_sim1_fedeitc,
                   taxsim_sim1_steitc, taxsim_sim3_atr_st)
  ) |> zap_labels()

  stopifnot(nrow(ported) == nrow(golden))

  cmp <- golden |>
    inner_join(ported |> select(serial, pernum, taxsim_sim1_fedeitc,
                                taxsim_sim1_steitc, taxsim_sim3_atr_st),
               by = c("serial", "pernum"), suffix = c("_g", "_r"))
  stopifnot(nrow(cmp) == nrow(golden))

  fails <- c(
    check(cmp, "taxsim_sim1_fedeitc", 2e-7, 1e-2),
    check(cmp, "taxsim_sim1_steitc",  2e-7, 1e-2),
    check(cmp, "taxsim_sim3_atr_st",  1e-5, 1e-6)
  )

  if (length(fails) > 0) stop("TAXSIM validation FAILED for ", y, ": ",
                              paste(fails, collapse = ", "))
  message("PASS: ", y, " — ", nrow(cmp), " rows")
  rm(ported, golden, cmp); invisible(gc())
}

message("===== TAXSIM validation PASSED for all years =====")
