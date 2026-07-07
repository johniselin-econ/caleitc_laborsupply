# The Labor Supply Effects of the California Earned Income Tax Credit

This repository contains the replication code and materials for the paper analyzing the labor supply effects of the California Earned Income Tax Credit (CalEITC).

**Author:** John Iselin
**Contact:** john.iselin@yale.edu

## Project Overview

This paper examines the labor supply effects of the CalEITC, introduced in 2015 as a state-level supplement to the federal EITC. Using American Community Survey (ACS) data and a triple-difference research design, I estimate the effect of the CalEITC on employment among single women with qualifying children.

## Repository Structure

The code is organized to match the paper structure. Files are numbered by section:
- `00_` - Main orchestration script
- `01_` - Data cleaning
- `02_` - Analysis (elasticities, MVPF)
- `03_` - Main text figures and tables (organized by paper section)
- `04_` - Appendix material

```
caleitc_laborsupply/
├── code/
│   │
│   │   ## (00-02) DATA AND ANALYSIS
│   ├── 00_caleitc.do              # Main script (runs all analyses)
│   ├── 01_clean_data.do           # Data cleaning and preparation
│   ├── 02_elasticities.do         # Elasticity calculations
│   ├── 02_mvpf.do                 # MVPF calculations
│   ├── 02_eitc_param_prep.do      # EITC benefit schedule preparation
│   ├── 02b_caleitc_param_gen.do   # CalEITC parameters generation
│   │
│   │   ## (03) MAIN TEXT — AEJ:EP (main_aejep.tex)
│   │   # Section 2: Policy Background
│   ├── 03_fig_eitc_sched.do       # Fig 1: EITC benefit schedules (TY 2016)
│   ├── 03_fig_earn_hist.do        # Fig 2: Histograms of CA workers
│   │   # Section 3: Conceptual Framework
│   ├── 03_fig_budget.do           # Fig 3: Budget constraint (2 QC, 2016)
│   │   # Section 5.1: Main Results
│   ├── 03_tab_main.do             # Table 1: Main triple-diff estimates
│   ├── 03_fig_event_emp.do        # Fig 4: Event-study (employment)
│   │   # Section 5.2: Decomposition
│   ├── 03_fig_hours_bins.do       # Fig 5: Effect by weekly hours
│   │   # Section 5.3: Robustness
│   ├── 03_sdid_county.do          # Table 2: County-panel weighted SDID
│   ├── 03_fig_event_col_placebo.do # Fig 6: College placebo (falsification)
│   ├── 03_tab_quad_diff.do        # (inline) Quadruple-difference
│   ├── 03_tab_oster_bounds.do     # (inline) Oster bounds
│   │   # Section 6: Earnings
│   ├── 03_tab_earnings.do         # Table 3: Earnings effects (OLS & PPML)
│   ├── 03_fig_earn_bins.do        # Fig 7: Earnings distribution changes
│   │   # Section 7: Heterogeneity
│   ├── 03_tab_het_adults.do       # Fig 8: By number of adults
│   ├── 03_fig_event_earn.do       # Own vs HH income event-study
│   │   # Section 8: MVPF
│   ├── 03_fig_mvpf_dist.do        # Fig 9: MVPF distribution
│   │   # Demoted to appendix (uncomment in 00_caleitc.do for full draft)
│   ├── 03_fig_emp_trends.do       # FT/PT employment trends
│   ├── 03_fig_weeks.do            # Effect by annual weeks
│   ├── 03_fig_spec_curve.do       # Specification curves
│   ├── 03_tab_het_qc.do           # By number of QC
│   ├── 03_tab_het_qc_age.do       # By age of youngest QC
│   ├── 03_fig_mvpf_spillovers.do  # Fiscal spillovers
│   │   # Archived (not in AEJ:EP submission)
│   ├── 03_sdid_state.do           # State-level SDID (superseded by county)
│   ├── 03_fig_treat_by_earn.do    # Treatment effects by earnings bins
│   ├── 03_tab_earn_hhcomp.do      # Earnings by HH composition
│   ├── 03_tab_intensive.do        # Intensive margin (hours, weeks)
│   ├── 03_tab_sim_inst.do         # Simulated instrument results
│   ├── 03_tab_hh_earn.do          # Household earnings (OLS & PPML)
│   ├── 03_tab_desc.do             # Deprecated — see 04_appA_tab1.do
│   ├── 02_descriptives.do         # Summary statistics (standalone)
│   │
│   │   ## (04) APPENDICES
│   │   # Appendix A: Additional Tables and Figures
│   ├── 04_appA_tab1.do            # Table A.1: Sample states and statistics
│   ├── 04_appA_fig_eitc_sched_15_17.do     # Figure A.1: EITC schedules 2015/2017
│   ├── 04_appA_fig_eitc_ctc_sched.do       # Figure A.2: EITC/CTC schedules (2016)
│   ├── 04_appA_fig_tcja_yctc.do            # Figure A.3: Post-2017 tax credit changes
│   ├── 04_appA_fig_unemp_trends.do         # Figure A.4: Unemployment trends
│   ├── 04_appA_fig_minwage.do              # Figure A.5: Minimum wages
│   ├── 04_appA_fig_atr_event.do            # Figure A.6: After-tax rate effect
│   ├── 04_appA_tab_balance.do              # Tables A.2-A.3: Balance tests
│   ├── 04_appA_tab_col_placebo.do          # Table A.4: College placebo table
│   │   # Appendix A: ** FUTURE WORK **
│   ├── 04_appA_fig_spec_curve_reported.do  # Spec curves (reported hours/weeks)
│   ├── 04_appA_fig_emp_trends_alt.do       # Alt FT/PT thresholds
│   ├── 04_appA_tab_alt_threshold.do        # Alt threshold estimates
│   ├── 04_appA_tab_het_qc_age.do           # Heterogeneity by youngest QC age
│   ├── 04_appendix.do                      # Placeholder (unused)
│   │   # Appendix B: Other Populations
│   ├── 04_appB_otherpops.do       # Figures B.1-B.3: Married women, single/married men
│   │   # Appendix C: Self-Employment
│   ├── 04_appC_tab_wage_emp.do    # Table C.1: Wage workers
│   ├── 04_appC_tab_self_emp.do    # Table C.2: Self-employment
│   ├── 04_appC_fig_wage_emp.do    # Figure C.1: Wage workers event-study
│   ├── 04_appC_fig_self_emp.do    # Figure C.2: Self-employment event-study
│   │   # Appendix D: Inference
│   ├── 04_appE_inference.do       # Table D.1: Alternative inference procedures
│   │   # Appendix D: Helper files (not directly called)
│   ├── 04_appE_inference_programs.do       # Inference helper programs
│   ├── 04_appE_inference_parallel.do       # Parallelized inference
│   ├── 04_appE_inference_worker.do         # Worker program for parallel
│   │
│   │   ## SUBDIRECTORIES
│   ├── R/                         # R pipeline (Stata-to-R migration; see below)
│   │   ├── 00_main.R              # Master driver (mirrors 00_caleitc.do)
│   │   ├── 01_clean_data.R        # Data cleaning port
│   │   ├── 01_data_prep_other.R   # BLS and minimum wage data prep
│   │   ├── 02_working_file.R      # Working-file assembly (validated vs Stata)
│   │   ├── 03_sdid_county.R       # Table 2: weighted SDID (synthdid fork)
│   │   ├── 03b_sdid_stateplacebo.R # State-placebo RI for the county SDID
│   │   ├── 03c_sdid_eventstudy.R  # SDID event studies (Ciccia decomposition)
│   │   ├── 03d_sdid_table2.R      # Table 2 tex fragments
│   │   ├── 03e_sdid_esfigures.R   # SDID event-study figures
│   │   ├── 04_appE_inference.R    # Appendix inference battery (R port)
│   │   ├── 04b_appE_table.R       # Appendix inference table (+ RI, CT rows)
│   │   ├── 05_mw_bite.R           # Minimum-wage bite test (§Threats)
│   │   ├── 05b_mw_bite_table.R    # MW bite tex fragments
│   │   ├── 06_honestdid.R         # Rambachan-Roth sensitivity (HonestDiD)
│   │   ├── 07_robustness_td.R     # Medicaid pool / alt thresholds / earn-density
│   │   ├── 07b_earnbins_scale.R   # Precision-scaled earnings permutation
│   │   ├── 07c_robustness_tables.R # Robustness tex fragments
│   │   ├── 08_dose_response.R     # Exposure-design dose response
│   │   ├── api_code.R             # IPUMS API data download
│   │   ├── gen_caleitc_params.R   # CalEITC kink parameters (provenance-verified)
│   │   ├── utils/                 # config, estimation, inference, taxsim,
│   │   │                          #   qc_assignment, sdid_panel/setup, clean_steps
│   │   └── validate/              # Stage-by-stage R-vs-Stata validation scripts
│   ├── hpc/                       # SLURM sbatch files (stages 1-18; see below)
│   ├── utils/
│   │   ├── globals.do             # Global macro definitions
│   │   ├── programs.do            # Reusable Stata programs
│   │   └── sdid_wt.do             # Weighted SDID estimation program
│   ├── archive/                   # Archived/backup files
│   └── logs/                      # Log files (incl. SLURM job logs)
│
├── config/
│   ├── parameters.yaml            # Years, seed, sample bounds, spec definitions
│   ├── caleitc_ftb3514.yaml       # Verified CalEITC schedule (FTB Form 3514)
│   └── local_paths.yaml(.example) # Machine-local paths (yaml gitignored)
│
├── data/
│   ├── raw/                       # Raw data files (not tracked)
│   ├── interim/                   # Intermediate processed data
│   ├── final/                     # Final analysis datasets (.dta and .rds)
│   ├── tmp/                       # Per-job scratch outputs (staged to results/)
│   ├── acs/                       # ACS data from IPUMS
│   ├── eitc_parameters/           # EITC benefit schedule parameters
│   │   └── caleitc_params.txt     # CalEITC kink point parameters by year/QC
│   └── taxsim/                    # TAXSIM working directory
│
├── results/
│   ├── figures/                   # Output figures (PNG, JPG)
│   ├── tables/                    # Output tables (LaTeX, CSV)
│   ├── paper/                     # Paper-ready outputs
│   ├── sdid_r/                    # Staged SDID results (job-tagged CSVs/.rds)
│   ├── appE_r/                    # Staged R inference-battery results
│   ├── mw_bite/                   # Staged minimum-wage bite results
│   ├── honestdid/                 # HonestDiD sensitivity CIs
│   ├── robustness/                # Medicaid / alt-threshold / earn-density results
│   └── dose_response/             # Dose-response results
│
├── renv/ + renv.lock              # R package library (R 4.4.2)
├── PLAN.md                        # Living revision/migration plan and work log
├── api_codes.txt                  # API keys (not tracked)
└── README.md
```

