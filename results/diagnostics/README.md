# Household-composition diagnostics

**Run:** 2026-09-01 · **Code:** `code/diagnostics/` · **Review page:** `three_adult_anomaly.html`

## The question

`sec:het_adults` in `paper/main_aejep.tex` reports that the full-time-to-part-time
shift is concentrated in households with three or more adults, and reads a
collective-labor-supply story into it. The pooled quadruple difference
(`03_tab_quad_diff.do`) kills the full-time effect while part-time survives.
Does the household-composition heterogeneity survive the fourth difference too?
If the 3+ adult full-time result is also sensitive to the fourth difference,
that points toward confounding rather than a credit response.

## The answer: no, and the failure is a reversal rather than an attenuation

Full-time work, percentage points, CA × post × QC:

| Adults | Triple-diff (committed) | Quad, subsample | Quad, interaction | College placebo |
|---|---|---|---|---|
| All | −4.08\*\*\* | −0.18 | — | −2.00\* |
| 1 | −1.58 | −3.20\*\* | −3.70\*\*\* | −1.18 |
| 2 | −1.85 | +5.25\*\*\* | −1.52\*\* | −3.75\*\* |
| 3+ | −7.26\*\*\* | +0.55 | +4.56\*\*\* | −3.53 |

Part-time work:

| Adults | Triple-diff | Quad, subsample | Quad, interaction | College placebo |
|---|---|---|---|---|
| All | +3.74\*\*\* | +1.77\*\*\* | — | +0.54 |
| 1 | +3.03\*\*\* | +4.37\*\*\* | +4.15\*\*\* | −1.70 |
| 2 | +2.63\*\* | −2.99\*\*\* | +2.38\*\*\* | +1.71 |
| 3+ | +4.93\*\*\* | +1.39 | −1.11\* | +4.23\*\* |

Three findings, in order of how much weight they can carry.

1. **The −7.3 pp full-time decline in 3+ adult households does not survive the
   fourth difference.** It goes to zero in the subsample version and flips sign
   in the pooled-interaction version. Both implementations agree on this.

2. **The college placebo shows the same pattern in the same cell.** College
   women are largely ineligible, yet in 3+ adult households their part-time
   work rises 4.23 pp (p < 0.05) against a pooled placebo of 0.54, nearly
   matching the treated estimate of 4.93. Something California-specific hit
   multi-adult households with children after 2014 and reached both education
   groups.

3. **Under the fourth difference the surviving part-time effect is a one- and
   two-adult phenomenon**, the opposite of the paper's current claim.

## Supporting checks

**Cell membership is not post-treatment.** Triple-difference estimates on the
probability of being in each adult-count cell are precise zeros for both
education groups (all |t| < 1.2), so `hh_adult_ct` is not behaving like a
collider and selection into household types is not the mechanism.

**Pre-period comparability, by cell.** Count of the six event-study panels per
cell (2 outcomes × 3 designs) with any pre-period coefficient at |t| ≥ 1.96:

| Cell | Panels failing |
|---|---|
| All households | 1 of 6 |
| 1 adult | 1 of 6 |
| 2 adults | 4 of 6 |
| 3+ adults | 4 of 6 |

Cutting by household size destabilizes every design, not only one. In the
part-time placebo for 3+ adults, California sits 5 to 8 points above the
control states in *every* year including 2012 and 2013, with no break at the
policy date — a comparability failure roughly the size of the effect the paper
attributes to the credit.

**Caveat on the pooled part-time headline.** The single pooled failure is the
quadruple difference on part-time, whose 2013 coefficient carries |t| = 2.61.
The post-2015 effect is large and persistent enough to survive it, but the
pre-period is not perfectly flat.

## What is NOT established

- The cell-level quad-diff magnitudes are unstable across implementations (the
  2-adult cell is +5.25 subsample against −1.52 interaction). Only the 3+
  conclusion is robust to both. The subsample version re-estimates the
  saturated FEs inside each cell, so the cell estimates do not aggregate to the
  pooled estimate.
- **The placebo may not be clean in this cell.** Treatment is assigned on the
  woman's own education, but the credit is claimed on a tax unit inside a
  household. In a 3+ adult household the other adults may themselves be
  CalEITC-eligible. If so the control group is partly treated, the fourth
  difference subtracts a genuine household-level response, and the quadruple
  difference over-differences precisely where the paper's mechanism operates.
  This is the one story under which the heterogeneity is real. **Test before
  rewriting `sec:het_adults`:** split the college sample by whether any other
  household adult has earnings in the eligible range.

## Implications for the draft

`sec:het_adults` needs the same bounded/attributional treatment the full-time
headline got on 2026-08-28. The elasticities section also leans on this result,
justifying the large mobility elasticities on the grounds that multi-adult
households drive the response; that justification does not survive either.
Read as a second independent instance of the paper's post-August spine: a gross
triple-difference effect in California contains a large common non-credit
component.

## Files

| File | Contents |
|---|---|
| `quad_het_adults.csv` | Static estimates: golden checks + quad-diff by adult count |
| `quad_het_adults_placebo.csv` | College placebo by adult count |
| `quad_het_event.csv` | 144 event-study coefficients (3 designs × 4 cells × 2 outcomes × 6 years) |
| `three_adult_anomaly.html` | Review page: event-study small multiples + candidate mechanisms |

## Validation

The pooled quadruple difference and the triple-difference heterogeneity table
were reproduced before any new cut was taken. Coefficients, standard errors and
sample sizes match `results/tables/tab_quad_diff_*.tex` and
`tab_het_adults_*.tex` exactly (N = 761,195 pooled; 133,712 / 164,039 / 163,865
by cell).

## Candidate mechanisms

Eight are set out with a testable implication for each in
`three_adult_anomaly.html`. A candidate has to be California-specific (state ×
year effects absorb anything national), arrive around 2015, bite harder with
qualifying children, and reach college-educated women. Best fits: the other
household adults returning to work during California's late, steep recovery;
in-home supportive services provider hour caps from February 2016; city and
county minimum wage ordinances that state × year effects do not absorb; and
mixed-status households after the TRUST Act and AB 60 licences in January 2015.
Five of the eight can be tested with variables already in the ACS extract.
