# BUMIDAS for Stata

Stata commands for Bottom-Up Mixed-Frequency Data Sampling.

This repository provides two commands:

- **`bumidas`** — estimates and selects direct Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS) regressions.
- **`mfcollapse`** — converts higher-frequency data to a lower-frequency dataset while preserving the high-frequency information needed for mixed-frequency modeling.

The repository also includes help files, reproducible examples, certification tests, a foreign-exchange application, and a representative simulation comparing BUMIDAS with conventional MIDAS approaches.

## Overview

Forecasts are often constructed for temporally aggregated variables—such as monthly averages or quarterly sums—even when higher-frequency information is available.

`mfcollapse` and `bumidas` provide a Stata workflow for constructing and estimating bottom-up mixed-frequency models using that information.

A typical workflow is:

```text
higher-frequency data
        |
        v
   mfcollapse
        |
        v
economic transformations
        |
        v
     bumidas
        |
        v
prediction / forecast evaluation
```

`mfcollapse` handles the data-construction step.

`bumidas` handles estimation and model selection.

The commands are designed to work together, but either may also be used separately.

---

## Commands

### `mfcollapse`

`mfcollapse` converts higher-frequency observations into a lower-frequency dataset while retaining the latest high-frequency observation, earlier high-frequency observations, and the within-period average.

For example:

```stata
mfcollapse wti, ///
    date(date) ///
    frequency(monthly) ///
    ar(1)
```

may generate variables such as

```text
wti_ld0
wti_ld1
...
wti_ld20
wti_ave
```

where `wti_ld0` is the most recent available higher-frequency observation in the lower-frequency period.

Supported frequency conversions are:

```text
daily   -> weekly
daily   -> monthly
daily   -> quarterly
weekly  -> monthly
weekly  -> quarterly
monthly -> quarterly
```

See:

```stata
help mfcollapse
```

for full documentation.

### `bumidas`

`bumidas` estimates direct Bottom-Up Mixed-Frequency Data Sampling regressions using preconstructed high-frequency lag blocks and optional low-frequency regressors.

A basic specification is:

```stata
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(20) ///
    search(full) ///
    ic(bic)
```

The command supports:

- exhaustive information-criterion selection;
- recursive forward block-order selection;
- fixed-order estimation;
- multiple required and optional high-frequency blocks;
- low-frequency target lags;
- low-frequency predictor lags;
- AIC, HQIC, and BIC;
- arbitrary direct forecast horizons;
- fixed controls;
- prediction and residuals.

See:

```stata
help bumidas
```

for full documentation.

---

## Installation

### GitHub

The package can be installed directly from GitHub:

```stata
net install bumidas, ///
    from("https://raw.githubusercontent.com/SSEconomics/bumidas-stata/main") ///
    replace
```

```stata
which mfcollapse
which bumidas

help mfcollapse
help bumidas
```

Repository:

https://github.com/SSEconomics/bumidas-stata

### Manual installation

Alternatively, copy the following files to a directory on your Stata ado-path:

```text
mfcollapse.ado
mfcollapse.sthlp
bumidas.ado
bumidas_p.ado
bumidas.sthlp
```

You can view your personal ado directory using:

```stata
sysdir
```

---

## Quick start

Suppose higher-frequency data have already been converted to the target frequency using `mfcollapse`, producing variables such as

```text
target_ld0 target_ld1 ...
oil_ld0    oil_ld1    ...
```

After creating the desired transformations, suppose the resulting mixed-frequency blocks are

```text
hfy0 hfy1 hfy2 ...
hfx0 hfx1 hfx2 ...
```

Estimate BUMIDAS using:

```stata
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(20) ///
    search(full) ///
    ic(bic) ///
    noconstant
```

Typical output is:

```text
Bottom-Up MIDAS regression
----------------------------
Forecast horizon =      1
Selection        = BIC, full
Observations     =      ...
Models evaluated =      ...

Selected orders
  Required HF (hfy)     2
  Optional HF (hfx)     0

BIC = ...
```

The final selected regression remains active as a standard Stata estimation result.

For the full coefficient table:

```stata
bumidas, regression
```

To generate fitted values:

```stata
predict double yhat
```

