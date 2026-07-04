# Revision & Migration Plan: CalEITC Labor Supply

*Drafted July 2026. Covers (A) robustness of the full-time margin, (B) methods upgrades,
(C) framing for publication, and (D) the Stata-to-R migration. Phase 0 status at the end.*

---

## 0. Diagnosis: what the repo and draft say today

Three findings from a full review of the code and `paper/main_aejep.tex`:

1. **The quad-diff and Oster bounds have never been run.** `code/03_tab_quad_diff.do` and
   `code/03_tab_oster_bounds.do` exist (added in commit `53a2fed`), but no
   `tab_quad_diff_*.tex` or `tab_oster_bounds.tex` exists anywhere in `results/`. The
   draft's conclusion currently asserts these checks "confirm that the results are not
   driven by unobserved confounders" — a claim with no numbers behind it yet.
   Relatedly, `results/tables/tab_main_educ_*.tex` and
   `fig_event_emp_educ_coefficients.csv` are committed with **no producing do-file** in
   the repo (reconstructed as `code/03_tab_main_educ.do`; see Phase 0).

2. **The alternative-inference code had real bugs, and the paper's significance claim
   leans on it.** The Mata Ferman-Pinto function compared bootstrap statistics against
   zero instead of the observed statistic (returned p ≈ 1 always); the parallel RIWB
   placebo-state filter (`if never_treat != 6`, always true) let California leak into the
   placebo set; and the RIWB-t/RIWB-b table labels were swapped. Both fixed in Phase 0
   (below), but **the Appendix E table must be regenerated** before the inference claims
   in the paper (fn. 261: "results remain significant at the five or ten percent level")
   can stand. As committed, `results/paper/tab_appE_tab1_*.tex` shows CRVE p = 0.000
   everywhere but wild-bootstrap/RI p-values of 0.08–0.40, with only "Corrected BB"
   (the buggy Ferman-Pinto path) below 0.05 for full-time.

3. **The full-time ambiguity is real but structured.** Because
   `employed = full_time + part_time`, the three coefficients are linearly dependent
   (main spec 4: −0.4 ≈ −3.8 + 3.4; college placebo: −1.2 ≈ −1.6 + 0.4). The college
   placebo does not show a "part-time effect leak" — college part-time is flat in every
   year — it shows an **employment decline among college CA mothers (−1.2 pp)** that
   loads onto full-time. Differencing out the college trend implies a quad-diff of
   roughly: employment **+0.8**, full-time **−2.2**, part-time **+3.0** (to be confirmed
   by actually running `03_tab_quad_diff.do`). The part-time increase is the clean,
   CalEITC-specific finding; the full-time decline is partly confounded and should be
   presented as a bounded quantity.

---

## A. Robustness agenda for the full-time margin

**Priority 0 — generate the evidence the draft already cites.**
Run `03_tab_quad_diff.do` and `03_tab_oster_bounds.do`; regenerate Appendix E with the
fixed inference code; validate the reconstructed `03_tab_main_educ.do` against the
committed outputs.