## Stata-to-R Migration (in progress)

The analysis is being migrated from Stata to R; `PLAN.md` is the living
plan and work log (author decisions, validation records, and the todo
list). Current state:

- **Validated ports** (R output checked against the Stata pipeline,
  row-for-row or coefficient-by-coefficient): QC assignment, working-file
  assembly, TAXSIM sims 1-3, the triple-diff/event-study estimation
  helpers, and the appendix inference battery.
- **New R-only analyses** (Phase 3 robustness agenda, PLAN.md §A):
  weighted county SDID on the `synthdid_weights` fork (Table 2), state-
  placebo randomization inference, SDID event studies + HonestDiD
  sensitivity, minimum-wage bite test, Medicaid-pool and alternative-
  threshold triple-diffs, earnings-density permutation, and the
  exposure-design dose response.
- **Still Stata**: the original `01`-`04` pipeline remains runnable;
  elasticities/MVPF (Phase 4) not yet ported.

### Cluster workflow

Long-running jobs go through SLURM (`code/hpc/stage*.sbatch`, stages
1-18: stages 1-3 legacy Stata jobs, 4-12 port-validation and inference
stages, 13-18 the SDID/robustness analyses). Jobs write to `data/tmp/`;
results are then staged into the job-tagged `results/` subdirectories
(e.g. `results/robustness/robustness_medicaid_job17253645.csv`) and
committed, so every committed result traces to a SLURM job id and log
in `code/logs/`.

