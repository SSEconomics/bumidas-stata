// -----------------------------------------------------------------------------
// umidas_example.do
// Examples for umidas
// BUMIDAS for Stata
// Version: 0.2.0
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------
//
// This file demonstrates the main umidas workflow using synthetic data.
// Higher-frequency lag blocks are already constructed as x0, x1, ... and
// z0, z1, ... .  With sampling ratio n_j and order p_j, umidas uses exactly
// p_j*(n_j-1) terms from each supplied HF block.
//
// In empirical applications, these blocks may be constructed from mfcollapse
// output and transformed before calling umidas.
//
// See help umidas for complete syntax and option documentation.
// -----------------------------------------------------------------------------

clear all
set more off
set seed 01102026

// 1. Create synthetic monthly data
set obs 360
gen time = tm(1995m1) + _n - 1
format time %tm
tsset time

// x: n=5 -> four HF terms per order
forvalues j=0/7 {
    gen double x`j' = rnormal()
}

// z: n=3 -> two HF terms per order
forvalues j=0/3 {
    gen double z`j' = rnormal()
}

gen double c = rnormal()
gen double u = rnormal()

gen double y = .
replace y = 0 in 1
forvalues i=2/360 {
    quietly replace y = ///
          0.30*y[`i'-1] ///
        + 0.60*x0[`i'-1] ///
        - 0.30*x1[`i'-1] ///
        + 0.20*z0[`i'-1] ///
        + 0.15*c[`i'-1] ///
        + 0.50*u[`i'] in `i'
}

// 2. Fixed common-order UMIDAS
// p_y=1, p_x=1 -> x0,...,x3
umidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    noconstant

matrix list e(orders)
matrix list e(hfterms)

// 3. Fixed block-specific orders
// p_y=2, p_x=2, p_z=1
// x uses 2*(5-1)=8 terms; z uses 1*(3-1)=2 terms.
umidas y, ///
    hfpredictors(x z) ///
    hfn(5 3) ///
    porders(2 2 1) ///
    noconstant

matrix list e(orders)
matrix list e(hfterms)

// 4. BIC selection over separate positive orders for each block
umidas y, ///
    hfpredictors(x z) ///
    hfn(5 3) ///
    pmax(2) ///
    search(block) ic(bic) ///
    noconstant

matrix list e(orders)

// 5. BIC selection with one common order
umidas y, ///
    hfpredictors(x z) ///
    hfn(5 3) ///
    pmax(2) ///
    search(common) ic(bic) ///
    noconstant

matrix list e(orders)

// 6. Alternative information criterion
umidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    pmax(2) ///
    search(block) ic(aic) ///
    noconstant

// 7. Add fixed unrestricted controls
// controls() are included exactly as supplied and are not horizon shifted.
umidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    controls(L.c) ///
    noconstant

// 8. Three-period-ahead direct regression
// LF target lags begin at L3.y and the HF block is shifted by L3.
umidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    horizon(3) ///
    noconstant

// 9. Full underlying regression output
umidas y, ///
    hfpredictors(x z) ///
    hfn(5 3) ///
    porders(1 1 1) ///
    noconstant ///
    regression

// 10. Trace the IC search
umidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    pmax(2) ///
    search(common) ic(bic) ///
    noconstant ///
    trace

// 11. Prediction
capture drop yhat uhat
predict double yhat
predict double uhat, residuals

list time y yhat uhat in -5/l, noobs

// 12. Inspect stored results
ereturn list
matrix list e(orders)
matrix list e(hfn)
matrix list e(hfterms)

// 13. Replay
umidas
umidas, regression

di _newline as result "umidas examples completed."
