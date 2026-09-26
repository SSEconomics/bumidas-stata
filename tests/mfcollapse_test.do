// -----------------------------------------------------------------------------
// mfcollapse_test.do
// Certification tests for mfcollapse
// BUMIDAS for Stata
// Version: 0.2.0
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------
//
// This file provides deterministic regression tests for mfcollapse.
// It verifies the main frequency-conversion, lag-construction, anchor,
// and validation behavior of the command.
//
// A successful run should complete without error.
//
// See help mfcollapse for complete syntax and option documentation.
// -----------------------------------------------------------------------------

clear all
capture log close _all
set more off

discard
which mfcollapse

// -----------------------------
// 1. Daily -> monthly
// Missing observations, multiple variables, ar()
// -----------------------------

set obs 65
gen time = mdy(1,1,2020) + _n - 1
format time %td
drop if inlist(dow(time),0,6)

gen x = _n
gen z = 2*_n

// Common missing observation: lag sequence should skip this date
replace x = . if time==mdy(1,30,2020)
replace z = . if time==mdy(1,30,2020)

quietly summarize x if time==mdy(1,31,2020), meanonly
scalar x0 = r(mean)
quietly summarize x if time==mdy(1,29,2020), meanonly
scalar x1 = r(mean)
quietly summarize x if mofd(time)==ym(2020,1), meanonly
scalar xave = r(mean)

tempfile daily
save `daily'

mfcollapse x z, date(time) frequency(monthly) ar(1)

local fmt : format time
local source `r(source_frequency)'
local target `r(frequency)'

assert "`source'"=="daily"
assert "`target'"=="monthly"
assert substr("`fmt'",1,3)=="%tm"
assert r(hfn)==20
assert r(maxlag)==19
assert r(N_dropped)==1
assert x_ld0==scalar(x0) if time==ym(2020,1)
assert x_ld1==scalar(x1) if time==ym(2020,1)
assert abs(x_ave-scalar(xave))<1e-10 if time==ym(2020,1)
confirm variable z_ld19 z_ave

// -----------------------------
// 2. Daily -> weekly / quarterly
// -----------------------------

foreach f in weekly quarterly {
    use `daily', clear
    mfcollapse x, date(time) frequency(`f') lags(2)

    local fmt : format time
    local source `r(source_frequency)'
    local target `r(frequency)'

    assert "`source'"=="daily"
    assert "`target'"=="`f'"
    assert r(maxlag)==2

    if "`f'"=="weekly"    assert substr("`fmt'",1,3)=="%tw"
    if "`f'"=="quarterly" assert substr("`fmt'",1,3)=="%tq"
}

// -----------------------------
// 3. Weekly -> monthly / quarterly
// -----------------------------

clear
set obs 40
gen time = yw(2020,1) + _n - 1
format time %tw
gen x = _n

tempfile weekly
save `weekly'

foreach f in monthly quarterly {
    use `weekly', clear
    mfcollapse x, date(time) frequency(`f') lags(2)

    local fmt : format time
    local source `r(source_frequency)'
    local target `r(frequency)'

    assert "`source'"=="weekly"
    assert "`target'"=="`f'"

    if "`f'"=="monthly"   assert substr("`fmt'",1,3)=="%tm"
    if "`f'"=="quarterly" assert substr("`fmt'",1,3)=="%tq"
}

// -----------------------------
// 4. Monthly -> quarterly
// Default ar() and explicit lags()
// -----------------------------

clear
set obs 12
gen time = ym(2020,1) + _n - 1
format time %tm
gen x = _n

tempfile monthly
save `monthly'

mfcollapse x, date(time) frequency(quarterly)

local fmt : format time
local source `r(source_frequency)'
local target `r(frequency)'

assert "`source'"=="monthly"
assert "`target'"=="quarterly"
assert substr("`fmt'",1,3)=="%tq"
assert r(hfn)==3
assert r(maxlag)==2
assert x_ld0==3 if time==yq(2020,1)
assert x_ld1==2 if time==yq(2020,1)
assert x_ld2==1 if time==yq(2020,1)
assert x_ave==2 if time==yq(2020,1)

use `monthly', clear
mfcollapse x, date(time) frequency(quarterly) lags(5)
assert r(maxlag)==5
confirm variable x_ld5

di _newline as result "All mfcollapse regression tests passed."
