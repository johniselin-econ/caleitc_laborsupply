# =============================================================================
# File:    taxsim.R
# Purpose: R port of the TAXSIM machinery in 01_clean_data.do (Step 9 sims
#          1 and 3, section 5 sim 2). Calls the SAME local NBER taxsim35
#          binary the Stata pipeline used (taxsimlocal35's
#          ~/ado/plus/t/taxsim35.exe, a statically linked Linux ELF), so
#          golden outputs are reproducible to the cent. The usincometaxes
#          package can be swapped in later and benchmarked against this.
#
#          Invocation mirrors taxsimlocal35.ado: input CSV on stdin with
#          mtr = 85 (ado default; plain `taxsimlocal35, full` never changes
#          it) and idtl = 2 (full output), +10 on the LAST row so the binary
#          emits a header line; results CSV on stdout.
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# FIPS -> SOI crosswalk (01_clean_data.do:552-558)
fips_to_soi <- local({
  fips <- c(1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 19, 20, 21,
            22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37,
            38, 39, 40, 41, 42, 44, 45, 46, 47, 48, 49, 50, 51, 53, 54, 55, 56)
  soi <- seq_along(fips)
  map <- integer(max(fips)); map[] <- NA_integer_; map[fips] <- soi
  function(state_fips) map[state_fips]
})

# taxsimlocal35.ado's input column order (txpyvars, subset we send)
TAXSIM_VARS <- c("taxsimid", "year", "state", "mstat", "page", "sage",
                 "depx", "pwages", "swages", "intrec", "otherprop",
                 "psemp", "ssemp")

run_taxsim35 <- function(df,
                         exe = path.expand("~/ado/plus/t/taxsim35.exe"),
                         workdir = tempdir()) {
  stopifnot(file.exists(exe), all(TAXSIM_VARS %in% names(df)))
  if (anyNA(df[TAXSIM_VARS])) stop("run_taxsim35: missing values in inputs")

  send <- df |>
    transmute(mtr = 85, idtl = 2,
              across(dplyr::all_of(TAXSIM_VARS))) |>
    mutate(idtl = ifelse(row_number() == n(), 12, idtl))

  infile  <- file.path(workdir, "txpydata.raw")
  outfile <- file.path(workdir, "results.raw")
  write_csv(send, infile)

  status <- system2(exe, stdin = infile, stdout = outfile, stderr = FALSE)
  if (status != 0) stop("taxsim35.exe exited with status ", status)

  res <- suppressWarnings(
    read_csv(outfile, show_col_types = FALSE, guess_max = 1e6)
  ) |>
    mutate(taxsimid = suppressWarnings(as.numeric(taxsimid))) |>
    filter(!is.na(taxsimid))
  res
}

# Run the binary on a preexisting input file verbatim (e.g. the byte-exact
# golden txpydata replica from code/hpc/stage8_txpydump.do). The file must
# already carry mtr/idtl columns with idtl + 10 on the last row.
run_taxsim35_file <- function(infile,
                              exe = path.expand("~/ado/plus/t/taxsim35.exe"),
                              workdir = tempdir(),
                              col_select = NULL) {
  stopifnot(file.exists(exe), file.exists(infile))
  outfile <- file.path(workdir, "results.raw")
  status <- system2(exe, stdin = infile, stdout = outfile, stderr = FALSE)
  if (status != 0) stop("taxsim35.exe exited with status ", status)

  res <- suppressWarnings(
    if (is.null(col_select)) {
      read_csv(outfile, show_col_types = FALSE, guess_max = 1e6)
    } else {
      read_csv(outfile, show_col_types = FALSE, guess_max = 1e6,
               col_select = dplyr::all_of(col_select))
    }
  ) |>
    mutate(taxsimid = suppressWarnings(as.numeric(taxsimid))) |>
    filter(!is.na(taxsimid))
  res
}

# -----------------------------------------------------------------------------
# Step 9b: TAXSIM input variables on a cleaned per-year frame
# (01_clean_data.do:561-628). sage note: Stata's tmp_max_age/tmp_min_age are
# the LAST/FIRST row's age within (hh_id, unit_id) sorted by pernum — not the
# max/min — replicated as such.
# -----------------------------------------------------------------------------

