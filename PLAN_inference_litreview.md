# Literature review: RI p-value convention & placebo design (PLAN.md §B decision)

*Deep-research run 2026-07-03 (workflow `wf_aaa5625b-8f7`, 104 agents, 22 sources,
25 claims verified against fetched full texts). The synthesis stage of the workflow
failed; this document is the synthesis, written from the recovered verified claims.
Six claims were adversarially cross-verified (unanimous votes); the rest were
extracted with supporting quotes from the fetched papers but not cross-verified —
spot-check page/equation references before citing in the paper.*

**Bottom line: all three of our flagged implementation choices have clear,
citable answers, and on two of them the current code is on the wrong side of the
literature.**

---

## Q1. The p-value convention: use p = (1 + #exceedances)/(1 + B)

Unanimous across statistics and econometrics. A reported RI/permutation p-value of
exactly 0.000 is not a valid Monte Carlo permutation p-value.

- **Phipson & Smyth (2010), *Stat. Appl. Genet. Mol. Biol.* 9(1), art. 39** — the
  canonical citation; the title is the claim: "Permutation p-values should never be
  zero." Computing #exceed/#draws is biased downward by ~1/m because it wrongly
  treats permutation as estimating a tail probability; the correct view is an exact
  discrete null distribution containing the observed statistic. *(Adversarially
  confirmed, 3–0.)*
- **Young (2019, QJE, "Channelling Fisher"), §III eq. (5), fn. 10** — the standard
  econ citation. The observed statistic is "automatically counted as a tie with
  itself," giving denominator N+1; the resulting p-value is exactly uniform under
  the null for any number of draws (attributing the result to Jöckel 1986, *Ann.
  Statist.*). *(Eq.-5 construction confirmed 3–0; the fn. 10/Jöckel attribution
  extracted but not cross-verified.)*
- **Canay, Romano & Shaikh (2017, Econometrica 85(3), 1013–1030), Remarks 2.2–2.3**
  — the formal basis: with a stochastic approximation, the reference set must be
  {identity} ∪ {B−1 random draws}; finite-sample validity holds only under this
  construction, and p ≥ 1/|G| by construction.
- **MacKinnon & Webb (2020, *J. Econometrics*, "Randomization inference for DiD
  with few treated clusters")** — their baseline eq. (13) is #exceed/S *without*
  the +1, but their Appendix A presents the +1 variant p′ = (Sp+1)/(S+1), notes
  including the actual sample in the reference set "is more common in the
  theoretical literature," and shows p′ is weakly more conservative (the no-+1
  version over-rejects when (1−α)(S+1) is not an integer). So even the one paper
  that baselines without +1 endorses +1 as the conservative theoretical standard.

**Decision for us:** adopt (1+#exceed)/(1+B) everywhere (`ri_bs`, RIWB, FP if we
report its p as randomization-based). Cite Phipson–Smyth (2010), Young (2019),
CRS (2017). The Appendix E FP p = 0.000 for full-time must become p ≥ 1/(B+1).

## Q2. Placebo refits: keep California in the sample, identical design

