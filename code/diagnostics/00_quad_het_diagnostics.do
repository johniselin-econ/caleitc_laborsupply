/*******************************************************************************
File Name:      code/diagnostics/00_quad_het_diagnostics.do
Creator:        John Iselin (with Claude Code)
Date:           September 2026

Purpose:        Orchestrator for the household-composition diagnostics.

                Question: does the heterogeneity by household adult count
                (sec:het_adults -- the full-time decline concentrated in 3+
                adult households) survive the fourth difference?

                Answer: no. See results/diagnostics/README.md.

                Stages:
                  01  static estimates -- reproduces the committed triple-diff
                      heterogeneity and pooled quad-diff tables as golden
                      checks, then adds the quad-diff within each adult-count
                      cell (subsample and pooled-interaction versions)
                  02  college placebo by adult count + a test of whether cell
                      membership is itself post-treatment
                  03  event studies for full- and part-time, by adult count,
                      under all three designs

Inputs:         data/final/acs_working_file.dta  (streamed with `use ... if`)
Outputs:        results/diagnostics/quad_het_adults.csv
                results/diagnostics/quad_het_adults_placebo.csv
                results/diagnostics/quad_het_event.csv

Usage:          Run from the repo root:  do code/diagnostics/00_quad_het_diagnostics.do

                NOTE: these stages are self-contained -- they do not source
                utils/globals.do or utils/programs.do, and they re-declare the
                handful of macros they need. That makes each stage runnable on
                its own through stata-mcp, which forbids nested do/run/include.
                Run the stages individually if you are going through the MCP
                server rather than an interactive Stata session.

                NOTE: written in Stata rather than R because the R pipeline
                needs data/final/acs_working_file_r.rds, which is not built on
                this machine (05_working_file.R needs ~96 GB). Stata's
                `use varlist if condition using file` streams the 9.5 GB
                working file from disk and keeps only the analysis sample.

Project: CalEITC Labor Supply Effects
*******************************************************************************/

clear all
set more off

do code/diagnostics/01_quad_het_adults.do
do code/diagnostics/02_quad_het_adults_placebo.do
do code/diagnostics/03_quad_het_event.do

di _n "QUAD-HET DIAGNOSTICS COMPLETE"
