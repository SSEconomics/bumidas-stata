// -----------------------------------------------------------------------------
// bumidas_simulation.do
// Simulation example for bumidas
// BUMIDAS for Stata
// Version: 0.1.1
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------
/*
This file provides an illustrative simulation of mixed-frequency forecasting
when the high-frequency target and predictor are observed.

A bivariate high-frequency VAR(p) is simulated and aggregated to a lower
frequency by taking within-period averages. The first 75 percent of the
lower-frequency sample is used for estimation and the remaining observations
are used for forecast evaluation.

The following forecasts are compared:

  1. Bottom-up recursive forecast
  2. BUMIDAS with the known VAR order
  3. BUMIDAS-BIC
  4. Unrestricted MIDAS (UMIDAS)
  5. Restricted MIDAS with a linear Almon polynomial
  6. Low-frequency VAR
  7. End-of-period no-change
  8. Low-frequency no-change

Forecast performance is reported using MSFE ratios relative to the
low-frequency no-change forecast and mean directional accuracy (MDA).

This is a compact demonstration of the methods and is not intended to
reproduce the full Monte Carlo experiments in the associated paper.

For the BUMIDAS methodology, see:

  Lee, Quinlan and Stephen Snudden (2025), "Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS)." SSRN 5312038

For UMIDAS, see Foroni, Marcellino, and Schumacher (2015).
For the linear Almon distributed lag, see Almon (1965).

Requirements:
  https://github.com/SSEconomics/bumidas-stata
*/
// -----------------------------------------------------------------------------

clear all
capture log close _all

set linesize 255
set more off
set seed 369

// -----------------------------
// Simulation parameters
// -----------------------------

local varp=1            // HF VAR order: 1 or 3
local hfperiods=20      // HF observations per LF period
local lfperiods=2000    // number of LF periods
local nburn=500         // HF burn-in observations
local cut=0.75          // fraction of LF sample used for estimation
local var=1             // innovation variance

// VAR(1) coefficients (used when varp=1)
local rho11=0.9	
local rho22=0.9			
local rho12=0.1	
local rho21=0.095	

// Contemporaneous impact coefficients
local eta1=0		
local eta2=0		

// -----------------------------
// Log file
// -----------------------------

local logfile "MIDAS_VAR`varp'_T`lfperiods'_n`hfperiods'.log"

log using "`logfile'", replace text name(midaslog)

// -----------------------------
// Generate High-frequency Data 
// -----------------------------

// Sample
local numobs= `hfperiods'*`lfperiods'+`nburn'  
set obs `numobs'  
gen t=_n
tsset t
local sd=sqrt(`var')

gen double u=rnormal(0,`sd')
gen double e=rnormal(0,`sd')
gen double y=0
gen double x=0

if `varp'==1 {
	forvalues d=2/`numobs' {
		local dm1=`d'-1
		qui replace y = `rho11'*y[`dm1'] + `rho12'*x[`dm1'] + u[`d'] + `eta1'*e[`d'] in `d'
		qui replace x = `rho21'*y[`dm1'] + `rho22'*x[`dm1'] + `eta2'*u[`d'] + e[`d'] in `d'
	}
}
else if `varp'==3 {
	forvalues d=4/`numobs' {
		local dm1=`d'-1
		local dm2=`d'-2
		local dm3=`d'-3
		qui replace y = ///
			0.55*y[`dm1'] +  0.10*x[`dm1'] ///
			+ 0.20*y[`dm2'] + 0.05*x[`dm2'] ///
			+ 0.10*y[`dm3'] + 0.02*x[`dm3'] ///
			+ u[`d'] + `eta1'*e[`d'] in `d'

		qui replace x = ///
			0.05*y[`dm1'] + 0.50*x[`dm1'] ///
			+ 0.02*y[`dm2'] + 0.18*x[`dm2'] ///
			+ 0.01*y[`dm3'] + 0.08*x[`dm3'] ///
			+ `eta2'*u[`d'] + e[`d'] in `d'
	}
}
else {
	di as error "varp must equal 1 or 3"
	exit 198
}
	
	
drop u e

// Burn initial observations
if `nburn'>0 {
	drop in 1/`nburn'
}

replace t=_n
tsset t

local ndaily=_N

// The forecast construction assumes complete periods
if mod(`ndaily',`hfperiods')!=0 {
	di as error "Post-burn sample is not divisible by days per period"
	exit 459
}

// -----------------------------
// Bottom-Up Forecasts
// -----------------------------

gen long mm=ceil(t/`hfperiods')
local nperiods=`ndaily'/`hfperiods'

// Initial estimation sample (high-frequency)
local startraw=round(`cut'*`nperiods',1)
local firstorigin=`startraw'*`hfperiods'
local lastorigin=`ndaily'-`hfperiods'
local origin=`firstorigin'
	
// Bottom-up forecast
gen double f0=.
gen double f_y=.
gen double f_x=.

// Fixed initial-sample VAR
qui var y x in 1/`firstorigin', noconstant lags(1/`varp')

// Cache estimated coefficients
forvalues p=1/`varp' {
	local byy`p'=_b[y:L`p'.y]
	local byx`p'=_b[y:L`p'.x]
	local bxy`p'=_b[x:L`p'.y]
	local bxx`p'=_b[x:L`p'.x]
}

