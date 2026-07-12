#!/usr/bin/env bash
# =============================================================================
# paper/build.sh — compile paper/main_aejep.tex to a PDF fully locally.
#
# The paper's \input{tables/...} and \includegraphics{figures/...} resolve
# against sibling tables/ and figures/ folders (as on Overleaf). Locally the
# artifacts are scattered across the canonical results/ output dirs, so this
# script assembles a self-contained build tree (paper/build/) of symlinks to
# whatever exists, stubs any genuinely-missing artifact with a flagged
# placeholder, and runs pdflatex + bibtex (aer style).
#
# Usage:   bash paper/build.sh            # -> paper/main_aejep.pdf
# Output:  paper/main_aejep.pdf (+ paper/build/ scratch, gitignored)
# =============================================================================
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
MAIN=main_aejep
SRC=paper
BUILD="$SRC/build"

# --- Toolchain (cluster: texlive module) -------------------------------------
if ! command -v pdflatex >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source /etc/profile.d/modules.sh 2>/dev/null || true
  module load texlive/20240312-GCC-13.3.0 2>/dev/null || true
fi
command -v pdflatex >/dev/null 2>&1 || {
  echo "ERROR: pdflatex not found. On the cluster: module load texlive/20240312-GCC-13.3.0" >&2
  exit 1; }

# --- Assemble a self-contained build tree ------------------------------------
rm -rf "$BUILD"
mkdir -p "$BUILD/tables" "$BUILD/figures"
ln -sf "$REPO/$SRC/$MAIN.tex"      "$BUILD/$MAIN.tex"
ln -sf "$REPO/$SRC/references.bib" "$BUILD/references.bib"
# Vendored bib style: TinyTeX (local) lacks aer.bst; cluster texlive has it,
# but the local copy takes precedence harmlessly either way.
[ -f "$REPO/$SRC/aer.bst" ] && ln -sf "$REPO/$SRC/aer.bst" "$BUILD/aer.bst"

# Search paths in precedence order (first hit wins).
TAB_SRCS=(results/tables results/paper)
FIG_SRCS=(results/figures results/paper results/paper/fiscal)

link_from () {  # $1=basename $2=destdir $3..=search dirs
  local base="$1" dest="$2"; shift 2
  local d
  for d in "$@"; do
    if [ -f "$REPO/$d/$base" ]; then ln -sf "$REPO/$d/$base" "$dest/$base"; return 0; fi
  done
  return 1
}

missing_tab=(); missing_fig=()
for t in $(grep -oE '\\input\{tables/[^}]+\}' "$SRC/$MAIN.tex" | sed -E 's|.*tables/||; s|\}||' | sort -u); do
  link_from "$t.tex" "$BUILD/tables" "${TAB_SRCS[@]}" || missing_tab+=("$t")
done
for f in $(grep -oE 'figures/[^}]+\.(jpg|png|pdf)' "$SRC/$MAIN.tex" | sed -E 's|figures/||' | sort -u); do
  link_from "$f" "$BUILD/figures" "${FIG_SRCS[@]}" || missing_fig+=("$f")
done

# --- Placeholders for genuinely-missing artifacts (flagged in the PDF) -------
for t in "${missing_tab[@]:-}"; do
  [ -n "$t" ] || continue
  echo "  [stub] table not found in any source dir: $t"
  printf '\\begin{tabular}{c}\\textbf{[MISSING TABLE: %s --- not yet produced]}\\end{tabular}\n' \
    "${t//_/\\_}" > "$BUILD/tables/$t.tex"
done
for f in "${missing_fig[@]:-}"; do
  [ -n "$f" ] || continue
  echo "  [WARN] figure not found in any source dir: $f (build will show a missing-file box)"
done

# --- Compile -----------------------------------------------------------------
cd "$BUILD"
echo "=== pdflatex (1/3) ==="; pdflatex -interaction=nonstopmode -file-line-error "$MAIN.tex" >/dev/null
echo "=== bibtex ===";         bibtex "$MAIN" >/dev/null
echo "=== pdflatex (2/3) ==="; pdflatex -interaction=nonstopmode -file-line-error "$MAIN.tex" >/dev/null
echo "=== pdflatex (3/3) ==="; pdflatex -interaction=nonstopmode -file-line-error "$MAIN.tex" >/dev/null

if [ -f "$MAIN.pdf" ]; then
  cp "$MAIN.pdf" "$REPO/$SRC/$MAIN.pdf"
  echo "=== BUILD OK -> $SRC/$MAIN.pdf ($(du -h "$MAIN.pdf" | cut -f1), $(pdfinfo "$MAIN.pdf" 2>/dev/null | awk '/Pages/{print $2" pages"}')) ==="
else
  echo "=== BUILD FAILED: no PDF produced (see $BUILD/$MAIN.log) ==="; exit 1
fi

# --- Diagnostics -------------------------------------------------------------
echo "--- BibTeX errors:         $(grep -c 'error message' "$MAIN.blg" 2>/dev/null || true) (see $BUILD/$MAIN.blg)"
echo "--- Undefined citations:   $(grep -c "Warning--I didn't find a database entry" "$MAIN.blg" 2>/dev/null || true)"
echo "--- Undefined references:  $(grep -c 'LaTeX Warning: Reference.*undefined' "$MAIN.log" 2>/dev/null || true)"
echo "--- Undefined citations (LaTeX+natbib): $(grep -cE '(LaTeX|Package natbib) Warning: Citation.*undefined' "$MAIN.log" 2>/dev/null || true)"
[ -s "$MAIN.bbl" ] || echo "--- WARNING: $MAIN.bbl is EMPTY — bibliography did not build (missing .bst?)"
