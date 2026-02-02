# The Labor Supply Effects of the California Earned Income Tax Credit

This repository contains the replication code and materials for the paper analyzing the labor supply effects of the California Earned Income Tax Credit (CalEITC).

**Author:** John Iselin
**Contact:** john.iselin@yale.edu

## Project Overview

This paper examines the labor supply effects of the CalEITC, introduced in 2015 as a state-level supplement to the federal EITC. Using American Community Survey (ACS) data and a triple-difference research design, I estimate the effect of the CalEITC on employment among single women with qualifying children.

## Repository Structure

```
caleitc_laborsupply/
├── code/
│   ├── 00_caleitc.do              # Master script (runs all analyses)
│   ├── 01_clean_data.do           # Data cleaning and preparation
│   ├── 02_descriptives.do         # Descriptive statistics
│   ├── 02_eitc_param_prep.do      # EITC benefit schedule preparation
│   ├── 02b_caleitc_param_gen.do   # CalEITC parameters generation
│   ├── 03_fig_eitc_sched.do       # Figure: EITC benefit schedules
│   ├── 03_fig_earn_hist.do        # Figure: Earnings histogram by employment type
│   ├── 03_fig_earn_bins.do        # Figure: Earnings distribution by bins
│   ├── 03_fig_treat_by_earn.do    # Figure: Treatment effects by earnings
│   ├── 03_fig_budget.do           # Figure: Budget constraint
│   ├── 03_tab_desc.do             # Table: Descriptive statistics (deprecated)
│   ├── 03_fig_emp_trends.do       # Figure: Employment trends
│   ├── 03_fig_event_emp.do        # Figure: Event-study estimates (employment)
│   ├── 03_fig_weeks.do            # Figure: Effect by weeks worked
│   ├── 03_fig_event_earn.do       # Figure: Event-study estimates (earnings, PPML)
│   ├── 03_fig_spec_curve.do       # Figure: Specification curves
│   ├── 03_tab_main.do             # Table: Main triple-difference estimates
│   ├── 03_tab_sim_inst.do         # Table: Simulated instrument results
│   ├── 03_tab_intensive.do        # Table: Intensive margin (hours, weeks, weekly emp)
│   ├── 03_tab_het_qc.do           # Table: Heterogeneity by QC count
│   ├── 03_tab_het_adults.do       # Table: Heterogeneity by adult count
│   ├── 03_tab_earnings.do         # Table: Earnings effects (OLS & PPML)
│   ├── 03_tab_earn_hhcomp.do      # Table: Earnings by HH composition
│   ├── 03_tab_hh_earn.do          # Table: Household earnings effects (OLS & PPML)
│   ├── 03_sdid_state.do           # SDID Table 1: State panel SDID (with event study)
│   ├── 03_sdid_county.do          # SDID Table 2: County panel weighted SDID
│   ├── 04_appA_tab1.do            # Appendix A Table 1: Descriptive statistics
│   ├── 04_appA_tab_balance.do     # Appendix A: Balance test for pre-treatment covariates
│   ├── 04_appA_tab_het_qc_age.do  # Appendix A: Heterogeneity by youngest QC age
│   ├── 04_appA_fig_eitc_sched_15_17.do     # Appendix A: EITC schedules 2015 vs 2017
│   ├── 04_appA_fig_eitc_ctc_sched.do       # Appendix A: EITC/CTC/CalEITC schedules (2016)
│   ├── 04_appA_fig_unemp_trends.do         # Appendix A: State unemployment trends
│   ├── 04_appA_fig_minwage.do              # Appendix A: State minimum wages
│   ├── 04_appA_fig_tcja_yctc.do            # Appendix A: 2018-2019 schedules with TCJA
│   ├── 04_appA_fig_atr_event.do            # Appendix A: CalEITC effect on ATR
│   ├── 04_appA_fig_event_ny_placebo.do     # Appendix A: NY placebo event study
│   ├── 04_appA_tab_ny_placebo.do           # Appendix A: NY placebo table
│   ├── 04_appA_fig_event_col_placebo.do    # Appendix A: College sample event study
│   ├── 04_appA_tab_col_placebo.do          # Appendix A: College sample table
│   ├── 04_appA_fig_spec_curve_reported.do  # Appendix A: Spec curves (reported hours/weeks)
│   ├── 04_appendix.do             # Additional appendix tables and figures
│   ├── 04_appendix_otherpops.do   # Appendix: Alternative populations analysis
│   ├── 04_appC_fig_wage_emp.do    # Appendix C Fig 1: Event study (wage workers)
│   ├── 04_appC_fig_self_emp.do    # Appendix C Fig 2: Event study (self-employment)
│   ├── 04_appC_tab_wage_emp.do    # Appendix C Tab 1: Triple-diff (wage workers)
│   ├── 04_appC_tab_self_emp.do    # Appendix C Tab 2: Triple-diff (self-employment)
│   ├── 04_appD_elasticity.do      # Appendix D: Elasticity calculations
│   ├── 04_appE_inference.do       # Appendix E: Alternative inference procedures
│   ├── 04_appE_inference_parallel.do       # Appendix E: Parallelized inference
│   ├── 04_appE_inference_programs.do       # Appendix E: Inference helper programs
│   ├── 04_appE_inference_worker.do         # Appendix E: Worker program for parallel
│   ├── 05_mvpf.do                 # MVPF calculations
│   ├── 05_fig_mvpf_dist.do        # Figure: MVPF distribution
│   ├── 05_fig_mvpf_spillovers.do  # Figure: MVPF fiscal spillovers
│   ├── R/
│   │   ├── api_code.R             # IPUMS API data download
│   │   └── 01_data_prep_other.R   # BLS and minimum wage data prep
│   ├── utils/
│   │   ├── globals.do             # Global macro definitions (NEW)
│   │   ├── programs.do            # Reusable Stata programs
│   │   └── sdid_wt.do             # Weighted SDID estimation program
│   ├── archive/                   # Archived/backup files
│   └── logs/                      # Log files
├── data/
│   ├── raw/                       # Raw data files (not tracked)
│   ├── interim/                   # Intermediate processed data
│   ├── final/                     # Final analysis datasets
│   ├── acs/                       # ACS data from IPUMS
│   ├── eitc_parameters/           # EITC benefit schedule parameters
│   │   └── caleitc_params.txt     # CalEITC kink point parameters by year/QC
│   └── taxsim/                    # TAXSIM working directory
├── results/
│   ├── figures/                   # Output figures (PNG, JPG)
│   ├── tables/                    # Output tables (LaTeX, CSV)
│   └── paper/                     # Paper-ready outputs
├── api_codes.txt                  # API keys (not tracked)
└── README.md
```

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

