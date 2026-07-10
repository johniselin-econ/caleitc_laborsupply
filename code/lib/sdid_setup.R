# =============================================================================
# File:    utils/sdid_setup.R
# Purpose: Shared panel.matrices setup for the county SDID scripts
#          (10_sdid.R, 12_sdid_eventstudy.R): aligned 2010-pop
#          treated weights, covariate array, size-quartile strata.
#          Extracted verbatim from 10_sdid.R (job 17203764 vintage);
#          callers must have sourced the synthdid_weights fork first
#          (panel.matrices comes from it).
# Project: CalEITC Labor Supply Effects
# =============================================================================

# panel.matrices setup + aligned pop weights / covariate array / strata.
# Units with any NA in the columns a spec needs are dropped (with a loud
# message; a dropped TREATED unit aborts — the estimand would change).
make_setup <- function(panel, ycol, xcols = NULL,
                       end_year = NULL, treat_year = 2015) {
  df <- panel
  if (!is.null(end_year)) df <- df[df$year <= end_year, ]
  need <- c(ycol, xcols)
  bad <- sort(unique(df$fips[!complete.cases(df[, need, drop = FALSE])]))
  if (length(bad)) {
    bad_treated <- unique(df$fips[df$state_fips == 6]) |> intersect(bad)
    if (length(bad_treated))
      stop("treated units dropped for NA in ", paste(need, collapse = "/"),
           ": fips ", paste(bad_treated, collapse = ", "))
    message("  dropping ", length(bad), " donor unit(s) with NA in ",
            paste(need, collapse = "/"))
    df <- df[!(df$fips %in% bad), ]
  }
  dfp <- data.frame(.unit = df$fips, .time = df$year,
                    y = df[[ycol]],
                    .W = as.integer(df$state_fips == 6 &
                                      df$year >= treat_year))
  setup <- panel.matrices(dfp)

  # Alignment by rownames(Y) — panel.matrices orders controls-first, each
  # block sorted by unit id; never assume input order.
  base_yr <- min(df$year)
  pop_map <- with(df[df$year == base_yr, ],
                  setNames(pop, as.character(fips)))
  units <- rownames(setup$Y)
  treated_units <- units[(setup$N0 + 1):nrow(setup$Y)]
  tw <- as.numeric(pop_map[treated_units])
  stopifnot(!anyNA(tw), all(tw > 0))

  X <- NULL
  if (length(xcols)) {
    X <- array(NA_real_, dim = c(nrow(setup$Y), ncol(setup$Y), length(xcols)),
               dimnames = list(units, colnames(setup$Y), xcols))
    for (k in seq_along(xcols)) {
      m <- tapply(df[[xcols[k]]],
                  list(as.character(df$fips), as.character(df$year)),
                  identity)
      X[, , k] <- m[units, colnames(setup$Y)]
    }
    stopifnot(!anyNA(X))
  }

  pop_all <- as.numeric(pop_map[units])
  strata <- cut(pop_all, quantile(pop_all, 0:4 / 4),
                include.lowest = TRUE, labels = FALSE)

  list(setup = setup, X = X, treated.weights = tw, strata = strata,
       n_dropped = length(bad), base_yr = base_yr)
}
