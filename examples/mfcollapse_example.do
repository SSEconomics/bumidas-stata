// -----------------------------------------------------------------------------
// mfcollapse_example.do
// Examples for mfcollapse
// BUMIDAS for Stata
// Version: 0.1.1
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------
//
// This file demonstrates the main mfcollapse workflow for converting
// higher-frequency data to a lower-frequency dataset while retaining the
// high-frequency observations needed for mixed-frequency modeling.
//
// See help mfcollapse for complete syntax and option documentation.
// -----------------------------------------------------------------------------

clear all
set more off

// -----------------------------
// Example 1: Daily -> monthly
// -----------------------------

clear
set obs 900

// Daily calendar
gen time = mdy(1,1,2020) + _n - 1
format time %td

// Keep weekdays only
drop if inlist(dow(time),0,6)

// Example daily series
gen x = 100 + _n

// Missing daily observations are allowed
replace x = . if inlist(time, ///
    mdy(1,20,2020), ///
    mdy(2,17,2020))

list time x in 1/10

mfcollapse x, date(time) frequency(monthly)

list
return list


// -----------------------------
// Example 2: Multiple HF variables
// -----------------------------

clear
set obs 900

gen time = mdy(1,1,2020) + _n - 1
format time %td
drop if inlist(dow(time),0,6)

gen x1 = 100 + _n
gen x2 = 200 + 2*_n
gen x3 = 300 + 3*_n

// Variables on the same tab/schedule share missing dates
replace x1 = . if time==mdy(1,20,2020)
replace x2 = . if time==mdy(1,20,2020)
replace x3 = . if time==mdy(1,20,2020)

mfcollapse x1 x2 x3, ///
    date(time) frequency(monthly) ar(1)

list time x1_ld0 x1_ld1 x1_ave ///
          x2_ld0 x2_ld1 x2_ave

return list


// -----------------------------
// Example 3: Monthly -> quarterly
// -----------------------------

clear
set obs 900

gen time = ym(2020,1) + _n - 1
format time %tm

gen x = 100 + _n

mfcollapse x, date(time) frequency(quarterly)

list
return list


// -----------------------------
// Example 4: Explicit lag length
// -----------------------------

clear
set obs 900

gen time = mdy(1,1,2020) + _n - 1
format time %td
drop if inlist(dow(time),0,6)

gen x = 100 + _n

// Create lag 0 through lag 10 directly
mfcollapse x, ///
    date(time) frequency(monthly) lags(10)

describe
return list