# STAT778 Project — Robustness of `gcKrig` for Spatial Count Data

A simulation study reproducing Kazianka (2013) and extending it to
test the robustness of `gcKrig` under realistic violations:
misspecification of the marginal family, random missingness,
zero-inflation, and irregular spatial sampling designs.

The accompanying report (`report.pdf`) summarizes findings; this
document describes how to reproduce them from source.

---

## Quick reproduction

If you only want to reproduce the report's results and don't need
the full background, this is the short version.

```bash
# 1. Clone and enter the project
git clone <repo-url> STAT778_Project
cd STAT778_Project

# 2. Activate the R environment (renv)
module load gnu10           # adjust per your HPC site
module load r/4.3.1-gnu-openblas
R -e 'renv::restore()'      # see "Environment setup" below if this fails

# 3. Run all simulations and fits via Slurm
#    (each line below is independent; submit them in order; later
#    fitting jobs depend on earlier generation jobs)
sbatch code/slurm/01_gen_h18b.slurm
sbatch code/slurm/02_gen_k13a.slurm   ; sbatch code/slurm/10_fit_k13a.slurm
sbatch code/slurm/03_gen_misspec.slurm; sbatch code/slurm/11_fit_misspec.slurm
sbatch code/slurm/04_gen_k13a_grid.slurm; sbatch code/slurm/12_fit_k13a_grid.slurm
sbatch code/slurm/05_gen_missing.slurm; sbatch code/slurm/13_fit_missing.slurm
sbatch code/slurm/06_gen_zip.slurm    ; sbatch code/slurm/14_fit_zip.slurm
sbatch code/slurm/07_gen_irregular.slurm; sbatch code/slurm/15_fit_irregular.slurm

# 4. After Slurm jobs complete, render analysis Rmds for tables and figures
Rscript -e 'rmarkdown::render("k13a_grid_analysis.Rmd")'
Rscript -e 'rmarkdown::render("misspec_analysis.Rmd")'
Rscript -e 'rmarkdown::render("missing_analysis.Rmd")'
Rscript -e 'rmarkdown::render("zip_analysis.Rmd")'
Rscript -e 'rmarkdown::render("irregular_analysis.Rmd")'
```

Total wall time end-to-end: roughly 4-6 hours on Hopper, dominated
by `12_fit_k13a_grid.slurm`.

---

## Repository layout

