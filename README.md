# BUMIDAS for Stata

**BUMIDAS for Stata** provides Stata commands for mixed-frequency data construction, estimation, model selection, and forecasting.

**Current version:** 0.2.0

| Command | Purpose |
|---|---|
| `mfcollapse` | Collapse higher-frequency data to a mixed-frequency dataset|
| `bumidas` | Estimate and select direct Bottom-Up Mixed-Frequency Data Sampling regressions |
| `umidas` | Estimate unrestricted MIDAS regressions |
| `rmidas` | Estimate restricted MIDAS regressions |

`rmidas` supports **Almon**, **step**, **Legendre**, **exponential Almon**, and **beta** weights.

The repository also contains self-contained examples, certification tests, an exchange-rate application, representative simulations, and conference materials.

---

## Why BUMIDAS?

Forecasts are often constructed for temporally aggregated variables—such as monthly averages or quarterly sums—even when higher-frequency information is available.

BUMIDAS estimates the direct forecast using the relevant higher-frequency state rather than first discarding that information through temporal aggregation.

```text
higher-frequency data
        |
        v
    mfcollapse
        |
        v
 bumidas / umidas / rmidas
        |
        v
prediction and forecast evaluation
```

`mfcollapse` handles mixed-frequency data construction. The estimation commands then provide alternative direct mixed-frequency specifications.

---

## Installation

Install directly from GitHub:

```stata
net install bumidas, from("https://raw.githubusercontent.com/SSEconomics/bumidas-stata/main") replace
```

Verify the installation:

```stata
which mfcollapse
which bumidas
which umidas
which rmidas

help mfcollapse
help bumidas
help umidas
help rmidas
```

---

## Quick start

### 1. Construct mixed-frequency data

Suppose `wti` is observed daily and the forecasting model is monthly:

```stata
mfcollapse wti, date(time) frequency(monthly)
```

The number of high-frequency subperiods to retain is calculated automatically. For a typical business-day series with 21 daily observations within a month this may create

```text
wti_ld0 wti_ld1 ... wti_ld20 wti_ave
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

See `help mfcollapse` for lag construction, anchors, metadata, explicit lag choices, and returned results.

### 2. Estimate BUMIDAS

After the desired transformations, suppose the mixed-frequency blocks are

```text
hfy0 hfy1 hfy2 ...
hfx0 hfx1 hfx2 ...
```

**Think of BUMIDAS as auto.arima for MIDAS models.**

Estimate BUMIDAS using BIC with:

```stata
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(20) ///
    search(full) ///
    ic(bic) ///
    noconstant
```

For larger model spaces, use the faster greedy search:

```stata
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(20) ///
    search(recursive) ///
    ic(bic) ///
    noconstant
```

Standard postestimation is available:

```stata
bumidas, regression
predict double yhat
predict double uhat, residuals
```

### 3. Estimate UMIDAS

With one higher-frequency predictor and 21 source-frequency observations per lower-frequency period:

```stata
umidas y, ///
    hfpredictors(hfx) ///
    hfn(21) ///
    porder(1) ///
    noconstant
```

This uses one low-frequency target lag and 20 (n - 1) unrestricted higher-frequency terms.

### 4. Estimate RMIDAS

A quadratic Almon specification is:

```stata
rmidas y, ///
    hfpredictors(hfx) ///
    hfn(21) ///
    porders(1 1) ///
    method(almon) degree(2) ///
    noconstant