taxsim_inputs <- function(df) {
  df |>
    mutate(state_soi = fips_to_soi(state_fips)) |>
    arrange(hh_id, unit_id, pernum) |>
    mutate(taxsimid = cumsum(!duplicated(cbind(hh_id, unit_id)))) |>
    group_by(hh_id, unit_id) |>
    mutate(tmp_first_age = first(age), tmp_last_age = last(age)) |>
    ungroup() |>
    mutate(
      state = state_soi,
      mstat = case_when(mfs == 1 ~ 6L, married == 1 ~ 2L, .default = 1L),
      depx  = qc_ct,
      page  = age,
      sage  = case_when(
        age == tmp_first_age & married == 1 & unit_ct > 1 ~ tmp_last_age,
        age == tmp_last_age  & married == 1 & unit_ct > 1 ~ tmp_first_age,
        .default = 0
      ),
      pwages = pmax(incwage_nom, 0),
      swages = pmax(incwage_tax_nom - incwage_nom, 0),
      psemp  = incse_nom,
      ssemp  = incse_tax_nom - incse_nom,
      intrec = pmax(incinvst_tax_nom, 0),
      otherprop = pmax(inctot_tax_nom - pmax(incwage_tax_nom, 0) -
                         incse_tax_nom - incinvst_tax_nom - incwel_nom, 0),
      primary_filer = as.integer(unit_id == pernum)
    ) |>
    select(-tmp_first_age, -tmp_last_age)
}

# Stata's mstat order: mstat=1; =2 if married; =6 if mfs (mfs wins) — matched
# by the case_when order above (mfs first).

# -----------------------------------------------------------------------------
# Simulation 1: observed characteristics (01_clean_data.do:630-697)
# All primary filers are sent (the "CA Only" comment in the Stata source is
# not reflected in its code — no CA filter exists there).
# -----------------------------------------------------------------------------

taxsim_sim1 <- function(df, ...) {
  filers <- df |> filter(primary_filer == 1) |>
    select(dplyr::all_of(TAXSIM_VARS))
  res <- run_taxsim35(filers, ...) |>
    select(taxsimid, year, sim1_fedeitc = v25, sim1_steitc = v39)
  df |>
    left_join(res, by = c("taxsimid", "year")) |>
    mutate(taxsim_sim1_fedeitc = sim1_fedeitc,
           taxsim_sim1_steitc  = sim1_steitc) |>
    select(-sim1_fedeitc, -sim1_steitc)
}

# -----------------------------------------------------------------------------
# Simulation 3: ATR at the CalEITC kink (01_clean_data.do:699-842)
# Two runs per year — pwages at the kink vs pwages = 0 — then
# ATR = ((fiitax - fiitax_0) + (siitax - siitax_0) + fica) / agi  for agi > 0
# (Kleven 2023 Eq. 7). agi is TAXSIM's v10.
# -----------------------------------------------------------------------------

load_caleitc_params <- function() {
  read_delim(path_data("eitc_parameters", "caleitc_params.txt"),
             delim = "\t", show_col_types = FALSE) |>
    transmute(year = tax_year, depx = qc_ct,
              pwages_kink = suppressWarnings(as.numeric(pwages)),
              pwages_unadj = suppressWarnings(as.numeric(pwages_unadj)))
}

taxsim_sim3 <- function(df, caleitc_params, cpi_2015, ...) {
  base <- df |>
    filter(primary_filer == 1) |>
    select(taxsimid, state, mstat, year, page, sage, depx, intrec,
           otherprop, cpi99) |>
    left_join(caleitc_params, by = c("year", "depx")) |>
    mutate(
      pwages = ifelse(year < 2015 & !is.na(pwages_unadj),
                      pwages_unadj * (cpi_2015 / cpi99), pwages_kink),
      swages = 0, psemp = 0, ssemp = 0
    )

  if (anyNA(base$pwages)) stop("sim3: missing kink wages for some year x depx")

  run1 <- run_taxsim35(base |> select(dplyr::all_of(TAXSIM_VARS)), ...) |>
    select(taxsimid, fiitax, siitax, fica, agi = v10)
  run2 <- run_taxsim35(base |> mutate(pwages = 0) |>
                         select(dplyr::all_of(TAXSIM_VARS)), ...) |>
    select(taxsimid, fiitax_0 = fiitax, siitax_0 = siitax, agi_0 = v10)

  atr <- base |>
    select(taxsimid) |>
    left_join(run1, by = "taxsimid") |>
    left_join(run2, by = "taxsimid") |>
    mutate(taxsim_sim3_atr_st =
             ifelse(!is.na(agi) & agi > 0,
                    ((fiitax - fiitax_0) + (siitax - siitax_0) + fica) / agi,
                    NA_real_)) |>
    select(taxsimid, taxsim_sim3_atr_st)

  df |> left_join(atr, by = "taxsimid")
}