```
STAT778_Project/
├── README.md                      ← you are here
├── analysis_00_main.pdf           ← knitted main analysis code (contains materials in report)
├── analysis_00_main.rmd           ← main analysis code (contains materials in report)
│
├── renv.lock                      ← active environment lockfile
├── renv.lock.r4.1.backup          ← historical (see Environment setup)
├── renv.lock.original.backup      ← historical (see Environment setup)
├── renv/                          ← package library (auto-managed)
├── .Rprofile                      ← activates renv on R startup
│
├── code/
│   ├── R/                         ← shared library, dataset-agnostic
│   │   ├── logging.R              # log_info/log_warn/log_debug
│   │   ├── grids.R                # make_locations() with 3 layouts
│   │   ├── spec_utils.R           # merge_spec()
│   │   ├── sim_core.R             # scenario schema + simulator
│   │   ├── io.R                   # save/load_scenario, list_scenarios
│   │   ├── fit_core.R             # fit_scenario, fit-result schema
│   │   ├── missingness.R          # apply_mcar()
│   │   └── plot_helpers.R         # save_base_plot()
│   │
│   ├── configs/                   ← one config per dataset family
│   │   ├── h18b.R
│   │   ├── k13a.R                 # K13-A pilot (single cell)
│   │   ├── k13a_grid.R            # K13-A grid (18 cells)
│   │   ├── misspec.R              # 2×2 misspecification
│   │   ├── missing.R              # 5 MCAR rates
│   │   ├── zip.R                  # 3 zero-inflation levels
│   │   └── irregular.R            # 3 layouts
│   │
│   ├── scripts/                   ← per-dataset gen and fit scripts
│   │   ├── 01_gen_h18b.R
│   │   ├── 02_gen_k13a.R       │  10_fit_k13a.R
│   │   ├── 03_gen_misspec.R    │  11_fit_misspec.R
│   │   ├── 04_gen_k13a_grid.R  │  12_fit_k13a_grid.R
│   │   ├── 05_gen_missing.R    │  13_fit_missing.R
│   │   ├── 06_gen_zip.R        │  14_fit_zip.R
│   │   └── 07_gen_irregular.R  │  15_fit_irregular.R
│   │
│   └── slurm/                     ← Slurm submission wrappers
│       ├── _env.sh                # shared environment setup
│       └── *.slurm                # one per script above
│
├── data/                          ← outputs (not committed)
│   ├── generated/                 # simulated scenarios (.rds)
│   └── fits/                      # fit results (.rds)
│
├── logs/                          ← Slurm stdout/stderr (not committed)
│
├── visualization/                 ← saved plots (not committed)
│   ├── example/                   # H18-B exploratory figures
│   ├── k13a_grid/                 # report figures from K13A-GRID
│   ├── missing/                   # report figures from MISSING
│   └── ...
│
├── analysis_01_k13a_grid.Rmd        ← analysis Rmd for K13A-GRID baseline (see below)
├── analysis_02_misspec.Rmd          ← analysis Rmd for marginal misspecification
├── analysis_03_missing.Rmd          ← analysis Rmd for MCAR missingness
├── analysis_04_irregular.Rmd        ← analysis Rmd for irregular spatial layouts
├── analysis_05_zip.Rmd              ← analysis Rmd for zero-inflation study
│
├── exploratory_analysis.Rmd         ← exploratory analysis mostly for understanding gcKrig and Kazianka (2013)
├── pipeline_debugging.Rmd           ← debugging notes for the simulation pipeline
├── pipeline_readme.Rmd              ← pipeline overview / how to run the project
├── project_log.Rmd                  ← development log
│
├── walkthrough_00_codebase.Rmd      ← codebase walkthrough (see below)
├── walkthrough_001_h18b.Rmd         ← H18B walkthrough
├── walkthrough_01_k13a.Rmd          ← K13A walkthrough
├── walkthrough_02_misspec.Rmd       ← misspecification walkthrough
├── walkthrough_03_missing.Rmd       ← missingness walkthrough
└── walkthrough_04_05_zip_irregular.Rmd ← ZIP and irregular-layout walkthrough

---

## What the Rmd files do

The repository has many Rmds. They serve three different purposes,
which matter for what you should actually run.

### Analysis Rmds — the report's source of truth

These read fit-result `.rds` files from `data/fits/` and produce the
tables and figures referenced in the report. **These are the Rmds
you must render to reproduce report results.**

| File | Generates the results referenced in |
|------|-------------------------------------|
| `k13a_grid_analysis.Rmd` | Section 3.1 (reproduction) |
| `misspec_analysis.Rmd` | Section 3.2 (misspecification) |
| `missing_analysis.Rmd` | Section 3.3 (missingness) |
| `zip_analysis.Rmd` | Section 3.4 (zero-inflation) |
| `irregular_analysis.Rmd` | Section 3.5 (irregular sampling) |

Each Rmd is self-contained in the sense that it only requires the
relevant fit results to exist on disk; rendering one does not depend
on the others.

Note that analysis_00_main.Rmd is for only creating the materials used in 
presentation and report, not an all-in-one container.

### Walkthrough Rmds — pedagogical, optional to render

These show the pipeline interactively for a specific dataset
(generation → smoke-test fit → inspection). They were used during
development for debugging and are kept for transparency. **You do
not need to render these to reproduce the report.** They are useful
if you want to understand how a specific dataset was generated or
fit, or if you are extending the project.

| File | What it walks through |
|------|----------------------|
| `h18b_example.Rmd` | The H18-B pipeline smoke test (only generation; no fit) |
| `k13a_walkthrough.Rmd` | K13-A pilot generation, smoke fit, inspection |
| `missing_walkthrough.Rmd` | MCAR masking applied to K13-A baseline, including a side-by-side comparison of masked vs unmasked fits |
| `codebase_walkthrough.Rmd` | A tour of the scenario schema, fit-result schema, and config conventions used throughout `code/R/` and `code/configs/` |

### Other Rmds

| File | Purpose |
|------|---------|
| `project_log.Rmd` | Development log: what was built, what broke, lessons learned. Read this if you want a chronological account of the project. |

---

## Environment setup

The project uses `renv` for package version management. There were
some friction during initial setup that's worth documenting, hence
the multiple `renv.lock` files in the repository.

### The three lockfiles

The repository ships with three lockfiles. **Only `renv.lock`
matters for reproduction.** The other two are kept as a record:

| File | Status | What it is |
|------|--------|-----------|
| `renv.lock` | **active** — use this | Pins the package versions actually used to produce the current report. R 4.3.1, gcKrig 1.1.8 (or whichever version your `renv::snapshot()` recorded). |
| `renv.lock.r4.1.backup` | inactive (historical) | The original lockfile, which pinned R 4.1.1 and an older gcKrig. Could not be restored on the current Hopper R modules; replaced by the active lockfile. |
| `renv.lock.original.backup` | inactive (historical) | An even earlier snapshot, kept for full transparency. |

These backups are not needed to reproduce results and can be ignored
for that purpose. They exist because the project hit a real
reproducibility hazard worth documenting: see "Why three lockfiles"
below.

### How to activate the environment

On a fresh checkout, on a system with R 4.3.x available:

```bash
cd STAT778_Project