**Recognize what the quad-diff can and cannot do.** It nets out confounders *common to
college and non-college mothers in CA* (childcare costs, housing, Medi-Cal,
mother-specific trends). It does **not** net out confounders that hit only low-wage
workers — above all the **minimum wage** (CA statewide increases July 2014 / Jan 2016 /
Jan 2017 plus SF/LA/San Jose ordinances). The current minwage×QC control is load-bearing
(it moves the FT estimate from −2.8 to −3.8), and the draft's direction-of-bias argument
(Godoy et al.: minimum wage raises single mothers' FT work) is one-sided — the
hours-reduction literature (Jardim et al. 2022; Cengiz et al. 2019) implies minimum wage
increases could *mimic* the FT→PT treatment effect. Complement the quad-diff with:

1. **Within-CA minimum-wage-bite test.** Reuse the county panel from
   `03_sdid_county.do`. Build (i) a county-level minimum-wage bite measure (share of
   single mothers earning below the incoming minimum, or a Kaitz index, from 2012–14
   ACS) and (ii) a county-level CalEITC exposure measure (share with earnings in the
   CalEITC range). Test whether the FT decline is concentrated where the *credit* bites
   or where the *minimum wage* bites; also re-run dropping the LA/SF/San Jose
   city-ordinance counties.
2. **Dose-response within non-college mothers.** Predict CalEITC exposure from
   pre-period demographic cells (education × age × QC count; the TAXSIM sim-2 simulated
   instrument machinery already builds most of this) and interact treatment with
   predicted-exposure terciles. Stays entirely inside the non-college sample, so it is
   immune to the "college women are a bad counterfactual" critique and has a different
   bias profile than the quad-diff. *(See `PLAN_siminstrument_note.md` for the
   continuous-DiD methodology: reframe Sim 2 as an exposure-design DiD per
   Callaway–Goodman-Bacon–Sant'Anna 2024 / Borusyak–Hull 2023, with dose-group
   event studies implementing this item.)*
3. **Medicaid.** CA expanded January 2014; part of the control pool did not. Promote the
   Medicaid-expansion-states-only control pool (already in the spec curve) to a named
   test; note the event-study break at 2015 (not 2014) as supporting evidence.
4. **Timing diagnostics.** The ACS 12-month reference window means the 2015 coefficient
   partly reflects work done before enactment (June 2015) and well before any credit was
   received (spring 2016) — a pattern a mid-2014 minimum-wage increase would also
   produce. Elevate the CPS monthly analysis from appendix afterthought to a real
   exhibit pinning down *when* within 2014–2016 hours fell.
5. **Alternative FT thresholds** (30/35/40 hours; `04_appA_tab_alt_threshold.do` is
   stubbed). Bonus: a 30-hour threshold also reassures on the ACA employer-mandate
   phase-in (2015–16).
6. **HonestDiD (Rambachan–Roth 2023)** sensitivity on the full-time event study — cheap
   to add once in R.
7. **Formalize the earnings-distribution evidence** (Fig. 7): a permutation test on the
   bin-level DiD density shifts into the $6k–18k CalEITC range turns the most
   credit-specific picture in the paper into a statistic.

## B. Methods upgrades

**Inference (one treated cluster among G = 28):**
- Fixed in Phase 0: FP p-value comparison; CA leaking into the RIWB placebo set;
  swapped RIWB column labels; serial/parallel divergences (outcome list, education
  filter). **Re-run the battery.**
- **Add Conley–Taber (2011) confidence intervals** — the canonical single-treated-state
  method, currently missing; referees will expect it.
- Adopt the `(1 + #exceed)/(1 + B)` randomization-inference convention (currently p can
  be exactly 0) and make the placebo refits use the same design as the real refit
  (currently placebos drop CA and refit on the never-treated subsample while j = 0 uses
  the full sample). *Flagged as an author decision — changes p-values.*
- Report design-based p-values (WCB or RI) in the **main** table, not only CRVE stars.
  Part-time at p ≈ 0.08–0.11 under WCB is defensible if framed as few-cluster inference;
  an unreplicable 0.000 is not.
- In R, `fwildclusterboot`/`WildBootTests.jl` is strictly richer than Stata's
  `wildbootstrap` (WCR/WCU, enumeration, subcluster bootstrap) — the port is an upgrade.

**Estimation:**
- The design is single-date, single-treated-unit: staggered-adoption estimators are not
  needed. Keep SDID; at the state level use placebo inference (as now); the county
  pop-weighted wrapper (`sdid_wt.do`) needs a careful custom port (also confirm the
  first-period-mean population-weight extraction, `sdid_wt.do:78-82`, is intended).
- Estimate employed/FT/PT as a **stacked system** and formally test β_FT = −β_PT (the
  "pure reallocation" null) with clustered inference — that test *is* the headline claim.

**Welfare:** carry the FT-effect bounds through elasticities and the MVPF. If the
CalEITC-attributable FT decline is ~−2.2 rather than −3.8, earnings losses shrink and
the MVPF rises toward ~1. Present "MVPF 0.7–~1.0, range reflecting how much of the
full-time decline is attributed to the credit."

## C. Framing for publication

- **Headline:** *the CalEITC increased part-time work by ~3 pp with no increase in total
  employment* — clean timing, no placebo counterpart, earnings density moving exactly
  into the credit-maximizing range, consistent with discrete labor supply
  (Kosonen–Matikka). That is the bulletproof, novel contribution.
- **Full-time as a bounded quantity.** Triple-diff (−3.8) as the upper bound, quad-diff
  (~−2.2) as the conservative estimate, with the decomposition identity making explicit
  that "part-time up, employment flat" mechanically requires full-time down — the open
  question is only attribution. Replace generic robustness with a short **"Threats to
  identification"** subsection naming the three candidate confounders (minimum wage,
  Medicaid, CA mother-specific trends), one targeted test each.
