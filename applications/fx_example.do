// -----------------------------------------------------------------------------
// fx_example.do
// Foreign-exchange application for bumidas
// BUMIDAS for Stata
// Version: 0.2.0
// -----------------------------------------------------------------------------
// Author: Stephen Snudden, PhD
// Wilfrid Laurier University
// Website: https://stephensnudden.com/
// Repository: https://github.com/SSEconomics/bumidas-stata
// -----------------------------------------------------------------------------

/*
This file demonstrates BUMIDAS forecasting of monthly-average exchange rates
using higher-frequency commodity-price information. The baseline application
uses daily exchange rates and daily WTI oil prices and compares BUMIDAS with
a low-frequency VAR, UMIDAS, and restricted MIDAS.

Data sources:

CAD/USD and NOK/USD
  Daily nominal spot exchange rates from the Federal Reserve Board H.10
  release, obtained through FRED (DEXCAUS and DEXNOUS). 

WTI
  Daily Cushing, Oklahoma West Texas Intermediate spot price FOB from the
  U.S. Energy Information Administration (series RWTC), U.S. dollars per
  barrel.

Effective exchange rates
  BIS daily narrow nominal effective exchange-rate indices for Canada and Norway.

The paper application uses data beginning in 1986M1 and evaluates
monthly-average exchange-rate forecasts over 2000M1-2025M6.

See Lee, Quinlan and Stephen Snudden (2025),
"Bottom-Up Mixed-Frequency Data Sampling (BUMIDAS)," SSRN 5312038,
for complete data construction and application details.
*/

// -----------------------------------------------------------------------------

/*
//Requirements:
//  Install bumidas and mfcollapse from
//  https://github.com/SSEconomics/bumidas-stata

net describe bumidas, from("https://raw.githubusercontent.com/SSEconomics/bumidas-stata/main")

net install bumidas, from("https://raw.githubusercontent.com/SSEconomics/bumidas-stata/main") replace
*/

// -----------------------------
// Preamble
// -----------------------------

clear all
capture log close _all

set linesize 255
set more off
capture set maxvar 5000

// -----------------------------
// Choose Targets and benchmarks
// -----------------------------

// No-Change Forecast is AVE (ave) or EoM (ld0)
local ncfor="ave"	

// Forecast Target is AVE (ave) or EoM (ld0)
local tar="ave"	

// Forecast Variable
local vari="cad"
*local vari="nok"
*local vari="cadeern"
*local vari="nokeern"

// Lag order used by benchmark specifications
local ar=1

// Forecast horizons
local horizons = "1 3"

// -----------------------------
// Log file
// -----------------------------

// Log Results
capture log close

local logfile "MIDASfx_`vari'_VAR`ar'_`tar'TAR_`ncfor'NC.log"

log using "`logfile'", replace text name(midaslog)

// -----------------------------
// FX: daily YYYYMMDD dates
// -----------------------------

import excel using "DataD.xlsx", sheet("`vari'") firstrow clear
tostring date, gen(datestr) format(%08.0f)
gen double time = daily(datestr,"YMD")
format time %td

mfcollapse `vari', date(time) frequency(monthly) ar(`ar')

local hfn_`vari' = r(hfn)

save "Data.dta", replace

// -----------------------------
// WTI: daily YYYYMMDD dates
// -----------------------------

import excel using "DataD.xlsx", sheet("wti") firstrow clear
tostring date, gen(datestr) format(%08.0f)
gen double time = daily(datestr,"YMD")
format time %td

mfcollapse wti, date(time) frequency(monthly) ar(`ar')

local hfn_wti = r(hfn)

merge 1:1 time using "Data.dta", nogenerate
save "Data.dta", replace


// ***************************
// Transform Data
// ***************************
tsset time
qui gen year  = year(dofm(time))
qui gen month = month(dofm(time))

// Monthly Average data
qui gen ao = (wti_ave/l.wti_ave-1)*100
qui gen ae = (`vari'_ave/l.`vari'_ave-1)*100

// Mixed Frequency Data Transformation - Predictor
local npo = `ar'*(`hfn_wti'-1)
forvalues i = 0(1)`=`npo'-1'{
	qui gen llo`i'= (wti_ld`i'/l.wti_ld`i'-1)*100
}

// Mixed Frequency Data Transformation - Target
local npe = `ar'*(`hfn_`vari''-1)
forvalues i = 0(1)`=`npe'-1'{
	qui gen lle`i'= (`vari'_ld`i'/l.`vari'_ld`i'-1)*100
}

// ***************************
// Expanding Window Out-of-Sample Forecasts
// ***************************

// Starting Sample for FX
drop if time<tm(1986m1)

// Input dates (Manually)
local startm = 1								// Start month of forecast evaluation sample     
local starty = 2000								// Start year of forecast evaluation sample 
local endm = 6									// End month of forecast evaluation sample 
local endy = 2025								// End year of forecast evaluation sample 