### R environment

```bash
module load R/4.4.2-gfbf-2024a   # cluster
Rscript -e 'renv::restore()'     # installs the locked package library
```

`renv` activates via the root `.Rprofile`. Machine-local paths go in
`config/local_paths.yaml` (copy the `.example`); shared parameters
(years, seed, sample bounds) live in `config/parameters.yaml`. The SDID
estimation sources John's fork of `synthdid` with population weights
from a local checkout (`synthdid_weights`, path set by
`synthdid_dir` in `config/local_paths.yaml`; default sibling
`../synthdid_weights`).

## Data Sources

### Primary Data
- **American Community Survey (ACS):** Downloaded via IPUMS API (2006-2019)
  - Individual-level employment, demographics, and income data
  - Downloaded year-by-year via `code/R/api_code.R`

### Supplementary Data
- **Bureau of Labor Statistics (BLS):** Local Area Unemployment Statistics
  - State and county-level unemployment rates
  - Downloaded via `code/R/01_data_prep_other.R`
- **Minimum Wage Data:** Vaghul & Zipperer (2022)
  - State-level binding minimum wage
  - Downloaded from GitHub repository
- **NBER Recession Indicators:** FRED Series USREC
  - Monthly recession indicator (1 = recession, 0 = expansion)
  - Source: https://fred.stlouisfed.org/series/USREC
  - Downloaded January 2026
  - Stored in `data/raw/USREC.csv`