- **Reframe the college placebo.** It *passes* for part-time (the headline outcome) and
  reveals a CA-wide employment decline among mothers that the quad-diff nets out — after
  which the extensive margin turns slightly positive, in line with phase-in theory.
  A coherent narrative, not damage control.
- **Soften the conclusion now** (it currently asserts quad-diff/Oster confirmation that
  does not yet exist); build the framing around bounds so murkier numbers don't force a
  rewrite.
- **Referee checklist to pre-empt:** one treated cluster (→ Conley–Taber + fixed FP
  battery); minimum wage (→ bite test); ACS reference period and the speed of the 2015
  response (→ CPS timing exhibit + outreach discussion); endogenous household
  composition in the multi-adult heterogeneity (→ flag as descriptive).

## D. R migration

Leverage point: ~5 helper programs in `code/utils/programs.do` (`run_triple_diff`,
`run_event_study`, `run_all_specs`, `export_results`, PPML wrappers) do nearly all the
work; the ~50 `03_/04_` files are thin callers. Port the helpers well and the rest is
mechanical.

**Package map:** `reghdfe`→`fixest::feols`; `ppmlhdfe`→`fixest::fepois` +
`marginaleffects`; `esttab`→`modelsummary`/`fixest::etable` with custom stat rows;
`coefplot`→`ggplot2`; `taxsimlocal35`→**`usincometaxes`** (same TAXSIM-35 backend; kills
the `cd`/`results.raw` disk dance; remap positional `v25`/`v39`/`v10` to named outputs);
`wildbootstrap`→`fwildclusterboot`; `rwolf2`→`wildrwolf`; BKY q-values→port the loop;
`sdid`→`synthdid`; `parallel`→`future`/`furrr`; `rcall`→eliminated.

**Genuinely custom ports (the standard-error worry, confirmed):** Ferman–Pinto and
the RIWB. No R packages exist; write and unit-test each against the (fixed) serial
Stata output.

