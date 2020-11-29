# CA/Browser Forum Guidline builder action

This action customizes the [Pandoc dockerfiles](https://github.com/pandoc/dockerfiles)
for use by [CA/Browser Forum](https://www.cabforum.org) Chartered Working
Groups to automatically produce Draft and Final Guidelines.

## Inputs

### `markdown-file`

**Required** The name of the Markdown file to convert. This should be relative
to [`GITHUB_WORKSPACE`](https://docs.github.com/en/free-pro-team@latest/actions/reference/environment-variables).

In general, running [`actions/checkout`](https://github.com/actions/checkout)
for the CWG repository is a necessary step before invoking this action, and
allows just passing the filename relative to the current repository.

### `pdf`

Generate a PDF from `markdown-file`. Default: `"true"`.

The resulting PDF will be in the same directory of `GITHUB_WORKSPACE` as the
input file, but with a `pdf` extension.

### `docx`

Generate a DOCX. Default: `"true"`.

The resulting PDF will be in the same directory of `GITHUB_WORKSPACE` as the
input file, but with a `docx` extension.

### `lint`

Check that all self-referencing links resolve. Default: `"false"`.

This runs a simple [Pandoc Lua filter](https://pandoc.org/lua-filters.html) to
check and make sure that links to section headers resolve. Note that Pandoc
removes leading numbers for sections, so the following would be valid:

```
# 1.1 Good Example

This is a link to the [Good Example](#good-example)
```

But this would fail:
```
# 1.1 Broken Example

This is a link to the [broken example](#1.1-broken-example)
```

### `draft`

Add a "DRAFT" watermark to the resulting document. Default: `"false"`

This is currently only supported for PDF outputs.

## Example usage

uses: cabforum/build-guidelines-action@v1
with:
  markdown-file: docs/BR.md
  draft: true
  lint: true
