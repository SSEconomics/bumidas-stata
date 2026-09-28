# BUMIDAS for Stata

Stata commands for **Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS)**.

This repository provides tools for mixed-frequency forecasting and temporal aggregation in Stata, together with examples comparing BUMIDAS with conventional **MIDAS**, **UMIDAS (unrestricted MIDAS)**, and **RMIDAS (restricted MIDAS)** specifications.

The two main commands are:

- **`bumidas`** — estimates and selects direct Bottom-Up Mixed-Frequency Data Sampling regressions.
- **`mfcollapse`** — converts higher-frequency data to a lower-frequency dataset while preserving the high-frequency information needed for mixed-frequency modeling.

The repository also includes reproducible examples, certification tests, a foreign-exchange application, and a representative simulation.

**Keywords:** Stata, BUMIDAS, MIDAS, UMIDAS, RMIDAS, mixed-frequency data, mixed-data sampling, forecasting, temporal aggregation, time series.

---

## Overview

Forecasts are often constructed for temporally aggregated variables—such as monthly averages or quarterly sums—even when higher-frequency information is available.

`mfcollapse` and `bumidas` provide a workflow for preserving and using that information directly:

```text
higher-frequency data
        |
        v
data construction / transformation
        |
        v
   mfcollapse
        |
        v
optional further transformations
        |
        v
      bumidas
        |
        v
prediction / forecast evaluation
```

