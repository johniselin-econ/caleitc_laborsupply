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
│   │   ## (03) MAIN TEXT - BY PAPER SECTION
│   │   # Section 2.1: Federal and California EITC Structure
│   ├── 03_fig_eitc_sched.do       # Figure 1: EITC benefit schedules (TY 2016)
│   ├── 03_fig_earn_hist.do        # Figure 2: Histograms of CA workers
│   │   # Section 3: Conceptual Framework
│   ├── 03_fig_budget.do           # Figure 3: Budget constraint (2 QC, 2016)
│   │   # Section 5.1: Trends
│   ├── 03_fig_emp_trends.do       # Figure 4: FT/PT employment trends
│   │   # Section 5.2: Primary Triple-Difference Results
│   ├── 03_tab_main.do             # Table 1: Main triple-diff estimates
│   ├── 03_fig_event_emp.do        # Figure 5: Event-study (employment)
│   ├── 03_fig_hours_bins.do       # Figure 6: Effect by weekly hours
│   ├── 03_fig_weeks.do            # Figure 7: Effect by annual weeks
│   │   # Section 5.4: Robustness
│   ├── 03_sdid_state.do           # Table 2: Synthetic DID estimates
│   ├── 03_fig_event_col_placebo.do # Figure 8: College placebo (falsification)
│   ├── 03_fig_spec_curve.do       # Figure 9: Specification curves
│   │   # Section 6: Annual Earnings
│   ├── 03_tab_earnings.do         # Table 3: Earnings effects (OLS & PPML)
│   ├── 03_fig_earn_bins.do        # Figure 10: Earnings distribution changes
│   │   # Section 7: Heterogeneity
│   ├── 03_tab_het_qc.do           # Figure 11: By number of QC
│   ├── 03_tab_het_adults.do       # Figure 12: By number of adults
│   ├── 03_tab_het_qc_age.do       # Figure 13: By age of youngest QC
│   ├── 03_fig_event_earn.do       # Figure 14: Own vs HH income event-study
│   │   # Section 8: MVPF and Fiscal Externalities
│   ├── 03_fig_mvpf_dist.do        # Figure 15: MVPF distribution
│   ├── 03_fig_mvpf_spillovers.do  # Figure 16: Fiscal spillovers
│   │   # ** FUTURE WORK ** (not currently in paper)
│   ├── 03_fig_treat_by_earn.do    # Treatment effects by earnings bins
│   ├── 03_tab_earn_hhcomp.do      # Earnings by HH composition
│   ├── 03_tab_intensive.do        # Intensive margin (hours, weeks)
│   ├── 03_tab_sim_inst.do         # Simulated instrument results
│   ├── 03_tab_hh_earn.do          # Household earnings (OLS & PPML)
│   ├── 03_sdid_county.do          # County panel weighted SDID
│   ├── 03_tab_desc.do             # Deprecated - see 04_appA_tab1.do
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
│   ├── R/
│   │   ├── api_code.R             # IPUMS API data download
│   │   └── 01_data_prep_other.R   # BLS and minimum wage data prep
│   ├── utils/
│   │   ├── globals.do             # Global macro definitions
│   │   ├── programs.do            # Reusable Stata programs
│   │   └── sdid_wt.do             # Weighted SDID estimation program
│   ├── archive/                   # Archived/backup files
│   └── logs/                      # Log files
│
├── data/
│   ├── raw/                       # Raw data files (not tracked)
│   ├── interim/                   # Intermediate processed data
│   ├── final/                     # Final analysis datasets
│   ├── acs/                       # ACS data from IPUMS
│   ├── eitc_parameters/           # EITC benefit schedule parameters
│   │   └── caleitc_params.txt     # CalEITC kink point parameters by year/QC
│   └── taxsim/                    # TAXSIM working directory
│
├── results/
│   ├── figures/                   # Output figures (PNG, JPG)
│   ├── tables/                    # Output tables (LaTeX, CSV)
│   └── paper/                     # Paper-ready outputs
│
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