# Load R via your HPC modules. On GMU Hopper:
module purge
module load gnu10
module load r/4.3.1-gnu-openblas

# Restore packages from renv.lock. Takes 30-60 minutes the first time
# because gcKrig and several dependencies are compiled from source.
R -e 'renv::restore()'
```

When R is started in this directory, `.Rprofile` automatically
activates renv, so `library(gcKrig)` will resolve to the project's
private library at `renv/library/R-4.3/...`.

Verify the environment:

```bash
R -e 'library(gcKrig); cat("gcKrig", as.character(packageVersion("gcKrig")), "OK\n")'
```

### Why three lockfiles

The original lockfile pinned R 4.1.1 with package versions snapshot
from late 2021. By the time we tried to restore it, `Rcpp 1.1.1`
had been archived out of the RStudio Package Manager — the URL
returned a 404. `renv::restore()` could not recover the original
environment.

We resolved this pragmatically: deleted the broken lockfile (saved
as `renv.lock.r4.1.backup`), installed `gcKrig` and dependencies
fresh under R 4.3.1 from current CRAN, then ran `renv::snapshot()`
to record the new environment as `renv.lock`. The backup is kept so
that the historical record is complete and so future readers can
see the kind of pinning-decay problem that affects long-lived
projects.

`gcmr`, listed as a dependency of the original `renv.lock`, was
dropped during this process: its dependency chain
(`MatrixModels` → `quantreg` → `car` → `gcmr`) hit a missing
system library on Hopper that we did not resolve. `gcmr` was only
used in Han and De Oliveira (2018) Section 4.4 for a package
benchmark comparison, which is not central to this project's
robustness thesis. The report cites Han's published benchmark
numbers rather than reproducing them.

### If `renv::restore()` fails

The most common failure modes:

- **Network blocked.** `renv::restore()` needs to reach CRAN at
  install time. On Hopper, run it on a login node, not a compute
  node.
- **System dependency missing.** Some packages compile against
  system libraries (BLAS, etc.). `module load gnu10` on Hopper
  pulls in the toolchain we used; on other systems install
  equivalents (a working C++ compiler, OpenBLAS or MKL).
- **Specific package URLs gone stale.** If a pinned version 404s
  the way `Rcpp 1.1.1` did for us, the recovery path is the same
  one we took: install the missing package fresh
  (`install.packages("PKG_NAME")`), then `renv::snapshot()` to
  update the lockfile.

---

## Reproducing report results

### Stage 1: simulations and fits

Each scenario in the project has a generation script (creates
`.rds` files in `data/generated/`) and, if applicable, a fitting
script (creates `.rds` files in `data/fits/`). All are launched
via Slurm wrappers in `code/slurm/`.

Run the generation jobs first (cheap; minutes total). Then run the
fitting jobs (varies; the largest is `fit_k13a_grid` at
~0.5 hours).

```bash
cd ~/STAT778_Project

# Phase 1: warm-up + Kazianka reproduction baseline
sbatch code/slurm/01_gen_h18b.slurm
sbatch code/slurm/02_gen_k13a.slurm
# Wait for completion, then:
sbatch code/slurm/10_fit_k13a.slurm

# Phase 2: K13-A grid (the headline reproduction)
sbatch code/slurm/04_gen_k13a_grid.slurm
# Wait, then:
sbatch code/slurm/12_fit_k13a_grid.slurm

