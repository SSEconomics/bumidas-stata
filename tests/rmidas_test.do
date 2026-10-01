// -----------------------------------------------------------------------------
// rmidas_test.do
// Certification tests for rmidas
// BUMIDAS for Stata
// Version: 0.2.0
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------
//
// This file provides deterministic regression tests for rmidas.
// It verifies Almon, Step, Legendre, Exp-Almon, and Beta restrictions;
// block-specific orders and sampling ratios; direct forecast horizons;
// controls, prediction, replay, stored weights, and validation behavior.
//
// A successful run should end with:
//     All rmidas regression tests passed.
//
// See help rmidas for complete syntax and option documentation.
// -----------------------------------------------------------------------------

clear all
capture log close _all
set more off
set seed 01102026

discard
capture which rmidas
if _rc {
    di as error "rmidas.ado not found on the ado-path"
    exit 111
}
capture which nlrmidas_lse
if _rc {
    di as error "nlrmidas_lse.ado not found on the ado-path"
    exit 111
}

// -----------------------------------------------------------------------------
// 1. Construct deterministic synthetic data
// -----------------------------------------------------------------------------

set obs 500
gen time = tm(1985m1) + _n - 1
format time %tm
tsset time

// x: n=5, up to p=2 -> x0,...,x7
forvalues j=0/7 {
    gen double x`j'=rnormal()
}

// z: n=3, up to p=2 -> z0,...,z3
forvalues j=0/3 {
    gen double z`j'=rnormal()
}

gen double c=rnormal()
gen double u=rnormal()

