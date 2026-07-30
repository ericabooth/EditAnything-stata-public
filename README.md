# editanything

**One Stata command to quickly open *any* text file from your Stata command line in your Do-file Editor, Viewer, or OS default app — not just `.ado`.**

`editanything` is a drop-in upgrade to SSC's [`adoedit`](https://ideas.repec.org/c/boc/bocode/s457486.html). It searches the ado-path for the file you name (or goes to the exact file if path provided), opens it in the Do-file Editor by default (or view in the smcl viewer), and adds a stack of useful options for everything else you'd want to do with a text file from inside Stata.

```stata
editanything regress.ado                  // edit a system ado (safely)
editanything documentation.html           // edit a html or css file (safely)
editanything regress.sthlp, view          // read only a help file in the Viewer
editanything README.md                    // edit Markdown from the editor
editanything analysis.py                  // ...or Python, R, CSV, JSON, ...
editanything new_helper, new              // start a brand-new .ado
editanything mymodel.do, clipboard        // copy file contents to clipboard
editanything ttest, replace               // clone a base ado into PERSONAL
editanything report.pdf, external         // hand off to the OS default app
```

---

## Why you'd reach for this

- **It's not just `.ado`.** `.sthlp`, `.hlp`, `.smcl`, `.do`, `.mata`, `.md`, `.html`, `.tex`, `.csv`, `.tsv`, `.txt`, `.raw`, `.log`, `.R`, `.py`, `.json`, `.yaml`, `.toml`, `.ini`, `.sql`, `.sh`, `.bat`, ... all open the same way.
- **It finds the file.** Searches the current directory, the full Stata ado-path, and `PERSONAL` — so `editanything regress` just works without you knowing where it lives.
- **It won't clobber Stata.** Refuses to edit `/ado/base/` and `/ado/updates/` files in place. Use `replace` to clone the file into `PERSONAL` first; your edits survive Stata updates.
- **Right tool for the job.**
  - `editor` (default) — open in the Do-file Editor.
  - `view` — render `.sthlp`/`.smcl` in the Viewer; show other text as-is.
  - `external` — let the OS open it (BBEdit, VS Code, Notepad++, Preview, Excel, ...).
  - `showpath` — return the clickable path without opening anything.
  - `clipboard` — copy the file's contents to the system clipboard.
- **`new`-as-an-option** spins up an empty file and opens it.
- **Returns the path** in `r(file)` for scripting.

---

## Install

```stata
net install editanything, from("https://raw.githubusercontent.com/ericabooth/EditAnything-stata-public/main/") replace force
help editanything
```

Or drop `editanything.ado` and `editanything.sthlp` anywhere on your Stata `adopath` (e.g. `c(sysdir_personal)`).

Requires Stata 14+.

<img width="2400" height="1260" alt="editanything" src="https://github.com/user-attachments/assets/7bf517a8-1f1e-4248-b943-c9ded3a7c758" />

---

## Quick examples

### Edit any ado on your path

```stata
editanything regress           // finds regress.ado on the ado-path
editanything outreg2.ado
```

### Render a help file instead of editing it

```stata
editanything regress.sthlp, view
```

`view` renders SMCL for `.sthlp`, `.hlp`, and `.smcl` files; everything else is shown as raw text via `view ..., asis`.

### Open a Python / R / Markdown file from Stata

```stata
editanything pipeline.py
editanything cleanup.R
editanything project_notes.md
editanything config/settings.toml
```

### Peek at a (not large) CSV file without `import delimited`-ing it

```stata
editanything raw/survey_responses.csv, view
```

### Safely customize a Stata-supplied ado (wrapper or alternative to -adoedit- from SSC)

```stata
editanything ttest, replace
```

That copies `…/ado/base/t/ttest.ado` into your `PERSONAL` directory and opens **the copy** — Stata updates won't overwrite your changes.

### Start a brand-new file

```stata
editanything new_helper, new                 // creates new_helper.ado in cwd
editanything project_notes, new ext(md)      // creates project_notes.md
```

### Hand a large file off to your OS editor

```stata
editanything massive_analysis.log, external
editanything quarterly_report.pdf, external
editanything roster.xlsx, external
```

### Use the path in a script

```stata
editanything regress, showpath
local path "`r(file)'"
display "regress.ado lives at: `path'"
```

### Copy a snippet to the clipboard

```stata
editanything mymodel.do, clipboard
```

Uses `pbcopy` on macOS, `clip` on Windows, `xclip` on Linux.

---

## Options at a glance

| Option | What it does |
| --- | --- |
| `editor` | Open in the Do-file Editor *(default)* |
| `view` | Open read-only in the Viewer (renders SMCL for `.sthlp`/`.hlp`/`.smcl`) |
| `external` | Hand off to the OS default application |
| `showpath` | Print a clickable path; do not open anything |
| `clipboard` | Copy contents to the system clipboard |
| `extension(str)` | Default extension to try when filename has none (default `ado`) |
| `personal` | Search `c(sysdir_personal)` first |
| `new` | Create a brand-new empty file at `filename`, then open it |
| `replace` | Clone a `base/`/`updates/` ado into PERSONAL, then open the copy |
| `force` | Skip the base-file and 32 KB size guardrails |
| `quietly` | Suppress the file-info banner |

Full reference: `help editanything` after install.

---

## Returns

| Return | What it is |
| --- | --- |
| `r(file)` | Fully-resolved file path |
| `r(basename)` | Filename portion only |
| `r(extension)` | Detected extension (lowercased, no dot) |
| `r(size)` | File size in bytes (when detectable) |

---

## Behavior notes

- **Resolution order.** `personal` (if set) → cwd / given path → `findfile` (full ado-path) → default-extension fallback → PERSONAL fallback. The first hit wins.
- **Extension fallbacks.** With the default `extension(ado)`, if `editanything foo` doesn't find `foo` or `foo.ado`, it also tries `foo.sthlp`, `foo.hlp`, then `foo.do`.
- **Size guard.** The Do-file Editor can't open files >32 KB on Stata < 11. On modern Stata there is no hard limit, but very large files are slow — `external` is usually the right call.
- **Stata-supplied files.** Anything under `/ado/base/` or `/ado/updates/` is refused unless you pass `replace` (recommended) or `force`. The Viewer (`view`) and clipboard/external modes always work — they don't modify the file.
- **Mutually-exclusive open modes.** Only one of `editor`, `view`, `external`, `showpath`, `clipboard` may be specified.

---
## Installation from Github notes

```stata
net install editanything, from("https://raw.githubusercontent.com/ericabooth/EditAnything-stata-public/main/") replace force
help editanything
```

One-liner version:

```stata
net install editanything, from("https://raw.githubusercontent.com/ericabooth/EditAnything-stata-public/main/") replace force
help editanything
```

To confirm it landed and try it:

```stata
which editanything
help editanything
editanything regress, showpath
```

To uninstall / reinstall a newer version later:

```stata
ado uninstall editanything
net install editanything, from("https://raw.githubusercontent.com/ericabooth/EditAnything-stata-public/main/") replace
```

---

## Authors

Eric A. Booth · Sr Researcher, Texas 2036 · [eric.a.booth@gmail.com](mailto:eric.a.booth@gmail.com) · [@ericabooth](https://github.com/ericabooth)

Elizabeth Teas · Sr Research Scientist, Far Harbor, LLC ·
[elizabeth@farharbor.com](mailto:elizabeth@farharbor.com) · 

--

Issues and PRs welcome.
