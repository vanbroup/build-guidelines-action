#!/bin/bash

set -euo pipefail

INPUT_DRAFT="${INPUT_DRAFT:-false}"
INPUT_PDF="${INPUT_PDF:-true}"
INPUT_DOCX="${INPUT_DOCX:-true}"
INPUT_LINT="${INPUT_LINT:-false}"
INPUT_DIFF_FILE="${INPUT_DIFF_FILE:-}"
TEXINPUTS="${TEXINPUTS:-}"

if [ "$#" -ne 1 ]; then
  echo "No markdown file specified"
  echo "Usage: $0 <markdown_file.md>"
  exit 1
fi
if [ ! -f "$1" ]; then
  echo "Invalid file specified: ${1} cannot be found."
  exit 1
fi
if [ "${1##*.}" != "md" ] ; then
  echo "Invalid file specified: ${1} is not a Markdown file."
  exit 1
fi
BASE_FILE="${1%.*}"

DIFF_FILE=
if [ ! -z "${INPUT_DIFF_FILE}" ]; then
  if [ ! -f "${INPUT_DIFF_FILE}" ]; then
    echo "Missing diff_file: ${1} cannot be found."
    exit 2
  fi
  if [ "${INPUT_DIFF_FILE##*.}" != "md" ]; then
    echo "Invalid diff_file specified: ${INPUT_DIFF_FILE} is not a Markdown file."
    exit 2
  fi
  DIFF_FILE="${INPUT_DIFF_FILE}"
fi

PANDOC_ARGS=( -f markdown --table-of-contents -s )

if [ "$INPUT_DRAFT" = "true" ]; then
  echo "Draft detected. Adding draft watermark"
  PANDOC_ARGS+=( -M draft )
fi

# Build PDF
if [ "$INPUT_PDF" = "true" ]; then
  echo "::group::Building PDF"
  PANDOC_PDF_ARGS=( "${PANDOC_ARGS[@]}" )
  PANDOC_PDF_ARGS+=( -t latex --pdf-engine=xelatex )
  PANDOC_PDF_ARGS+=( --template=/cabforum/templates/guideline.latex )
  PANDOC_PDF_ARGS+=( -o "${BASE_FILE}.pdf" "${1}" )

  set -x
  pandoc "${PANDOC_ARGS[@]}" -t latex --template=/cabforum/templates/guideline.latex -o "${BASE_FILE}.tex" "${1}"
  TEXINPUTS="${TEXINPUTS}:/cabforum/" pandoc "${PANDOC_PDF_ARGS[@]}"
  set +x
  echo "::set-output name=pdf_file::${BASE_FILE}.pdf"
  echo "::endgroup::"

  if [ ! -z "${DIFF_FILE}" ]; then
    echo "::group::Generating diff"
    TMP_DIR=$(mktemp -d)
    OUT_DIFF_TEX=$(basename "${DIFF_FILE}")
    OUT_DIFF_TEX="${TMP_DIR}/${OUT_DIFF_TEX%.*}"
    set -x
    pandoc "${PANDOC_ARGS[@]}" -t latex --template=/cabforum/templates/guideline.latex -o "${OUT_DIFF_TEX}.tex" "${DIFF_FILE}"
    latexdiff --packages=hyperref "${OUT_DIFF_TEX}.tex" "${BASE_FILE}.tex" > "${OUT_DIFF_TEX}-redline.tex"
    # Run twice, to enable the Table of Contents to be generated on the first
    # run, then output on the second run.
    TEXINPUTS="${TEXINPUTS}:/cabforum/" xelatex -interaction=nonstopmode --output-directory="${TMP_DIR}" "${OUT_DIFF_TEX}-redline.tex"
    TEXINPUTS="${TEXINPUTS}:/cabforum/" xelatex -interaction=nonstopmode --output-directory="${TMP_DIR}" "${OUT_DIFF_TEX}-redline.tex"
    set +x
    cp "${OUT_DIFF_TEX}-redline.pdf" "${BASE_FILE}-redline.pdf"
    echo "::set-output name=pdf_redline_file::${BASE_FILE}-redline.pdf"
    echo "::endgroup::"
  fi

fi

if [ "$INPUT_DOCX" = "true" ]; then
  echo "::group::Building DOCX"
  PANDOC_DOCX_ARGS=( "${PANDOC_ARGS[@]}" )
  PANDOC_DOCX_ARGS+=( -t docx )
  PANDOC_DOCX_ARGS+=( --reference-doc=/cabforum/templates/guideline.docx )
  PANDOC_DOCX_ARGS+=( -o "${BASE_FILE}.docx" "${1}" )

  set -x
  pandoc "${PANDOC_DOCX_ARGS[@]}"
  set +x
  echo "::set-output name=docx_file::${BASE_FILE}.docx"
  echo "::endgroup::"
fi

if [ "$INPUT_LINT" = "true" ]; then
  echo "::group::Checking links"
  PANDOC_LINT_ARGS=( "${PANDOC_ARGS[@]}" )
  PANDOC_LINT_ARGS+=( -t gfm )
  PANDOC_LINT_ARGS+=( --lua-filter=/cabforum/filters/broken-links.lua )
  PANDOC_LINT_ARGS+=( -o /dev/null "${1}" )

  set -x
  pandoc "${PANDOC_LINT_ARGS[@]}"
  set +x
  echo "::endgroup::"
fi