Outputs are organized to match the paper structure.

### Main Text Figures and Tables

| Paper Ref | Output File | Description |
|-----------|-------------|-------------|
| **Section 2.1: Federal and California EITC Structure** |||
| Figure 1 (p.10) | `fig_eitc_sched.*` | Federal and CA EITC benefits schedule, TY 2016 |
| Figure 2 (p.11) | `fig_earn_hist.*` | Histograms of California workers |
| **Section 3: Conceptual Framework** |||
| Figure 3 (p.13) | `fig_budget.*` | Budget constraint for parent with 2 QC (2016) |
| **Section 5.1: Trends** |||
| Figure 4 (p.22) | `fig_emp_trends.*` | Full-time and part-time employment in the ACS |
| **Section 5.2: Primary Triple-Difference Results** |||
| Table 1 (p.24) | `tab_main*.tex` | Triple-diff estimates on annual employment |
| Figure 5 (p.25) | `fig_event_emp.*` | Event-study estimates on annual employment |
| Figure 6 (p.27) | `fig_hours_bins.*` | Effect by weekly hours worked |
| Figure 7 (p.28) | `fig_weeks.*` | Effect by annual weeks of work |
| **Section 5.4: Robustness** |||
| Table 2 (p.30) | `tab_sdid_state*.tex` | Synthetic DID estimates |
| Figure 8 (p.31) | `fig_event_col_placebo.*` | College-educated sample (falsification) |
| Figure 9 (p.34) | `fig_spec_curve.*` | Specification curves |
| **Section 6: Annual Earnings** |||
| Table 3 (p.38) | `tab_earnings*.tex` | Triple-diff estimates on annual earnings |
| Figure 10 (p.39) | `fig_earn_bins.*` | Changes in earnings distribution over time |
| **Section 7: Heterogeneity** |||
| Figure 11 (p.45) | `fig_tab_het_qc.*` | Employment effects by number of QC |
| Figure 12 (p.47) | `fig_tab_het_adults.*` | Employment effects by number of adults |
| Figure 13 (p.48) | `fig_tab_het_qc_age.*` | Employment effects by age of youngest QC |
| Figure 14 (p.50) | `fig_event_earn.*` | Mother's earnings vs household income |
| **Section 8: MVPF and Fiscal Externalities** |||
| Figure 15 (p.53) | `fig_mvpf_dist.*` | Distribution of MVPF estimates |
| Figure 16 (p.55) | `fig_mvpf_spillovers.*` | Implied fiscal spillovers |

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

### Additional Outputs (Not in Current Paper)

- `tab_sim_inst_*.tex` - Simulated instrument (RF and IV/2SLS)
- `tab_intensive_*.tex` - Intensive margin (hours, weeks, weekly employment)
- `tab_earn_hhcomp_*.tex` - Earnings by household composition
- `tab_hh_earn_*.tex` - Household earnings (OLS and PPML)
- `tab_sdid_county_*.tex` - County panel weighted SDID
- `fig_appA_spec_curve_reported_*` - Specification curves (reported hours/weeks only)

## Notes

- **NY Placebo Test Removed:** The New York placebo test was removed from the analysis because the pre-trends were ill-fitting, making it unsuitable as a falsification test.
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

## To-Do List

### Part 1: Paper → Code (Items to run/update in repo)

#### Figure Naming Inconsistencies
- [ ] **MVPF distribution figure**: Paper references `fig13.jpg`, code produces `fig_mvpf_dist.jpg` → Update paper reference or rename output
- [ ] **Earnings bins figure**: Paper references `fig_earn_binsa.jpg`/`fig_earn_binsb.jpg`, code produces `fig_earn_bins_a.jpg`/`fig_earn_bins_b.jpg` → Standardize naming
- [ ] **Appendix A figures use old numeric naming**: Paper still references `fig_appA_fig3.jpg`, `fig_appA_fig4.jpg`, `fig_appA_fig5a.jpg`, `fig_appA_fig5b.jpg`, `fig_appA_fig6.jpg` → Either:
  - Update code to produce both old and new names, OR
  - Update paper to use new descriptive names (`fig_appA_unemp_trends.jpg`, `fig_appA_minwage.jpg`, etc.)