The exact ordering of economic transformations and `mfcollapse` is a modeling choice. Transformations may be applied either **before or after** `mfcollapse`; see [Data transformations](#data-transformations).

`mfcollapse` handles mixed-frequency data construction.

`bumidas` handles direct BUMIDAS estimation and model selection.

The commands are designed to work together, but either can also be used separately.

---

## Installation

Install directly from GitHub:

```stata
net install bumidas, ///
    from("https://raw.githubusercontent.com/SSEconomics/bumidas-stata/main") ///
    replace
```

Verify the installation:

```stata
which mfcollapse
which bumidas

help mfcollapse
help bumidas
```

Repository:

https://github.com/SSEconomics/bumidas-stata

### Manual installation

Alternatively, copy the files in `stata/` to a directory on your Stata ado-path.

Use

```stata
sysdir
```

to view Stata's ado directories.

---

## Quick start

Suppose daily or other higher-frequency data have been converted to the target frequency using `mfcollapse`, producing variables such as

```text
target_ld0 target_ld1 ...
oil_ld0    oil_ld1    ...
```

After applying the desired economic transformations, suppose the resulting mixed-frequency blocks are

```text
hfy0 hfy1 hfy2 ...
hfx0 hfx1 hfx2 ...
```

A BUMIDAS specification can then be estimated using:

```stata
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(20) ///
    search(full) ///
    ic(bic) ///
    noconstant
```

For the full coefficient table:

```stata
bumidas, regression
```

Predictions and residuals use standard Stata postestimation:

```stata
predict double yhat
predict double uhat, residuals
```

For complete syntax, options, model-selection rules, stored results, and additional examples, see:

```stata
help bumidas
```

---

## `mfcollapse`

`mfcollapse` converts higher-frequency observations into a lower-frequency dataset while retaining recent higher-frequency observations and the within-period average.

For example:

```stata
mfcollapse wti, ///
    date(date) ///
    frequency(monthly) ///
    ar(1)
```

may create

```text
wti_ld0
wti_ld1
...
wti_ld20
wti_ave
```

where `wti_ld0` is the most recent available higher-frequency observation in the lower-frequency period.

Supported conversions are:

```text
daily   -> weekly
daily   -> monthly
daily   -> quarterly
weekly  -> monthly
weekly  -> quarterly
monthly -> quarterly
```

For details on lag construction, source-frequency observations, anchors, explicit lag choices, and returned results, see:

```stata
help mfcollapse
```

---

## Data transformations

`mfcollapse` does **not** impose an economic transformation on the underlying series.

Transformations may be performed either before or after `mfcollapse`, depending on the information the mixed-frequency regressors are intended to represent.

### Transform after `mfcollapse`

For example, begin with daily WTI levels:

```text
daily WTI levels
        |
        v
   mfcollapse
        |
        v
wti_ld0 wti_ld1 ...
        |
        v
month-over-month transformations
```

After collapsing to monthly frequency, a transformation such as

```stata
gen llo0 = 100*(wti_ld0/L.wti_ld0 - 1)
```

measures the change in the most recent daily observation relative to the corresponding retained observation in the previous month.

Likewise,

```stata
gen llo1 = 100*(wti_ld1/L.wti_ld1 - 1)
```

transforms the second-most-recent higher-frequency position across lower-frequency periods.

This approach is used in the foreign-exchange application.

### Transform before `mfcollapse`

Alternatively, the researcher may want the mixed-frequency regressors themselves to represent **day-over-day changes**.

In that case, construct daily growth before calling `mfcollapse`.

For data observed on business days, first order the data and calculate growth between consecutive **available observations**:

```stata
sort date
drop if missing(wti)

gen double wti_d = 100*(wti/wti[_n-1] - 1) if _n>1
```

Then apply `mfcollapse` to the transformed series:

```stata
mfcollapse wti_d, ///
    date(date) ///
    frequency(monthly) ///
    ar(1)
```

The resulting variables

```text
wti_d_ld0
wti_d_ld1
...
```

are day-over-day growth rates observed at different positions within the month.

Thus the two workflows are:

```text
Levels -> mfcollapse -> lower-frequency-interval transformations
```

and

```text
Levels -> source-frequency transformations -> mfcollapse
```

They are generally **not equivalent**. For nonlinear transformations such as growth rates,

```text
transform then collapse != collapse then transform
```

The appropriate ordering depends on the economic interpretation of the desired predictor.

For business-day data such as exchange rates or commodity prices, using consecutive available observations avoids introducing artificial missing values from weekends and holidays. Researchers requiring literal calendar-day changes should instead construct an appropriate complete daily calendar before transforming the series.

---

## `bumidas`

`bumidas` estimates direct Bottom-Up Mixed-Frequency Data Sampling regressions using preconstructed high-frequency blocks and optional low-frequency regressors.

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

- full information-criterion search;
- recursive forward block-order selection;
- fixed-order estimation;
- multiple required and optional high-frequency blocks;
- low-frequency target and predictor lags;
- AIC, HQIC, and BIC;
- direct multi-period forecast horizons;
- fixed controls;
- standard prediction and residual postestimation.

### High-frequency block notation

`bumidas` identifies high-frequency information through variable-name stubs.

For example,

```text
hfy0 hfy1 hfy2 hfy3
```

defines the stub

```text
hfy
```

and orders count the **number of included terms**:

```text
order 0 = omitted
order 1 = hfy0
order 2 = hfy0 hfy1
order 3 = hfy0 hfy1 hfy2
```

Blocks specified in `hftarget()` are required and therefore have minimum order 1.

Blocks specified in `hfpredictors()` may have order 0 and may therefore be excluded.

Despite the option name, an `hftarget()` block need not literally represent the forecast target. It may represent any higher-frequency block whose latest observation should always enter the model.

### Model selection

The default

```stata
search(full)
```

evaluates all admissible combinations of block orders.

For larger search spaces,

```stata
search(recursive)
```

uses a greedy forward block-order search and is generally much faster, although it need not identify the global information-criterion minimum.

Prespecified orders can be estimated using:

```stata
search(none)
```

All candidate models within a search are estimated on a common sample so that their information criteria are comparable.

For the precise search algorithms, common-sample construction, low-frequency regressors, controls, forecast horizons, and fixed-order syntax, see:

```stata
help bumidas
```

---

## Examples

Self-contained command examples are provided in:

```text
examples/
```

### `mfcollapse_example.do`

Illustrates:

- higher- to lower-frequency conversion;
- automatic inference of HF observations per LF period;
- generated higher-frequency lag variables;
- multiple input variables;
- explicit lag selection.

### `bumidas_example.do`

Illustrates:

- BUMIDAS-BIC;
- required and optional HF blocks;
- recursive and full search;
- low-frequency regressors;
- alternative information criteria;
- multi-step direct forecasting;
- fixed-order estimation;
- controls;
- prediction and replay.

Run, for example:

```stata
do examples/bumidas_example.do
```

---

## Foreign-exchange application

A substantive application is provided in:

```text
applications/fx/
```

It uses daily exchange-rate and WTI oil-price data to demonstrate the complete forecasting workflow:

```text
daily data
    |
    v
mfcollapse
    |
    v
economic transformations
    |
    v
BUMIDAS / BUMIDAS-BIC
    |
    v
UMIDAS / RMIDAS / LF benchmarks
    |
    v
forecast evaluation
```

The application includes alternative Canadian-dollar and Norwegian-krone exchange-rate measures and compares:

- BUMIDAS;
- BUMIDAS-BIC;
- unrestricted MIDAS (**UMIDAS**);
- restricted MIDAS (**RMIDAS**, linear Almon);
- a low-frequency VAR;
- no-change forecasts.

The supplied dataset contains the daily exchange-rate and WTI series used by the example.

This application is intended as a transparent substantive demonstration rather than a complete journal replication archive.

---

## Simulation

A representative simulation is provided in:

```text
simulations/
```

The simulation generates a high-frequency VAR process, aggregates it to a lower frequency, and compares:

- recursive bottom-up forecasting;
- known-order BUMIDAS;
- BUMIDAS-BIC;
- unrestricted MIDAS (**UMIDAS**);
- restricted MIDAS (**RMIDAS**, using a linear Almon lag);
- a low-frequency VAR;
- end-of-period and low-frequency no-change forecasts.

UMIDAS and RMIDAS are implemented directly in the simulation and application code as benchmark methods. They are **not separate commands** included in the Stata package.

The simulation is intentionally compact and illustrates the forecasting implications of preserving higher-frequency information. It does not reproduce every Monte Carlo experiment in the associated paper.

---

## Tests

Certification tests are included in:

```text
tests/
```

Run:

```stata
do tests/mfcollapse_test.do
do tests/bumidas_test.do
```

The tests cover the main data-construction, estimation, model-selection, forecasting, prediction, and validation behavior of the commands.

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
├── applications/
│   └── fx/
│       ├── fx_example.do
│       └── DataD.xlsx
│
├── simulations/
│   └── bumidas_simulation.do
│
└── tests/
    ├── mfcollapse_test.do
    └── bumidas_test.do
```

---

## Documentation

Detailed command documentation is available directly in Stata:

```stata
help mfcollapse
help bumidas
```

The help files document syntax, options, block-order definitions, search procedures, common-sample construction, stored results, replay, prediction, and examples.

`bumidas` is an e-class estimation command, and its selected regression remains active as a standard Stata estimation result.

Useful additional stored results include:

```text
e(horizon)
e(icvalue)
e(N_models)
e(N_common)
e(search)
e(ic)
e(rhs)
e(orders)
e(path)
```

For example:

```stata
matrix list e(orders)
```

For recursive searches:

```stata
matrix list e(path)
```

See `help bumidas` for the complete list.

---

## Software status

Current public version:

```text
v0.1.1
```

The command interfaces are intended to remain stable, although minor improvements may be made following broader user testing.

See:

```text
CHANGELOG.md
```

for version history.

---

## Requirements

The commands use

```stata
version 11.0
```

for compatibility and are designed for **Stata 11 or later**.

They have been tested successfully under Stata 14, Stata 16, and Stata 18.

Time-series operators used by `bumidas` require the data to be appropriately declared using `tsset`.

---

## Research background

The BUMIDAS methodology is developed in:

> Lee, Quinlan and Snudden, Stephen, **“Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS)”**, April 1, 2025.

Available at SSRN:

https://ssrn.com/abstract=5312038

DOI:

https://doi.org/10.2139/ssrn.5312038

The central idea is that forecasts of temporally aggregated variables can exploit underlying higher-frequency information directly rather than first discarding that information through temporal aggregation.

The framework accommodates:

- observed higher-frequency target information;
- higher-frequency predictors;
- proxies for unavailable higher-frequency states;
- low-frequency target and predictor information.

For theory, simulations, empirical applications, and methodological discussion, see the paper.

---

## Citation

If you use the Stata software, please cite the repository.

### Software

Suggested citation:

```text
Snudden, Stephen. 2026.
BUMIDAS for Stata: Bottom-Up Mixed-Frequency Data Sampling commands.
Version 0.1.1.
https://github.com/SSEconomics/bumidas-stata
```

A machine-readable citation is provided in:

```text
CITATION.cff
```

### Methodology

If you use the BUMIDAS methodology in academic work, please cite:

> Lee, Quinlan and Snudden, Stephen, **Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS)** (April 1, 2025). Available at SSRN: https://ssrn.com/abstract=5312038.

Users employing UMIDAS, RMIDAS, or other MIDAS benchmarks should also cite the original methodological references appropriate to those specifications.

---

## Reproducibility

The command examples and certification tests are designed to run independently of the authors' research environment.

The foreign-exchange application includes the data required for the supplied example.

The simulation is fully generated within Stata using a fixed random-number seed.

This software repository is distinct from the complete journal replication archive.

---

## License

This project is licensed under the MIT License. See `LICENSE` for details.

---

## Contributing and issues

Bug reports and reproducible examples are welcome through the GitHub issue tracker:

https://github.com/SSEconomics/bumidas-stata/issues

When reporting a problem, please include:

- the Stata version;
- the command used;
- the complete error message;
- a minimal reproducible example when possible.

For command usage and methodological details, first consult:

```stata
help bumidas
help mfcollapse
```

and the BUMIDAS paper.

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

---

## Disclaimer

This software is provided for research and educational purposes under the terms of the MIT License.

Users are responsible for verifying that the specifications, data transformations, model-selection procedures, and forecasting methods are appropriate for their application.
