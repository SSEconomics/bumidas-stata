// -----------------------------------------------------------------------------
// rmidas_example.do
// Examples for rmidas
// BUMIDAS for Stata
// Version: 0.2.0
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------
//
// This file demonstrates the main rmidas workflow using synthetic data.
// Higher-frequency lag blocks are already constructed as x0, x1, ... and
// z0, z1, ... .  With sampling ratio n_j and order p_j, rmidas restricts
// exactly p_j*(n_j-1) underlying HF observations in each supplied block.
//
// In empirical applications, these blocks may be constructed from mfcollapse
// output and transformed before calling rmidas.
//
// The nonlinear Exp-Almon and Beta methods require nlrmidas_lse.ado on the
// ado-path.  See help rmidas for complete syntax and option documentation.
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
        + 0.45*x0[`i'-1] ///
        + 0.25*x1[`i'-1] ///
        + 0.12*x2[`i'-1] ///
        + 0.06*x3[`i'-1] ///
        + 0.20*z0[`i'-1] ///
        + 0.15*c[`i'-1] ///
        + 0.50*u[`i'] in `i'
}

// 2. Quadratic Almon polynomial (default degree 2)
rmidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    method(almon) ///
    noconstant

matrix list e(weights)

// 3. Step-3 restriction
rmidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    method(step) steps(3) ///
    noconstant

// 4. Legendre polynomial, degree 3
rmidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    method(legendre) degree(3) ///
    noconstant

// 5. Normalized exponential Almon
rmidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    method(expalmon) ///
    noconstant

matrix list e(shapeweights)
matrix list e(shapeparams)

// 6. Normalized Beta polynomial
rmidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    method(beta) ///
    noconstant

matrix list e(shapeweights)
matrix list e(shapeparams)

// 7. Multiple HF blocks with different sampling ratios and orders
// p_y=1, p_x=2, p_z=1 -> x uses 8 terms, z uses 2 terms.
rmidas y, ///
    hfpredictors(x z) ///
    hfn(5 3) ///
    porders(1 2 1) ///
    method(almon) degree(2) ///
    noconstant

matrix list e(orders)
matrix list e(hfterms)

// 8. Add fixed unrestricted controls
rmidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    method(almon) ///
    controls(L.c) ///
    noconstant

// 9. Three-period-ahead direct regression
// LF target lags begin at L3.y and every HF term is shifted by L3.
rmidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    method(almon) ///
    horizon(3) ///
    noconstant

// 10. Full underlying regression output
rmidas y, ///
    hfpredictors(x z) ///
    hfn(5 3) ///
    porders(1 1 1) ///
    method(step) steps(2) ///
    noconstant ///
    regression

// 11. Trace nonlinear construction and estimation
rmidas y, ///
    hfpredictors(x) ///
    hfn(5) ///
    porder(1) ///
    method(expalmon) ///
    noconstant ///
    trace

// 12. Prediction
capture drop yhat uhat
predict double yhat
predict double uhat, residuals

list time y yhat uhat in -5/l, noobs

// 13. Inspect stored results
ereturn list
matrix list e(orders)
matrix list e(hfn)
matrix list e(hfterms)
matrix list e(weights)

// 14. Replay
rmidas
rmidas, regression

di _newline as result "rmidas examples completed."
