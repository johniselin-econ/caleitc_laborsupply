# RUNBOOK — full re-run of the CalEITC labor-supply pipeline (R)

The analysis is an R pipeline (`code/`). Heavy stages load the ~2 GB working
file or call TAXSIM and run as SLURM batch jobs (`code/hpc/*.sbatch`); light
stages (parameter prep, exhibit builders) run locally. This is the end-to-end
recipe. The legacy Stata implementation is archived under `legacy/stata/` and
its golden logs (`legacy/stata/logs.zip`) are the validation targets.

## 0. Prerequisites

- **R** 4.4.2 (`module load R/4.4.2-gfbf-2024a` on the cluster). Restore the
  library once: `Rscript -e 'renv::restore()'` (uses `renv.lock`).
- **TAXSIM** binary at `~/ado/plus/t/taxsim35.exe` (used by 05, 50, 51).
- **Data**: IPUMS ACS extracts in `data/acs/` (or set `acs_source: shared` in
  `config/parameters.yaml` to read the Budget Lab common extract; path in
  `config/local_paths.yaml`). CalEITC FTB tables ship in
  `data/eitc_parameters/ftb3514/`.
- **Config**: copy `config/local_paths.yaml.example` → `config/local_paths.yaml`
  and set machine paths. Analysis window and state pools live in
  `config/parameters.yaml`; the verified CalEITC schedule in
  `config/caleitc_ftb3514.yaml`.
- Run everything **from the repo root**. Scripts source `code/lib/config.R`,
  which resolves paths via `here::here()`.

## 1. Data preparation

| Order | Script | Where | Notes |
|---|---|---|---|
| 1 | `01_download_acs.R` | local (network) | IPUMS API extract, ~hours. `run_download` in `00_run_all.R`, or run directly. |
| 2 | `02_download_aux.R` | local (network) | FIPS crosswalk, BLS unemployment, state minimum wages. |
| 3 | `03_caleitc_params.R` | local | CalEITC schedule params from the FTB 3514 tables → `data/eitc_parameters/caleitc_params.txt`. |
| 4 | `04_clean_acs.R` | HPC `stage9_clean_years.sbatch` | Per-year cleaning (QC assignment, demographics, employment, earnings, TAXSIM inputs). |
| 5 | `05_working_file.R` | HPC `stage9_working_file.sbatch` (~96 GB) | Append years + TAXSIM Simulation-2 cell instrument → `data/final/acs_working_file_r.rds`. |

## 2. Compute stages (HPC — submit in order, wait for results to stage)

Each writes job-tagged outputs into `results/<area>/`. Submit with
`sbatch code/hpc/<file>`; check `code/logs/slurm_<stage>_<jobid>.out`.

| Script | sbatch | Output area |
|---|---|---|
| `10_sdid.R` | `stage13_sdid_county.sbatch` | `results/sdid_r/` |
| `11_sdid_placebo.R` | `stage14_sdid_stateplacebo.sbatch` | `results/sdid_r/` |
| `12_sdid_eventstudy.R` | `stage15_sdid_eventstudy.sbatch` | `results/sdid_r/` |
| `20_altinference.R` | `stage12_appE_battery.sbatch` | `results/appE_r/` |
| `30_mw_bite.R` | `stage16_mw_bite.sbatch` | `results/mw_bite/` |
| `33_robustness_td.R` | `stage17_robustness_td.sbatch` | `results/robustness/` |
| `34_earnbins_scale.R` | `stage17b_earnbins_scale.sbatch` | `results/robustness/` |
| `36_dose_response.R` | `stage18_dose_response.sbatch` | `results/dose_response/` |
| `38_quad_oster.R` | `stage19_quad_oster.sbatch` | `results/quad_oster/` |
| `50_elasticities.R` | `stage21_elasticities.sbatch` | `results/elasticities/` |
| `51_mvpf.R` | `stage22_mvpf.sbatch` | `results/mvpf/` |
| `60_state_tab.R` | `stage20_appA_state_table.sbatch` | `results/tables/` (loads working file) |

Most stages self-validate in-run against the Stata golden (see the script's
validation block; tolerances noted there). `32_honestdid.R` runs locally off
the stage-15 replication matrices (no working file).

## 3. Exhibits (local — regenerate the paper tables/figures)

Once the compute stages have staged their results:

```
Rscript code/00_run_all.R      # rebuild_exhibits = TRUE by default
```

This sources the exhibit builders (`13/14_sdid`, `21_altinference`,
`32_honestdid`, `31_mw_bite`, `35_robustness`, `37_dose`, `39_quad_oster`,
`52_mvpf`), which read the committed job-tagged results and write `.tex`/`.jpg`
into `results/tables/`, `results/figures/`, and the Overleaf mirror
`results/paper/`. The exhibit builders reference specific job IDs — update those
if you re-run a compute stage and want the new job's outputs.

## 4. Paper

```
bash paper/build.sh            # -> paper/main_aejep.pdf
```

Assembles a self-contained build tree from `results/` and compiles with
`pdflatex`+`bibtex`. Expect 0 undefined citations; the only undefined reference
is `sec:app_self` (self-employment appendix, part of the online-supplement
split). See `paper/references.bib`.

## 5. Validation

`code/validate/` re-checks R outputs against the Stata golden
(`legacy/stata/logs.zip`): cleaning, QC assignment, TAXSIM, working file,
event study, `tab_main`, inference, SDID panel, sim-2. Several have their own
sbatch (`stage*_validate.sbatch`). The in-run validation blocks in the compute
scripts are the first line of defense.
