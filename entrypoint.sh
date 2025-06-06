#!/bin/bash

set -euo pipefail

INPUT_MARKDOWN_FILE="${INPUT_MARKDOWN_FILE:-}"
INPUT_TEMPLATE="${INPUT_TEMPLATE:-guideline}"
INPUT_TEMPLATES_FILE="${INPUT_TEMPLATES_FILE:-}"
INPUT_FILTERS_FILE="${INPUT_FILTERS_FILE:-}"
INPUT_DRAFT="${INPUT_DRAFT:-false}"
INPUT_PDF="${INPUT_PDF:-true}"
INPUT_DOCX="${INPUT_DOCX:-true}"
INPUT_LINT="${INPUT_LINT:-false}"
INPUT_DIFF_FILE="${INPUT_DIFF_FILE:-}"
TEXINPUTS="${TEXINPUTS:-}"

# Consider all Git repositories as safe
# https://github.blog/2022-04-18-highlights-from-git-2-36/
git config --global --add safe.directory "*"

# Rather than relying on 'set -x', which will output the command to STDERR,
# use a function that logs to STDOUT. This ensures a deterministic sequence
# of output (e.g. during tests), by writing everything to a single output.
#
# While 'set -x / set +x' gives a good degree of flexibility, the downside to
# this is that by default, stderr is unbuffered and stdout is buffered, and
# that when run under Docker, there is additional non-determinism in how
# outputs are logged, as captured at https://github.com/moby/moby/issues/31706
#
# See https://github.com/cabforum/build-guidelines-action/issues/11 for more
# history.
LogAndRun() {
  echo "$@"
  "$@"
}

if [ -z "${INPUT_MARKDOWN_FILE}" ]; then
  echo "An input markdown file MUST be specified via the markdown_file argument"
  exit 1
fi
if [ ! -f "${INPUT_MARKDOWN_FILE}" ]; then
  echo "Invalid file specified: ${INPUT_MARKDOWN_FILE} cannot be found."
  exit 1
fi
if [ "${INPUT_MARKDOWN_FILE##*.}" != "md" ] ; then
  echo "Invalid file specified: ${INPUT_MARKDOWN_FILE} is not a Markdown file."
  exit 1
fi
BASE_FILE="${INPUT_MARKDOWN_FILE%.*}"

DIFF_FILE=
if [ -n "${INPUT_DIFF_FILE}" ]; then
  if [ -f "${INPUT_DIFF_FILE}" ] && [[ "${INPUT_DIFF_FILE}" =~ .*\.md ]]; then
    DIFF_FILE="${INPUT_DIFF_FILE}"
  else
    echo "Skipping redline; unable to find ${INPUT_DIFF_FILE} or the filename doesn't end in .md"
  fi
fi

# Extract templates tar.gz file and add to templates directory
if [ -n "${INPUT_TEMPLATES_FILE}" ]; then
  echo "::group::Extracting templates"
  tar -xvzf "${INPUT_TEMPLATES_FILE}" -C /cabforum/templates/
  echo "::endgroup::"
fi

# Extract filters tar.gz file and add to filters directory
if [ -n "${INPUT_FILTERS_FILE}" ]; then
  echo "::group::Extracting filters"
  tar -xvzf "${INPUT_FILTERS_FILE}" -C /cabforum/filters/
  echo "::endgroup::"
fi

# Extract version
echo "::group::Extract version"
FILE_VERSION=
FILE_COMMIT=
if [ -n "${INPUT_MARKDOWN_FILE}" ]; then
  FILE_VERSION=$(head -20 "${INPUT_MARKDOWN_FILE}" | sed -nE 's/(version:|subtitle: Version) *([0-9]+\.[0-9]+\.[0-9]+)/v\2/p' | tr -cd 'v0-9.')
  FILE_COMMIT=$(git log -n 1 --pretty=format:%h -- "${INPUT_MARKDOWN_FILE}")
  echo "File $(basename ${INPUT_MARKDOWN_FILE}) is at version ${FILE_VERSION} and commit ${FILE_COMMIT}"
  echo "file_version=${FILE_VERSION}" >> $GITHUB_OUTPUT
  echo "file_commit=${FILE_COMMIT}" >> $GITHUB_OUTPUT