```r
# Core packages
install.packages(c(
  "dplyr", "tidyr", "readr", "stringr",
  "tidycensus", "blsR", "readxl"
))

# IPUMS integration
install.packages("ipumsr")
```

## Running the Analysis

### Full Pipeline

1. **Set up API keys:** Create `api_codes.txt` with your IPUMS and BLS API keys

2. **Run master script:**
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
- `state_status = 2`: California (treated)
- `state_status = 1`: Control states (no state EITC changes)
- `state_status = 0`: Excluded (states with EITC policy changes)
- `state_status = -1`: Excluded (Alaska, DC)

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

### Figures
- **fig_eitc_sched:** Federal and California EITC benefit schedules
- **fig_earn_hist:** Distribution of earnings by full-time/part-time status
- **fig_budget:** Budget constraint with EITC
- **fig_emp_trends:** Employment trends by treatment group
- **fig_event_emp:** Event-study estimates (employment)
- **fig_weeks:** Effect by annual weeks of work
- **fig_event_earn:** Event-study estimates (earnings, PPML)
- **fig_spec_curve:** Specification curve analysis
- **fig_tab_main:** Coefficient plot for main results table
- **fig_tab_het_qc:** Coefficient plot for QC heterogeneity table
- **fig_tab_het_adults:** Coefficient plot for adult count heterogeneity table

### Tables
- **tab_main:** Triple-difference estimates on employment (main results)
- **tab_sim_inst_rf:** Reduced form estimates using simulated EITC instrument
- **tab_sim_inst_iv:** IV/2SLS estimates using simulated EITC as instrument
- **tab_intensive:** Triple-difference estimates on intensive margin (hours, weeks, weekly employment)
- **tab_het_qc:** Heterogeneity by qualifying children count
- **tab_het_adults:** Heterogeneity by adults in household
- **tab_earnings:** Effect on annual earnings (OLS and PPML)
- **tab_earn_hhcomp:** Earnings by household composition
- **tab_hh_earn:** Effect on household earnings (OLS and PPML)

### SDID Tables
- **tab_sdid_state:** State panel SDID estimates (Basic and Triple, with/without covariates)
- **tab_sdid_state_combined:** Combined state panel results across all outcomes
- **tab_sdid_county:** County panel weighted SDID estimates
- **tab_sdid_county_combined:** Combined county panel results across all outcomes

### SDID Figures
- **fig_sdid_event_employed_y:** SDID event study for employment
- **fig_sdid_event_full_time_y:** SDID event study for full-time employment
- **fig_sdid_event_part_time_y:** SDID event study for part-time employment
- **fig_sdid_event_incearn_real:** SDID event study for earnings

### Appendix A
- **Appendix Table 1:** Descriptive statistics
- **tab_balance:** Balance test for pre-treatment covariate balance
- **fig_appA_eitc_ctc_sched:** Federal EITC, CTC, and CalEITC benefit schedules for TY 2016 (by QC count)
- **fig_appA_unemp_trends:** State-level unemployment trends (2006-2019), CA vs control states
- **fig_appA_minwage:** Binding state minimum wages in control pool (2010-2017)
- **fig_appA_tcja_yctc:** CTC comparison 2017 vs 2018 (TCJA) and 2019 with YCTC
- **fig_appA_atr_event:** Triple-diff estimate of CalEITC effect on after-tax rates (event study)
- **fig_event_ny_placebo:** NY placebo event study (NY as treatment, CA excluded)
- **tab_ny_placebo:** NY placebo triple-diff table
- **fig_event_col_placebo:** College-educated sample event study (falsification test)
- **tab_col_placebo:** College-educated sample triple-diff table
- **fig_appA_spec_curve_reported_*:** Specification curves restricted to individuals with reported (non-imputed) hours and weeks worked
- **tab_otherpops_nocov:** Triple-diff by population (no covariates)
- **tab_otherpops_allcov:** Triple-diff by population (all covariates)
- **fig_event_emp_sw/sm/mw/mm:** Event study by population