**SDID: use the `synthdid_weights` fork instead of porting `sdid_wt.do` / `sdid_event`**
(reviewed 2026-07-03; repo at `../synthdid_weights`, the Iselin–Ryan weighted-SDID
package). It covers both custom pieces natively:
`synthdid_estimate_weighted(Y, N0, T0, treated.weights, ...)` replaces the
`sdid_wt.do` population-weighted aggregation, and `synthdid_event_study()` (Ciccia
decomposition, bootstrap/placebo bands, uses the estimate's stored `cluster`)
replaces `sdid_event`. `vcov()` offers bootstrap/jackknife/placebo with per-resample
weight renormalization. Tests are current (38 weighted/remedy tests, 2026-07-01).
Notes for the port:

- **Estimator difference, not a bug:** `sdid_wt.do` fits SDID once *per treated CA
  county* vs. the common donor pool, then averages ATTs weighted by each county's
  **first-period (2010) mean population** (`sdid_wt.do:78-82`; the flagged author
  decision). The package fits **one joint weighted SDID** with `treated.weights`.
  Numbers will differ from Table 2; treat as an upgrade + re-estimation, not a
  golden-file replication. Match `treated.weights` to 2010 county pop for
  comparability (or resolve the author decision first).
- **Inference with one treated state:** state-clustered bootstrap is infeasible (one
  treated cluster). Unit-level bootstrap over counties = like-for-like with the
  current Stata block bootstrap (B=100, **no seed** — set one). Placebo SE is the
  only valid method if collapsing to one treated unit; it can't cluster and
  under-covers at high weight concentration (their MC: 0.74 coverage vs 1.00).
- **The fork's own ACA results are a direct warning for our design:** pop-weighted
  county SDID with big urban treated counties failed in-time placebos (placebo
  ≈ −15 vs headline −17.5) from size-correlated differential trends; not
  CA-specific. Remedies shipped in the package: `detrend = TRUE` (per-unit
  pre-period linear trend; needs T0 ≥ 3, no covariates) and
  `synthdid_estimate_stratified()` (size-binned donor pools). When porting Table 2,
  pair the headline with in-time placebos + both remedies and report a range.
- **Mechanics:** load by sourcing the fork's `R/*.R` (their own scripts do this; no
  install needed; only base R + mvtnorm required). `panel.matrices()` requires a
  balanced no-NA panel and orders rows controls-first sorted by unit ID —
  `treated.weights`/`cluster` must align to that order. No covariate passthrough
  (`X` must be built by hand; Stata's `covariates(, projected)` ≠ the package's
  joint-beta `X` handling — document the difference). Cluster R: `module load
  R/4.4.2-gfbf-2024a` (see the fork's CLAUDE.md for Lmod gotchas).
- **Pipeline facts (from the 2026-07-03 review):** the paper's only SDID exhibit is
  Table 2 = `tab_sdid_county_1/2/3` + `_end` (earnings `_4` produced, unused; state
  script + the 8 `fig_sdid_event_*` jpgs superseded/not in paper).
  `data/interim/sdid_county_panel.dta` does not exist on disk — the panel is
  rebuilt only when `03_sdid_county.do` runs, and the committed SDID tables predate
  the 2026-07-02 working-file rebuild (stale). Discrepancies to fix: table note
  says "500 replications", code uses B=100; note says 2012–2017, panel is
  2010–2017; the paper's hard-coded column headers (Basic/Triple/Basic+Cov/
  Triple+Cov) disagree with the code's column order (Basic/Basic+Cov/Triple/
  Triple+Cov) and the `_end` checkmark footer. Stale `tab_sdid_county_*_{nonweighted,
  standard,weighted}.tex` and `tab_sdid_state_combined.tex` in `results/` come from
  an older version — ignore.

**Phases:**
0. *(In Stata, before porting — in progress, see below.)* Fix inference bugs; reconcile
   serial/parallel divergences; reconstruct the education script; regenerate quad-diff,
   Oster, Appendix E, and education outputs. Never port a bug.
1. R skeleton: `renv`; `config/local_paths.yaml` + `.example` (also retires the
   hard-coded Overleaf path at `00_caleitc.do:61`); **one parameters file** replacing the
   EITC schedules / CPI factors / control-state FIPS lists currently duplicated and
   inconsistent across `01_clean_data.do`, `02_eitc_param_prep.do`, `02b_*`, and
   `02_mvpf.do`; fold `code/R/api_code.R` and `01_data_prep_other.R` in natively.
2. Cleaning pipeline + `qc_assignment` (the per-person loop collapses to a grouped join
   on `momloc`/`poploc` pointers, but it defines treatment — **validate row-for-row**
   against the Stata `.dta`), then the estimation helpers, validated
   coefficient-by-coefficient against existing tables as golden files.
3. Inference battery + SDID (custom SE code, tested against corrected Stata output; add
   Conley–Taber here). FP/RIWB are the custom-port hard parts; SDID rides on the
   `synthdid_weights` fork (see notes above) — regenerate the county panel first
   (`sdid_county_panel.dta` is not on disk and Table 2 is stale vs. the rebuilt data).