The literature keeps the treated unit in the estimation sample when reassigning
treatment to a control state; what varies is only whether the *observed statistic*
joins the reference distribution (Q1's +1 question). No paper found drops the
treated state and refits placebos on the control subsample — which is what our
code currently does (placebos refit on never-treated states while j = 0 uses the
full sample).

- **MacKinnon & Webb (2020):** each re-randomization assigns treatment to one
  control group and re-estimates on **all G groups**, treated cluster included as
  an untreated unit; placebo set = all C(G,G₁)−1 assignments except the actual one.
- **Conley & Taber (2011, REStat)** (as reconstructed in Hagemann's Example 4.1):
  the initial regression uses the **full sample including the treated cluster**;
  the reference distribution is built from the q control clusters' residual-based
  placebo coefficients.
- **Exchangeability is the reason:** MW state the invariance condition citing
  Lehmann & Romano (2005, §15.2) — the placebo statistic must have the same
  distribution as the observed one under the null, which requires the *identical*
  regression design. Changing the sample between the real refit and the placebo
  refits breaks this by construction. MW further warn that unequal cluster sizes
  already strain exchangeability for coefficient-based RI (RI-β) and recommend
  t-statistic-based RI (RI-t), while noting even RI-t is unreliable with one
  treated cluster and heterogeneous sizes.
- **Contamination from CA's actual effect** is handled by imposing the sharp null,
  not by dropping CA: Young adjusts outcomes under H₀ (y_S = y_E − T_Eβ₀ + T_Sβ₀;
  no adjustment needed for β₀ = 0). **Hagemann's rearrangement test** (arXiv
  2010.04076) is the design that avoids contamination structurally — separate
  per-cluster regressions, no full-sample placebo refit — and he explicitly
  characterizes Conley–Taber as resting on exchangeability/homogeneity and
  Ferman–Pinto as requiring the heteroskedasticity form to be known. Useful both
  as a citable discussion of the exchangeability requirement and as a candidate
  additional method.
- **Ferman & Pinto (2019, REStat)** supply the size-heteroskedasticity warning:
  methods using control-group information under/over-reject when the treated
  group is larger/smaller than controls, even asymptotically; their conditional-
  permutation argument (no control state matches CA's size, so the conditional
  p-value interval is [0,1]) is the sharpest statement of why the placebo design
  must match the real design as closely as possible.

**Decision for us:** placebo refits must keep CA in the sample (as untreated) and
use the exact spec of the j = 0 refit; prefer RI-t over RI-β per MW. This changes
`04_appE_inference_programs.do` (the RIWB placebo loop currently refits on the
never-treated subsample).

## Q3. Reference distribution: placebo statistics only — never mix in
## bootstrap draws under the real assignment

- **Young (2019):** the randomization distribution consists only of statistics
  under counterfactual allocations; bootstrap-t/-c under the real assignment is a
  *separate, confirmatory* method, never pooled into the RI distribution.
- **MacKinnon & Webb (2020):** reference distribution is placebo-assignment
  statistics only; the observed statistic enters at most via the +1 construction.
- **The citable precedent for our hybrid RIWB is MacKinnon & Webb (2019),
  "Wild bootstrap randomization inference for few treated clusters," *Advances in
  Econometrics* vol. 39, ch. 3, pp. 61–85** — wild bootstrap draws are used to
  *enlarge the randomization set within each placebo assignment* when C(G,G₁) is
  small (our case: 27 placebo states). This is exactly our RIWB design; cite it.
- **Ferman & Pinto (2019)** is different by design and should stay as-is: a wild
  cluster residual bootstrap with H₀ imposed on the full sample (treated group
  included), reference distribution = the B bootstrap draws only. It is a
  bootstrap test, not RI — no treated-unit exclusion, and its p-value convention
  is the bootstrap one.

**Decision for us:** the RIWB reference distribution = placebo-assignment
statistics only (wild draws within each placebo assignment per MW 2019); the
observed CA statistic enters via +1. Do not add real-assignment wild draws to it.

## Applied precedent (one treated state, top journals)

From the source sweep (flagged for exact usage, not fully verified): Cunningham &
Shah (2018, ReStud — Rhode Island decriminalization; CT-style placebo inference),
Abadie, Diamond & Hainmueller (2010, JASA — the synthetic-control placebo
tradition, permutation across donor states), Buchmueller, DiNardo & Valletta
(2011, AEJ:EP — Hawaii, one treated state). The MW/CT/FP trio above are the
methods anchors referees will expect.

## Implementation checklist (maps PLAN.md §B decision to code)

1. `(1+#exceed)/(1+B)` in `ri_bs` and the RIWB p-values; report FP with its own
   bootstrap convention but never as 0.000 (floor at 1/(B+1) with a note, or
   report the +1 version).
2. RIWB placebo refits: full sample including CA, identical spec to j = 0;
   switch/keep the statistic as t-based (RI-t), not coefficient-based.
3. Reference distribution: placebo-only + observed via +1 (cite MW 2019 AiE for
   the wild-draw enlargement).
4. Re-run the Appendix E battery after 1–3; update fn. 261 and the Alternative
   Inference appendix numbers.
5. Still to add per PLAN §B: Conley–Taber CIs; consider Hagemann's rearrangement
   test as the exchangeability-free complement.

## Sources fetched by the workflow

Phipson & Smyth 2010 (arXiv:1603.05766 / SAGMB); Young 2019 QJE (LSE PDF);
Canay–Romano–Shaikh 2017 Econometrica; MacKinnon & Webb 2020 J.Econometrics
(QED WP 1355); MacKinnon & Webb 2019 Advances in Econometrics v39 (via NBER/RePEc
listing); Ferman & Pinto 2019 REStat (MIT Press); Hagemann rearrangement test
(arXiv:2010.04076 + author PDF); Abadie–Diamond–Hainmueller 2010 JASA;
Firpo & Possebom 2018 (synthetic control inference sensitivity); Roodman et al.
2019 Stata J. (boottest); Hemerik & Goeman 2018 (via arXiv:2605.03886 survey);
Canay–Santos–Shaikh wild bootstrap few-clusters (arXiv:2102.09058);
Cunningham & Shah 2018 ReStud; Buchmueller–DiNardo–Valletta 2011 AEJ:EP; plus
datacolada.org/99 and additional arXiv surveys.

*Raw claim/quote/vote JSON preserved at the workflow record
(`~/.claude/projects/.../25a8a662.../workflows/wf_aaa5625b-8f7.json`).*
