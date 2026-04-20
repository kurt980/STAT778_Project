# STAT778 Project

Simulation study of Gaussian-copula spatial models for geostatistical
count data using the `gcKrig` package. Based on Han and De Oliveira
(2018) and Kazianka (2013).

## Repository structure

```
STAT778_Project/                   ← repo root; run everything from here
├── README.md
├── .gitignore
├── h18b_example.Rmd                ← interactive example, level-1
│
├── code/                           ← all source code lives under here
│   ├── R/                          ← shared library
│   │   ├── logging.R               #   log_info / log_debug / log_warn
│   │   ├── grids.R                 #   make_locations()
│   │   ├── spec_utils.R            #   merge_spec() -- recursive merge
│   │   ├── sim_core.R              #   scenario schema + MC / fixed generators
│   │   └── io.R                    #   save_scenario / load_scenario
│   ├── configs/                    ← per-dataset configs
│   │   └── h18b.R
│   ├── scripts/                    ← per-dataset generation scripts (R)
│   │   └── 01_gen_h18b.R
│   └── slurm/                      ← Slurm submission scripts
│       ├── _env.sh
│       └── 01_gen_h18b.slurm
│
├── data/generated/                 ← simulation outputs (.rds)
└── logs/                           ← Slurm stdout/stderr logs
```

All commands below assume you are sitting in the repo root
(`~/STAT778_Project/`).

## Prerequisites

- R >= 4.0
- R package `gcKrig`:

```bash
module load r     # adjust for your Hopper site
R -e 'install.packages("gcKrig", repos = "https://cloud.r-project.org")'
```

## Running interactively

```bash
cd ~/STAT778_Project
Rscript code/scripts/01_gen_h18b.R
```

Inside R or an Rmd:

```r
setwd("~/STAT778_Project")
source("code/scripts/01_gen_h18b.R")
```

To generate only specific scenarios:

```bash
Rscript code/scripts/01_gen_h18b.R default
Rscript code/scripts/01_gen_h18b.R range_0.5 range_0.7
```

## Running under Slurm

First-time setup: edit `code/slurm/_env.sh` to load the R module
available on your Hopper account.

Submit (from the repo root):

```bash
cd ~/STAT778_Project
sbatch code/slurm/01_gen_h18b.slurm
```

Only specific scenarios:

```bash
sbatch --export=ALL,SCENARIO_IDS="default range_0.5" code/slurm/01_gen_h18b.slurm
```

Monitor:

```bash
squeue -u $USER
tail -f logs/gen_h18b-<jobid>.out
```

## Running the Rmd example

Open `h18b_example.Rmd` in RStudio and click Knit. It lives at the
repo root, so the working directory is already correct.

## Scenario object schema

Every `.rds` written by the pipeline has the same structure:

| field                     | content                                        |
|---------------------------|------------------------------------------------|
| `dataset_id`              | e.g. `"H18-B"`                                 |
| `scenario_id`             | e.g. `"default"`                               |
| `config`                  | full input spec, verbatim                      |
| `locations`               | n x 2 numeric matrix                           |
| `values`                  | n x B numeric matrix (B = sim_n)               |
| `values_full`             | NULL (populated if missingness added later)    |
| `true_params`             | flat named list of generating parameters       |
| `seed_info`               | list: scheme / seed / sim_n                    |
| `created_at`              | POSIXct                                        |
| `r_version`               | from `R.version.string`                        |
| `gcKrig_version`          | package version at generation time             |
| `coord_transform_applied` | logical                                        |
| `missingness_spec`        | NULL (extension hook)                          |
| `contamination_spec`      | NULL (extension hook)                          |

Load any scenario:

```r
setwd("~/STAT778_Project")
source("code/R/logging.R")
source("code/R/io.R")
s <- load_scenario("H18-B", "default")
```

## Adding new datasets

Each dataset follows the same three-file pattern:

1. `code/configs/<dataset>.R` -- builder + `<DATASET>_SCENARIOS`.
2. `code/scripts/<NN>_gen_<dataset>.R` -- iterate scenarios.
3. `code/slurm/<NN>_gen_<dataset>.slurm` -- submission script.

The shared library under `code/R/` is dataset-agnostic.