while `origin'<=`lastorigin' {
	local forecast_start=`origin'+1
	local forecast_end=`origin'+`hfperiods'
	local history_start=`origin'-`varp'+1
	qui replace f_y=y in `history_start'/`origin'
	qui replace f_x=x in `history_start'/`origin'
	if `varp'==1 {
		forvalues d=`forecast_start'/`forecast_end' {
			local dm1=`d'-1
			qui replace f_y = `byy1'*f_y[`dm1'] + `byx1'*f_x[`dm1'] in `d'
			qui replace f_x = `bxy1'*f_y[`dm1'] + `bxx1'*f_x[`dm1'] in `d'
		}
	}
	else if `varp'==3 {
		forvalues d=`forecast_start'/`forecast_end' {
			local dm1=`d'-1
			local dm2=`d'-2
			local dm3=`d'-3
			qui replace f_y = ///
				`byy1'*f_y[`dm1'] + `byx1'*f_x[`dm1'] ///
				+ `byy2'*f_y[`dm2'] + `byx2'*f_x[`dm2'] ///
				+ `byy3'*f_y[`dm3'] + `byx3'*f_x[`dm3'] ///
				in `d'

			qui replace f_x = ///
				`bxy1'*f_y[`dm1'] + `bxx1'*f_x[`dm1'] ///
				+ `bxy2'*f_y[`dm2'] + `bxx2'*f_x[`dm2'] ///
				+ `bxy3'*f_y[`dm3'] + `bxx3'*f_x[`dm3'] ///
				in `d'
		}
	}

	qui summarize f_x in `forecast_start'/`forecast_end', meanonly
	qui replace f0=r(mean) in `forecast_end'
	local origin=`origin'+`hfperiods'
}

drop f_y f_x

// -----------------------------
// Mixed-Freq Data
// -----------------------------

// End-of-period indictor
bysort mm (t): gen byte eop = _n==_N

// Period average
sort mm
by mm: egen ax=mean(x)
by mm: egen ay=mean(y)
sort t
tsset t

// Number of HF terms and maximum lag index
local nhf = `varp'*(`hfperiods'-1)
local maxlag = `nhf'-1

// Mixed-frequency lags
foreach lg of numlist 0/`maxlag' {
	qui gen ldy`lg'=L`lg'.y
	qui gen ldx`lg'=L`lg'.x
}

// Convert LF to HF data 
keep if eop
drop eop
replace t=mm
tsset t
local numobs = _N

// Start and end dates of forecast sample
local startraw = `cut'*`numobs' 
local start0 = round(`startraw', 1) 	
local fend= `numobs'		

// one step ahead
local fstart= `start0'+1	

// -----------------------------
// Mixed-Freq Forecasts
// -----------------------------

// ----------------
// BUMIDAS 
if `varp'==1 qui reg ax L.ldy0 L.ldx0 in 1/`start0', noconstant
else if `varp'==3 qui reg ax L.ldx0 L.ldx1 L.ldx2 L.ldy0 L.ldy1 L.ldy2 in 1/`start0', noconstant
qui predict double f1 in `fstart'/`fend'

// ----------------
// BUMIDAS-BIC
// Recursive grid search - include EoM of both hftarget series 
qui bumidas ax in 1/`start0', hftarget(ldy ldx) hfmax(`nhf') search(recursive) ic(bic) horizon(1) noconstant 
qui predict double f2 in `fstart'/`fend'

// ----------------
// UMIDAS (OLS)
if `varp'==1 qui reg ax L.ax L.ldy* in 1/`start0', noconstant
else if `varp'==3 qui reg ax L.ax L2.ax L3.ax L.ldy* in 1/`start0', noconstant
qui predict double f3 in `fstart'/`fend'	

// ----------------
// RMIDAS - Almon Linear (OLS)
tempvar wy0 wy1 wy2
qui gen double `wy0'=0
qui gen double `wy1'=0
qui gen double `wy2'=0
forvalues j=1/`nhf' {
	local lag=`j'-1
	qui replace `wy0'=`wy0'+L1.ldy`lag'
	qui replace `wy1'=`wy1'+`j'*L1.ldy`lag'
	qui replace `wy2'=`wy2'+(`j'^2)*L1.ldy`lag'
}
if `varp'==1 {
	qui reg ax L.ax `wy0' `wy1' `wy2' in 1/`start0', noconstant
}
else if `varp'==3 {
	qui reg ax L.ax L2.ax L3.ax `wy0' `wy1' `wy2' in 1/`start0', noconstant
}
qui predict double f4 in `fstart'/`fend'		