```

Other supported restrictions are available through `method()`:

```text
almon
step
legendre
expalmon
beta
```

See `help rmidas` for parameterizations, method-specific options, weights, and stored results.

---

## Important order conventions

### `hfn()` is the sampling ratio

`hfn()` specifies the number of source-frequency observations per lower-frequency period—not the number of regressors.

For example,

```stata
hfn(21)
```

with higher-frequency order 1 implies

```text
1 x (21 - 1) = 20
```

higher-frequency terms:

```text
hfx0 ... hfx19
```

### `porder()` versus `porders()`

`porder(#)` applies the same order to the low-frequency target and every higher-frequency predictor.

With one higher-frequency predictor:

```stata
porder(3)
```

is equivalent to

```stata
porders(3 3)
```

`porders()` allows block-specific orders and must contain exactly **J + 1** positive values:

```text
porders(p_y p_1 ... p_J)
```

where the first value is the low-frequency target order and the remaining values correspond to the higher-frequency predictors.

For example,

```stata
porders(3 1)
```

with `hfn(21)` means three low-frequency target lags and 20 higher-frequency terms.

A one-element specification such as

```stata
porders(3)
```

is invalid when one higher-frequency predictor is supplied. Use `porder(3)` for a common order.

When combining higher-frequency series with different source frequencies, specifying `hfn()` explicitly is recommended.

---

## Command notes

### `bumidas`

`bumidas` identifies higher-frequency blocks through variable-name stubs.

For

```text
hfy0 hfy1 hfy2 hfy3
```

the stub is `hfy`, and orders count included terms:

```text
order 0 = omitted
order 1 = hfy0
order 2 = hfy0 hfy1
order 3 = hfy0 hfy1 hfy2
```

Blocks in `hftarget()` are required. Blocks in `hfpredictors()` are optional.

Selection modes are:

```text
search(full)       exhaustive IC search
search(recursive)  greedy forward block-order search
search(none)       fixed-order estimation
```

The command supports BIC, HQIC, AIC, low-frequency target and predictor lags, controls, multiple higher-frequency blocks, and direct multi-period horizons. Candidate models within a search are estimated on a common sample.

See `help bumidas` for complete syntax and stored results.

### `rmidas`

Supported weight families are:

| `method()` | Restriction |
|---|---|
| `almon` | Almon polynomial |
| `step` | Step function |
| `legendre` | Legendre polynomial |
| `expalmon` | Exponential Almon |
| `beta` | Beta polynomial/kernel |

Almon, step, and Legendre specifications use linear regression constructions. Exponential Almon and beta specifications use nonlinear estimation with numerically stabilized weight evaluation.

See `help rmidas` for method-specific references and implementation details.

---

## Data transformations

`mfcollapse` does **not** impose an economic transformation on the underlying series.

Transformations may be applied either before or after collapsing, depending on what the mixed-frequency regressors are intended to represent.

For example, after collapsing daily WTI levels:

```stata
gen llo0 = 100*(wti_ld0/L.wti_ld0 - 1)
gen llo1 = 100*(wti_ld1/L.wti_ld1 - 1)
```

constructs changes in the same retained higher-frequency positions across lower-frequency periods.

If the desired regressors are instead day-over-day changes, transform the daily data first and then call `mfcollapse`.

These operations are generally not equivalent:

```text
transform -> collapse  !=  collapse -> transform
```

The appropriate ordering is an economic modeling choice. The exchange-rate application illustrates transformation after `mfcollapse`.

---

## Examples and certification tests

Self-contained examples are provided in `examples/`:

```text
mfcollapse_example.do
bumidas_example.do
umidas_example.do
rmidas_example.do
```

Run, for example:

```stata
do examples/bumidas_example.do
do examples/umidas_example.do
do examples/rmidas_example.do
```

Certification tests are provided in `tests/`:

```stata
do tests/mfcollapse_test.do
do tests/bumidas_test.do
do tests/umidas_test.do
do tests/rmidas_test.do
```

The tests cover data construction, estimation, model selection, order handling, horizon timing, prediction, stored results, and input validation.

The UMIDAS and RMIDAS tests include comparisons with equivalent hand-coded regressions. RMIDAS additionally tests its linear and nonlinear weighting implementations.

---

## Applications and simulations

### Foreign-exchange application

The exchange-rate application uses daily exchange rates and WTI oil prices in an expanding-window forecasting exercise.

It compares:

- BUMIDAS;
- BUMIDAS with information-criterion selection;
- UMIDAS;
- RMIDAS;
- a low-frequency VAR;
- no-change benchmarks.

The example covers one- and multi-month horizons and illustrates forecast evaluation and comparison tests.

### Simulation

The representative simulation generates a higher-frequency VAR process, aggregates it to a lower frequency, and compares:

- recursive bottom-up forecasting;
- known-order BUMIDAS;
- BUMIDAS with information-criterion selection;
- UMIDAS;
- RMIDAS;
- a low-frequency VAR;
- end-of-period and low-frequency no-change forecasts.

The command-based UMIDAS and RMIDAS forecasts are validated against equivalent hand-coded implementations.

These files are examples rather than the complete journal replication archive.

---

## Repository structure

```text
bumidas-stata/
|
|-- README.md
|-- LICENSE
|-- CITATION.cff
|-- CHANGELOG.md
|-- stata.toc
|-- bumidas.pkg
|
|-- stata/
|   |-- mfcollapse.ado
|   |-- mfcollapse.sthlp
|   |-- bumidas.ado
|   |-- bumidas_p.ado
|   |-- bumidas.sthlp
|   |-- umidas.ado
|   |-- umidas_p.ado
|   |-- umidas.sthlp
|   |-- rmidas.ado
|   |-- rmidas_p.ado
|   |-- nlrmidas_lse.ado
|   `-- rmidas.sthlp
|
|-- examples/
|-- tests/
|-- applications/
|-- simulations/
`-- conferences/
```

---

## Documentation and requirements

Detailed documentation is available directly in Stata:

```stata
help mfcollapse
help bumidas
help umidas
help rmidas
```

The commands are designed for **Stata 11 or later**. Estimation commands that use time-series operators require data to be appropriately declared with `tsset`.

See `CHANGELOG.md` for version history.

---

## Research background

The BUMIDAS methodology is developed in:

> Lee, Quinlan and Stephen Snudden. **“Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS).”** 2025.  
> DOI: 10.2139/ssrn.5312038  
> https://ssrn.com/abstract=5312038

The paper develops direct bottom-up mixed-frequency forecasting for temporally aggregated processes and studies the roles of higher-frequency target information, predictors, proxies, and low-frequency information.

---

## Citation

If you use this software, please cite both the software and the associated BUMIDAS paper.

### Software

```text
Snudden, Stephen. 2026.
BUMIDAS for Stata.
Version 0.2.0.
https://github.com/SSEconomics/bumidas-stata
```

A machine-readable citation is provided in `CITATION.cff`.

### Methodology

> Lee, Quinlan and Stephen Snudden. **“Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS).”** 2025.  
> DOI: 10.2139/ssrn.5312038  
> https://ssrn.com/abstract=5312038

Users employing UMIDAS, RMIDAS, or other MIDAS specifications should also cite the original methodological references appropriate to those methods. Method-specific references are listed in the command help files.

---

## License and feedback

This project is licensed under the MIT License.

Bug reports and reproducible examples are welcome through:

https://github.com/SSEconomics/bumidas-stata/issues

Please include the Stata version, command used, complete error message, and a minimal reproducible example when possible.

---

## Author

**Stephen Snudden**  
Department of Economics  
Wilfrid Laurier University

Website: https://stephensnudden.com  
GitHub: https://github.com/SSEconomics  
Repository: https://github.com/SSEconomics/bumidas-stata

### Acknowledgment

The BUMIDAS methodology was developed jointly with Quinlan Lee.

---

## Disclaimer

This software is provided for research and educational purposes under the terms of the MIT License. Users are responsible for verifying that the specifications, transformations, model-selection procedures, and forecasting methods are appropriate for their application.