or residuals:

```stata
predict double uhat, residuals
```

---

## High-frequency block notation

`bumidas` identifies high-frequency information using variable-name stubs.

For example:

```text
hfy0 hfy1 hfy2 hfy3
```

defines the stub

```text
hfy
```

An order indicates the number of included high-frequency terms:

```text
order 0 = omitted
order 1 = hfy0
order 2 = hfy0 hfy1
order 3 = hfy0 hfy1 hfy2
```

Thus, an order of 3 means three terms are included; it does not mean the largest suffix is 3.

### Required HF blocks

Blocks listed in `hftarget()` must have order at least 1.

For example:

```stata
hftarget(hfy oil)
```

requires both `hfy0` and `oil0` to appear in every candidate model.

Despite the option name, a block in `hftarget()` does not have to literally represent the forecast target. It may be any high-frequency block whose most recent observation should always be included.

### Optional HF blocks

Blocks listed in `hfpredictors()` may have order 0 and therefore may be excluded.

For example:

```stata
hfpredictors(oil rates)
```

allows either block to be omitted if doing so improves the selected information criterion.

---

## Model selection

### Full grid search

The default is:

```stata
search(full)
```

which evaluates every admissible combination of block orders.

For example, one required HF block with orders 1 through 20 and one optional HF block with orders 0 through 20 produces

```text
20 x 21 = 420
```

candidate models.

Full search identifies the global minimum of the specified information criterion over the admissible grid.

### Recursive search

For larger model spaces:

```stata
search(recursive)
```

uses a forward block-order search.

The procedure:

1. starts from the minimum admissible model;
2. increases one block order by one;
3. evaluates all one-step expansions;
4. accepts the expansion with the lowest information criterion if it improves on the current model;
5. repeats until no further improvement is available.

For example:

```stata
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(oil rates commodity) ///
    hfmax(20) ///
    search(recursive) ///
    ic(bic) ///
    trace
```

`trace` displays the accepted search path.

Recursive search is typically much faster than a large full grid, but because it is a greedy forward procedure it does not necessarily find the global information-criterion minimum.

### Fixed orders

To estimate a prespecified model:

```stata
search(none)
```

For example:

```stata
bumidas y, ///
    hftarget(hfy oil) ///
    hfpredictors(rates) ///
    hforders(3 1 0) ///
    search(none)
```

sets:

```text
hfy   = order 3
oil   = order 1
rates = order 0
```

Required HF blocks are listed first in `hforders()`, followed by optional HF blocks.

---

## Low-frequency regressors

Low-frequency target lags can be selected using:

```stata
lfymax(3)
```

which allows target orders:

```text
0, 1, 2, 3
```

Additional low-frequency predictors can be specified using:

```stata
lfpredictors(x1 x2) ///
lfxmax(3)
```

Each LF predictor receives its own independently selected order.

For example:

```stata
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(20) ///
    lfymax(3) ///
    lfpredictors(x1 x2) ///
    lfxmax(3) ///
    search(recursive)
```

---

## Direct forecast horizons

`bumidas` estimates direct forecast regressions.

The default is:

```stata
horizon(1)
```

For a three-period-ahead regression:

```stata
horizon(3)
```

the selected high-frequency variables are shifted automatically.

For example, HF order 2 becomes:

```text
L3.hfy0
L3.hfy1
```

and LF predictor order 2 becomes:

```text
L3.x
L4.x
```

Horizon-zero nowcasting is not currently implemented.

---

## Common estimation sample

All candidate models within a search are estimated on the same sample.

`bumidas` first determines the estimation sample using the largest admissible candidate model and then holds that sample fixed during model selection.

This ensures that AIC, HQIC, and BIC are comparable across candidate models within a search.

A consequence is that changing the search space can change the common sample.

For example, changing

```stata
lfxmax(3)
```

to

```stata
lfxmax(4)
```

may reduce the estimation sample even if the same final order is selected.

Information-criterion values from different searches therefore should not generally be compared unless their estimation samples are identical.

---

## Information criteria

The default criterion is:

```stata
ic(bic)
```

The following are available:

```text
AIC
HQIC
BIC
```

with:

```text
AIC  = -2 ll + 2k

HQIC = -2 ll + 2 ln(ln(N)) k

BIC  = -2 ll + ln(N) k
```

where `ll` is the regression log likelihood, `k` is the estimated rank, and `N` is the common-sample number of observations.

---

## Controls

Variables specified in

```stata
controls()
```

are included in every candidate model.

For example:

```stata
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(20) ///
    controls(L.inflation i.month) ///
    search(full)
```

Controls are included exactly as supplied.

They are not automatically shifted by `horizon()`.

---

## Examples

Self-contained examples are included in:

```text
examples/
```

### `mfcollapse_example.do`

Demonstrates:

- higher- to lower-frequency conversion;
- automatic inference of the average number of HF observations per LF period;
- generated high-frequency lag variables;
- multiple input variables;
- explicit lag selection.

### `bumidas_example.do`

Demonstrates:

- BUMIDAS-BIC;
- required and optional HF blocks;
- multiple required HF blocks;
- recursive search;
- low-frequency regressors;
- alternative information criteria;
- multi-step direct forecasting;
- fixed-order estimation;
- controls;
- prediction;
- replay.

Run from Stata using:

```stata
do examples/bumidas_example.do
```

---

## Empirical application

The repository includes a foreign-exchange application in:

```text
applications/fx/
```

The application illustrates the complete workflow using exchange rates and higher-frequency predictors:

```text
raw daily / weekly data
        |
        v
   mfcollapse
        |
        v
transformations
        |
        v
BUMIDAS estimation
        |
        v
benchmark models
        |
        v
forecast comparison
```

The application is intended as a substantive demonstration rather than a minimal command example.

See:

```text
applications/fx/README.md
```

for data sources and replication instructions.

---

## Simulation

A representative simulation is included in:

```text
simulations/
```

The simulation compares:

- BUMIDAS;
- BUMIDAS with information-criterion selection;
- unrestricted MIDAS (UMIDAS);
- restricted MIDAS (RMIDAS);
- a low-frequency benchmark.

UMIDAS and RMIDAS are implemented directly in the simulation code as benchmark models. They are not separate commands included in this package.

The simulation is intended to illustrate the forecasting implications of preserving high-frequency information rather than to reproduce every simulation reported in the associated research paper.

The complete research replication archive is separate from this software repository.

---

## Tests

Certification tests are included in:

```text
tests/
```

### `mfcollapse_test.do`

Tests the main data-construction functionality of `mfcollapse`.

### `bumidas_test.do`

Tests:

- exhaustive full-grid selection;
- agreement with a hand-coded BIC search;
- required and optional HF blocks;
- multiple HF blocks;
- models without required HF blocks;
- LF-only models;
- recursive search;
- AIC, HQIC, and BIC;
- fixed orders;
- direct forecast horizons;
- controls;
- prediction;
- replay;
- expected validation errors.

Run the tests using:

```stata
do tests/mfcollapse_test.do
do tests/bumidas_test.do
```

A successful `bumidas_test.do` ends with:

```text
All bumidas regression tests passed.
```

---

## Repository structure

```text
bumidas-stata/
│
├── README.md
├── LICENSE
├── CITATION.cff
├── CHANGELOG.md
├── .gitignore
├── stata.toc
├── bumidas.pkg
│
├── stata/
│   ├── mfcollapse.ado
│   ├── mfcollapse.sthlp
│   ├── bumidas.ado
│   ├── bumidas_p.ado
│   └── bumidas.sthlp
│
├── examples/
│   ├── mfcollapse_example.do
│   └── bumidas_example.do
│
└── tests/
    ├── mfcollapse_test.do
    └── bumidas_test.do
```

---

## Documentation

Detailed command documentation is available within Stata:

```stata
help mfcollapse
help bumidas
```

The `.sthlp` files document:

- syntax;
- all options;
- block-order definitions;
- search methods;
- common-sample construction;
- stored results;
- replay;
- prediction;
- examples.

---

## Stored results

`bumidas` is an e-class estimation command.

The final selected regression remains active and retains standard `regress` results such as:

```text
e(b)
e(V)
e(N)
e(ll)
e(rank)
e(sample)
```

Additional results include:

```text
e(horizon)
e(icvalue)
e(N_models)
e(N_common)
e(search)
e(ic)
e(rhs)
e(hftarget)
e(hfpredictors)
e(lfpredictors)
e(controls)
e(orders)
e(path)
```

For example:

```stata
matrix list e(orders)
```

may display:

```text
          HT_hfy  HP_hfx
selected       2       0
```

where:

```text
HT_ = required HF block
HP_ = optional HF block
LY_ = LF target block
LP_ = LF predictor block
```

For recursive search:

```stata
matrix list e(path)
```

shows the accepted model-selection path.

---

## Software status

The initial public release is:

```text
v0.1.1
```

The software should be regarded as an early public release.

The command interfaces are intended to remain stable, but minor improvements may be made following broader user testing.

See:

```text
CHANGELOG.md
```

for version history.

---

## Research background

The commands implement methods developed in:

> Lee, Quinlan and Snudden, Stephen, **“Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS)”**, April 1, 2025.

Available at SSRN:

https://ssrn.com/abstract=5312038

DOI:

https://doi.org/10.2139/ssrn.5312038

The central idea is that forecasts of temporally aggregated variables can exploit the underlying high-frequency information directly rather than first discarding that information through temporal aggregation.

`bumidas` provides a direct regression representation that can use:

- high-frequency observations of the target when available;
- high-frequency predictors;
- proxies for unavailable high-frequency states;
- low-frequency target and predictor information.

For the theoretical results, simulations, and empirical applications, see the BUMIDAS paper.

---

## Citation

If you use the Stata software, please cite the software repository.

### Software

Suggested citation:

```text
Snudden, Stephen. 2026.
BUMIDAS for Stata: Bottom-Up Mixed-Frequency Data Sampling commands.
Version 0.1.1.
https://github.com/SSEconomics/bumidas-stata
```

A machine-readable software citation is provided in:

```text
CITATION.cff
```

### Methodology

If you use the BUMIDAS methodology in academic work, please cite:

> Lee, Quinlan and Snudden, Stephen, **Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS)** (April 1, 2025). Available at SSRN: https://ssrn.com/abstract=5312038 or https://doi.org/10.2139/ssrn.5312038.

---

## Related research

The methodology implemented by `bumidas` is developed in:

Lee, Quinlan and Snudden, Stephen. 2025.  
**Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS).**  
Available at SSRN: https://ssrn.com/abstract=5312038  
DOI: https://doi.org/10.2139/ssrn.5312038

The full bibliography and methodological discussion are provided in the paper.

---

## Reproducibility

The examples and certification tests are designed to run independently of the authors' research environment.

Substantive applications may require external datasets.

Where redistribution of raw data is not appropriate, the relevant application directory will provide:

- original data sources;
- download instructions;
- data-construction code where feasible.

This software repository is distinct from the complete journal replication archive.

---

## Requirements

The current commands are written for:

```text
Stata 11 or later.
```

The commands require time-series data to be declared using:

```stata
tsset
```

Future testing may establish compatibility with earlier Stata versions.

---

## License

This project is licensed under the MIT License.

See:

```text
LICENSE
```

for details.

---

## Contributing and issues

Bug reports and reproducible examples are welcome through the GitHub issue tracker:

https://github.com/SSEconomics/bumidas-stata/issues

When reporting a problem, please include:

- the Stata version;
- the command used;
- the complete error message;
- a minimal reproducible example when possible.

For methodological questions, please consult:

```stata
help bumidas
help mfcollapse
```

and the BUMIDAS paper before opening an issue.

---

## Author

**Stephen Snudden**  
Department of Economics  
Wilfrid Laurier University

Website: https://stephensnudden.com

GitHub: https://github.com/SSEconomics

Repository: https://github.com/SSEconomics/bumidas-stata

YouTube: https://youtube.com/@ssnudden

---

## Acknowledgments

The BUMIDAS methodology was developed jointly with Quinlan Lee.

Additional acknowledgments for research assistance, conference feedback, or software testing can be added here as appropriate.

---

## Disclaimer

This software is provided for research and educational purposes under the terms of the MIT License. Users are responsible for verifying that the specifications, data transformations, and forecasting procedures are appropriate for their application.
