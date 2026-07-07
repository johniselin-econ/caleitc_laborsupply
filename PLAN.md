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
   Source CalEITC schedules from the verified `config/caleitc_ftb3514.yaml`, not the
   superseded `eitc_california` block (wrong for every year — see the Phase 2 audit);
   welfare numbers will shift for the better-parameters reason, not a port bug.

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
- [x] **TAXSIM machinery ported and validated (sims 1, 2, 3).**
      `code/R/utils/taxsim.R` calls the SAME local NBER taxsim35 binary the
      Stata pipeline used (not `usincometaxes` — swappable later), so golden
      outputs reproduce to the cent. Sims 1/3 validate exactly for 2012 +
      2015 (job 17095726; ~2.2M rows each, v25/v39/v10 remapping confirmed).
      Sim 2 (cell instrument) validates via the byte-exact golden input
      dumps (`code/hpc/stage8_sim2dump.do` + `stage8_txpydump.do`):
      280,268/280,642 working-file cells reproduce exactly through the R
      stack + collapse (job 17114718). Two Stata artifacts documented as
      deliberate non-ports (see `taxsim.R` header note and
      `validate_sim2.R`):
      (1) **sage contamination is non-deterministic** — the combined-file
      regeneration draws spouse age through an UNSTABLE sort over per-year
      hh_id collisions, so the 374 diverging cells (all married; childless
      via the federal age test, with-kids via state-EITC age dependence)
      embed a run-specific tie realization that is irreproducible in
      principle (the merge-back re-sorted the working file, erasing the
      order; diagnosed in `diagnose_sim2_residual.R`, jobs 17113329/30).
      The validation gate requires exact reproduction outside the computed
      sage-ambiguity set and containment within it.
      (2) **outsheet %10.0g rounding** — taxsimlocal35.ado sent the
      cpi-reflated money inputs rounded to ~8-9 significant digits; flips
      5,362 of 16M row-level EITCs but never moves a cell mean past
      tolerance. The R port sends full precision and the correct 2014-only
      sage; production impact vs the working file: 1,530 cells (~0.5%).
- [x] **Working file assembled in R and validated on the full file**
      (commit `0dc6f9b`; stage-9 chain jobs 17115507/508/509, completed
      2026-07-05). Per-year cleans (2006–2019) run as a SLURM array, then
      `02_working_file.R` appends years, rebuilds the sim-2 instrument
      from 2014 primary filers, and merges cell values back.
      `validate_working_file.R`: **113 columns identical on 30,989,151
      rows** against the Stata working file; sim-2 fedeitc/steitc
      divergence is the documented sage carve-out gated in
      `validate_sim2.R`. The cleaning port is complete.
- [x] **CalEITC schedule audit vs FTB Form 3514** (commit `4b8575c`,
      2026-07-05): the `eitc_california` block in `parameters.yaml` /
      `02b_caleitc_param_gen.do` matches FTB 3514 for **no year** —
      phase-in rates 0.50× federal instead of the statutory 0.85×,
      max_income from the wrong QC row, childless filers wrongly coded
      ineligible pre-2018. Verified schedule (TY2015–19, incl. piecewise
      phase-outs) in `config/caleitc_ftb3514.yaml`; parsed $50-bin FTB
      lookup tables + archived sources in `data/eitc_parameters/ftb3514/`.
      Affects `02_elasticities.do` / `02_mvpf.do` only (TAXSIM sims and
      DiD estimates compute EITC internally). Stata pipeline left as-is;
      **Phase 3/4 R ports must read `eitc_california_ftb3514`** and
      document the break vs the old Stata welfare numbers.
- [x] **Sim-3 kink targets re-derived; provenance mystery solved**
      (2026-07-06). Every `caleitc_params.txt` value is the midpoint of
      the $50 FTB credit-table bin where the CalEITC peaks (per year ×
      QC; pre-2015 rows carry nominal 2015 values, reflated at use).
      `code/R/gen_caleitc_params.R` regenerates the file from
      `data/eitc_parameters/ftb3514/` **byte-for-byte** — the sim-3
      targets were always FTB-consistent; only the schedule *parameters*
      (`eitc_california`) were wrong. No downstream numbers change.
- [ ] Remaining table helpers (`run_all_specs` wrapper, `add_table_stats`
      ymean/implied-effect stats, PPML wrappers, export/`modelsummary`
      layer) — deliberately deferred into Phase 3: port each with the
      first exhibit that needs it, validated against the committed tables.

