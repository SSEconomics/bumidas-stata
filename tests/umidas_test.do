// -----------------------------------------------------------------------------
// umidas_test.do
// Certification tests for umidas
// BUMIDAS for Stata
// Version: 0.2.0
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------
//
// This file provides deterministic regression tests for umidas.
// It verifies fixed common and block-specific orders, block/common IC searches,
// multiple sampling ratios, direct forecast horizons, controls, prediction,
// replay, stored results, and validation behavior.
//
// A successful run should end with:
//     All umidas regression tests passed.
//
// See help umidas for complete syntax and option documentation.
// -----------------------------------------------------------------------------

clear all
capture log close _all
set more off
set seed 01102026

discard
capture which umidas
if _rc {
    di as error "umidas.ado not found on the ado-path"
    exit 111
}

// -----------------------------------------------------------------------------
// 1. Construct deterministic synthetic data
// -----------------------------------------------------------------------------

set obs 420
gen time = tm(1990m1) + _n - 1
format time %tm
tsset time

// x: n=5, so each UMIDAS order contributes 4 HF terms.
forvalues j=0/7 {
    gen double x`j' = rnormal()
}

// z: n=3, so each UMIDAS order contributes 2 HF terms.
forvalues j=0/3 {
    gen double z`j' = rnormal()
}

gen double c = rnormal()
gen double u = rnormal()