### EITC Parameters
- **CalEITC Parameters:** `data/eitc_parameters/caleitc_params.txt`
  - CalEITC kink point parameters (income that maximizes credit) by tax year and QC count
  - `pwages`: Kink point for years >= 2015
  - `pwages_unadj`: Values for CPI adjustment for years < 2015
- **TAXSIM:** NBER's tax simulation model
  - Used for computing federal and state tax liabilities, EITC benefits, and average tax rates
  - Requires `taxsimlocal35` Stata package

## API Keys Required

To run this analysis, you will need API keys from:

1. **IPUMS:** https://developer.ipums.org/docs/v2/get-started/
2. **BLS:** https://www.bls.gov/developers/home.htm

Store your API keys in a file called `api_codes.txt` in the project root with the format:
```
name, code
"ipums", "YOUR_IPUMS_API_KEY"
"bls", "YOUR_BLS_API_KEY"
```

This file is gitignored for security.

## Setup and Installation

### Stata Packages

```stata
* Install required packages
ssc install ftools
ssc install reghdfe
ssc install ppmlhdfe
ssc install fre
ssc install coefplot
ssc install estout
ssc install gtools
ssc install balancetable
ssc install ivreghdfe
ssc install ivreg2
ssc install ranktest
ssc install _gwtmean
ssc install rwolf2
ssc install wyoung

* For parallelized inference (optional)
net install parallel, from(https://raw.github.com/gvegayon/parallel/stable/) replace

* Install rcall for R integration
net install github, from("https://haghish.github.io/github/")
github install haghish/rcall, stable

* Install TAXSIM for tax simulations
net install taxsimlocal35, from("https://taxsim.nber.org/stata")
```

### R Packages

The R library is managed by `renv` (see the migration section above):

```r
renv::restore()   # installs everything in renv.lock (R 4.4.2)
```

Key packages: `dplyr`/`tidyr`/`readr` (data), `fixest` (estimation),
`HonestDiD` (sensitivity), `yaml`, `ipumsr`, `blsR`, `here`, plus the
local `synthdid_weights` fork for SDID.

## Running the Analysis

### Full Pipeline

1. **Set up API keys:** Create `api_codes.txt` with your IPUMS and BLS API keys

2. **Run main script:**
   ```stata
   * Open Stata and run
   do "code/00_caleitc.do"
   ```

   This will:
   - Load global macro definitions (`utils/globals.do`)
   - Load utility programs (`utils/programs.do`)
   - Download ACS data via IPUMS API (R)
   - Download BLS and minimum wage data (R)
   - Clean and prepare data (Stata)
   - Run all analyses (Stata)
   - Generate tables and figures (Stata)

### Individual Components

```stata
* Data preparation only
do "code/01_clean_data.do"

* Specific table
do "code/03_tab_main.do"

* Specific figure
do "code/03_fig_event_emp.do"
```

## Empirical Strategy

### Triple-Difference Design

The identification strategy compares:
- **Treatment group:** Single women with qualifying children in California
- **Control groups:**
  - Single women without qualifying children in California
  - Single women with/without qualifying children in control states

### Regression Specification

```
Y_ist = β(CA_s × Post_t × QC_i) + γX_ist + δ_s + δ_t + δ_q
        + δ_st + δ_sq + δ_tq + ε_ist
```

