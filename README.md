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
│   ├── 03_fig_eitc_sched.do       # Figure: EITC benefit schedules
│   ├── 03_fig_earn_hist.do        # Figure: Earnings histogram by employment type
│   ├── 03_fig_budget.do           # Figure: Budget constraint
│   ├── 03_fig_emp_trends.do       # Figure: Employment trends
│   ├── 03_fig_event_emp.do        # Figure: Event-study estimates (employment)
│   ├── 03_fig_weeks.do            # Figure: Effect by weeks worked
│   ├── 03_fig_event_earn.do       # Figure: Event-study estimates (earnings, PPML)
│   ├── 03_fig_spec_curve.do       # Figure: Specification curves
│   ├── 03_tab_main.do             # Table: Main triple-difference estimates
│   ├── 03_tab_intensive.do        # Table: Intensive margin (hours, weeks, weekly emp)
│   ├── 03_tab_het_qc.do           # Table: Heterogeneity by QC count
│   ├── 03_tab_het_adults.do       # Table: Heterogeneity by adult count
│   ├── 03_tab_earnings.do         # Table: Earnings effects (OLS & PPML)
│   ├── 03_tab_earn_hhcomp.do      # Table: Earnings by HH composition
│   ├── 03_tab_hh_earn.do          # Table: Household earnings effects (OLS & PPML)
│   ├── 03_sdid_state.do           # SDID Table 1: State panel SDID (with event study)
│   ├── 03_sdid_county.do          # SDID Table 2: County panel weighted SDID
│   ├── 04_appA_tab1.do            # Appendix Table 1: Descriptive statistics
│   ├── 04_appendix.do             # Additional appendix tables and figures
│   ├── R/
│   │   ├── api_code.R             # IPUMS API data download
│   │   └── 01_data_prep_other.R   # BLS and minimum wage data prep
│   ├── utils/
│   │   ├── programs.do            # Reusable Stata programs
│   │   └── sdid_wt.do             # Weighted SDID estimation program
│   └── logs/                      # Log files
├── data/
│   ├── raw/                       # Raw data files (not tracked)
│   ├── interim/                   # Intermediate processed data
│   ├── final/                     # Final analysis datasets
│   └── acs/                       # ACS data from IPUMS
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

* Install rcall for R integration
net install github, from("https://haghish.github.io/github/")
github install haghish/rcall, stable
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
- Ages 20-50
- No college degree
- US citizens
- Not in armed services
- Not currently in school

### Control States

States are classified based on their EITC policies during the study period:
- `state_status = 2`: California (treated)
- `state_status = 1`: Control states (no state EITC changes)
- `state_status = 0`: Excluded (states with EITC policy changes)
- `state_status = -1`: Excluded (Alaska, DC)

## Key Programs

The `code/utils/programs.do` file contains reusable Stata programs:

- **`qc_assignment`**: Assigns qualifying children to potential adults in household based on IPUMS relationship variables
- **`run_triple_diff`**: Runs triple-difference regression with specified controls and FEs
- **`run_event_study`**: Runs event study regression with year interactions
- **`make_event_plot`**: Creates event study coefficient plots
- **`get_pre_period_mean`**: Calculates weighted mean for treated group in pre-period
- **`run_ppml_regression`**: Runs PPML regression with margins for average marginal effect
- **`export_table_panel`**: Exports regression results to LaTeX format
- **`sdid_wt`**: Population-weighted Synthetic DID estimation with bootstrap standard errors

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
- **fig_tab_intensive:** Coefficient plot for intensive margin table

### Tables
- **tab_main:** Triple-difference estimates on employment (main results)
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

### Appendix
- **Appendix Table 1:** Descriptive statistics

## Notes

- All monetary values are adjusted to 2019 dollars using CPI99
- Standard errors are clustered at the state level
- The analysis excludes individuals assigned as qualifying children (age < 18 or QC flag)
- County-level unemployment rates are imputed for suppressed counties using state-year averages
- PPML estimates include average marginal effects (AME) for interpretation in levels

## Citation

If you use this code or data, please cite:

```
Iselin, John. "The Labor Supply Effects of the California Earned Income Tax Credit."
Working Paper, Yale University.
```

## License

This project is for academic research purposes. Please contact the author for permissions.

## Changelog

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