fi
DIFF_VERSION=
DIFF_COMMIT=
if [ -n "${DIFF_FILE}" ]; then
  DIFF_VERSION=$(head -20 "${DIFF_FILE}" | sed -nE 's/(version:|subtitle: Version) *([0-9]+\.[0-9]+\.[0-9]+)/v\2/p' | tr -cd 'v0-9.')
  DIFF_COMMIT=$(cd "$(dirname "${DIFF_FILE}")"; git log -n 1 --pretty=format:%h -- "$(basename "${DIFF_FILE}")")
  echo "Diff $(basename ${DIFF_VERSION}) is at version ${DIFF_VERSION} and commit ${DIFF_COMMIT}"
  echo "diff_version=${DIFF_VERSION}" >> $GITHUB_OUTPUT
  echo "diff_commit=${DIFF_COMMIT}" >> $GITHUB_OUTPUT

  CHANGELOG=
  
  # Check if the commits exist and are in the right order
  if git merge-base --is-ancestor "${DIFF_COMMIT}" "${FILE_COMMIT}" 2>/dev/null; then
    CHANGELOG=$(git log --pretty=format:"- %h %s" "${DIFF_COMMIT}..${FILE_COMMIT}" -- "${INPUT_MARKDOWN_FILE}")
  else
    # No direct ancestry between commits
    COMMON_ANCESTOR=$(git merge-base "${DIFF_COMMIT}" "${FILE_COMMIT}" 2>/dev/null || echo "")
    if [ -n "${COMMON_ANCESTOR}" ]; then
      echo "Using changes since common ancestor ${COMMON_ANCESTOR} between ${DIFF_COMMIT} and ${FILE_COMMIT}"
      CHANGELOG=$(git log --pretty=format:"- %h %s" "${COMMON_ANCESTOR}..${FILE_COMMIT}" -- "${INPUT_MARKDOWN_FILE}")
    else
      echo "Cannot determine changelog between these versions"
    fi
  fi

  # Changelog can have multiple lines, which is causing issues with the GitHub output
  echo "changelog<<EOF" >> $GITHUB_OUTPUT
  echo "${CHANGELOG}" >> $GITHUB_OUTPUT
  echo "EOF" >> $GITHUB_OUTPUT
  echo "Changelog:"
  echo "${CHANGELOG}"
fi
echo "::endgroup::"

# Include version in filenames
OUTPUT_FILENAME="${BASE_FILE}"
if [ -n "${FILE_VERSION}" ]; then
  OUTPUT_FILENAME="${BASE_FILE}-${FILE_VERSION}"
fi
OUTPUT_DIFF_FILENAME="${OUTPUT_FILENAME}-redline"
if [ -n "${DIFF_VERSION}" ]; then
  OUTPUT_DIFF_FILENAME="${BASE_FILE}-${DIFF_VERSION}-to-${FILE_VERSION}-redline"
fi

PANDOC_ARGS=( -f markdown+gfm_auto_identifiers --table-of-contents -s --no-highlight )

