# Note: the simulated instrument under the continuous-DiD literature

*Drafted 2026-07-04 for the AEJ:EP revision. Concerns the Gruber–Saez
simulated-instrument analysis (TAXSIM Simulation 2; `03_tab_sim_inst.do`;
currently Online Appendix E and the "lacks power to decompose the margin"
footnote in §Results). Companion to PLAN.md §A.2 (dose-response within
non-college mothers) and §A.1 (minimum-wage bite test).*

## 1. What the design actually is

Simulation 2 freezes the 2014 primary-filer population, CPI-reflates each
filer's money inputs through every tax year 2010–2019, runs TAXSIM-35 under
each year's law, and collapses the resulting CalEITC dollars to weighted cell
means, where a cell is state × female × QC count × marital status × education
× age bracket. The analysis then (i) regresses outcomes on the cell-mean
simulated credit with cell-dimension and year fixed effects (reduced form),
and (ii) instruments the individual's actual TAXSIM credit with the simulated
cell credit (2SLS), zeroing non-CA state EITCs so the instrument carries only
CalEITC variation.

Two structural facts matter for what follows:

- **The dose is a deterministic function of cell traits.** Simulated credit
  dollars are pinned down by QC count and by where the cell's 2014 earnings
  distribution sits relative to the CalEITC kinks. There is no variation in
  the instrument that is not a function of (fixed) cell characteristics
  interacted with the (single) law change.
- **The first stage is near-mechanical.** Simulated credit predicts actual
  credit almost by construction, so the 2SLS estimate is essentially the
  reduced form rescaled. The exclusion restriction and the reduced form's
  parallel-trends assumption are the same assumption.

## 2. What the new literature says

**Continuous-treatment DiD (Callaway, Goodman-Bacon & Sant'Anna 2024).**
The reduced form is a two-way fixed-effects regression of an outcome on a
continuous dose. CGS show that under ordinary parallel trends (each dose
group tracks its own counterfactual), such regressions identify *level*
effects ATT(d|d) for each dose group, but the cross-dose comparisons that a
single slope coefficient aggregates confound treatment-effect heterogeneity
with the causal response to dose ("selection on dose"). Recovering an
average causal response per dollar requires **strong parallel trends**:
every cell, regardless of its actual dose, would have responded identically
to any *given* dose. When effects are heterogeneous across dose levels, the
TWFE/2SLS coefficient is a weighted average of causal responses whose
weights need not be convex (cf. also de Chaisemartin & D'Haultfœuille's
results for continuous and fuzzy designs).

Strong parallel trends is substantively demanding here. The dose gradient
runs along QC count and low-earnings position — exactly the dimensions along
which the other California shocks of 2014–2017 (minimum-wage steps in July
2014/Jan 2016/Jan 2017 plus city ordinances, the Medi-Cal expansion, housing
costs) differentially bind. The minimum-wage confounder from PLAN §A does
not just survive the simulated-instrument design; it **loads onto the dose
itself**, because credit bite and wage-floor bite concentrate in the same
cells.

**Formula instruments and recentering (Borusyak & Hull 2023).** A simulated
instrument is a formula instrument: z(cell, t) = f(fixed composition;
policy_t). Borusyak–Hull's identification route treats the *shocks* as
quasi-random and recenters z by its expectation over counterfactual shock
draws to purge non-random exposure. With a single shock — one state, one
adoption date — there is no shock distribution to recenter against. The
design therefore cannot claim shock-level quasi-randomness; its credibility
rests entirely on cell-level parallel trends. In other words, **Simulation 2
is a DiD, not an IV**: it repackages the same CA × post × exposure variation
as the triple-difference, with a finer dose.

**What the machinery is genuinely for.** Freezing the 2014 population kills
endogenous composition — people entering CalEITC eligibility *because* they
respond to the credit. That is the real Gruber–Saez contribution and should
be stated as the motivation, in place of IV language.

**Aggregation/attenuation.** The header of `03_tab_sim_inst.do` already
notes that the cell-mean dollar instrument averages over within-cell
nonlinearity, attenuating the kink-driven margin. In CGS terms, cell-mean
dose masks within-cell dose heterogeneity and pushes the estimand toward a
coarse level comparison. This is a clean mechanical account of the current
footnote ("confirms the overall employment effect but lacks power to
decompose the full-time/part-time margin"): slope-type parameters are
intrinsically more demanding than level ATTs. The power statement is
expected behavior, not a data quirk — but it should not be oversold as
confirmation either.

## 3. Recommendations for the revision

1. **Reframe the appendix from "IV estimation" to "exposure-design DiD".**
   Present the simulated credit as a composition-fixed *exposure measure*;
   state the strong-parallel-trends assumption explicitly when interpreting
   per-dollar magnitudes; cite Callaway–Goodman-Bacon–Sant'Anna (2024) and
   Borusyak–Hull (2023). Drop language implying identification beyond the
   triple-difference.
2. **Report dose-group contrasts instead of (or alongside) the linear
   slope.** Discretize simulated exposure (zero/low/high or terciles within
   non-college mothers) and estimate group-specific DiDs against the
   lowest-exposure group — CGS's recommended comparison — with **event
   studies by exposure group**. Flat pre-trends at every dose level is a
   direct partial test of strong parallel trends, and "effects increasing in
   dose, flat pre-periods throughout" is more persuasive than one 2SLS
   coefficient. This implements PLAN §A.2 with the simulated credit as the
   exposure measure, so one analysis serves both purposes.
3. **Keep the inference honest.** The dose varies at cell level within one
   treated state; the one-treated-cluster problem is unchanged. Use the
   Appendix E battery (or randomization inference over the dose assignment)
   for the dose-response estimates, not bare CRVE stars.
4. **Pair with the minimum-wage bite test (PLAN §A.1).** Effects
   concentrating where the credit bites is also what a wage-floor story
   predicts. The credit-range exposure gradient and the sub-minimum-wage
   share gradient are correlated but not identical across cells/counties;
   showing the response follows the former conditional on the latter is what
   actually rules the confounder out.
5. **Make the meta-point in the paper's framing.** The headline binary
   triple-difference needs only ordinary parallel trends and is therefore
   *more* robust under the new literature than the simulated IV. Present
   Simulation 2 as supporting dose-response evidence under an explicitly
   stronger assumption — not as an independent identification strategy.

## References to add to the bibliography (Overleaf references.bib)

- Callaway, B., A. Goodman-Bacon, and P. H. C. Sant'Anna (2024),
  "Difference-in-Differences with a Continuous Treatment" (NBER WP 32117 /
  latest working version).
- Borusyak, K., and P. Hull (2023), "Non-Random Exposure to Exogenous
  Shocks," *Econometrica* 91(6).
- de Chaisemartin, C., and X. D'Haultfœuille (2020), "Two-Way Fixed Effects
  Estimators with Heterogeneous Treatment Effects," *AER* 110(9) — and their
  continuous-treatment extensions (with Pasquier and Vazquez-Bare).
- (Already cited: Gruber and Saez 2002.)
