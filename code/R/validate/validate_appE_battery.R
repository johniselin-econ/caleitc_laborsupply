# =============================================================================
# File:    validate_appE_battery.R
# Purpose: Compare the R Appendix E battery (stage 12, data/tmp/appE_r_task
#          <k>.csv) against the golden Stata tables from SLURM job 17058169
#          (results/paper/tab_appE_tab1_{1,2,3}.tex; new numbering:
#          1 = employed, 2 = full-time, 3 = part-time; spec columns 1-4).
#
#          Deterministic quantities (ATE, SE, N, CRVE p) must match at the
#          table's display precision. Resampling p-values (WCBS, RIWB-t/b,
#          BB, Corrected BB) are independent Monte-Carlo estimates of the
#          same true p on DIFFERENT RNG streams (R cannot reproduce Stata's),
#          so they are gated within a two-sample binomial band:
#            |p_R - p_S| <= 3.1 * sqrt(pbar(1-pbar)(1/B_R + 1/B_S)) + slop
#          with pbar the pooled estimate (floored at 0.005 so the band never
#          collapses), B from each side's draw count, and slop = 0.0015 for
#          the golden table's 3-decimal rounding plus the +1-convention
#          difference in the Stata builtin `wildbootstrap` divisor.
#          Draw counts: WCBS/BB/Corrected-BB B = 1000 both sides; RIWB
#          reference is placebo-only, 27 x 100 = 2700 draws both sides
#          (cluster-correlated, so the nominal band is conservative-ish;
#          treated as approximate).
#
# Usage:   Rscript code/R/validate/validate_appE_battery.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
suppressPackageStartupMessages(library(dplyr))

OUTCOMES <- c("employed_y", "full_time_y", "part_time_y")

## Golden tables ---------------------------------------------------------------
parse_row <- function(lines, label) {
  ln <- grep(paste0("^\\s*", label, "\\s*&"), lines, value = TRUE)
  stopifnot(length(ln) == 1)
  cells <- strsplit(sub("\\\\\\\\\\s*$", "", ln), "&")[[1]][-1]
  as.numeric(gsub("[^0-9.eE+-]", "", gsub("\\\\sym\\{[^}]*\\}", "", cells)))
}

golden <- lapply(1:3, function(oi) {
  lines <- readLines(file.path("results", "paper",
                               sprintf("tab_appE_tab1_%d.tex", oi)))
  data.frame(outcome = OUTCOMES[oi], spec = 1:4,
             ate_g  = parse_row(lines, "ATE"),
             n_g    = parse_row(lines, "Observations"),
             crve_g = parse_row(lines, "CRVE P-Value"),
             wcbs_g = parse_row(lines, "WCBS P-Value"),
             riwt_g = parse_row(lines, "RIWB-t P-Value"),
             riwb_g = parse_row(lines, "RIWB-b P-Value"),
             bb_g   = parse_row(lines, "BB P-Value"),
             fp_g   = parse_row(lines, "Corrected BB P-Value"))
}) |> bind_rows()

## R battery results -----------------------------------------------------------
files <- file.path(path_data("tmp"), sprintf("appE_r_task%d.csv", 1:12))
missing <- files[!file.exists(files)]
if (length(missing)) stop("Missing task outputs: ",
                          paste(basename(missing), collapse = ", "))
res <- bind_rows(lapply(files, read.csv))

cmp <- inner_join(res, golden, by = c("outcome", "spec"))
stopifnot(nrow(cmp) == 12)

## Gates -----------------------------------------------------------------------
mc_band <- function(p_r, p_s, B_r, B_s, slop = 0.0015) {
  pbar <- pmax((p_r + p_s) / 2, 0.005)
  3.1 * sqrt(pbar * (1 - pbar) * (1 / B_r + 1 / B_s)) + slop
}

fails <- 0
check <- function(label, ok, detail) {
  status <- ifelse(ok, "OK  ", "FAIL")
  cat(sprintf("%s %-28s %s\n", status, label, detail))
  if (any(!ok)) fails <<- fails + sum(!ok)
}

cat("=== Deterministic layer (display precision) ===\n")
check("ATE (1 dp)", round(cmp$b, 1) == cmp$ate_g,
      paste("max abs diff", format(max(abs(round(cmp$b, 1) - cmp$ate_g)))))
check("N", cmp$N == cmp$n_g, paste("N =", cmp$N[1]))
check("CRVE p (3 dp)", abs(cmp$p_crve - cmp$crve_g) <= 0.0005 + 1e-12,
      paste("max abs diff", format(max(abs(cmp$p_crve - cmp$crve_g)))))

cat("\n=== Resampling p-values (Monte-Carlo bands, 3.1 sigma) ===\n")
gate <- function(label, p_r, p_s, B_r, B_s) {
  band <- mc_band(p_r, p_s, B_r, B_s)
  check(label, abs(p_r - p_s) <= band,
        sprintf("max |diff| %.4f, min headroom %.4f",
                max(abs(p_r - p_s)), min(band - abs(p_r - p_s))))
}
gate("WCBS",         cmp$p_wcbs,     cmp$wcbs_g, 1000, 1000)
gate("RIWB-t",       cmp$p_riwcbs_t, cmp$riwt_g, 2700, 2700)
gate("RIWB-b",       cmp$p_riwcbs_b, cmp$riwb_g, 2700, 2700)
gate("BB",           cmp$p_block,    cmp$bb_g,   1000, 1000)
gate("Corrected BB", cmp$p_block_fp, cmp$fp_g,   1000, 1000)

cat("\n=== Per-task detail ===\n")
print(cmp |>
        transmute(task, outcome, spec, b = round(b, 4),
                  crve = p_crve, crve_g,
                  wcbs = p_wcbs, wcbs_g,
                  riwt = p_riwcbs_t, riwt_g,
                  riwb = p_riwcbs_b, riwb_g,
                  bb = p_block, bb_g,
                  fp = p_block_fp, fp_g) |>
        mutate(across(where(is.numeric), \(x) round(x, 3))),
      row.names = FALSE)

cat("\n=== Conley-Taber (NEW - no golden benchmark; report only) ===\n")
print(cmp |>
        transmute(task, outcome, spec, b = round(b, 2),
                  ct_lower = round(ct_lower, 2), ct_upper = round(ct_upper, 2),
                  ct_p_ri) , row.names = FALSE)

if (fails > 0) {
  cat("\nAPPE BATTERY VALIDATION FAILED:", fails, "gate(s)\n")
  quit(status = 1)
}
cat("\nAPPE BATTERY VALIDATION PASSED (12 tasks, 8 gates)\n")