4. Elasticities and MVPF last — `02_mvpf.do` is the hardest single file (9-deep spec
   loop, `savefe` counterfactuals, `runiform` behavioral-group assignment). RNG streams
   won't match Stata: treat as re-estimation with a documented seed, not replication.

**Repo hygiene (fold into Phase 1):** duplicate `00_caleitc.do` at root and `code/`;
stale copies in `results/tables/` vs `results/paper/` (e.g. two different
`tab_appE_tab1_1.tex`); `02b_caleitc_param_gen.do` writes
`caleitc_max_inc_max_cred.xlsx` but downstream reads `caleitc_params.txt` (provenance
unclear); `02_elasticities.do:439` closes a log handle (`log_04`) that doesn't exist;
explicit RNG seeds for `ri_bs`, `ferman_pinto_boot_ind`, and `sdid_wt` (only
`wildbootstrap` currently gets `rseed()`), with per-worker seeds under parallel.

---

## Phase 0 status

Done in this pass (code changes, not yet re-run):

- [x] `04_appE_inference_programs.do`: FP Mata p-values now compare bootstrap α² against
      the observed α̂² (was: against 0 → p ≈ 1 always). `alpha_hat` is passed into
      `fp_vectorized_bootstrap()`.
- [x] `04_appE_inference_programs.do`: RIWB placebo set now `if never_treat == 1`
      (was `never_treat != 6`, always true → CA leaked into the placebo set).
- [x] `04_appE_inference.do` + `04_appE_inference_parallel.do`: RIWB-t/RIWB-b stats
      order now matches the printed labels (was swapped).
- [x] `04_appE_inference_parallel.do` + `_worker.do`: reconciled with the serial file —
      3 outcomes including `employed_y` (12 tasks), `education < 4` filter.
      **Note:** table numbering changes — `tab_appE_tab1_1/2/3` is now
      employed/full-time/part-time (was full-time/part-time under the 2-outcome run);
      check the paper's appendix includes when regenerated.
- [x] `code/03_tab_main_educ.do` (new): reconstruction of the missing script behind
      `tab_main_educ_*.tex` / `fig_event_emp_educ_coefficients.csv`. Best-guess design:
      **within-California** triple-diff, education (non-college vs college) in place of
      the state dimension, county FEs in col 2, county-clustered SEs. Validation
      targets in the file header (ATE 1.8/1.1/0.7; N = 132,910; pre-means
      71.6/51.3/20.4). Must be validated against the committed outputs before trusting.

Runs (updated 2026-07-02):

- [x] Rebuilt `data/final/acs_working_file.dta` on the cluster (IPUMS download +
      `01_clean_data.do`, Stage 1, `code/hpc/stage1.do`).