# -----------------------------------------------------------------------------
# Simulation 2: simulated instrument from 2014 cells (01_clean_data.do:889-1127)
# 2014 primary filers are replicated to each year 2010-2019 with money inputs
# reflated by cpi99(y)/cpi99(2014); TAXSIM outputs are collapsed to weighted
# cell means by (year, state_soi, female, qc_ct, mstat, education,
# age_bracket); sim2_cellwt is the UNWEIGHTED cell count (Stata collapse
# (sum) of 1 under aweights normalizes weights to sum to N).
#
# DELIBERATE NON-PORTS of two Stata artifacts (validate_sim2.R proves they
# are the ONLY divergences, by reproducing the working-file cells from the
# byte-exact golden input dump):
#
# 1. sage contamination — non-deterministic. 01_clean_data.do regenerates the
#    sim-2 inputs on the combined all-years file, where hh_id is a per-year
#    dense rank — `bysort hh_id unit_id (pernum)` there pools up to 14
#    unrelated households, contaminating sage (spouse age, 38.9% of 2014
#    filers, all married multi-person units) and thereby the EITC age tests.
#    Because the tie order among colliding (hh_id, unit_id, pernum) rows
#    comes from an UNSTABLE sort, the realized sage varies across runs: the
#    original working-file run drew a different realization than the golden
#    dumps, so 374 married cells are irreproducible in principle
#    (validate_sim2.R bounds the divergence to exactly that ambiguity set).
#    This port takes inputs from the 2014 frame only (equivalent to the
#    per-year Step 9 inputs, which validate row-for-row) — deterministic and
#    correct.
#
# 2. outsheet %10.0g rounding. taxsimlocal35.ado writes the TAXSIM input
#    file with `outsheet`, which uses display formats — the money vars are
#    doubles at the default %10.0g (~8-9 significant digits). The cpi
#    reflation below creates long decimal tails that Stata rounded before
#    they reached taxsim35.exe; near TAXSIM's $50 EITC-table brackets this
#    flips single rows' EITC (5,362 of 16M rows) but never moves a cell mean
#    past the 2-cent comparison tolerance. This port sends full double
#    precision. Sims 1/3 are unaffected: their money inputs are clean ACS
#    integers, which %10.0g writes exactly.
# -----------------------------------------------------------------------------

taxsim_sim2_stack <- function(combined, cpi_by_year) {
  base14 <- combined |>
    filter(year == 2014, primary_filer == 1) |>
    select(taxsimid, state, mstat, depx, page, sage, pwages, swages,
           psemp, ssemp, intrec, otherprop,
           cpi99, education, age_bracket, female, weight)

  bind_rows(lapply(2010:2019, function(y) {
    base14 |>
      mutate(across(c(pwages, swages, psemp, ssemp, intrec, otherprop),
                    ~ .x * (cpi_by_year[[as.character(y)]] / cpi99)),
             year = y)
  })) |>
    arrange(year, taxsimid) |>
    mutate(taxsimid = row_number())
}

taxsim_sim2_collapse <- function(stacked_with_results) {
  stacked_with_results |>
    group_by(year, state_soi = state, female, qc_ct = depx, mstat,
             education, age_bracket) |>
    summarise(
      sim2_cellwt  = n(),
      sim2_fedeitc = weighted.mean(sim2_fedeitc, weight),
      sim2_steitc  = weighted.mean(sim2_steitc, weight),
      .groups = "drop"
    )
}

taxsim_sim2_cells <- function(combined, cpi_by_year, ...) {
  stacked <- taxsim_sim2_stack(combined, cpi_by_year)

  res <- run_taxsim35(stacked |> select(dplyr::all_of(TAXSIM_VARS)), ...) |>
    select(taxsimid, sim2_fedeitc = v25, sim2_steitc = v39)

  stacked |>
    left_join(res, by = "taxsimid") |>
    taxsim_sim2_collapse()
}