# Phase 3: extensions
sbatch code/slurm/03_gen_misspec.slurm
sbatch code/slurm/05_gen_missing.slurm
sbatch code/slurm/06_gen_zip.slurm
sbatch code/slurm/07_gen_irregular.slurm
# Wait for all four to finish, then:
sbatch code/slurm/11_fit_misspec.slurm
sbatch code/slurm/13_fit_missing.slurm
sbatch code/slurm/14_fit_zip.slurm
sbatch code/slurm/15_fit_irregular.slurm
```

Monitor with `squeue -u $USER`. Logs land in `logs/<jobname>-<jobid>.out`.

### Stage 2: rendering analysis

After all Slurm jobs complete, render the analysis Rmds. These
read the `.rds` files and produce HTML reports (and the figures
saved to `visualization/`):

```bash
cd ~/STAT778_Project
Rscript -e 'rmarkdown::render("k13a_grid_analysis.Rmd")'
Rscript -e 'rmarkdown::render("misspec_analysis.Rmd")'
Rscript -e 'rmarkdown::render("missing_analysis.Rmd")'
Rscript -e 'rmarkdown::render("zip_analysis.Rmd")'
Rscript -e 'rmarkdown::render("irregular_analysis.Rmd")'
```

Each Rmd produces an `.html` with the tables, figures, and summary
statistics referenced by the corresponding section of the report.

### Stage 3: rebuilding the report PDF

```bash
pdflatex report.tex
bibtex report
pdflatex report.tex
pdflatex report.tex
```

The above files are not contained in the repository

The figures referenced by `report.tex` come from `visualization/`,
which is populated by Stage 2. Tables are partially generated from
the analysis Rmds; numbers in prose were transcribed manually and
are documented as such in `project_log.Rmd`.

---

## Running interactively (no Slurm)

For development or curiosity, every Slurm script just runs an
ordinary `Rscript` command. You can run the same R scripts by hand:

```bash
cd ~/STAT778_Project

# Direct equivalent of `sbatch 02_gen_k13a.slurm`:
Rscript code/scripts/02_gen_k13a.R

# Direct equivalent of `sbatch 10_fit_k13a.slurm`:
Rscript code/scripts/10_fit_k13a.R
```

For interactive exploration in RStudio, open any of the walkthrough
Rmds and step through chunks. They are self-contained (each sources
the libraries it needs) and produce informative output even without
running on Slurm.

---

## Project structure conventions

For someone reading the code or extending it, three conventions
will make navigation easier.

### Two-level naming

Every dataset has a `dataset_id` (the family — "K13-A", "MISSPEC",
"ZIP") and a `scenario_id` (the cell within the family —
"default", "pois_pilot", "p0_20"). On disk, every output is
`data/<generated|fits>/<dataset_id>/<scenario_id>.rds`.

### Three-part pipeline per dataset

Each new dataset follows the same template:

1. `code/configs/<name>.R` — defines the scenarios.
2. `code/scripts/<NN>_gen_<name>.R` — generates them.
3. `code/scripts/<NN>_fit_<name>.R` — fits them (where applicable).
4. (Optional) An analysis Rmd at the repo root.

The `code/R/` library is shared and dataset-agnostic.

### Scenario object schema

Every saved scenario `.rds` is a 14-field list with the same shape.
See `codebase_walkthrough.Rmd` for the full field list. The most
important fields are `$values` (the simulated data, `n × sim_n`
matrix), `$locations` (the spatial grid, `n × 2` matrix), and
`$config` (the full input spec, verbatim, for reproducibility
audits).

### Fit-result object schema

Every fit-result `.rds` parallels the scenario schema. Key fields:
`$results` (a long data frame keyed by replicate × method),
`$scenario_config` (the generating spec), `$fit_marginal_spec`
(what was actually fit, may differ from generating for
misspecification studies), `$misspecified` (TRUE/FALSE flag).

---

## References

- Han, Z. and De Oliveira, V. (2018). On the correlation structure
  of Gaussian copula models for geostatistical count data.
  *Australian & New Zealand Journal of Statistics*, 58(1), 47-69.
- Kazianka, H. (2013). Approximate copula-based estimation and
  prediction of discrete spatial data. *Stochastic Environmental
  Research and Risk Assessment*, 27(8), 2015-2026.
- Kazianka, H. and Pilz, J. (2010). Copula-based geostatistical
  modeling of continuous and discrete data including covariates.
  *Stochastic Environmental Research and Risk Assessment*, 24(5),
  661-673.