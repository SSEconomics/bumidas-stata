// -----------------------------------------------------------------------------
// bumidas_example.do
// Examples for bumidas
// BUMIDAS for Stata
// Version: 0.2.0
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------
//
// This file demonstrates the main bumidas workflow using synthetic data.
// High-frequency lag blocks are already constructed as hfy0, hfy1, ... and
// hfx0, hfx1, ...
//
// In empirical applications, these blocks may be constructed from mfcollapse
// output and transformed before calling bumidas.
//
// See help bumidas for complete syntax and option documentation.
// -----------------------------------------------------------------------------

clear all
set more off
set seed 26092026

// 1. Create synthetic monthly data
set obs 300
gen time = tm(2000m1) + _n - 1
format time %tm
tsset time

forvalues j=0/5 {
    gen double hfy`j' = rnormal()
    gen double hfx`j' = rnormal()
}
forvalues j=0/3 {
    gen double hfn`j' = rnormal()
}

gen double lf_x = rnormal()
gen double u = rnormal()

gen double y = .
replace y = 0 in 1
forvalues i=2/300 {
    quietly replace y = ///
          0.25*y[`i'-1] ///
        + 0.80*hfy0[`i'-1] ///
        - 0.35*hfy1[`i'-1] ///
        + 0.45*hfx0[`i'-1] ///
        + 0.25*lf_x[`i'-1] ///
        + 0.60*u[`i'] in `i'
}

// 2. Basic BUMIDAS-BIC
// Required HF: minimum order 1.
// Optional HF: may be excluded at order 0.
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(6) ///
    search(full) ic(bic) ///
    horizon(1) noconstant

matrix list e(orders)

// 3. Print the final selected regression
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(6) ///
    search(full) ic(bic) ///
    horizon(1) noconstant ///
    regression

// 4. Require the latest observation from multiple HF blocks
bumidas y, ///
    hftarget(hfy hfx) ///
    hfpredictors(hfn) ///
    hfmax(4) ///
    search(full) ic(bic) ///
    horizon(1) noconstant

// 5. Make all HF blocks optional
bumidas y, ///
    hfpredictors(hfy hfx hfn) ///
    hfmax(4) ///
    search(full) ic(bic) ///
    horizon(1) noconstant

// 6. Recursive forward search with trace
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx hfn) ///
    hfmax(6) ///
    search(recursive) ic(bic) ///
    horizon(1) noconstant ///
    trace

matrix list e(path)

// 7. Add LF target and LF predictor blocks
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx hfn) ///
    hfmax(6) ///
    lfymax(3) ///
    lfpredictors(lf_x) lfxmax(3) ///
    search(recursive) ic(bic) ///
    horizon(1) noconstant ///
    regression

// 8. Alternative information criterion
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx hfn) ///
    hfmax(6) ///
    search(recursive) ic(aic) ///
    horizon(1) noconstant

// 9. Three-period-ahead direct regression
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx hfn) ///
    hfmax(6) ///
    lfymax(2) ///
    lfpredictors(lf_x) lfxmax(2) ///
    search(recursive) ic(aic) ///
    horizon(3) noconstant ///
    regression

// 10. Fixed-order BUMIDAS
// hforders(): required HF blocks first, then optional HF blocks.
// hfy=2, hfx=1, hfn=0.
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx hfn) ///
    hforders(2 1 0) ///
    search(none) ///
    horizon(1) noconstant ///
    regression

matrix list e(orders)

// 11. Fixed controls
// controls() are included exactly as supplied and are not horizon shifted.
bumidas y, ///
    hftarget(hfy) ///
    hfpredictors(hfx) ///
    hfmax(6) ///
    controls(L.lf_x) ///
    search(full) ic(bic) ///
    horizon(1)

// 12. Prediction
capture drop yhat uhat
predict double yhat
predict double uhat, residuals

list time y yhat uhat in -5/l, noobs

// 13. Replay
bumidas
bumidas, regression

di _newline as result "bumidas examples completed."
