// -----------------------------------------------------------------------------
// bumidas_test.do
// Certification tests for bumidas
// BUMIDAS for Stata
// Version: 0.1.2
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------
//
// This file provides deterministic regression tests for bumidas.
// It verifies model selection, required and optional high-frequency blocks,
// low-frequency terms, direct forecast horizons, prediction, replay,
// and validation behavior.
//
// A successful run should end with:
//     All bumidas regression tests passed.
//
// See help bumidas for complete syntax and option documentation.
// -----------------------------------------------------------------------------

version 18.0
clear all
set more off
set seed 26092026

// 0. Confirm command is available
capture which bumidas
if _rc {
    di as error "bumidas.ado not found on the ado-path"
    exit 111
}

// 1. Construct deterministic synthetic data
set obs 360
gen time = tm(1995m1) + _n - 1
format time %tm
tsset time

forvalues j=0/3 {
    gen double r`j' = rnormal()
    gen double x`j' = rnormal()
}
forvalues j=0/2 {
    gen double z`j' = rnormal()
}

gen double p1 = rnormal()
gen double p2 = rnormal()
gen double u  = rnormal()

gen double y = .
replace y = 0 in 1
forvalues i=2/360 {
    quietly replace y = ///
          0.20*y[`i'-1] ///
        + 0.80*r0[`i'-1] ///
        - 0.40*r1[`i'-1] ///
        + 0.30*z0[`i'-1] ///
        + 0.25*p1[`i'-1] ///
        + 0.60*u[`i'] in `i'
}

// 2. Full-grid search versus hand-coded exhaustive BIC search
tempvar sample
quietly regress y ///
    L.r0 L.r1 L.r2 L.r3 ///
    L.x0 L.x1 L.x2 L.x3, noconstant
gen byte `sample' = e(sample)

local bestbic = .
local phat = .
local qhat = .

forvalues p=1/4 {
    local rrhs ""
    forvalues j=0/`=`p'-1' {
        local rrhs "`rrhs' L.r`j'"
    }

    forvalues q=0/4 {
        local xrhs ""
        if `q'>0 {
            forvalues j=0/`=`q'-1' {
                local xrhs "`xrhs' L.x`j'"
            }
        }

        quietly regress y `rrhs' `xrhs' if `sample', noconstant
        local bic = -2*e(ll) + ln(e(N))*e(rank)

        if missing(`bestbic') | `bic'<`bestbic' {
            local bestbic = `bic'
            local phat = `p'
            local qhat = `q'
        }
    }
}

quietly bumidas y, ///
    hftarget(r) ///
    hfpredictors(x) ///
    hfmax(4) ///
    search(full) ic(bic) ///
    horizon(1) noconstant

matrix O = e(orders)
assert O[1,1] == `phat'
assert O[1,2] == `qhat'
assert abs(e(icvalue)-`bestbic') < 1e-8
assert e(N_models) == 20
di as result "PASS 1: full grid reproduces hand-coded exhaustive BIC search"

// 3. Multiple required and optional HF blocks
quietly bumidas y, ///
    hftarget(r z) ///
    hfpredictors(x) ///
    hfmax(3) ///
    search(full) ic(bic) ///
    horizon(1) noconstant

matrix O = e(orders)
assert e(N_models) == 36
assert O[1,1] >= 1 & O[1,1] <= 3
assert O[1,2] >= 1 & O[1,2] <= 3
assert O[1,3] >= 0 & O[1,3] <= 3
di as result "PASS 2: multiple required/optional HF blocks"

// 4. No required HF block
quietly bumidas y, ///
    hfpredictors(r x) ///
    hfmax(3) ///
    search(full) ic(bic) ///
    horizon(1) noconstant

matrix O = e(orders)
assert e(N_models) == 16
assert O[1,1] >= 0 & O[1,1] <= 3
assert O[1,2] >= 0 & O[1,2] <= 3
di as result "PASS 3: command runs without hftarget()"

// 5. LF-only search
quietly bumidas y, ///
    lfymax(2) ///
    lfpredictors(p1 p2) lfxmax(2) ///
    search(full) ic(bic) ///
    horizon(1)

matrix O = e(orders)
assert e(N_models) == 27
assert colsof(O) == 3
assert O[1,1] >= 0 & O[1,1] <= 2
assert O[1,2] >= 0 & O[1,2] <= 2
assert O[1,3] >= 0 & O[1,3] <= 2
di as result "PASS 4: LF-only search"

// 6. Recursive path consistency
quietly bumidas y, ///
    hftarget(r) ///
    hfpredictors(x z) ///
    hfmax(3) ///
    search(recursive) ic(bic) ///
    horizon(1) noconstant

matrix O = e(orders)
matrix P = e(path)
local last = rowsof(P)

assert colsof(P) == 4
assert P[1,1] == 1
assert P[1,2] == 0
assert P[1,3] == 0
assert P[`last',1] == O[1,1]
assert P[`last',2] == O[1,2]
assert P[`last',3] == O[1,3]
di as result "PASS 5: recursive search path is internally consistent"

// 7. Alternative information criteria
foreach c in aic hqic bic {
    quietly bumidas y, ///
        hftarget(r) ///
        hfpredictors(x) ///
        hfmax(3) ///
        search(full) ic(`c') ///
        horizon(1) noconstant

    if "`e(ic)'" != "`c'" {
        di as error "incorrect stored information criterion for ic(`c')"
        exit 9
    }
}
di as result "PASS 6: AIC, HQIC, and BIC"

// 8. Fixed-order estimation
quietly bumidas y, ///
    hftarget(r z) ///
    hfpredictors(x) ///
    hforders(2 1 0) ///
    search(none) ///
    horizon(1) noconstant

matrix O = e(orders)
assert e(N_models) == 1
assert O[1,1] == 2
assert O[1,2] == 1
assert O[1,3] == 0
di as result "PASS 7: fixed-order estimation"

// 9. LF blocks and horizon > 1
quietly bumidas y, ///
    hftarget(r) ///
    hfpredictors(x) ///
    hfmax(3) ///
    lfymax(2) ///
    lfpredictors(p1 p2) lfxmax(2) ///
    search(recursive) ic(aic) ///
    horizon(3) noconstant

matrix O = e(orders)
assert e(horizon) == 3
assert colsof(O) == 5

if strpos("`e(rhs)'","L3.") == 0 {
    di as error "horizon(3) was not applied to the selected regression"
    exit 9
}
di as result "PASS 8: LF blocks and horizon(3)"

// 10. Fixed controls
quietly bumidas y, ///
    hftarget(r) ///
    hfpredictors(x) ///
    hfmax(3) ///
    controls(L.p1) ///
    search(full) ic(bic) ///
    horizon(1)

if "`e(controls)'" != "L.p1" {
    di as error "controls() not stored correctly"
    exit 9
}
if strpos("`e(rhs)'","L.p1") == 0 {
    di as error "controls() not included in final regression"
    exit 9
}
di as result "PASS 9: controls()"

// 11. predict and replay
capture drop yhat uhat
predict double yhat
predict double uhat, residuals
assert abs(y-yhat-uhat) < 1e-8 if e(sample)

scalar ic_before = e(icvalue)
local search_before "`e(search)'"

quietly bumidas
assert abs(e(icvalue)-ic_before) < 1e-12
if "`e(search)'" != "`search_before'" {
    di as error "replay altered stored estimation results"
    exit 9
}

quietly bumidas, regression
assert abs(e(icvalue)-ic_before) < 1e-12
di as result "PASS 10: predict and replay"

// 12. Expected validation errors
gen double g0 = rnormal()
gen double g2 = rnormal()

capture quietly bumidas y, hftarget(g) hfmax(3)
if _rc == 0 {
    di as error "expected malformed-stub error was not returned"
    exit 9
}

capture quietly bumidas y, hftarget(r) hfpredictors(r) hfmax(3)
if _rc == 0 {
    di as error "expected duplicate-HF-stub error was not returned"
    exit 9
}

capture quietly bumidas y, hftarget(r) hforders(0) search(none)
if _rc == 0 {
    di as error "expected required-HF order error was not returned"
    exit 9
}

capture quietly bumidas y, hftarget(r) hforders(2) hfmax(3) search(none)
if _rc == 0 {
    di as error "expected search(none)/hfmax() option error was not returned"
    exit 9
}

di as result "PASS 11: validation errors"

di _newline as result "All bumidas regression tests passed."