**Phase 2 closed 2026-07-06** (data pipeline fully ported and validated;
the table-helper tail rides with the Phase 3 exhibits).

---

## Phase 3 status (started 2026-07-06)

- [x] **SDID county panel regenerated and R port validated** (stage 10).
      Stata golden build (`code/hpc/stage10_sdid_panel.do`, job 17137337:
      panel-build section of `03_sdid_county.do` verbatim, 2010-2017) →
      `data/interim/sdid_county_panel.dta`. R port
      (`code/R/utils/sdid_panel.R`) **validated** (job 17138700,
      2026-07-06): 1,928 rows × 24 columns; the four `_diff` columns pass
      under level-scaled gates (float-storage cancellation only, all
      levels ≤ 1e-7 rel).
- [x] **FP + RIWB ported to R** (`code/R/utils/inference.R`): appE sample/
      specs, CRVE (dof = G-1), Ferman-Pinto (parallel-program correction
      semantics), RIWB (+1 convention, placebo-only reference,
      identical-design refits). Deterministic layers validated against
      stage-11 Stata dumps (job 17137585 → 17137733): RI b ≤ 5e-6, FP
      q/P/var_M/alpha_hat ≤ 5e-7 rel everywhere; RI t and FP W_did sit at
      1e-5-5e-5 from float-stored intermediates in the Stata programs
      (documented gates in `validate_inference_det.R`; re-run **passed**,
      job 17138701). **WCBS re-implemented as a hand-rolled WCR-t on
      `appE_fit`** (2026-07-06) after two failed `fwildclusterboot`
      attempts: job 17138702 died on a bare `factor()` for spec 1's empty
      controls; job 17158597 (post-fix, `fe = NULL` since the R engine
      can't combine WLS with FE projection) died in boottest's dense
      solve — rebuilding the absorbed grp_state_year FE as dummies
      alongside the group factors is rank-deficient. The hand-rolled WCR
      (null imposed, cluster Rademacher, full-model refit t's, +1
      convention) reuses the machinery already validated at 1e-7;
      fwildclusterboot via the WildBootTests.jl engine (Julia is on the
      cluster) remains the §B upgrade path if enumeration/WCU variants
      are wanted later. Full R battery (stage 12,
      `code/R/04_appE_inference.R`, 12-task array, B=1000/B_ri=100, seed
      56403+task with per-method offsets +0/+1e5/+2e5) completed as job
      17177816 (2026-07-06). **Validator PASSED** (`validate_appE_battery.R`,
      12 tasks × 8 gates): deterministic ATE/SE/N/CRVE-p match at display
      precision; WCBS/RIWB-t/RIWB-b/BB/FP-corrected-BB all inside the
      Bonferroni MC bands vs the job-17058169 golden tables. Exhibit
      integrated 2026-07-07 (step 5 below).
- [x] **Conley-Taber (2011) CIs** — implemented on the placebo-refit
      distribution (`conley_taber()` in inference.R; inverse-ECDF
      quantiles, 27 placebos); produced per task by stage 12.
      Convention settled with the exhibit: 90% level (95% endpoints
      with 27 placebos are the min/max order statistics — rationale in
      the table note). Integrated 2026-07-07 (step 5 below).
- [x] **SDID Table 2 on the synthdid_weights fork** — estimation script
      written 2026-07-06 (`code/R/03_sdid_county.R`): joint
      weighted fit per §D (treated.weights = 2010 county pop, aligned by
      rownames), specs in the CODE order of `03_sdid_county.do` (Basic/
      Basic+Cov/Triple/Triple+Cov; the paper's printed headers are
      misordered vs the numbers — fix when the exhibit is rebuilt), unit-
      level bootstrap B = 500 seeded per fit, variants per spec: weighted /
      unweighted / detrend / stratified (no-cov specs; fork forbids
      detrend+X, X-in-strata unverified) / in-time placebo (2013 law on
      2010-14 data). Covariates use the fork's joint-beta X handling, not
      Stata's covariates(, projected) — a documented methodology break.
      Panel: 241 units (35 CA counties, 206 donors), T0 = 5. Smoke run
      (triple FT): weighted −2.56, detrend −2.17, stratified −2.95 vs old
      per-county-loop −2.40/−2.45. First serial run (job 17185223) was
      cancelled at 2h46: cov-spec bootstraps redo the joint-beta
      optimization per replicate (~90 min/variant → ~24h serial vs the 4h
      limit), and output was written only at the end. Restructured
      2026-07-06 as a 12-task array (one outcome × spec per task,
      per-task `sdid_county_r_task<k>.{csv,rds}`, per-cell seed offsets so
      array == serial seeds) and resubmitted as job 17203764 (12h limit).
      **Completed 2026-07-07**: all 12 tasks exited 0 (no-cov ~12 min,
      cov ~5.2h each); 48 fits in `data/tmp/sdid_county_r_task*.csv`.
      Results (pp; weighted = headline candidate, unit bootstrap SE):
      - **Part-time is clean everywhere**: weighted 3.08/2.53/3.49/3.77
        (Basic/Basic+Cov/Triple/Triple+Cov), robust to unweighted
        (2.8–3.4), detrend (2.8/2.0), stratified (2.3/3.0); in-time
        placebos small (−0.78 to +1.37, all |t| < 1).
      - **Full-time spans −1.15 to −5.02**: weighted −1.15/−3.67/−2.56/
        −5.02 — covariates (fork joint-beta) amplify the decline;
        remedies on the no-cov specs are stable (detrend −1.82/−2.17,
        stratified −1.19/−2.95, vs old per-county-loop triple
        −2.40/−2.45). **In-time placebos pass** (+0.49/−0.81/−0.30/
        −1.43, all |t| ≤ 0.9) — the fork's ACA-style size-correlated-
        trend failure does NOT materialize on this panel.
      - **Employed is null/unstable**: weighted +2.35/−1.00/+0.99/−1.37
        (sign flips with covariates); in-time placebos comparable in
        magnitude. Consistent with the paper's employment-flat framing.
- [x] **State-level placebo (RI) inference for the county SDID**
      (`code/R/03b_sdid_stateplacebo.R`, stage 14, job 17220617,
      completed 2026-07-07; all 12 tasks, ≤ 8 min each). Treatment is
      assigned at the state level, so the county unit bootstrap in
      stage 13 is not the inference object: each of the 27 donor states
      is refit as the pseudo-treated block (its counties weighted by
      their 2010 pops, CA kept in the donor pool — identical-design
      convention per `PLAN_inference_litreview.md`, author decision
      2026-07-07), exhaustive enumeration, deterministic, +1 convention
      (floor 1/28 ≈ 0.036). Two statistics reported (raw ATT and
      ATT/pre-RMSPE, ADH scaling on the covariate-adjusted gap).
      Results in `data/tmp/sdid_county_stateplacebo_r_task*.csv`:
      - Full-time: RMSPE-scaled p at the 0.036 floor for Basic+Cov/
        Triple/Triple+Cov (CA has the best pre-fit AND a large post
        gap); raw-ATT p 0.14–0.68 (placebo sd 3.1–3.6 pp swamps the
        smaller ATTs).
      - Part-time: raw p 0.14–0.25, RMSPE p 0.14 for Triple/Triple+Cov.
      - Employed: null under both statistics (p 0.25–0.75).
      Note the tension with the DiD appE battery (there part-time is
      the significant margin): here the RMSPE statistic favors
      full-time. Raw-vs-RMSPE is a flagged author decision; with 27
      placebos the floor itself limits what "significant" can mean —
      frame as corroboration, not a standalone test.

**Phase 3 remaining — ordered next steps (as of 2026-07-07):**

1. **Commit the estimation layer** — `03_sdid_county.R`,
   `03b_sdid_stateplacebo.R`, stage 13/14 sbatch files are untracked;
   this PLAN update is uncommitted. Consider copying the per-task
   `data/tmp` CSVs somewhere durable (`results/` staging or a job-tagged
   folder) before anything sweeps tmp.
2. **Author decisions — made 2026-07-07:**
   (i) **Weighted joint fit is the headline** column per spec; in-time
   placebos + detrend/stratified remedies as a compact robustness panel
   below the main panel (no-cov specs only, per fork constraints). The
   passing in-time placebos are displayed as a result, given the fork's
   ACA warning. (ii) **All four specs stay in Table 2**; the full-time
   −1.15 to −5.02 spread is stated as a range in text, with part-time
   (spec-invariant, 2.5–3.8) as the SDID takeaway; full-time
   attribution stays with the quad-diff/DiD bounds machinery in §C;
   joint-beta covariate break documented in the table note. (iii)
   **Table 2 cells: ATT (unit-bootstrap SE) [RMSPE-scaled RI p]**;
   raw-ATT RI p-values in the note/appendix detail; note states the
   1/28 attainable floor; state-placebo RI framed as corroboration.
3. **Weighted event studies** (author request 2026-07-07) —
   `code/R/03c_sdid_eventstudy.R` (stage 15, job 17232065, submitted
   2026-07-07): Ciccia decomposition via the fork's
   `synthdid_event_study()` on the 12 weighted headline fits, unit
   bootstrap bands B = 500 (same scheme as the stage-13 SEs), seeds
   `params$seed + 201..212`. Replication matrices saved in the .rds
   for HonestDiD (§A.6) without refitting. `make_setup` extracted to
   `code/R/utils/sdid_setup.R` (shared with 03, verbatim).
   **Completed 2026-07-07**: all 12 tasks (no-cov ~2.5 min, cov
   ~1.8-2h), no bootstrap warnings; curves staged in
   `results/sdid_r/sdid_county_es_r_job17232065.csv` (+ per-task .rds
   with replication matrices). **Figures built**
   (`code/R/03e_sdid_esfigures.R`): 12 × `fig_sdid_event_<out>_<spec>`
   (png → results/figures, jpg → results/paper), paper coefplot style,
   ATT cross-check vs stage 13 exact. Old per-county-loop jpgs
   replaced (same names for basic/triple; basic_cov/triple_cov new).
   Pre-period placebo coefficients ≈ 0 everywhere; PT jumps +3.9/+4.4
   in 2015-16 (2017 +2.2, CI touches 0); FT −3.0/−3.7 in 2015-16,
   −1.0 in 2017. Not yet included in the paper — author call whether
   an SDID event-study figure joins the robustness section.
4. **Table 2 exhibit — built 2026-07-07** (`code/R/03d_sdid_table2.R`
   reads the committed `results/sdid_r/` job CSVs and writes
   `tab_sdid_county_{1,2,3,end}.tex` to `results/tables/` +
   `results/paper/`). Panels: ATT / (unit-bootstrap SE) / [RMSPE-scaled
   RI p] headline row, then in-time placebo / detrended / stratified
   robustness rows (blank where the fork forbids the variant); no
   stars — the RI p is the inference object. `main_aejep.tex` fixed:
   header order now matches the fragments (Basic/Basic+Cov/Triple/
   Triple+Cov — the old header was misordered), note rewritten (2010–17,
   B = 500 now true, joint weighted fit, joint-beta covariates, RI
   convention + 1/28 floor, raw-ATT p-values quoted, variant
   definitions), §Robustness SDID paragraph updated to the new ranges
   (PT +2.5–3.8, FT −1.1 to −5.0) with the placebo/RI sentences.
   Standalone shell + fragments compile clean (pdflatex smoke test).
   Stale `tab_sdid_county_*_{nonweighted,standard,weighted}`,
   `tab_sdid_county_4`, `tab_sdid_state_*` swept from `results/`
   (unreferenced in the paper; the 8 `fig_sdid_event_*` jpgs stay until
   the stage-15 event-study figures replace them). Remaining: verify on
   Overleaf once synced (floatfoot length).
5. **appE + Conley–Taber exhibit integration — done 2026-07-07**
   (`code/R/04b_appE_table.R` reads the staged
   `results/appE_r/appE_r_job17177816.csv`; battery CSVs + per-task
   refit .rds staged there from data/tmp). Regenerated
   `tab_appE_tab1_{1,2,3}.tex` (results/tables + results/paper):
   deterministic rows (ATE/SE/N/CRVE) match the committed Stata tables
   at display precision; resampling p-values are now the R battery's
   (canonical; within MC bands — note FT spec-2 Corrected BB moved
   0.043 → 0.052, prose claims unaffected). Two new rows: RI P-Value
   (pure placebo-refit RI on the coefficient, floor 1/28) and CT 90%
   CI. CT intervals are wide and include zero everywhere (placebo-b
   dispersion ~10× the CRVE SEs) — framed in the appendix prose as a
   bounding exercise. Paper updates: §app_inf procedure list (+RI,
   +CT), results paragraph (+CT/RI sentences), table note (+RI/CT
   definitions, 1/28 floor, 90% rationale), fn. 261 softened ("at or
   near the ten percent level, p = 0.10–0.12" — PT spec-4 WCBS is now
   0.111) with a CT sentence. Standalone compile verified. The generic
   esttab-replacement layer (`add_table_stats`, modelsummary export)
   stays deferred — 03d/04b are purpose-built writers; port the
   generic layer with the first main-text table that needs it.
6. **§A.1 minimum-wage bite test — in flight** (started 2026-07-07;
   `code/R/05_mw_bite.R`, stage 16, job 17232853). Three parts:
   (1) county measures from the 2012–14 working file on the 35 SDID CA
   units — bite (share of employed with implied real hourly wage below
   the incoming $10.50 Jan-2017 statewide minimum; wage trim $1–200
   2019 USD), Kaitz variant, CalEITC exposure (share of mothers with
   earnings in (0, TY2015 max_income(qc)]; FTB 3514 schedule);
   (2) within-CA county-year DiD horse race: outcome_diff on
   post×bite_z and post×exposure_z, county+year FE, pop-weighted,
   county-clustered (35 clusters); (3) ordinance-drop SDID refits of
   the weighted triple spec — drop3 = LA/SF/Santa Clara (plan's named
   three), drop4 = +Alameda, B = 500, seeds +301...
   **Defaults reviewed — author decisions 2026-07-07: all kept as
   implemented.** (i) $10.50 incoming minimum stays (z-scored ranking is
   threshold-insensitive; Kaitz variant is the hedge); (ii) [$1,$200]
   trim stays (permissive but transparent; z-scoring absorbs the level);
   (iii) exposure stays mothers-only with all mothers in the denominator
   (matches the QC-present treated margin; zero-earners capture the
   extensive margin); (iv) drop3/drop4 only — no San Diego/Contra Costa
   variant (SD's Jul-2016 ordinance led the statewide $10.50 by six
   months, immaterial for annual ACS outcomes; further drops push the
   estimand away from statewide CA). No reruns; job-17232853 results
   are final.
   First submission (17232841) cancelled pre-results: R zero-indexing
   bug in the exposure threshold lookup (qc_ct = 0 rows), fixed.
   **Completed 2026-07-07** (13 min; staged in `results/mw_bite/`,
   job-tagged). Results support the §C attribution story:
   - Horse race (per 1 SD): the PART-TIME increase tracks CalEITC
     exposure (+1.48, p = 0.053), not minimum-wage bite (−0.93,
     p = 0.17, wrong-signed for confounding). The FT decline loads on
     exposure (−1.15) not bite (+1.05, again wrong-signed), but
     neither is significant (35 clusters). Employed: nothing.
     bite–exposure corr 0.53; measures: bite 0.22–0.55, exp 0.09–0.30.
   - Ordinance drops (weighted triple; full sample FT −2.56, PT
     +3.49): drop3 FT −1.47 (SE 1.28), PT +3.35; drop4 FT −1.18
     (SE 1.36), PT +2.90. **PT robust; the SDID FT decline roughly
     halves and loses significance without the ordinance counties** —
     caveat: dropping LA/SF/SC drops ~32% of the treated-sample
     population (LA alone 28%), so the estimand shifts toward
     non-ordinance CA.
   **Exhibit + §C text done 2026-07-07**: `05b_mw_bite_table.R` builds
   tab_mw_bite_{1,2}.tex (Panel A horse race, coef/(SE)/[cluster-t p],
   no stars; Panel B ordinance drops with the Table 2 col-3 weighted
   triple as reference row) from the committed job-tagged CSVs; new
   "Threats to identification" subsection (`sec:threats`) after
   Robustness with the minimum-wage test written and \todo stubs for
   Medicaid (§A.3) and CA mother-trends (quad-diff); Kaitz variant in
   the table note. Standalone compile verified. **Bib entries needed
   on Overleaf**: cengiz_effect_2019, jardim_minimum_2022.
7. **Then Phase 4** (elasticities/MVPF on `eitc_california_ftb3514`),
   and the rest of the §A robustness agenda (dose-response §A.2,
   Medicaid pool §A.3, CPS timing §A.4, HonestDiD §A.6 — replication
   matrices already saved by stage 15).
