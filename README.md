# MIDAS for Stata

**MIDAS for Stata** provides Stata commands for mixed-frequency data construction, estimation, model selection, and forecasting.

**Current version:** 0.2.0

| Command | Purpose |
|---|---|
| `mfcollapse` | Collapse higher-frequency data to a mixed-frequency dataset|
| `bumidas` | Estimate and select direct Bottom-Up MIDAS regressions |
| `umidas` | Estimate and select unrestricted MIDAS regressions |
| `rmidas` | Estimate restricted MIDAS regressions |

`rmidas` supports **Almon**, **step**, **Legendre**, **exponential Almon**, and **beta** weights.

The repository also contains self-contained examples, certification tests, an exchange-rate application, representative simulations, and conference materials.

---

## Why MIDAS?

MIDAS estimates the direct forecast of lower-frequency data using higher-frequency data. This aviods discarding valuable information, substantially improving forecast accuracy.

How MIDAS works in Stata:
```text
load higher-frequency data
        |
        v
mfcollapse creates mixed freq. data
        |
        v
 estimate using bumidas / umidas / rmidas
        |
        v
prediction and forecast evaluation
```

`mfcollapse` handles mixed-frequency data construction. The estimation commands then provide alternative direct mixed-frequency specifications.

---

## Installation

Install the four commands directly from GitHub using one line:

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

Suppose `wti` is observed daily and you want to forecast the monthly average:

```stata
mfcollapse wti, date(time) frequency(monthly)
```

The number of high-frequency subperiods to retain is calculated automatically. For oil, it will find that there are typically 21 daily business-day observations within a month so will create monthly series

```text
wti_ld0 wti_ld1 ... wti_ld20 wti_ave
```

where `wti_ave' is the monthly average `[t]`, `wti_ld0` is the end-of-month high-frequency observation `[t,n]`, `wti_ld1` is the second last daily observation `[t,n-1]`, `wti_ld2` is the third last daily observation `[t,n-2]`, etc.

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

### 2. Estimate MIDAS model

After the desired transformations, suppose the mixed-frequency blocks are

```text
hfy0 hfy1 hfy2 ...
hfx0 hfx1 hfx2 ...
```

**Think of BUMIDAS as auto.arima for MIDAS models.**

Use information criteria to find and estimate best fitting unrestricted model using the daily data of the target and predictor:

```stata
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(20) ///
    search(full) ///
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

Use 21 lags of the higher-frequency predictor and the lag of the low-frequency target:

```stata
umidas y, ///
    hfpredictors(hfx) ///
    hfn(21) ///
    porder(1) ///
    noconstant
```

The `umidas' command can automatically searh order `p' of `p(n-1)' using information criteria.

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

---

## Important order conventions

### `hfn()` is the sampling ratio

`mfcollaspe' automatically returns `hfn()`, the number of HF observations per LF period `n'.

For example,

```stata
hfn(21)
```

with higher-frequency order `p=1' implies

```text
1 x (21 - 1) = 20
```

higher-frequency terms:

```text
hfx0 ... hfx19
```

The estimation commands can use the `hfn()` from each HF series to easily combine alternative HF sampling (weekly and daily) on RHS.   

---

## Command notes

Higher-frequency blocks are provided through variable-name stubs.

For example, given the stub `hfy` and `p=1', the HF data for 3 months in a quarter `hfn(3)` is

```text
hfy0 hfy1 hfy2 
```

Blocks in `hftarget()` are required. Blocks in `hfpredictors()` are optional.

The autoregressive order `p' denotes how many quarters of HF data to use based on `p(n-1)': 

```text
p=0 => omitted
p=1 = hfy0 hfy1 hfy2 
p=2 = hfy0 hfy1 hfy2 hfy3 hfy4 hfy5 
```

BUMIDAS searches individual HF predictors over `p(n-1)', UMIDAS searches over `p' given `n'.

Selection modes for IC are:

```text
search(full)       exhaustive IC search
search(recursive)  forward block-order search
search(none)       fixed-order estimation
```

The command supports BIC, HQIC, AIC, low-frequency target and predictor lags, controls, multiple higher-frequency blocks, and direct multi-period horizons. Candidate models within a search are estimated on a common sample.

See `help bumidas` and `help umidas` for complete syntax and stored results.

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

Transformations may be applied either before or after collapsing, depending on the desired lag use.

For example, after collapsing daily WTI levels to months, the lag in the growth rate:

```stata
gen llo0 = 100*(wti_ld0/L.wti_ld0 - 1)
gen llo1 = 100*(wti_ld1/L.wti_ld1 - 1)
...
```

constructs month-over-month changes.

Instead, if day-over-day is desired, transform the daily data first 

```stata
gen llo = 100*(wti/L.wti - 1)
```

then call `mfcollapse`:

```stata
gen llo0 
gen llo1
...
```

These order of the operations are not equivalent:

```text
transform -> collapse  !=  collapse -> transform
```

The appropriate tranformation is a modeling choice. 

---

## Examples and certification tests

Self-contained examples are provided in `examples/`:

```text
mfcollapse_example.do
bumidas_example.do
umidas_example.do
rmidas_example.do
```

Certification tests are provided in `tests/`:

```stata
do tests/mfcollapse_test.do
do tests/bumidas_test.do
do tests/umidas_test.do
do tests/rmidas_test.do
```

The tests cover data construction, estimation, model selection, order handling, horizon timing, prediction, stored results, and input validation.

---

## Applications and simulations

### Foreign-exchange application

The exchange-rate application uses daily exchange rates and WTI oil prices in an expanding-window forecasting exercise.

It compares:

- BUMIDAS;
- BUMIDAS with BIC selection;
- UMIDAS;
- RMIDAS;
- a low-frequency VAR;
- no-change benchmarks.

The example covers one- and multi-month horizons and illustrates forecast evaluation and comparison tests.

### Simulation

The representative simulation generates a higher-frequency VAR process, aggregates it to a lower frequency, and compares:

- recursive bottom-up forecasting;
- known-order BUMIDAS;
- BUMIDAS with BIC selection;
- UMIDAS;
- RMIDAS;
- a low-frequency VAR;
- end-of-period and low-frequency no-change forecasts.

The simulation file is an example rather than any replication from the article.

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

## MIDAS research background

The BUMIDAS methodology:

> Lee, Quinlan and Stephen Snudden. **“Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS).”** 2025.  
> DOI: 10.2139/ssrn.5312038  
> https://ssrn.com/abstract=5312038

The paper develops BUMIDAS and studies the efficicent use of MF data and model structure, when the HF data of the target is observed, proxied, or unobserved.

Users employing other MIDAS specifications should also cite the original methodological references appropriate to those methods. 

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