// ----------------
// Aggregate VAR
qui var ax ay in 1/`start0', noconstant lags(1/`varp') 
qui predict double f5 in `fstart'/`fend', equation(ax)

// ----------------
// End-of-Month No-change 
qui gen double f6 = l.ldx0 in `fstart'/`fend'	

// ----------------
// Monthly Average No-change  
qui gen double f7 = l.ax in `fstart'/`fend'   

// ----------------
// Number of models
local nmod=7
// Names of models
local f0name  = "Bottom-up recursive"
local f1name  = "BUMIDAS"
local f2name  = "BUMIDAS-BIC"
local f3name  = "UMIDAS"
local f4name  = "Linear Almon"
local f5name  = "LF VAR"
local f6name = "EoP no-change"
local f7name = "LF no-change"

// -----------------------------
// Evaluate Forecasts
// -----------------------------

// Forecast errors and directional accuracy 
forvalues j=0/`nmod' {
	qui gen double error`j'=ax-f`j' in `fstart'/`fend'
	qui gen sign`j'= ((ax-L.ax)*(f`j'-L.ax)>0) if !missing(ax,f`j',L.ax) in `fstart'/`fend'
}
	
// MSFE, mean directional accuracy (MDA)
forvalues j=0/`nmod' {
    qui gen double error_`j'_sq=error`j'^2
    qui sum error_`j'_sq
    scalar msfe`j'=r(mean)
    qui sum sign`j'
    scalar sr`j'=r(mean)
}

// MSFE ratios relative to low-frequency no-change
forvalues j=0/`nmod' {
    scalar m`j'=msfe`j'/msfe`nmod'
}

// Print simulation setup
di _newline as text "Simulation: " ///
    "Var=" as result %3.1f `var' ///
    as text " | Burn=" as result %4.0f `nburn' ///
    as text " | Train=" as result %4.2f `cut' ///
    as text " | HF/LF=" as result %2.0f `hfperiods' ///
    as text " | LF obs=" as result %4.0f `lfperiods' ///
    as text " | VAR(" as result %1.0f `varp' as text ")"


// Print MSFE Ratios and Mean Directional Accuracy 
forvalues j=0/`nmod' {
    di as text %-20s "`f`j'name'" ///
       " Rel. MSFE = " as result %5.3f m`j' ///
       as text " | MDA = " as result %5.3f sr`j'
}

// -----------------------------
// References
// -----------------------------

/*
Method-specific references

Bottom-up recursive:
	 - Benmoussa, A. A., Ellwanger, R., and Snudden, S. (2026). Carpe diem: Can daily oil prices improve model-based forecasts of the real price of
crude oil? International Journal of Forecasting, 42(1), 281–295.

BUMIDAS and BUMIDAS-BIC:
	- Lee, Q., and Snudden, S. (2025). Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS). SSRN Working Paper 5312038.

UMIDAS:
	- Foroni, C., Marcellino, M., and Schumacher, C. (2015). Unrestricted mixed data sampling (MIDAS): MIDAS regressions with unrestricted lag polynomials. Journal of the Royal Statistical Society: Series A (Statistics in Society), 178(1), 57–82.

Linear Almon distributed lag:
	- Almon, S. (1965). The distributed lag between capital appropriations and expenditures. Econometrica, 33(1), 178–196.
	- Ghysels, E., Sinko, A., and Valkanov, R. (2007). MIDAS regressions: Further results and new directions. Econometric Reviews, 26(1), 53–90.

End-of-period no-change forecasts of temporal averages:
	- McCarthy, M., & Snudden, S. (2025). Predictable by construction: Assessing forecast directional accuracy of temporal aggregates. Applied Economics, 1-16.
	- Ellwanger, R., and Snudden, S. (2023). Forecasts of the real price of oil revisited: Do they beat the random walk? Journal of Banking & Finance,
154, 106962.


*/

// -----------------------------
// Close log
// -----------------------------

log close midaslog

//---------------------------------------------------------------------------------------------------------
// End of file
//---------------------------------------------------------------------------------------------------------