Where:
- `Y_ist`: Employment outcome for individual i in state s at time t
- `CA_s`: Indicator for California
- `Post_t`: Indicator for post-2015
- `QC_i`: Indicator for presence of qualifying children
- `X_ist`: Individual controls (education, age, race, etc.)
- Fixed effects: state, year, QC count, and interactions

### Sample Restrictions
- Single women
- Ages 20-49 (using `age_sample_20_49` indicator)
- No college degree (education < 4)
- US citizens
- Not in armed services
- Not currently in school

### TAXSIM Simulations

The data pipeline (`01_clean_data.do`) includes three TAXSIM simulations for elasticity and instrumental variable analyses. All simulations are restricted to years 2010-2019 (TAXSIM-compatible range).

1. **Simulation 1 - Observed Characteristics (All States)**
   - Runs TAXSIM on actual data with observed income for all states
   - One observation per tax unit (primary filer only)
   - Creates `taxsim_sim1_fedeitc` (federal EITC) and `taxsim_sim1_steitc` (state EITC)
   - Used for descriptive analysis of actual EITC receipt

2. **Simulation 2 - Simulated Instrument (All States, Sex-Specific)**
   - Uses 2014 observations as base year, projects to all years via CPI adjustment
   - Append-based approach: 2014 data is duplicated for each year with income scaled by CPI ratio
   - Runs TAXSIM on projected data, then collapses to cell-level weighted means
   - Cells: year × state × QC count × marital status × education × age bracket × sex
   - Creates `taxsim_sim2_fedeitc`, `taxsim_sim2_steitc`, `taxsim_sim2_wt`
   - Used as instrument in IV/2SLS estimation (Gruber & Saez 2002 approach)

3. **Simulation 3 - ATR at CalEITC Kink (Individual-Level)**
   - Computes average tax rate at CalEITC-maximizing income for each tax unit
   - Runs TAXSIM twice: (1) at CalEITC kink point, (2) at zero wages
   - For years < 2015: kink point is CPI-adjusted from 2015 values
   - Creates `taxsim_sim3_atr_st` using Kleven (2023) formula
   - Merged back at individual level (not cell-collapsed)
   - Used for elasticity calculations in Appendix D

### Control States

States are classified based on their EITC policies during the study period:
- `state_status = 2`: California (treated) - FIPS 6
- `state_status = 1`: Control states (no state EITC changes)
- `state_status = 0`: Excluded (states with EITC policy changes)
- `state_status = -1`: Excluded (Alaska, DC) - FIPS 2, 11

**States with EITC policy changes (excluded, FIPS codes):**
8 (CO), 9 (CT), 15 (HI), 17 (IL), 19 (IA), 20 (KS), 22 (LA), 23 (ME), 24 (MD), 25 (MA), 26 (MI), 27 (MN), 30 (MT), 34 (NJ), 35 (NM), 39 (OH), 41 (OR), 44 (RI), 45 (SC), 50 (VT), 55 (WI)

### Alternative Control State Pools

For robustness checks, two alternative control pools are used:

**States with a state EITC (excluded from "no-EITC" control pool, FIPS codes):**
2 (AK), 8 (CO), 9 (CT), 10 (DE), 11 (DC), 15 (HI), 17 (IL), 18 (IN), 19 (IA), 23 (ME), 24 (MD), 25 (MA), 26 (MI), 27 (MN), 30 (MT), 31 (NE), 34 (NJ), 35 (NM), 39 (OH), 40 (OK), 41 (OR), 44 (RI), 45 (SC), 49 (UT), 50 (VT), 51 (VA), 55 (WI)

**Medicaid expansion states (2014, for robustness, FIPS codes):**
4 (AZ), 5 (AR), 6 (CA), 8 (CO), 9 (CT), 10 (DE), 11 (DC), 15 (HI), 17 (IL), 19 (IA), 21 (KY), 24 (MD), 25 (MA), 26 (MI), 27 (MN), 32 (NV), 33 (NH), 34 (NJ), 35 (NM), 36 (NY), 38 (ND), 39 (OH), 41 (OR), 44 (RI), 50 (VT), 53 (WA), 54 (WV)

## Key Programs

### Global Macros (`code/utils/globals.do`)

