# =============================================================================
# File:    config.R
# Purpose: Load machine-specific paths (config/local_paths.yaml, falling back
#          to the committed .example) and analysis parameters
#          (config/parameters.yaml). Sourced by every pipeline script.
#
#          Exposes:
#            cfg    — named list of local paths, with directories resolved to
#                     absolute paths under the repo root
#            params — named list of analysis parameters
#            path_data(), path_results() — path helpers
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

suppressPackageStartupMessages({
  library(yaml)
  library(here)
})

if (!exists("%||%", mode = "function")) {  # base R >= 4.4 provides this
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

repo_root <- here::here()

local_paths_file <- file.path(repo_root, "config", "local_paths.yaml")
if (!file.exists(local_paths_file)) {
  warning("config/local_paths.yaml not found; using defaults from ",
          "config/local_paths.yaml.example — copy and edit it for this machine.")
  local_paths_file <- file.path(repo_root, "config", "local_paths.yaml.example")
}

cfg <- yaml::read_yaml(local_paths_file)

# Resolve data/results dirs relative to the repo root unless absolute
.resolve <- function(p) {
  if (is.null(p) || p == "") return(p)
  if (grepl("^(/|[A-Za-z]:)", p)) p else file.path(repo_root, p)
}
cfg$data_dir    <- .resolve(cfg$data_dir %||% "data")
cfg$results_dir <- .resolve(cfg$results_dir %||% "results")
cfg$api_codes   <- .resolve(cfg$api_codes %||% "api_codes.txt")
if (isTRUE(cfg$overleaf) && (is.null(cfg$overleaf_dir) || cfg$overleaf_dir == "")) {
  stop("local_paths.yaml sets overleaf: true but no overleaf_dir")
}

params <- yaml::read_yaml(file.path(repo_root, "config", "parameters.yaml"))

path_data    <- function(...) file.path(cfg$data_dir, ...)
path_results <- function(...) file.path(cfg$results_dir, ...)