- [x] **Other populations figures**: Renamed to `fig_appB_event_mw.jpg`, `fig_appB_event_sm.jpg` (code: `04_appB_otherpops.do`)

#### Missing/Incomplete Code
- [ ] **Household income event study figure**: Paper references `fig_event_earn_hh.jpg` → Verify `03_fig_event_earn.do` produces this or create new code
- [ ] **State table**: Paper references `tables/fig_appA_fig1.tex` (confusing name for a table) → Rename to `tab_state_sample.tex`

#### Code Updates Needed
- [ ] Verify all SDID event study figures are being exported with correct names
- [ ] Ensure MVPF spillovers figure exports to `fig_mvpf_spillovers.jpg` (check `05_fig_mvpf_spillovers.do`)
- [x] Run `04_appB_otherpops.do` to generate Appendix B figures for married women and men (renamed and updated)

---

### Part 2: Code → Paper (Items to add/reference in paper)

#### Analyses in Repo Not Yet in Paper
- [ ] **Simulated instrument analysis** (`03_tab_sim_inst.do`): Reduced form and IV/2SLS estimates using TAXSIM-based instrument
  - Add as robustness check or main specification
  - Tables: `tab_sim_inst_rf_*.tex`, `tab_sim_inst_iv_*.tex`
- [ ] **Intensive margin table** (`03_tab_intensive.do`): Hours, weeks, weekly employment effects
  - Could strengthen hours-per-week discussion in paper
  - Tables: `tab_intensive_*.tex`
  - Figure: `fig_tab_intensive.jpg`
- [ ] **State-level SDID** (`03_sdid_state.do`): Paper only shows county SDID
  - Event study figures: `fig_sdid_event_*.jpg`
  - Tables: `tab_sdid_state_*.tex`
- [ ] **Earnings by household composition** (`03_tab_earn_hhcomp.do`):
  - Could support heterogeneity discussion
  - Tables: `tab_earn_hhcomp_*.tex`

#### Appendix Items to Add/Reference
- [ ] **Specification curves for reported hours/weeks** (`04_appA_fig_spec_curve_reported.do`):
  - Figures: `fig_appA_spec_curve_reported_*.jpg`
  - Add note in paper about robustness to excluding imputed values
- [ ] **Descriptive statistics table** (`04_appA_tab1.do`):
  - Table: `tab_appA_tab1.tex`
  - Reference in Appendix A
- [ ] **MVPF by sample/specification** (`05_mvpf.do`):
  - CSVs: `mvpf_by_sample.csv`, `mvpf_by_contrs.csv`, `mvpf_by_hetero.csv`
  - Could add sensitivity table to MVPF section

#### Cross-Reference Updates
- [ ] Update paper's Appendix D (Elasticity) to reference `04_appD_elasticity.do` methodology
- [ ] Update paper's Appendix E (Inference) section to reference `04_appE_inference.do` programs
- [ ] Add data availability statement referencing IPUMS API and BLS data sources
- [ ] Add software citation for TAXSIM (Feenberg & Coutts)

---

### Part 3: Synchronization Tasks

#### File Organization
- [ ] Ensure Overleaf `figures/` folder matches repo `results/figures/` output
- [ ] Ensure Overleaf `tables/` folder matches repo `results/tables/` output
- [ ] Create mapping document: paper figure/table number ↔ code file ↔ output filename

#### Documentation
- [ ] Add paper figure numbers to code file headers (e.g., "Creates Figure 3")
- [ ] Update code comments to reference paper sections
- [ ] Add Overleaf sync instructions to README

#### Quality Checks
- [ ] Run full pipeline (`00_caleitc.do`) and verify all outputs generate without errors
- [ ] Compare Overleaf figure files against repo output files for any discrepancies
- [ ] Verify all table `.tex` files have matching column counts with paper table environments

