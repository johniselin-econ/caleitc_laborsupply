# =============================================================================
# File:    04c_appA_state_table.R
# Purpose: Build Appendix Table A.1 (tab:state_tab / tab_appA_fig1), "Sample
#          states and population statistics" — the one exhibit referenced by
#          the paper with no producer anywhere in the repo. Reconstructed from
#          the caption spec: mean/min/max annual population of the baseline
#          sample (single non-college women aged 20--49) by state over
#          2012--2017, with membership flags for the main pool, the Medicaid-
#          expansion pool, and the no-state-EITC pool.
#
#          Pools (config/parameters.yaml, matching 03_fig_spec_curve.do:81-96):
#            main     = state_status > 0 (CA + non-excluded, non-EITC-change).
#            medicaid = main & fips in pools$medicaid_2014_keep.
#            no-EITC  = main & fips NOT in pools$no_state_eitc_drop.
#
#          Unlike the other fragments, the paper loads this one as a COMPLETE
#          tabular (\resizebox{...}{\input{tables/tab_appA_fig1}}), so the
#          output is a full \begin{tabular}...\end{tabular}.
#
# Inputs:  data/final/acs_working_file_r.rds
# Output:  results/tables/tab_appA_fig1.tex, mirrored to results/paper/.
#
# Usage:   Rscript code/R/04c_appA_state_table.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
suppressPackageStartupMessages(library(dplyr))

FIPS_NAME <- c(
  "1"="Alabama","2"="Alaska","4"="Arizona","5"="Arkansas","6"="California",
  "8"="Colorado","9"="Connecticut","10"="Delaware","11"="District of Columbia",
  "12"="Florida","13"="Georgia","15"="Hawaii","16"="Idaho","17"="Illinois",
  "18"="Indiana","19"="Iowa","20"="Kansas","21"="Kentucky","22"="Louisiana",
  "23"="Maine","24"="Maryland","25"="Massachusetts","26"="Michigan",
  "27"="Minnesota","28"="Mississippi","29"="Missouri","30"="Montana",
  "31"="Nebraska","32"="Nevada","33"="New Hampshire","34"="New Jersey",
  "35"="New Mexico","36"="New York","37"="North Carolina","38"="North Dakota",
  "39"="Ohio","40"="Oklahoma","41"="Oregon","42"="Pennsylvania",
  "44"="Rhode Island","45"="South Carolina","46"="South Dakota",
  "47"="Tennessee","48"="Texas","49"="Utah","50"="Vermont","51"="Virginia",
  "53"="Washington","54"="West Virginia","55"="Wisconsin","56"="Wyoming")

message("Loading working file (2 GB) ...")
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
df <- wf |>
  filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
         citizen_test == 1, education < 4, state_status > 0,
         year >= params$years$analysis_start,
         year <= params$years$analysis_end) |>
  select(weight, year, state_fips)
rm(wf); invisible(gc())
message("Baseline sample: N = ", nrow(df), " over ",
        length(unique(df$state_fips)), " states")

# Annual population by state, then mean/min/max across years.
st <- df |>
  group_by(state_fips, year) |>
  summarise(pop = sum(weight), .groups = "drop") |>
  group_by(state_fips) |>
  summarise(mean_pop = mean(pop), min_pop = min(pop), max_pop = max(pop),
            .groups = "drop")

MED  <- params$states$pools$medicaid_2014_keep
NODR <- params$states$pools$no_state_eitc_drop
st <- st |>
  mutate(state    = FIPS_NAME[as.character(state_fips)],
         main     = "Yes",
         medicaid = ifelse(state_fips %in% MED, "Yes", "No"),
         noeitc   = ifelse(!(state_fips %in% NODR), "Yes", "No")) |>
  arrange(state)
stopifnot(!anyNA(st$state))

## Emit a complete tabular (loaded inside \resizebox in the paper) -----------
cfmt <- function(x) formatC(round(x), format = "d", big.mark = ",")
rows <- sprintf("%-22s & %9s & %9s & %9s & %s & %s & %s \\\\",
                st$state, cfmt(st$mean_pop), cfmt(st$min_pop), cfmt(st$max_pop),
                st$main, st$medicaid, st$noeitc)
tex <- c(
  "\\begin{tabular}{lrrrccc}",
  "\\hline\\hline",
  " & \\multicolumn{3}{c}{Annual population} & \\multicolumn{3}{c}{Sample} \\\\",
  "\\cmidrule(lr){2-4}\\cmidrule(lr){5-7}",
  "State & Mean & Min & Max & Main & Medicaid & No-EITC \\\\",
  "\\hline",
  rows,
  "\\hline",
  "\\end{tabular}")

for (d in c("results/tables", "results/paper"))
  writeLines(tex, file.path(d, "tab_appA_fig1.tex"))
message("tab_appA_fig1: ", nrow(st), " states written")
message("  Medicaid pool: ", sum(st$medicaid == "Yes"),
        " ; no-EITC pool: ", sum(st$noeitc == "Yes"))
message("STATE TABLE EXPORT COMPLETE")
