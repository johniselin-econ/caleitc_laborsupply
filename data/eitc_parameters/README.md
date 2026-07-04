# eitc_parameters

## caleitc_params.txt — PROVENANCE UNCLEAR (documented 2026-07-04)

Read by `01_clean_data.do:707` (simulation-3 kink targets) and `02_mvpf.do:34`.
No script in the repo produces it. It is **not** the output of
`02b_caleitc_param_gen.do`: that script writes
`caleitc_max_inc_max_cred.{xlsx,dta}` here, and its values disagree with this
file (e.g. TY2015 qc1 kink 2500 in 02b vs `pwages = 4925.5` here; TY2016
5089 vs 5025.5). Column quirks: pre-2015 rows populate `pwages_unadj` and
2015+ rows populate `pwages`; qc2 and qc3 always share a value; all values
end in .5 (suggesting midpoints of some bracket, possibly an earlier
kink-window construction).

Do not regenerate from 02b — numbers would silently change. The R migration
must re-derive the sim-3 kink targets transparently from
`config/parameters.yaml` and validate the effect on downstream results
(flagged in PLAN.md Phase 2).