gen double y = .
replace y = 0 in 1
forvalues i=2/420 {
    quietly replace y = ///
          0.25*y[`i'-1] ///
        + 0.75*x0[`i'-1] ///
        - 0.35*x1[`i'-1] ///
        + 0.20*z0[`i'-1] ///
        + 0.15*c[`i'-1] ///
        + 0.45*u[`i'] in `i'
}

// -----------------------------------------------------------------------------
// 2. Fixed porder(1): exact hand-coded OLS comparison
// -----------------------------------------------------------------------------

quietly umidas y, hfpredictors(x) hfn(5) porder(1) noconstant

assert "`e(cmd)'"=="umidas"
assert "`e(selection)'"=="fixed"
assert "`e(search)'"=="fixed"
assert "`e(fixedtype)'"=="common"
assert e(horizon)==1
assert e(p)==1

matrix O=e(orders)
matrix T=e(hfterms)
assert O[1,1]==1 & O[1,2]==1
assert T[1,1]==4

tempvar smp f_um f_man d
quietly gen byte `smp'=e(sample)
quietly predict double `f_um'
quietly regress y L.y L.x0 L.x1 L.x2 L.x3 if `smp', noconstant
quietly predict double `f_man' if `smp'
quietly gen double `d'=abs(`f_um'-`f_man') if `smp'
quietly summarize `d', meanonly
assert r(max)<1e-10

di as result "PASS 1: fixed porder(1) reproduces hand-coded UMIDAS"

// -----------------------------------------------------------------------------
// 2b. Infer hfn from single-block mfcollapse-style variable metadata
// -----------------------------------------------------------------------------

char x0[mfcollapse_hfn] "5"
quietly umidas y, hfpredictors(x) porder(1) noconstant
matrix HM=e(hfn)
assert HM[1,1]==5

di as result "PASS 1b: single-block hfn metadata inference"

// -----------------------------------------------------------------------------
// 3. Block-specific orders and multiple n_j: exact hand-coded comparison
// -----------------------------------------------------------------------------

quietly umidas y, ///
    hfpredictors(x z) hfn(5 3) ///
    porders(2 2 1) controls(L.c) noconstant

matrix O=e(orders)
matrix H=e(hfn)
matrix T=e(hfterms)
assert O[1,1]==2 & O[1,2]==2 & O[1,3]==1
assert H[1,1]==5 & H[1,2]==3
assert T[1,1]==8 & T[1,2]==2
assert "`e(fixedtype)'"=="block"
assert "`e(controls)'"=="L.c"

tempvar smp2 f_um2 f_man2 d2
quietly gen byte `smp2'=e(sample)
quietly predict double `f_um2'
quietly regress y L.y L2.y ///
    L.x0 L.x1 L.x2 L.x3 L.x4 L.x5 L.x6 L.x7 ///
    L.z0 L.z1 L.c if `smp2', noconstant
quietly predict double `f_man2' if `smp2'
quietly gen double `d2'=abs(`f_um2'-`f_man2') if `smp2'
quietly summarize `d2', meanonly
assert r(max)<1e-10

di as result "PASS 2: porders() and multiple sampling ratios"

// -----------------------------------------------------------------------------
// 4. search(block): reproduce exhaustive BIC search for one HF block
// -----------------------------------------------------------------------------

tempvar bsamp
quietly regress y L.y L2.y ///
    L.x0 L.x1 L.x2 L.x3 L.x4 L.x5 L.x6 L.x7, noconstant
quietly gen byte `bsamp'=e(sample)
quietly count if `bsamp'
local commonN=r(N)

local bestbic=.
local bestpy=.
local bestpx=.
forvalues py=1/2 {
    local yrhs ""
    forvalues q=1/`py' {
        local yrhs "`yrhs' L`q'.y"
    }
    forvalues px=1/2 {
        local xrhs ""
        local K=4*`px'
        forvalues k=0/`=`K'-1' {
            local xrhs "`xrhs' L.x`k'"
        }
        quietly regress y `yrhs' `xrhs' if `bsamp', noconstant
        local bic=-2*e(ll)+ln(e(N))*e(rank)
        if missing(`bestbic') | `bic'<`bestbic' {
            local bestbic=`bic'
            local bestpy=`py'
            local bestpx=`px'
        }
    }
}

quietly umidas y, ///
    hfpredictors(x) hfn(5) pmax(2) ///
    search(block) ic(bic) noconstant

matrix O=e(orders)
assert O[1,1]==`bestpy'
assert O[1,2]==`bestpx'
assert abs(e(icvalue)-`bestbic')<1e-8
assert e(N_models)==4
assert e(N_common)==`commonN'
assert inlist(e(drop_improves),0,1)

di as result "PASS 3: search(block) reproduces exhaustive BIC search"

// -----------------------------------------------------------------------------
// 5. search(common): reproduce common-order BIC search
// -----------------------------------------------------------------------------

local bestbic=.
local bestp=.
forvalues p=1/2 {
    local rhs ""
    forvalues q=1/`p' {
        local rhs "`rhs' L`q'.y"
    }
    local K=4*`p'
    forvalues k=0/`=`K'-1' {
        local rhs "`rhs' L.x`k'"
    }
    quietly regress y `rhs' if `bsamp', noconstant
    local bic=-2*e(ll)+ln(e(N))*e(rank)
    if missing(`bestbic') | `bic'<`bestbic' {
        local bestbic=`bic'
        local bestp=`p'
    }
}

quietly umidas y, ///
    hfpredictors(x) hfn(5) pmax(2) ///
    search(common) ic(bic) noconstant

matrix O=e(orders)
assert O[1,1]==`bestp' & O[1,2]==`bestp'
assert e(common_selected)==1
assert e(p)==`bestp'
assert e(N_models)==2
assert abs(e(icvalue)-`bestbic')<1e-8

di as result "PASS 4: search(common) reproduces common-order BIC search"

// -----------------------------------------------------------------------------
// 6. Alternative information criteria
// -----------------------------------------------------------------------------

foreach crit in aic hqic bic {
    quietly umidas y, ///
        hfpredictors(x) hfn(5) pmax(2) ///
        search(common) ic(`crit') noconstant
    assert "`e(ic)'"=="`crit'"
}

di as result "PASS 5: AIC, HQIC, and BIC"

// -----------------------------------------------------------------------------
// 7. Direct horizon: exact hand-coded horizon(3) comparison
// -----------------------------------------------------------------------------

quietly umidas y, ///
    hfpredictors(x) hfn(5) porder(1) ///
    horizon(3) noconstant

assert e(horizon)==3
if strpos("`e(rhs)'","L3.y")==0 {
    di as error "horizon(3) was not applied to the LF target block"
    exit 9
}
if strpos("`e(rhs)'","L3.x0")==0 {
    di as error "horizon(3) was not applied to the HF block"
    exit 9
}

tempvar hsamp f_h f_hman dh
quietly gen byte `hsamp'=e(sample)
quietly predict double `f_h'
quietly regress y L3.y L3.x0 L3.x1 L3.x2 L3.x3 if `hsamp', noconstant
quietly predict double `f_hman' if `hsamp'
quietly gen double `dh'=abs(`f_h'-`f_hman') if `hsamp'
quietly summarize `dh', meanonly
assert r(max)<1e-10

di as result "PASS 6: horizon(3) timing"

// -----------------------------------------------------------------------------
// 8. Prediction, residual identity, stored results, and replay
// -----------------------------------------------------------------------------

quietly umidas y, ///
    hfpredictors(x z) hfn(5 3) ///
    porders(1 1 1) controls(L.c)

capture drop yhat uhat
predict double yhat
predict double uhat, residuals
assert abs(y-yhat-uhat)<1e-8 if e(sample)

matrix O_before=e(orders)
scalar ic_before=e(icvalue)
local rhs_before "`e(rhs)'"

quietly umidas
matrix O_after=e(orders)
assert rowsof(O_before)==rowsof(O_after) & colsof(O_before)==colsof(O_after)
forvalues j=1/3 {
    assert O_before[1,`j']==O_after[1,`j']
}
assert abs(e(icvalue)-ic_before)<1e-12
assert "`e(rhs)'"=="`rhs_before'"

quietly umidas, regression
assert abs(e(icvalue)-ic_before)<1e-12

di as result "PASS 7: prediction, stored results, and replay"

// -----------------------------------------------------------------------------
// 9. Expected validation errors
// -----------------------------------------------------------------------------

gen double g0=rnormal()
gen double g2=rnormal()

capture quietly umidas y, hfpredictors(g) hfn(5) porder(1)
if _rc==0 {
    di as error "expected malformed/insufficient HF stub error was not returned"
    exit 9
}

capture quietly umidas y, hfpredictors(x x) hfn(5 5) porder(1)
if _rc==0 {
    di as error "expected duplicate-stub error was not returned"
    exit 9
}

capture quietly umidas y, hfpredictors(x z) hfn(5 3 2) porder(1)
if _rc==0 {
    di as error "expected hfn() length error was not returned"
    exit 9
}

capture quietly umidas y, hfpredictors(x) hfn(5) porder(1) porders(1 1)
if _rc==0 {
    di as error "expected porder()/porders() conflict was not returned"
    exit 9
}

capture quietly umidas y, hfpredictors(x) hfn(5) pmax(2) porder(1)
if _rc==0 {
    di as error "expected pmax()/fixed-order conflict was not returned"
    exit 9
}

capture quietly umidas y, hfpredictors(x) hfn(5) search(foo)
if _rc==0 {
    di as error "expected invalid search() error was not returned"
    exit 9
}

di as result "PASS 8: validation errors"

di _newline as result "All umidas regression tests passed."