gen double y=.
replace y=0 in 1
forvalues i=2/500 {
    quietly replace y = ///
          0.25*y[`i'-1] ///
        + 0.70*x0[`i'-1] ///
        - 0.30*x1[`i'-1] ///
        + 0.20*z0[`i'-1] ///
        + 0.15*c[`i'-1] ///
        + 0.40*u[`i'] in `i'
}

// Dedicated nonlinear DGPs centered near the command's starting shapes.
// Exp-Almon: c1=-2, c2=0.
scalar EX_DEN=0
forvalues j=1/4 {
    scalar EX_DEN=EX_DEN+exp(-2*`j')
}
forvalues j=1/4 {
    scalar EX_W`j'=exp(-2*`j')/EX_DEN
}

gen double uexp=rnormal()
gen double yexp=.
replace yexp=0 in 1
forvalues i=2/500 {
    quietly replace yexp = ///
          0.25*yexp[`i'-1] ///
        + 0.80*(EX_W1*x0[`i'-1] + EX_W2*x1[`i'-1] ///
              + EX_W3*x2[`i'-1] + EX_W4*x3[`i'-1]) ///
        + 0.10*uexp[`i'] in `i'
}

// Beta: c1=0, c2=0 -> uniform normalized shape weights.
gen double ubeta=rnormal()
gen double ybeta=.
replace ybeta=0 in 1
forvalues i=2/500 {
    quietly replace ybeta = ///
          0.25*ybeta[`i'-1] ///
        + 0.80*0.25*(x0[`i'-1]+x1[`i'-1]+x2[`i'-1]+x3[`i'-1]) ///
        + 0.10*ubeta[`i'] in `i'
}

// Two-block nonlinear DGPs, again centered near the default shape starts.
scalar EXZ_DEN=exp(-2)+exp(-4)
scalar EXZ_W1=exp(-2)/EXZ_DEN
scalar EXZ_W2=exp(-4)/EXZ_DEN

gen double umexp=rnormal()
gen double ymexp=.
replace ymexp=0 in 1
forvalues i=2/500 {
    quietly replace ymexp = ///
          0.20*ymexp[`i'-1] ///
        + 0.70*(EX_W1*x0[`i'-1] + EX_W2*x1[`i'-1] ///
              + EX_W3*x2[`i'-1] + EX_W4*x3[`i'-1]) ///
        + 0.35*(EXZ_W1*z0[`i'-1] + EXZ_W2*z1[`i'-1]) ///
        + 0.10*umexp[`i'] in `i'
}

gen double umbeta=rnormal()
gen double ymbeta=.
replace ymbeta=0 in 1
forvalues i=2/500 {
    quietly replace ymbeta = ///
          0.20*ymbeta[`i'-1] ///
        + 0.70*0.25*(x0[`i'-1]+x1[`i'-1]+x2[`i'-1]+x3[`i'-1]) ///
        + 0.35*0.50*(z0[`i'-1]+z1[`i'-1]) ///
        + 0.10*umbeta[`i'] in `i'
}

// -----------------------------------------------------------------------------
// 2. Almon degree 2: exact hand-coded comparison
// -----------------------------------------------------------------------------

quietly rmidas y, ///
    hfpredictors(x) hfn(5) porder(1) ///
    method(almon) degree(2) noconstant

assert "`e(cmd)'"=="rmidas"
assert "`e(engine)'"=="ols"
assert "`e(rmtype)'"=="almon"
assert e(degree)==2

matrix O=e(orders)
matrix T=e(hfterms)
assert O[1,1]==1 & O[1,2]==1
assert T[1,1]==4

tempvar a0 a1 a2 smpa f_rm f_man da
foreach v in `a0' `a1' `a2' {
    quietly gen double `v'=0
}
forvalues j=1/4 {
    local k=`j'-1
    quietly replace `a0'=`a0'+L.x`k'
    quietly replace `a1'=`a1'+`j'*L.x`k'
    quietly replace `a2'=`a2'+(`j'^2)*L.x`k'
}
quietly gen byte `smpa'=e(sample)
quietly predict double `f_rm'
quietly regress y L.y `a0' `a1' `a2' if `smpa', noconstant
quietly predict double `f_man' if `smpa'
quietly gen double `da'=abs(`f_rm'-`f_man') if `smpa'
quietly summarize `da', meanonly
assert r(max)<1e-10

di as result "PASS 1: Almon degree 2 reproduces hand-coded OLS"

// -----------------------------------------------------------------------------
// 2b. Infer hfn from single-block mfcollapse-style variable metadata
// -----------------------------------------------------------------------------

char x0[mfcollapse_hfn] "5"
quietly rmidas y, hfpredictors(x) porder(1) method(almon) noconstant
matrix HM=e(hfn)
assert HM[1,1]==5

di as result "PASS 1b: single-block hfn metadata inference"

// -----------------------------------------------------------------------------
// 3. Step-3: exact hand-coded comparison
// -----------------------------------------------------------------------------

quietly rmidas y, ///
    hfpredictors(x) hfn(5) porder(1) ///
    method(step) steps(3) noconstant

assert "`e(engine)'"=="ols"
assert e(steps)==3

tempvar w1 w2 w3 smps f_rs f_ms ds
foreach v in `w1' `w2' `w3' {
    quietly gen double `v'=0
}
forvalues g=1/3 {
    local lo=floor((`g'-1)*4/3)+1
    local hi=floor(`g'*4/3)
    local vg : word `g' of `w1' `w2' `w3'
    forvalues j=`lo'/`hi' {
        local k=`j'-1
        quietly replace `vg'=`vg'+L.x`k'
    }
}
quietly gen byte `smps'=e(sample)
quietly predict double `f_rs'
quietly regress y L.y `w1' `w2' `w3' if `smps', noconstant
quietly predict double `f_ms' if `smps'
quietly gen double `ds'=abs(`f_rs'-`f_ms') if `smps'
quietly summarize `ds', meanonly
assert r(max)<1e-10

di as result "PASS 2: Step-3 reproduces hand-coded OLS"

// -----------------------------------------------------------------------------
// 4. Legendre degree 3: exact hand-coded comparison
// -----------------------------------------------------------------------------

quietly rmidas y, ///
    hfpredictors(x) hfn(5) porder(1) ///
    method(legendre) degree(3) noconstant

assert "`e(engine)'"=="ols"
assert e(degree)==3

tempvar p0 p1 p2 p3 smpl f_rl f_ml dl
foreach v in `p0' `p1' `p2' `p3' {
    quietly gen double `v'=0
}
forvalues j=1/4 {
    local k=`j'-1
    local z=-1+2*(`j'-1)/(4-1)
    local P0=1
    local P1=`z'
    local P2=.5*(3*(`z')^2-1)
    local P3=.5*(5*(`z')^3-3*(`z'))
    quietly replace `p0'=`p0'+`P0'*L.x`k'
    quietly replace `p1'=`p1'+`P1'*L.x`k'
    quietly replace `p2'=`p2'+`P2'*L.x`k'
    quietly replace `p3'=`p3'+`P3'*L.x`k'
}
quietly gen byte `smpl'=e(sample)
quietly predict double `f_rl'
quietly regress y L.y `p0' `p1' `p2' `p3' if `smpl', noconstant
quietly predict double `f_ml' if `smpl'
quietly gen double `dl'=abs(`f_rl'-`f_ml') if `smpl'
quietly summarize `dl', meanonly
assert r(max)<1e-10

di as result "PASS 3: Legendre degree 3 reproduces hand-coded OLS"

// -----------------------------------------------------------------------------
// 5. Block-specific orders and multiple n_j
// -----------------------------------------------------------------------------

quietly rmidas y, ///
    hfpredictors(x z) hfn(5 3) ///
    porders(2 2 1) method(almon) degree(2) ///
    controls(L.c) noconstant

matrix O=e(orders)
matrix H=e(hfn)
matrix T=e(hfterms)
assert O[1,1]==2 & O[1,2]==2 & O[1,3]==1
assert H[1,1]==5 & H[1,2]==3
assert T[1,1]==8 & T[1,2]==2
assert "`e(controls)'"=="L.c"
matrix WM=e(weights)
assert rowsof(WM)==2
assert colsof(WM)==8

di as result "PASS 4: porders(), multiple sampling ratios, and controls"

// -----------------------------------------------------------------------------
// 6. Direct horizon: exact hand-coded Almon horizon(3) comparison
// -----------------------------------------------------------------------------

quietly rmidas y, ///
    hfpredictors(x) hfn(5) porder(1) ///
    method(almon) degree(2) horizon(3) noconstant

assert e(horizon)==3

tempvar h0 h1 h2 smph f_rh f_mh dh
foreach v in `h0' `h1' `h2' {
    quietly gen double `v'=0
}
forvalues j=1/4 {
    local k=`j'-1
    quietly replace `h0'=`h0'+L3.x`k'
    quietly replace `h1'=`h1'+`j'*L3.x`k'
    quietly replace `h2'=`h2'+(`j'^2)*L3.x`k'
}
quietly gen byte `smph'=e(sample)
quietly predict double `f_rh'
quietly regress y L3.y `h0' `h1' `h2' if `smph', noconstant
quietly predict double `f_mh' if `smph'
quietly gen double `dh'=abs(`f_rh'-`f_mh') if `smph'
quietly summarize `dh', meanonly
assert r(max)<1e-10

di as result "PASS 5: horizon(3) timing"

// -----------------------------------------------------------------------------
// 7. Exp-Almon: stabilized nonlinear estimation and stored-weight certification
// -----------------------------------------------------------------------------

quietly rmidas yexp, ///
    hfpredictors(x) hfn(5) porder(1) ///
    method(expalmon) noconstant

assert "`e(engine)'"=="nl"
assert e(converged)==1
assert inlist(e(shape_warning),0,1)

matrix W=e(weights)
matrix S=e(shapeweights)
matrix P=e(shapeparams)
matrix LF=e(lfcoef)
scalar RSS=e(rss)

scalar SS=0
forvalues j=1/4 {
    scalar SS=SS+S[1,`j']
    assert abs(W[1,`j']-P[1,1]*S[1,`j'])<1e-8
}
assert abs(SS-1)<1e-8

tempvar f_re f_we de sse
quietly predict double `f_re'
quietly gen double `f_we'=LF[1,1]*L.yexp
forvalues j=1/4 {
    local k=`j'-1
    quietly replace `f_we'=`f_we'+W[1,`j']*L.x`k'
}
quietly gen double `de'=abs(`f_re'-`f_we') if e(sample)
quietly summarize `de', meanonly
assert r(max)<1e-8
quietly gen double `sse'=(yexp-`f_re')^2 if e(sample)
quietly summarize `sse', meanonly
assert abs(RSS-r(mean)*r(N))<1e-6*max(1,abs(RSS))

di as result "PASS 6: Exp-Almon stabilized nonlinear estimation"

// -----------------------------------------------------------------------------
// 8. Beta: stabilized nonlinear estimation and stored-weight certification
// -----------------------------------------------------------------------------

quietly rmidas ybeta, ///
    hfpredictors(x) hfn(5) porder(1) ///
    method(beta) noconstant

assert "`e(engine)'"=="nl"
assert e(converged)==1
assert inlist(e(shape_warning),0,1)

matrix W=e(weights)
matrix S=e(shapeweights)
matrix P=e(shapeparams)
matrix LF=e(lfcoef)
scalar RSS=e(rss)

scalar SS=0
forvalues j=1/4 {
    scalar SS=SS+S[1,`j']
    assert abs(W[1,`j']-P[1,1]*S[1,`j'])<1e-8
}
assert abs(SS-1)<1e-8

tempvar f_rb f_wb db ssb
quietly predict double `f_rb'
quietly gen double `f_wb'=LF[1,1]*L.ybeta
forvalues j=1/4 {
    local k=`j'-1
    quietly replace `f_wb'=`f_wb'+W[1,`j']*L.x`k'
}
quietly gen double `db'=abs(`f_rb'-`f_wb') if e(sample)
quietly summarize `db', meanonly
assert r(max)<1e-8
quietly gen double `ssb'=(ybeta-`f_rb')^2 if e(sample)
quietly summarize `ssb', meanonly
assert abs(RSS-r(mean)*r(N))<1e-6*max(1,abs(RSS))

di as result "PASS 7: Beta stabilized nonlinear estimation"

// -----------------------------------------------------------------------------
// 9. Multiple nonlinear HF blocks
// -----------------------------------------------------------------------------

foreach wf in expalmon beta {
    if "`wf'"=="expalmon" local dep ymexp
    else                    local dep ymbeta

    quietly rmidas `dep', ///
        hfpredictors(x z) hfn(5 3) ///
        porders(1 1 1) method(`wf') noconstant

    assert "`e(engine)'"=="nl"
    assert e(converged)==1

    matrix MW=e(weights)
    matrix MS=e(shapeweights)
    matrix MP=e(shapeparams)
    matrix MT=e(hfterms)

    assert rowsof(MW)==2 & rowsof(MS)==2 & rowsof(MP)==2
    assert colsof(MP)==3
    assert MT[1,1]==4 & MT[1,2]==2

    forvalues r=1/2 {
        if `r'==1 local K=4
        else      local K=2
        scalar MSS=0
        forvalues j=1/`K' {
            scalar MSS=MSS+MS[`r',`j']
            assert abs(MW[`r',`j']-MP[`r',1]*MS[`r',`j'])<1e-8
        }
        assert abs(MSS-1)<1e-8
    }
}

di as result "PASS 8: multiple nonlinear HF blocks"

// -----------------------------------------------------------------------------
// 10. Prediction, constant handling, and replay
// -----------------------------------------------------------------------------

quietly rmidas y, ///
    hfpredictors(x z) hfn(5 3) ///
    porders(1 1 1) method(step) steps(2) ///
    controls(L.c)

assert e(constant)<.
capture drop yhat uhat
predict double yhat
predict double uhat, residuals
assert abs(y-yhat-uhat)<1e-8 if e(sample)

matrix O_before=e(orders)
local type_before "`e(rmtype)'"
quietly rmidas
matrix O_after=e(orders)
assert rowsof(O_before)==rowsof(O_after) & colsof(O_before)==colsof(O_after)
forvalues j=1/3 {
    assert O_before[1,`j']==O_after[1,`j']
}
assert "`e(rmtype)'"=="`type_before'"
quietly rmidas, regression
assert "`e(rmtype)'"=="`type_before'"

di as result "PASS 9: prediction, constant handling, and replay"

// -----------------------------------------------------------------------------
// 11. Expected validation errors
// -----------------------------------------------------------------------------

gen double g0=rnormal()
gen double g2=rnormal()

capture quietly rmidas y, hfpredictors(x) hfn(5) method(foo)
if _rc==0 {
    di as error "expected invalid method() error was not returned"
    exit 9
}

capture quietly rmidas y, hfpredictors(x x) hfn(5 5) method(almon)
if _rc==0 {
    di as error "expected duplicate-stub error was not returned"
    exit 9
}

capture quietly rmidas y, hfpredictors(g) hfn(5) porder(1) method(almon)
if _rc==0 {
    di as error "expected malformed/insufficient HF stub error was not returned"
    exit 9
}

capture quietly rmidas y, hfpredictors(x) hfn(5) porder(1) porders(1 1) method(almon)
if _rc==0 {
    di as error "expected porder()/porders() conflict was not returned"
    exit 9
}

capture quietly rmidas y, hfpredictors(x) hfn(5) method(beta) degree(2)
if _rc==0 {
    di as error "expected invalid degree() option error was not returned"
    exit 9
}

capture quietly rmidas y, hfpredictors(x) hfn(5) method(almon) steps(3)
if _rc==0 {
    di as error "expected invalid steps() option error was not returned"
    exit 9
}

capture quietly rmidas y, hfpredictors(x z) hfn(5 3 2) method(almon)
if _rc==0 {
    di as error "expected hfn() length error was not returned"
    exit 9
}

di as result "PASS 10: validation errors"

di _newline as result "All rmidas regression tests passed."