### Appendix C: Wage Workers and Self-Employment
- **fig_appC_fig1:** Event-study estimates for wage workers only
- **fig_appC_fig2:** Event-study estimates for self-employment
- **tab_appC_tab1:** Triple-diff estimates for wage workers
- **tab_appC_tab2:** Triple-diff estimates for self-employment

### Appendix D: Elasticity Calculations
- **Participation elasticity:** Calculated using ATR changes at CalEITC kink point
- **Mobility elasticity:** Calculated using TAXSIM simulations for different wage scenarios

### Appendix E: Alternative Inference
- **tab_appE_tab1:** Alternative inference procedures for main results
  - Cluster-robust variance estimator (CRVE)
  - Wild cluster bootstrap (WCBS)
  - Randomization inference wild bootstrap (RIWB-t, RIWB-b)
  - Block bootstrap with Ferman-Pinto (2019) correction

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

This project is for academic research purposes. Please contact the author for permissions.

## Changelog

### February 2026 (Code Refactoring)
- **Major code refactoring for improved maintainability:**
  - Created `utils/globals.do` to centralize standard variable definitions
  - Added 7 new utility programs to `utils/programs.do`:
    - `load_baseline_sample`: Standardized data loading with sample restrictions
    - `setup_did_vars`: Standardized DID variable creation
    - `export_results`: Dual export to local and Overleaf
    - `run_all_specs`: Run all 4 specifications in one call
    - `export_event_coefficients`: Export coefficients to CSV
    - `export_graph`: Standardized graph export
    - `run_heterogeneity_table`: Standardized heterogeneity analysis
  - Refactored 15+ analysis files to use new utilities
  - ~50% reduction in boilerplate code
- **Bug fixes:**
  - Fixed export paths in `03_tab_het_qc.do` and `03_tab_het_adults.do` (was exporting to `tables/` instead of `figures/`)
  - Standardized age restriction to 20-49 using `age_sample_20_49` indicator across all files
  - Fixed hardcoded start year in `04_appE_inference_parallel.do`
- **File organization:**
  - Renamed Appendix A figure files with descriptive names:
    - `04_appA_fig2.do` → `04_appA_fig_eitc_ctc_sched.do`
    - `04_appA_fig3.do` → `04_appA_fig_unemp_trends.do`
    - `04_appA_fig4.do` → `04_appA_fig_minwage.do`
    - `04_appA_fig5.do` → `04_appA_fig_tcja_yctc.do`
    - `04_appA_fig6.do` → `04_appA_fig_atr_event.do`
  - Created `code/archive/` folder for backup files
  - Moved deprecated inference files to archive
- **New appendix files:**
  - `04_appA_tab_balance.do`: Balance test for pre-treatment covariate balance
  - `04_appA_tab_het_qc_age.do`: Heterogeneity by age of youngest qualifying child
- **Package updates:**
  - Added `rwolf2` for Romano-Wolf p-values
  - Added `wyoung` for Westfall-Young q-values
  - Added `parallel` for parallelized inference (optional)

### February 2026 (TAXSIM Integration)
- Added TAXSIM simulations to data cleaning pipeline (`01_clean_data.do`)
  - Simulation 1: Observed characteristics (all states) for actual EITC receipt
  - Simulation 2: Simulated instrument using 2014 base year with CPI projection (Gruber & Saez approach)
  - Simulation 3: ATR at CalEITC kink (individual-level) for elasticity calculations
  - All simulations restricted to years 2010-2019 (TAXSIM-compatible range)
- Added FIPS-to-SOI crosswalk for TAXSIM state codes
- Created `03_tab_sim_inst.do` for simulated instrument results (reduced form and IV/2SLS)
- Added CalEITC parameters file (`data/eitc_parameters/caleitc_params.txt`)
- Updated package requirements: added `ivreghdfe`, `ivreg2`, `ranktest`, `taxsimlocal35`

### January 2026
- Initial repository setup
- Implemented data pipeline via IPUMS API
- Created triple-difference and event-study analyses
- Added reusable Stata programs for regressions and figures
- Added specification curve analysis (Figure 7)
- Added earnings analysis with PPML (Tables 5 and 6)
- Moved descriptive statistics to appendix
- Added Synthetic DID (SDID) analysis: state panel with event studies, county panel with population weights
- Created `sdid_wt` program for weighted SDID estimation
- Added Appendix A: NY placebo test and college-educated sample falsification tests
- Added Appendix C: Wage workers and self-employment analysis
- Added Appendix D: Participation and mobility elasticity calculations (with TAXSIM)
- Added Appendix E: Alternative inference procedures (CRVE, Wild Bootstrap, Ferman-Pinto correction)
