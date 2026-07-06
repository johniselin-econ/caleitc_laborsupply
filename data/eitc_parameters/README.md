# eitc_parameters

## caleitc_params.txt — sim-3 kink targets (provenance RESOLVED 2026-07-06)

Read by `01_clean_data.do:707` / `code/R/utils/taxsim.R` (simulation-3 kink
targets), `02_elasticities.do:302`, and `02_mvpf.do:34`. Long documented as
provenance-unknown (no producing script; values disagree with
`02b_caleitc_param_gen.do`); resolved 2026-07-06: each value is the **midpoint
of the $50 credit-table bin in which the CalEITC attains its maximum**, per
tax year × QC count, from FTB's published Form 3514 tables
(`ftb3514/caleitc_table_{year}.csv`). Pre-2015 rows carry the nominal 2015
values in `pwages_unadj` (sim-3 reflates by `cpi_2015/cpi99` at use); 2015+
rows populate `pwages`. qc2/qc3 share values because their credit tables peak
in the same bin.

`code/R/gen_caleitc_params.R` regenerates the file from the ftb3514 tables and
reproduces the committed version **byte-for-byte** — so the sim-3 targets were
always consistent with FTB 3514, even though the repo's schedule *parameters*
(`eitc_california` in `parameters.yaml` / `02b_caleitc_param_gen.do`) were not
(see `config/caleitc_ftb3514.yaml` and the 2026-07-05 audit).

## caleitc_max_inc_max_cred.{xlsx,dta} — 02b output, superseded

Written by `02b_caleitc_param_gen.do` from the old (wrong) schedule
parameters. Nothing downstream should read these once the Phase 3/4 R ports
land; use `config/caleitc_ftb3514.yaml` instead.

## ftb3514/ — verified ground truth

Parsed $50-bin CalEITC lookup tables (TY2015–2019) plus archived source
PDFs/HTML from FTB Form 3514 instructions. See `config/caleitc_ftb3514.yaml`
for the piecewise schedule fitted to these tables and
`code/R/validate/fig_caleitc_ftb3514_audit.R` for diagnostic figures.
