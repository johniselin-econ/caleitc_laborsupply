# =============================================================================
# File:    20_altinference.R
# Purpose: Run the full Appendix E alternative-inference battery in R —
#          port of 04_appE_inference(_parallel).do on the machinery in
#          code/lib/inference.R, plus the NEW Conley-Taber (2011) CIs.
#
#          One (outcome x spec) task per invocation (SLURM array 1-12,
#          task_id mapping identical to the Stata battery: employed_y 1-4,
#          full_time_y 5-8, part_time_y 9-12). B = 1000 (WCBS, FP),
#          B_ri = 100 (RIWB), per-task seed = params$seed + task, with
#          per-method offsets (+0 WCBS, +1e5 RIWB, +2e5 FP) so the three
#          resampling streams are independent within a task.
#
#          Output: data/tmp/appE_r_task<k>.rds (all objects incl. draws) and
#          data/tmp/appE_r_task<k>.csv (one row of p-values) for assembly and
#          the Monte-Carlo-band comparison against the job-17058169 golden
#          tables. RNG streams differ from Stata by construction — see the
#          header of inference.R.
#
# Usage:   Rscript code/20_altinference.R   (APPE_TASK or
#          SLURM_ARRAY_TASK_ID selects the task; default 1)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))

suppressPackageStartupMessages({
  library(dplyr)
})
source(file.path("code", "lib", "estimation.R"))
source(file.path("code", "lib", "inference.R"))

task <- as.integer(Sys.getenv("APPE_TASK",
                              Sys.getenv("SLURM_ARRAY_TASK_ID", "1")))
OUTCOMES <- c("employed_y", "full_time_y", "part_time_y")
oi <- ceiling(task / 4)
spec <- task - (oi - 1) * 4
out <- OUTCOMES[oi]

B <- 1000
B_ri <- 100
seed <- params$seed + task

message(sprintf("Task %d: outcome %s, spec %d, seed %d", task, out, spec, seed))

wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
samp <- appE_sample(wf, params$start_year %||% 2012, params$end_year %||% 2017)
rm(wf); invisible(gc())
message("Sample: ", nrow(samp), " rows")

## Main fit + CRVE ------------------------------------------------------------
main <- appE_fit(out, samp, spec)
ms <- fit_stats(main, "treated")
p_crve <- appE_crve_p(ms[["t"]])
message(sprintf("ATE %.4f (SE %.4f), CRVE p = %.4f", ms[["b"]], ms[["se"]],
                p_crve))

## Wild cluster bootstrap ------------------------------------------------------
message("WCBS (B = ", B, ")...")
wcbs <- appE_wcbs(out, samp, spec, B = B, seed = seed, fit = main,
                  progress = TRUE)
message("WCBS p = ", round(wcbs$p, 4))

## RIWB + Conley-Taber ---------------------------------------------------------
message("RI refits (deterministic)...")
refits <- appE_ri_refits(out, samp, spec)
ct <- conley_taber(refits, level = 0.90)
message(sprintf("Conley-Taber 90%% CI: [%.3f, %.3f], refit RI p = %.3f",
                ct$lower, ct$upper, ct$p_ri))

message("RIWB wild draws (", (max(refits$j) + 1) * B_ri, " refits)...")
riwb <- appE_riwb(out, samp, spec, B = B_ri, seed = seed + 100000,
                  refits = refits, progress = TRUE)
message(sprintf("RIWB p_t = %.4f, p_beta = %.4f", riwb$p_t, riwb$p_beta))

## Ferman-Pinto ----------------------------------------------------------------
message("Ferman-Pinto (B = ", B, ")...")
fp <- appE_fp(out, samp, spec, B = B, seed = seed + 200000)
message(sprintf("FP p_without = %.4f, p_with = %.4f", fp$p_without, fp$p_with))

## Save ------------------------------------------------------------------------
res <- data.frame(task = task, outcome = out, spec = spec,
                  N = main$nobs, b = ms[["b"]], se = ms[["se"]],
                  p_crve = p_crve, p_wcbs = wcbs$p,
                  p_riwcbs_t = riwb$p_t, p_riwcbs_b = riwb$p_beta,
                  p_block = fp$p_without, p_block_fp = fp$p_with,
                  ct_lower = ct$lower, ct_upper = ct$upper, ct_p_ri = ct$p_ri,
                  seed = seed, B = B, B_ri = B_ri)
saveRDS(list(results = res, refits = refits, fp_state = fp$state,
             fp_draws = fp$draws, riwb_draws = riwb$draws,
             wcbs_t = wcbs$t_star),
        path_data("tmp", sprintf("appE_r_task%d.rds", task)))
write.csv(res, path_data("tmp", sprintf("appE_r_task%d.csv", task)),
          row.names = FALSE)
message("TASK ", task, " COMPLETE")