# Add all filters in the filters directory
for filter_file in /cabforum/filters/*.lua; do
  # skip broken-links.lua, which needs to run last
  if [ "$(basename "${filter_file}")" = "broken-links.lua" ]; then
    continue
  fi
  PANDOC_ARGS+=( --lua-filter="${filter_file}" )
done
PANDOC_ARGS+=( --filter=pantable )

if [ "$INPUT_DRAFT" = "true" ]; then
  echo "Draft detected. Adding draft watermark and file suffix"
  PANDOC_ARGS+=( -M draft )

  OUTPUT_FILENAME="${OUTPUT_FILENAME}_draft-${FILE_COMMIT}"
  OUTPUT_DIFF_FILENAME="${OUTPUT_DIFF_FILENAME}_draft-${DIFF_COMMIT}-to-${FILE_COMMIT}"
fi

# Build PDF
if [ "$INPUT_PDF" = "true" ]; then
  echo "::group::Building PDF"
  PANDOC_PDF_ARGS=( "${PANDOC_ARGS[@]}" )
  PANDOC_PDF_ARGS+=( -t latex --pdf-engine=xelatex )
  PANDOC_PDF_ARGS+=( --template=/cabforum/templates/${INPUT_TEMPLATE}.latex )
  PANDOC_PDF_ARGS+=( -o "${OUTPUT_FILENAME}.pdf" "${INPUT_MARKDOWN_FILE}" )

  LogAndRun pandoc "${PANDOC_ARGS[@]}" -t latex --template=/cabforum/templates/${INPUT_TEMPLATE}.latex -o "${BASE_FILE}.tex" "${INPUT_MARKDOWN_FILE}"
  TEXINPUTS="${TEXINPUTS}:/cabforum/" LogAndRun pandoc "${PANDOC_PDF_ARGS[@]}"
  echo "pdf_file=${OUTPUT_FILENAME}.pdf" >> $GITHUB_OUTPUT
  echo "::endgroup::"

  if [ -n "${DIFF_FILE}" ]; then
    echo "::group::Generating diff"
    TMP_DIR=$(mktemp -d)
    OUT_DIFF_TEX=$(basename "${DIFF_FILE}" ".md")
    OUT_DIFF_TEX="${TMP_DIR}/${OUT_DIFF_TEX}"
    LogAndRun pandoc "${PANDOC_ARGS[@]}" -t latex --template=/cabforum/templates/${INPUT_TEMPLATE}.latex -o "${OUT_DIFF_TEX}.tex" "${DIFF_FILE}"
    LogAndRun latexdiff --packages=hyperref "${OUT_DIFF_TEX}.tex" "${BASE_FILE}.tex" > "${OUT_DIFF_TEX}-redline.tex"
    # Three runs in total are required (and match what Pandoc does under the hood)
    TEXINPUTS="${TEXINPUTS}:/cabforum/" LogAndRun xelatex -interaction=nonstopmode --output-directory="${TMP_DIR}" "${OUT_DIFF_TEX}-redline.tex" || true
    TEXINPUTS="${TEXINPUTS}:/cabforum/" LogAndRun xelatex -interaction=nonstopmode --output-directory="${TMP_DIR}" "${OUT_DIFF_TEX}-redline.tex" || true
    TEXINPUTS="${TEXINPUTS}:/cabforum/" LogAndRun xelatex -interaction=nonstopmode --output-directory="${TMP_DIR}" "${OUT_DIFF_TEX}-redline.tex" || true
    if [ -f "${OUT_DIFF_TEX}-redline.pdf" ]; then
      cp "${OUT_DIFF_TEX}-redline.pdf" "${OUTPUT_DIFF_FILENAME}.pdf"
      echo "pdf_redline_file=${OUTPUT_DIFF_FILENAME}.pdf" >> $GITHUB_OUTPUT
    fi
    echo "::endgroup::"
  fi

fi

if [ "$INPUT_DOCX" = "true" ]; then
  echo "::group::Building DOCX"
  PANDOC_DOCX_ARGS=( "${PANDOC_ARGS[@]}" )
  PANDOC_DOCX_ARGS+=( -t docx )
  PANDOC_DOCX_ARGS+=( --reference-doc=/cabforum/templates/${INPUT_TEMPLATE}.docx )
  PANDOC_DOCX_ARGS+=( -o "${OUTPUT_FILENAME}.docx" "${INPUT_MARKDOWN_FILE}" )

  LogAndRun pandoc "${PANDOC_DOCX_ARGS[@]}"
  echo "docx_file=${OUTPUT_FILENAME}.docx" >> $GITHUB_OUTPUT
  echo "::endgroup::"
fi

if [ "$INPUT_LINT" = "true" ]; then
  echo "::group::Checking links"
  PANDOC_LINT_ARGS=( "${PANDOC_ARGS[@]}" )
  PANDOC_LINT_ARGS+=( -t gfm )
  PANDOC_LINT_ARGS+=( --lua-filter=/cabforum/filters/broken-links.lua )
  PANDOC_LINT_ARGS+=( -o /dev/null "${INPUT_MARKDOWN_FILE}" )

  LogAndRun pandoc "${PANDOC_LINT_ARGS[@]}"
  echo "::endgroup::"
fi