// Sets date counters (Automatic)
local yy1 = year[1]
local mm1 = month[1]
local adj = tm(`yy1'm`mm1')-1 				// Default for time is 0 at 1960m1 (see tsset) Adjusts so start = 1
local start = tm(`starty'm`startm')-`adj'-1 // Origin before first evaluation month
local start0 =`start'						// Counter for period
local startd =`start'+1						// Counter for period+1
local end =tm(`endy'm`endm')-`adj'-1 	    // End of forecast evaluation sample minus one (evaluation sample -1)
local mm = `startm'							// Start month of loop
local aa = `starty'							// Start year of loop
local ar1=`ar'-1							// Largest HF suffix for known-order BUMIDAS

local mods=5
// For saving forecasts
forvalues i = 1(1)`mods'{
	foreach h in `horizons' {
		local startd=`start0'+`h'
		qui gen for`h'_mod`i'=. in `startd'/`end'
	}
}

// Loop from start to end
while  `start0'<=`end' {
	display "Forecasting: `aa'm`mm'" 
	// Restrict data to information available 												
	qui gen ax= ao in 1/`start0'	
	qui gen ay= ae in 1/`start0'	
	// Forecasts
	foreach h in `horizons' {
		qui gen y= (`vari'_`tar'/l`h'.`vari'_`tar'-1)*100  in 1/`start0'
		qui gen yl= (`vari'_`tar'/l`h'.`vari'_ld0-1)*100  in 1/`start0'
		local startd=`start0'+`h'
		local startd1=`start0'+1
		
		// -------
		// Model 1 
		local method1 "BUMIDAS"
		qui reg yl L`h'.llo0-llo`ar1' L`h'.lle0-lle`ar1', noconstant	
		qui predict f_y			    					 
		qui replace for`h'_mod1=f_y in `startd'/`startd'        
		drop f_y
		
		// -------
		// Model 2
		local method2   "BUMIDAS-BIC"
		qui bumidas yl, hftarget(lle llo) hfmax(`npo') search(recursive) ic(bic) horizon(`h') noconstant 
		qui predict double f_y in `startd'/`startd'
		qui replace for`h'_mod2=f_y in `startd'/`startd'
		drop f_y
		
		// -------
		// Model 3 
		local method3 "LF VAR"
		qui var ay ax, lags(1/`ar')				 
		fcast compute f_, step(`h') nose
		qui gen double flvl = `vari'_`tar' in `start0'/`start0'
		qui replace flvl=(1+f_ay/100)*L.flvl in `startd1'/`startd'
		qui replace for`h'_mod3=100*(flvl/L`h'.`vari'_`tar'-1) in `startd'/`startd'
		drop f_ay f_ax flvl
		
		// -------
		// Model 4 - UMIDAS
		local method4 "UMIDAS"
		qui umidas y in 1/`start0', ///
			hfpredictors(llo) ///
			hfn(`hfn_wti') ///
			porder(`ar') ///
			horizon(`h') ///
			noconstant
		qui predict double f_y in `startd'/`startd'
		qui replace for`h'_mod4=f_y in `startd'/`startd'
		drop f_y

		// -------
		// Model 5 - RMIDAS, linear Almon
		local method5 "RMIDAS"
		qui rmidas y in 1/`start0', ///
			hfpredictors(llo) ///
			hfn(`hfn_wti') ///
			porder(`ar') ///
			method(almon) degree(2) ///
			horizon(`h') ///
			noconstant
		qui predict double f_y in `startd'/`startd'
		qui replace for`h'_mod5=f_y in `startd'/`startd'
		drop f_y
		
		// Clean-up
		drop yl y
	} //h
	drop ax ay 
	// Update period by one
	local start0=`start0'+1
	local startd=`startd'+1
	// Update real time data by one period
    if `mm'<12 { 
      local mm=`mm'+1 
    } 
    else if `mm'==12 { 
      local mm=1 
      local aa=`aa'+1 
    }
}

// ************************
// Summarize Forecast Performance
// ************************

// Forecast Target Level 	
qui gen y= `vari'_`tar'	

// Define Baseline No-change
gen y_nc=`vari'_`ncfor'

// Model 0: End-of-Month No-Change
local method0 "EoP NC"
local datatype0 "Mixed"
foreach h in `horizons' {
	local startd=`start'+`h'
	qui gen lvlfor`h'_mod0=L`h'.`vari'_ld0 in `startd'/`end'
}
	
// Transform Forecasts if needed
forvalues i=1(1)`mods' {
	foreach h in `horizons' {
		local startd=`start'+`h'
		if `i'==1 | `i'==2 qui gen lvlfor`h'_mod`i'=(1+for`h'_mod`i'/100)*l`h'.`vari'_ld0 in `startd'/`end'
		else qui gen lvlfor`h'_mod`i'=(1+for`h'_mod`i'/100)*l`h'.`vari'_`tar' in `startd'/`end'
	}
}

// MSFE ratios and one-sided DM p-values
foreach h in `horizons' {
	local startd=`start'+`h'
	qui gen double error_rw=y-L`h'.y_nc in `startd'/`end'
	qui gen double error_rwsq=error_rw^2
	qui sum error_rwsq
	scalar msfe_rw=r(mean)
	forvalues i=0(1)`mods' {
		qui gen double error_mod`i'=y-lvlfor`h'_mod`i' in `startd'/`end'
		qui gen double error_mod`i'sq=error_mod`i'^2
		qui sum error_mod`i'sq
		scalar msfe_`i'=r(mean)
		// DM test with Newey-West HAC standard errors
		qui gen double d`i'=error_rwsq-error_mod`i'sq
		qui count if !missing(d`i') in `startd'/`end'
		local obs=r(N)
		local nlags=round(4*(`obs'/100)^(2/9))
		qui newey d`i' in `startd'/`end', lag(`nlags')
		scalar pvalue`i'=normal(-_b[_cons]/_se[_cons])
		local stat : display %4.2f (msfe_`i'/msfe_rw)
		local pv : display %5.3f pvalue`i'
		local dmstat_`h'_`i'=trim("`stat'")
		local dmpv_`h'_`i'=trim("`pv'")
		drop error_mod`i' error_mod`i'sq d`i'
	}
	drop error_rw error_rwsq
}

// Mean directional accuracy and PT (2009) p-values
foreach h in `horizons' {
	local startd=`start'+`h'
	qui gen byte signy=(y-L`h'.y_nc)>0 in `startd'/`end'
	forvalues i=0(1)`mods' {
		qui gen byte da`i'=sign(y-L`h'.y_nc)==sign(lvlfor`h'_mod`i'-L`h'.y_nc) in `startd'/`end'
		qui gen byte sign`i'=(lvlfor`h'_mod`i'-L`h'.y_nc)>0 in `startd'/`end'
		qui sum da`i'
		scalar mda`i'=r(mean)
		local obs=r(N)
		// PT (2009) test with Newey-West HAC standard errors
		local nlags=round(4*(`obs'/100)^(2/9))
		qui newey signy sign`i' in `startd'/`end', lag(`nlags')
		scalar pvsr`i'=normal(-_b[sign`i']/_se[sign`i'])
		local stat : display %4.2f mda`i'
		local pv : display %5.3f pvsr`i'
		local srstat_`h'_`i'=trim("`stat'")
		local srpv_`h'_`i'=trim("`pv'")
		drop da`i' sign`i'
	}
	drop signy
}

// ************************
// DM tests: BUMIDAS (model 1) against models >1
// Positive loss differential favors BUMIDAS
// ************************

foreach h in `horizons' {
	local pvdm_`h'_0 "."
	local pvdm_`h'_1 "."

	if `mods'>1 {
		local startd=`start'+`h'
		tempvar bumerror2
		qui gen double `bumerror2'=(y-lvlfor`h'_mod1)^2 in `startd'/`end'

		forvalues i=2/`mods' {
			tempvar alterror2 dmbum
			qui gen double `alterror2'=(y-lvlfor`h'_mod`i')^2 in `startd'/`end'
			qui gen double `dmbum'=`alterror2'-`bumerror2' in `startd'/`end'

			qui count if !missing(`dmbum') in `startd'/`end'
			local obs=r(N)
			local nlags=round(4*(`obs'/100)^(2/9))

			capture quietly newey `dmbum' in `startd'/`end', lag(`nlags')
			if _rc | missing(_se[_cons]) | _se[_cons]<=0 {
				local pvdm "."
			}
			else {
				local zdm=_b[_cons]/_se[_cons]
				local pvdm : display %5.3f normal(-`zdm')
				local pvdm=trim("`pvdm'")
			}

			local pvdm_`h'_`i' "`pvdm'"

			local methodlabel "`method`i''"
			if `"`methodlabel'"'=="" local methodlabel "Model `i'"

			display "Horizon `h': BUMIDAS vs. `methodlabel', one-sided DM p-value = `pvdm'"

			drop `alterror2' `dmbum'
		}
		drop `bumerror2'
	}
}

// -----------------------------
// Print forecast performance
// -----------------------------

// No-change benchmark
if "`ncfor'"=="ave" local nclabel "Average no-change"
else if "`ncfor'"=="ld0" local nclabel "EoM no-change"

di _newline as text "FX Forecast: " ///
    "Target=" as result "`vari'" ///
    as text " | AR=" as result %1.0f `ar' ///
    as text " | Benchmark=" as result "`nclabel'"
	
foreach h in `horizons' {
    forvalues i=0/`mods' {
        di as text "h=" as result %2.0f `h' ///
            as text " | " %-24s "`method`i''" ///
            as text " Rel. MSFE = " as result %5.3f `dmstat_`h'_`i'' ///
            as text " (" as result "`dmpv_`h'_`i''" as text ")" ///
            as text " [" as result %5.3f `pvdm_`h'_`i'' as text "]" ///
            as text " | MDA = " as result %5.3f `srstat_`h'_`i'' ///
            as text " (" as result "`srpv_`h'_`i''" as text ")"
    }
}

// -----------------------------
// Close log
// -----------------------------

log close midaslog