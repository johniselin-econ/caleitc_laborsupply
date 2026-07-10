# =============================================================================
# File:    hpc/stage_rerun.R
# Purpose: Stage a full re-run's fresh compute outputs (data/tmp/) into the
#          job-tagged results/<area>/ layout the exhibit builders consume via
#          latest_result(). Run by stage_exhibits.sbatch after all compute
#          stages complete (see run_pipeline.sh). The job tag is this staging
#          job's SLURM_JOB_ID, so the freshly staged files win latest_result()
#          by mtime over the committed ones.
#
#          Array stages (10/11/12 SDID, 20 appE) write one data/tmp/<base>_task
#          <k>.csv per grid cell; these are row-bound into the combined file.
#          Their per-task .rds replication matrices are copied by name (32
#          HonestDiD reads sdid_county_es_r_task*.rds). Single-job stages write
#          the combined data/tmp/<base>.csv directly.
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
JID <- { j <- Sys.getenv("SLURM_JOB_ID"); if (nzchar(j)) j else "rerun" }
tmp <- function(f) path_data("tmp", f)

stage_one <- function(area, tmpbase, target = tmpbase, ext = "csv") {
  src <- tmp(paste0(tmpbase, ".", ext))
  if (!file.exists(src)) { message("  skip ", area, "/", tmpbase, " (no tmp)"); return(invisible()) }
  dir.create(path_results(area), showWarnings = FALSE, recursive = TRUE)
  dst <- path_results(area, sprintf("%s_job%s.%s", target, JID, ext))
  file.copy(src, dst, overwrite = TRUE); message("  staged ", dst)
}

combine_array <- function(area, tmpbase, target = tmpbase) {
  fs <- Sys.glob(tmp(paste0(tmpbase, "_task*.csv")))
  dir.create(path_results(area), showWarnings = FALSE, recursive = TRUE)
  if (length(fs)) {
    d <- do.call(rbind, lapply(fs, read.csv))
    dst <- path_results(area, sprintf("%s_job%s.csv", target, JID))
    write.csv(d, dst, row.names = FALSE)
    message("  combined ", length(fs), " tasks -> ", dst)
  } else stage_one(area, tmpbase, target)   # serial fallback (combined tmp)
  # per-task replication matrices copied by name (consumed as-is by 32)
  for (r in Sys.glob(tmp(paste0(tmpbase, "_task*.rds"))))
    file.copy(r, path_results(area, basename(r)), overwrite = TRUE)
}

message("Staging re-run outputs (job tag ", JID, ") ...")
## Array stages -----------------------------------------------------------------
combine_array("sdid_r", "sdid_county_r")
combine_array("sdid_r", "sdid_county_stateplacebo_r")
combine_array("sdid_r", "sdid_county_es_r")
combine_array("appE_r", "appE_r")
## Single-job stages ------------------------------------------------------------
for (b in c("mw_bite_reg", "mw_bite_sdid_drop", "mw_bite_measures"))
  stage_one("mw_bite", b)
for (b in c("robustness_medicaid", "robustness_altthresh", "robustness_medicaid_es",
            "robustness_earnbins_bins", "robustness_earnbins_states"))
  stage_one("robustness", b)
for (b in c("earnbins_scaled_states", "earnbins_scaled_p")) stage_one("robustness", b)
for (b in c("dose_post", "dose_ri", "dose_es", "dose_cells")) stage_one("dose_response", b)
for (b in c("quad_diff_r", "oster_bounds_r")) stage_one("quad_oster", b)
for (b in c("elast_participation_r", "elast_mobility_r", "elast_qc_shares_r"))
  stage_one("elasticities", b)
stage_one("mvpf", "mvpf_models_r", "mvpf_models")
stage_one("mvpf", "mvpf_summary_r", "mvpf_summary")
message("STAGE RERUN COMPLETE")