---

### Priority Items (for next revision)

**High Priority:**
1. Fix figure naming inconsistencies (especially MVPF and Appendix A figures)
2. Add simulated instrument results to paper (strengthens identification)
4. Verify household income event study figure exists

**Medium Priority:**
1. Add state-level SDID to paper (currently only county)
2. Add intensive margin table to appendix
3. Reference specification curves for reported values

**Low Priority:**
1. Rename state table from `fig_appA_fig1.tex` to `tab_state_sample.tex`
2. Standardize all Appendix A figure names to descriptive format
3. Add full data/code availability statement

## Changelog

### February 2026 (Data and Analysis Updates)
- **Added monthly minimum wage data processing:**
  - Updated `code/R/01_data_prep_other.R` to process monthly minimum wage data from Vaghul & Zipperer
  - New output files: `VKZ_state_minwage_monthly.csv`, `VKZ_substate_minwage_monthly.csv`
- **Updated minimum wage figure to use monthly data:**
  - `04_appA_fig_minwage.do` now uses monthly data for consistency with unemployment trends figure
  - Both `fig_appA_unemp_trends.jpg` and `fig_appA_minwage.jpg` now show monthly trends
- **Added NBER recession shading to figures:**
  - `04_appA_fig_unemp_trends.do` and `04_appA_fig_minwage.do` now include recession shading
  - Uses NBER recession indicator from FRED (USREC series, downloaded January 2026)
  - Great Recession (Dec 2007 - Jun 2009) visible in study period
- **Removed NY placebo test:**
  - Deleted `04_appA_fig_event_ny_placebo.do` and `04_appA_tab_ny_placebo.do`
  - Removed associated output files
  - Reason: Pre-trends were ill-fitting, making the test unsuitable as a falsification exercise

### February 2026 (File Reorganization)
- **Reorganized `00_caleitc.do` to match paper structure:**
  - Section 2 (Policy Background): `03_fig_eitc_sched.do`, `03_fig_earn_hist.do`, `03_fig_budget.do`
  - Section 5 (Main Results): Employment trends, event studies, main tables, SDID
  - Section 6 (Earnings): Earnings event studies and tables
  - Section 8 (Heterogeneity): QC count, adult count, QC age, household income tables
  - Section 9 (MVPF): MVPF figures and intensive margin figures
  - Appendix A-D: Organized by appendix section
- **File movements and renames:**
  - `04_appendix_otherpops.do` → `04_appB_otherpops.do` (now exports to `fig_appB_event_*.jpg`)
  - `05_mvpf.do` → `02_mvpf.do` (moved to analysis section)
  - `05_fig_mvpf_dist.do` → `03_fig_mvpf_dist.do` (moved to paper figures section)
  - `05_fig_mvpf_spillovers.do` → `03_fig_mvpf_spillovers.do` (moved to paper figures section)
  - `04_appD_elasticity.do` → `02_elasticities.do` (moved to analysis section)
- **New files:**
  - `04_appA_fig_emp_trends_alt.do`: Employment trends with alternative FT/PT thresholds (31hr, 39hr)
  - `04_appA_tab_alt_threshold.do`: Main tables with alternative FT/PT thresholds
- **Added alternative full-time/part-time measures to `01_clean_data.do`:**
  - `full_time_y_31` / `part_time_y_31`: 31-hour threshold (baseline - 4 hours)
  - `full_time_y_39` / `part_time_y_39`: 39-hour threshold (baseline + 4 hours)
- **README updates:**
  - Added FIPS codes for all state classifications
  - Added no-EITC state pool codes
  - Added Medicaid expansion state (2014) codes

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
- Added Appendix A: College-educated sample falsification test
- Added Appendix C: Wage workers and self-employment analysis
- Added Appendix D: Participation and mobility elasticity calculations (with TAXSIM)
- Added Appendix E: Alternative inference procedures (CRVE, Wild Bootstrap, Ferman-Pinto correction)
