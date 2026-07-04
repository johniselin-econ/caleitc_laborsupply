# =============================================================================
# File:    qc_assignment.R
# Purpose: R port of the Stata qc_assignment program
#          (code/utils/programs.do:23-182). Assigns potential qualifying
#          children (QC) to adults. This variable DEFINES TREATMENT, so the
#          port is validated row-for-row against a Stata golden dump
#          (code/hpc/stage4_qcdump.do -> code/R/validate/
#          validate_qc_assignment.R) before anything downstream uses it.
#
#          The Stata original loops over pernum (one pass per person slot,
#          O(max_pernum) full-data passes). Both phases collapse to grouped
#          joins here. Faithfulness notes — each mirrors a quirk of the
#          original that must NOT be "fixed" silently:
#            (1) age 0 is recoded to 1 before matching (and the mutated age
#                is what downstream Stata steps see);
#            (2) matched counts DISTINCT parents matching a child in the
#                pointer phase (a child matched by both mom and pop has
#                matched = 2), then the relationship fallback sets it to 1;
#            (3) qc_ct is capped at 9 BETWEEN the pointer phase and the
#                relationship fallback — fallback additions can exceed 9;
#            (4) pointer matches require the target person to exist, be
#                non-QC, and be STRICTLY older than the child;
#            (5) the relationship fallback assigns only to the householder
#                (related == 101), only for children unmatched in the pointer
#                phase, in the order grandchild -> foster -> sibling (order
#                is inert in practice — `related` codes are mutually
#                exclusive — but preserved anyway);
#            (6) Stata missing-value semantics: a household with no
#                householder has hoh_qc missing, so `hoh_qc == 0` is FALSE
#                and no fallback assignment occurs (the always-true
#                `age < missing` comparison never rescues it).
#
# Input:   data frame with hh_id, pernum, age, qc, hoh, sibling, foster,
#          grandchild, momloc, momloc2, poploc, poploc2 (one row per person;
#          hh_id x pernum unique).
# Output:  the same data frame plus qc_ct, matched, min_qc_age, and with
#          age mutated per note (1).
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

qc_assignment <- function(df) {

  stopifnot(!anyDuplicated(df[, c("hh_id", "pernum")]))

  # (1) age 0 -> 1
  df <- df |> mutate(age = ifelse(age == 0, 1L, age))

  # ---------------------------------------------------------------------------
  # Phase A: parent-pointer matching
  # ---------------------------------------------------------------------------

  links <- df |>
    filter(qc == 1) |>
    select(hh_id, kid_pernum = pernum, kid_age = age,
           momloc, momloc2, poploc, poploc2) |>
    pivot_longer(c(momloc, momloc2, poploc, poploc2),
                 values_to = "par_pernum") |>
    filter(par_pernum > 0) |>
    distinct(hh_id, kid_pernum, kid_age, par_pernum) |>          # note (2)
    inner_join(df |> filter(qc == 0) |>
                 select(hh_id, par_pernum = pernum, par_age = age),
               by = c("hh_id", "par_pernum")) |>                 # note (4)
    filter(kid_age < par_age)                                    # note (4)

  par_stats <- links |>
    group_by(hh_id, pernum = par_pernum) |>
    summarise(qc_ct_a = n(), min_qc_age_a = min(kid_age), .groups = "drop")

  kid_stats <- links |>
    count(hh_id, pernum = kid_pernum, name = "matched_a")

  df <- df |>
    left_join(par_stats, by = c("hh_id", "pernum")) |>
    left_join(kid_stats, by = c("hh_id", "pernum")) |>
    mutate(
      qc_ct      = coalesce(qc_ct_a, 0L),
      matched    = coalesce(matched_a, 0L),
      min_qc_age = min_qc_age_a
    ) |>
    select(-qc_ct_a, -matched_a, -min_qc_age_a)

  # (3) cap BEFORE the relationship fallback
  df <- df |> mutate(qc_ct = pmin(qc_ct, 9L))

  # ---------------------------------------------------------------------------
  # Phase B: relationship fallback to the householder
  # ---------------------------------------------------------------------------

  hoh_info <- df |>
    filter(hoh == 1) |>
    group_by(hh_id) |>
    summarise(hoh_age = mean(age), hoh_qc = mean(qc), .groups = "drop")

  df <- df |> left_join(hoh_info, by = "hh_id")

  for (rel in c("grandchild", "foster", "sibling")) {            # note (5)

    df <- df |>
      mutate(newly = qc == 1 & .data[[rel]] == 1 & matched == 0 &
               (!is.na(hoh_qc) & hoh_qc == 0) &                  # note (6)
               (is.na(hoh_age) | age < hoh_age))

    adds <- df |>
      filter(newly) |>
      group_by(hh_id) |>
      summarise(n_add = n(), min_add = min(age), .groups = "drop")

    df <- df |>
      left_join(adds, by = "hh_id") |>
      mutate(
        qc_ct = ifelse(hoh == 1 & qc == 0 & !is.na(n_add),
                       qc_ct + n_add, qc_ct),
        min_qc_age = ifelse(hoh == 1 & qc == 0 & !is.na(min_add) &
                              (is.na(min_qc_age) | min_qc_age > min_add),
                            min_add, min_qc_age),
        matched = ifelse(newly, 1L, matched)
      ) |>
      select(-n_add, -min_add, -newly)
  }

  df |> select(-hoh_age, -hoh_qc)
}