Centralizes standard variable definitions used across all analysis files:
- **`$outcomes`**: Primary outcome variables (`employed_y full_time_y part_time_y`)
- **`$controls`**: Demographic controls (`education age_bracket minage_qc race_group hispanic hh_adult_ct`)
- **`$unemp`**, **`$minwage`**: Economic control variables
- **`$clustervar`**: Clustering variable (`state_fips`)
- **`$did_base`**, **`$did_event`**: Fixed effects specifications
- **`$baseline_sample`**: Standard sample restriction conditions
- **`$stats_list`**, **`$stats_fmt`**: Table statistics formatting

### Utility Programs (`code/utils/programs.do`)

Reusable Stata programs for analysis:

| Program | Purpose |
|---------|---------|
| `qc_assignment` | Assigns qualifying children to potential adults in household based on IPUMS relationship variables |
| `load_baseline_sample` | Loads ACS data with standard sample restrictions |
| `setup_did_vars` | Creates ca, post, treated variables and caps hh_adult_ct |
| `run_triple_diff` | Runs triple-difference regression with specified controls and FEs |
| `run_event_study` | Runs event study regression with year interactions |
| `make_event_plot` | Creates event study coefficient plots |
| `get_pre_period_mean` | Calculates weighted mean for treated group in pre-period |
| `run_ppml_event_study` | Runs PPML event study regression |
| `run_ppml_regression` | Runs PPML regression with margins for average marginal effect |
| `export_results` | Dual export to local and Overleaf with single call |
| `run_all_specs` | Runs all 4 specifications for a given outcome |
| `export_event_coefficients` | Exports event study coefficients to CSV |
| `export_graph` | Exports graph to local and Overleaf |
| `run_heterogeneity_table` | Runs heterogeneity analysis across subgroups |
| `add_spec_indicators` | Adds specification indicator statistics to stored estimates |
| `add_table_stats` | Adds common table statistics (ymean, implied effect) |
| `export_spec_indicators` | Exports specification indicators table |
| `export_table_panel` | Exports regression results to LaTeX format |
| `make_table_coefplot` | Creates coefficient plot from table estimates |

### SDID Program (`code/utils/sdid_wt.do`)
- **`sdid_wt`**: Population-weighted Synthetic DID estimation with bootstrap standard errors

### Inference Programs (`code/04_appE_inference_programs.do`)
- **`ferman_pinto_boot_ind`**: Block bootstrap with Ferman-Pinto (2019) adjustment for few treated clusters
- **`ri_bs`**: Randomization inference wild cluster bootstrap (MacKinnon & Webb 2019)

## Output

Outputs are organized to match the paper structure. Two paper versions exist:
- **`main_aejep.tex`** — AEJ:EP submission (~40 pages, 12 main-text exhibits)
- **`main.tex`** — Full working draft (~93 pages, 19+ exhibits)

The master script `00_caleitc.do` produces exhibits for `main_aejep.tex` by default. To reproduce the full draft, uncomment the "DEMOTED" and "ARCHIVED" blocks.

### Main Text Exhibits (AEJ:EP, `main_aejep.tex`)

| Exhibit | Output File | Description |
|---------|-------------|-------------|
| **Section 2: Policy Background** |||
| Figure 1 | `fig_eitc_sched.*` | Federal and CA EITC benefits schedule, TY 2016 |
| Figure 2 | `fig_earn_hist.*` | Histograms of California workers |
| **Section 3: Conceptual Framework** |||
| Figure 3 | `fig_budget.*` | Budget constraint for parent with 2 QC (2016) |
| **Section 5.1: Main Results** |||
| Table 1 | `tab_main*.tex` | Triple-diff estimates on annual employment |
| Figure 4 | `fig_event_emp.*` | Event-study estimates on annual employment |
| **Section 5.2: Decomposition** |||
| Figure 5 | `fig_hours_bins.*` | Effect by weekly hours worked |
| **Section 5.3: Robustness** |||
| Table 2 | `tab_sdid_county*.tex` | County-panel weighted SDID estimates |
| Figure 6 | `fig_event_emp_college.*` | College-educated sample (falsification) |
| **Section 6: Earnings** |||
| Table 3 | `tab_earnings*.tex` | Triple-diff estimates on annual earnings |
| Figure 7 | `fig_earn_bins.*` | Changes in earnings distribution over time |
| **Section 7: Heterogeneity** |||
| Figure 8 | `fig_tab_het_adults.*` | Employment effects by number of adults |
| **Section 8: MVPF** |||
| Figure 9 | `fig_mvpf_distribution.*` | Distribution of MVPF estimates |