- [x] Ran `03_tab_quad_diff.do` and `03_tab_oster_bounds.do`. Quad-diff:
      employment ~+1.8***, full-time ~−0.1 (n.s.), part-time ~+1.9*** — the
      CalEITC-attributable full-time decline essentially disappears after netting
      out the college trend (plan's back-of-envelope had −2.2; see §C framing).
- [x] Ran reconstructed `03_tab_main_educ.do`. Partial validation: N (132,910) and
      pre-period means (71.6/51.3/20.4) match the committed tables exactly, but
      ATE is 2.1** vs. committed 1.8* and adj. R² is lower (0.063 vs 0.099) — the
      original spec likely absorbed more (different FEs). See author decision below.
- [x] Fixed Appendix E battery: completed (SLURM job 17006108, `code/hpc/stage2.do`,
      9h50m, 2026-07-03). All 12 workers succeeded; the Mata fail-fast never fired;
      corrected placebo filter and RIWB label order verified in the log. (First
      attempt 16996060 crashed: Stata's `parallel` transfers ado-programs via
      `prog()` but not Mata functions, so every worker died at
      `ri_compute_pvalues() not found`. Fixed — `run_inference_task` now compiles
      `04_appE_inference_programs.do` in each worker.)
- [x] Compared fixed p-values against committed `results/paper/tab_appE_tab1_*.tex`
      (old numbering: 1 = full-time, 2 = part-time; N 480,445 on old data vs.
      461,616 rebuilt). Spec 4: part-time WCBS 0.102 (all specs 0.096–0.110),
      FP 0.043; full-time WCBS 0.106 (was 0.082 — no spec below 0.10 anymore),
      FP 0.000, RIWB 0.14–0.24; employment null everywhere (ATE −0.3, WCBS 0.59).
      Regenerated appE ATEs/N match the stage-1 main tables exactly.
- [x] Updated the paper's inference footnote (`main_aejep.tex:261`, 2026-07-03):
      now states part-time significant at ~10% (WCB) / 5% (FP, preferred spec),
      full-time only under FP, employment null. Added the missing
      `\section{Alternative Inference}` (`sec:app_inf` was a dangling ref) with the
      regenerated three-panel table (`tab_appE_tab1_1/2/3` = employed/FT/PT) and a
      methods note; synced the three tables to `results/paper/`. FP p = 0.000 still
      awaits the `(1+#exceed)/(1+B)` convention decision below.
- [x] **Vintage mismatch in `results/paper/` — resolved by the recovered run logs**
      (`logs.zip`, explored 2026-07-04): the author's own local pipeline switched
      from N = 480,445 to N = 461,616 at the **2026-02-01/02 data-clean overhaul**
      (new TAXSIM sim-3 machinery, `primary_filer` logic), and every local run
      thereafter (2026-02-02 through the final 2026-03-07 `03_tab_main` run) used
      the 461,616 extract with coefficients matching the cluster rebuild
      **exactly** (spec-1 employed 0.8280433, spec-4 FT −4.076644). The committed
      `results/paper/tab_main_*` (480,445) are simply pre-overhaul stale files
      that were never regenerated. **The rebuilt extract is canonical.**
      Done 2026-07-04: synced rebuilt-extract `tab_main_*`, `tab_col_placebo_*`,
      `tab_earnings_*` into `results/paper/` (SDID tables left alone — being
      re-estimated from scratch; `tab_appA_balance_*` has no local mirror).
      Prose was already written against rebuilt numbers; fixed the remaining
      mismatches (FT lower bound 2.1→2.2, implied shift 75,000→76,000; spec-1
      employment is now 0.8** so "insignificant across all specifications"
      reworded; college-placebo FT decline now starred in all four specs so
      "not consistently significant" reworded). Flagged, not changed
      (author-voice calls): §Earnings "4 and 7 percent" understates the PPML
      upper bound (−0.08 ⇒ 8%; true in the old vintage too), and the intro's
      "approximately 50,000" sits low in the new 41k–76k implied range.
- [x] **+1 RI convention re-run complete** (SLURM job 17058169, 10h15m,
      2026-07-04; debug validation job 17048331 agreed on ATEs/CRVE with
      coarser resampling p-values). vs. the pre-change benchmark (17006108):
      WCBS unchanged, part-time FP 0.043 → 0.037 (spec 4, still <0.05),
      full-time FP now 0.001 (no more exact zeros). Tables committed and
      synced to `results/paper/`; appendix table note updated with the +1
      convention and identical-design refit language. Footnote 261 prose
      verified still accurate.

Author decisions flagged (not made unilaterally):

- [x] RI p-value convention `(1+#exceed)/(1+B)` and identical-design placebo refits
      (§B) — **approved 2026-07-03 and implemented** (lit review in
      `PLAN_inference_litreview.md`: +1 convention per Phipson–Smyth 2010 /
      Young 2019 QJE / Canay–Romano–Shaikh 2017; CA kept in placebo refits with
      identical design per MacKinnon–Webb 2020 / Conley–Taber 2011; placebo-only
      reference distribution with MW 2019 Adv. Econometrics v39 as the RIWB
      precedent). Changes in `04_appE_inference_programs.do` (both RIWB fixes +
      FP +1) and the serial `04_appE_inference.do` (same, plus an off-by-one in
      serial `ri_bs` STEP 5 where the first reference-distribution row was
      missing — counted as an exceedance — and the last draw was dropped).
      Benchmark re-run of the battery: debug validation job 17048331, then full
      stage-2; committed job-17006108 tables are the pre-change benchmark.
- [x] `sdid_wt` population-weight extraction — **mooted 2026-07-04**: author
      decision to start the SDID from scratch on the new methodology (the
      `synthdid_weights` fork, one joint weighted fit) rather than replicate
      `sdid_wt.do`. No golden-file replication of the per-county-loop
      estimator; Table 2 will be re-estimated (with in-time placebos +
      detrend/stratified remedies per §D).
- [x] Education design — **recovered from the original run logs 2026-07-04**
      (`03_tab_main_educ_log_2026-03-05.log` + `03_fig_event_emp_educ_log_2026-03-05.log`
      in `logs.zip`; Stata logs echo the full scripts). The July reconstruction
      was wrong in one load-bearing way: the original triple-diff FEs interact
      the **full 4-level `education`** variable (`qc_ct#education`,
      `year#education`), not the binary no-college indicator, and spec 1 has no
      county FEs — this explains the 2.1 vs 1.8 ATE and 0.063 vs 0.099 adj-R²
      gaps. Also: the event study was a **separate script**
      (`03_fig_event_emp_educ.do`, eventvar `childXyearXnocol`), whose 2016
      employed coefficient 2.887 (1.124) matches the committed CSV. Both
      scripts re-transcribed verbatim from the logs into `code/` and registered
      in `code/00_caleitc.do`; log-vintage data is the same rebuilt extract
      (CA N = 132,910), so a validation re-run should now match the committed
      tables to the digit. **Validated 2026-07-04** (job 17093834): all four
      `tab_main_educ_*` tables and the event-study CSV are **byte-identical**
      to the originally committed 53a2fed outputs. Phase 0 closed.

---

## Phase 1 status (started 2026-07-04)

- [x] **renv** on R 4.4.2 (`module load R/4.4.2-gfbf-2024a`): project library
      hydrated from the site + `~/r_libs_4.4` libraries (70 packages incl.
      ipumsr, tidycensus, blsR, synthdid), `renv.lock` committed. Root
      `.Rprofile` auto-activates (also under Stata `rcall`).
- [x] **`config/parameters.yaml`** — consolidated years/seed/sample bounds,
      state classification + the three named control pools, all three
      price-index blocks (recorded verbatim; series/base-year inconsistencies
      flagged inline rather than resolved), federal TY2016 + CalEITC
      TY2015–17 schedules. **All three reconciliations resolved 2026-07-04**
      (details in parameters.yaml comments): (i) the two state lists are
      complementary by construction — the mvpf/spec-curve "no state EITC"
      drop runs AFTER the baseline `state_status > 0` filter, so it only
      names the stable-EITC states and correctly omits the changers KS/LA;
      the R port must preserve that order of operations (minor flag: 49 UT
      pre-2022 EITC status worth a check if the pool is revisited).
      (ii) cpi99-2015 fallback was wrong: true value 0.703 (extracted from
      acs_2015.csv, constant across all 2,997,503 rows); fixed in
      01_clean_data.do — behavior-neutral, the fallback never triggered.
      Full empirical cpi99 table (2006–2019) now in parameters.yaml.
      (iii) canonical deflator: IPUMS cpi99 base 2019 for all person-level
      income (already the main-results convention); CPI-U-RS retained only
      for CalEITC kink backcasting in parameter generation; the mvpf CPI-U
      block is legacy — Phase 4 port re-expresses welfare numbers in 2019
      USD; figure-specific bases (2014/2017) migrate to 2019 when ported.
- [x] **`config/local_paths.yaml(.example)`** — retires the hard-coded
      Overleaf/Dropbox path for the R pipeline (Stata master unchanged, so
      John's Windows setup still works).
- [x] **R scripts folded in natively**: `code/R/00_main.R` + `utils/config.R`
      drive `api_code.R` / `01_data_prep_other.R` without `rcall` (the rcall
      entry point still works — scripts self-execute when the expected
      variables exist). Smoke-tested on the cluster.
- [x] **Hygiene**: root `00_caleitc.do` duplicate deleted (code/ copy is the
      March revision; README already pointed there); `02_elasticities.do:439`
      log-handle fix (`log_04`→`log_02`); deterministic per-task RNG seeds
      (`${seed} + task_id`) in the parallel worker, `run_inference_task`, and
      the serial battery loop — serial and parallel now use identical streams
      per task (note: next appE regeneration will shift resampling p-values
      slightly since workers previously started with arbitrary RNG state);
      `data/eitc_parameters/README.md` documents that `caleitc_params.txt`
      is NOT 02b output (values disagree; provenance unknown) — sim-3 kink
      targets must be re-derived transparently in Phase 2.
- [x] `api_codes.txt` confirmed never committed (gitignored from the start);
      keys stay machine-local.
- [ ] Stale legacy outputs in `results/` (old `tab_sdid_county_*_{nonweighted,
      standard,weighted}`, `tab_sdid_state_*`, `tab2_*`–`tab6_*` in
      `results/paper/`) — left in place; sweep when the new SDID exhibits land.

---

## Phase 2 status (started 2026-07-04)

- [x] **`qc_assignment` ported and validated row-for-row.**
      `code/R/utils/qc_assignment.R` collapses the per-pernum Stata loop to
      grouped joins; six faithfulness quirks documented inline (age 0→1
      recode, distinct-parent `matched` counts, cap-at-9 placed BETWEEN the
      pointer phase and the HOH fallback, strict-age pointer matches,
      grandchild→foster→sibling order, Stata missing semantics for
      HOH-less households). Golden dumps for 2012 + 2015
      (`code/hpc/stage4_qcdump.do`, job 17094344): **all 5,957,813 rows
      identical** on qc_ct/matched/min_qc_age (job 17094416).
- [x] **Estimation helpers ported and validated coefficient-by-coefficient.**
      `code/R/utils/estimation.R`: `setup_did_vars`, `run_triple_diff`,
      `run_event_study` on fixest. Golden checks (jobs 17094715/17094737):
      all 12 tab_main coefficient/SE pairs and all 15 event-study
      coefficients match at display precision (coefs ≤ 1.5e-7 rel., SEs
      ≤ 6.6e-6 rel., N exact). Three reghdfe-matching conventions locked in
      (documented in estimation.R): `ssc(fixef.K = "nested",
      cluster.adj = TRUE)`; the qc-interacted state-year controls drop the
      HIGHEST qc level (mirrors reghdfe's collinearity omission —
      `Σ_k x·1[qc=k] = x` lies in the absorbed state×year span);
      `fixef.tol = 1e-10` (fixest's default 1e-6 leaves clustered SEs
      drifting at ~1e-3 in the interaction specs).
- [ ] Cleaning pipeline port (`01_clean_data.do` → R): the big remaining
      piece — per-year prep, TAXSIM via `usincometaxes` (sim 1/2/3), income
      variables, merges (unemployment, minimum wage, county), state_status,
      sample flags, working-file assembly. `qc_assignment` (done) was the
      treatment-defining risk; TAXSIM columns v25/v39/v10 remapping and the
      sim-3 kink targets (`caleitc_params.txt`, provenance unknown — see
      `data/eitc_parameters/README.md`) are the remaining hard parts.
- [ ] Remaining table helpers as needed by later exhibits (`run_all_specs`
      wrapper, `add_table_stats` ymean/implied-effect stats, PPML wrappers,
      export/`modelsummary` layer).