Additional inline results from: `03_tab_quad_diff.do` (quadruple-diff), `03_tab_oster_bounds.do` (Oster bounds), `03_fig_event_earn.do` (own vs HH income)

### Appendix Outputs

| Paper Ref | Output File | Description |
|-----------|-------------|-------------|
| **Appendix A: Additional Tables and Figures** |||
| Table A.1 (p.68) | `tab_appA_tab1.tex` | Sample states and population statistics |
| Figure A.1 (p.69) | `fig_appA_eitc_sched_15_17.*` | EITC schedules, TY 2015 and 2017 |
| Figure A.2 (p.70) | `fig_appA_eitc_ctc_sched.*` | EITC and CTC schedule by QC (2016) |
| Figure A.3 (p.71) | `fig_appA_tcja_yctc.*` | Post-2017 changes to tax credits |
| Figure A.4 (p.72) | `fig_appA_unemp_trends.*` | State-level unemployment trends |
| Figure A.5 (p.73) | `fig_appA_minwage.*` | Binding state minimum wages |
| Figure A.6 (p.74) | `fig_appA_atr_event.*` | Triple-diff effect on after-tax rate |
| Tables A.2-A.3 (p.75) | `tab_balance*.tex` | Triple-diff balance tests |
| Table A.4 (p.76) | `tab_col_placebo*.tex` | College placebo test |
| **Appendix B: Other Populations** |||
| Figures B.1-B.3 (p.78-80) | `fig_appB_event_*.jpg` | Married women, single men, married men |
| **Appendix C: Self-Employment** |||
| Table C.1 (p.83) | `tab_appC_tab1*.tex` | Employment effects (wage workers) |
| Table C.2 (p.84) | `tab_appC_tab2*.tex` | Effects on self-employment |
| Figure C.1 (p.85) | `fig_appC_fig1.*` | Event-study (wage workers) |
| Figure C.2 (p.86) | `fig_appC_fig2.*` | Event-study (self-employment) |
| **Appendix D: Inference** |||
| Table D.1 (p.93) | `tab_appE_tab1*.tex` | Alternative inference procedures |

### Demoted from Main Text (appendix or available from full draft)

| Output File | Description | Status |
|-------------|-------------|--------|
| `fig_emp_trends.*` | FT/PT employment trends | Appendix candidate |
| `fig_weeks.*` | Effect by annual weeks | Appendix candidate |
| `fig_spec_curve.*` | Specification curves | Appendix candidate |
| `fig_tab_het_qc.*` | Employment effects by number of QC | Appendix candidate |
| `fig_tab_het_qc_age.*` | Employment effects by age of youngest QC | Appendix candidate |
| `fig_mvpf_spillovers.*` | Implied fiscal spillovers | Appendix candidate |

### Archived Outputs (not in AEJ:EP submission)

- `tab_sim_inst_*.tex` — Simulated instrument (footnote only)
- `tab_intensive_*.tex` — Intensive margin (hours, weeks)
- `tab_earn_hhcomp_*.tex` — Earnings by HH composition
- `tab_hh_earn_*.tex` — Household earnings (OLS and PPML)
- `tab_sdid_state_*.tex` — State-level SDID (superseded by county)
- `fig_appA_spec_curve_reported_*` — Specification curves (reported hours/weeks)

## Notes

- All monetary values are adjusted to 2019 dollars using CPI99
- Standard errors are clustered at the state level
- The analysis excludes individuals assigned as qualifying children (age < 18 or QC flag)
- County-level unemployment rates are imputed for suppressed counties using state-year averages
- PPML estimates include average marginal effects (AME) for interpretation in levels
- TAXSIM simulations are restricted to years 2010-2019 and use SOI state codes (converted from FIPS via inline crosswalk)
- TAXSIM output variables: `v25` = federal EITC, `v39` = state EITC, `v10` = AGI
- Simulated instrument (Sim 2) uses 2014 as base year with CPI projection to other years
- ATR calculations (Sim 3) follow Kleven (2023): ATR = ((fiitax - fiitax_0) + (siitax - siitax_0) + fica) / agi

## Citation

If you use this code or data, please cite:

```
Iselin, John. "The Labor Supply Effects of the California Earned Income Tax Credit."
Working Paper, Yale University.
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
