*! version 0.1.0 25sep2026
program define mfcollapse, rclass
    version 18.0

    syntax varlist(min=1 numeric) [if] [in], ///
        DATE(varname numeric) FREQuency(string) ///
        [AR(integer -1) LAGS(integer -1) ANCHor(varname numeric)]

    // -----------------------------
    // Parse and validate options
    // -----------------------------

    local frequency = lower("`frequency'")

    if !inlist("`frequency'","weekly","monthly","quarterly") {
        di as error "frequency() must be weekly, monthly, or quarterly"
        exit 198
    }

    if `ar'!=-1 & `lags'!=-1 {
        di as error "specify only one of ar() or lags()"
        exit 198
    }

    // Default is ar(1)
    if `ar'==-1 & `lags'==-1 local ar 1

    if `ar'!=-1 & `ar'<1 {
        di as error "ar() must be a positive integer"
        exit 198
    }

    if `lags'!=-1 & `lags'<0 {
        di as error "lags() must be a nonnegative integer"
        exit 198
    }

    // date() cannot also be one of the collapsed variables
    foreach v of local varlist {
        if "`v'"=="`date'" {
            di as error "date() may not also be included in varlist"
            exit 198
        }
    }

    // Default anchor is the first variable in varlist
    if "`anchor'"=="" local anchor : word 1 of `varlist'

    // anchor() must be one of the variables being collapsed
    local anchorok 0
    foreach v of local varlist {
        if "`v'"=="`anchor'" local anchorok 1
    }

    if !`anchorok' {
        di as error "anchor() must identify a variable in varlist"
        exit 198
    }

    marksample touse, novarlist

    // Protect the user's data if an error occurs during construction
    preserve

    quietly keep if `touse'

    if _N==0 {
        di as error "no observations"
        exit 2000
    }

    // date() must be observed and uniquely identify HF rows
    quietly count if missing(`date')
    if r(N)>0 {
        di as error "date() contains missing values in the estimation sample"
        exit 459
    }

    sort `date'

    capture isid `date'
    if _rc {
        di as error "date() does not uniquely identify high-frequency observations"
        duplicates report `date'
        exit 459
    }

    // -----------------------------
    // Establish common HF schedule
    // -----------------------------

    // All variables on the same block must share the anchor's
    // observed/missing pattern.
    foreach v of local varlist {
        quietly count if missing(`anchor') != missing(`v')
        if r(N)>0 {
            di as error ///
                "`v' does not share the same observation schedule as anchor `anchor'"
            exit 459
        }
    }

    quietly count if missing(`anchor')
    local Ndropped = r(N)

    quietly drop if missing(`anchor')

    if _N==0 {
        di as error "anchor variable `anchor' contains no nonmissing observations"
        exit 2000
    }

    local Nhf = _N

    // -----------------------------
    // Sequential observed-HF clock
    // -----------------------------

    tempvar hfindex lfperiod nhf periodtag eop

    sort `date'
    quietly gen long `hfindex' = _n
    quietly tsset `hfindex'

    // -----------------------------
    // Define LF period
    // -----------------------------

    if "`frequency'"=="weekly" {
        quietly gen long `lfperiod' = wofd(`date')
        format `lfperiod' %tw
        local lfformat "%tw"
    }
    else if "`frequency'"=="monthly" {
        quietly gen long `lfperiod' = mofd(`date')
        format `lfperiod' %tm
        local lfformat "%tm"
    }
    else {
        quietly gen long `lfperiod' = qofd(`date')
        format `lfperiod' %tq
        local lfformat "%tq"
    }

    // -----------------------------
    // Infer HF observations per LF period
    // -----------------------------

    quietly bysort `lfperiod': gen int `nhf' = _N
    quietly egen byte `periodtag' = tag(`lfperiod')

    quietly summarize `lfperiod', meanonly
    local firstperiod = r(min)
    local lastperiod  = r(max)

    // Exclude first and last periods because they may be partial
    quietly summarize `nhf' if `periodtag' ///
        & `lfperiod'>`firstperiod' ///
        & `lfperiod'<`lastperiod', meanonly

    // Fallback for samples with fewer than three LF periods
    if r(N)==0 {
        quietly summarize `nhf' if `periodtag', meanonly
    }

    local hfmean = r(mean)
    local hfn    = ceil(`hfmean')

    if `lags'!=-1 {
        local maxlag = `lags'
        local lagrule "lags(`lags')"
    }
    else {
        local maxlag = `ar'*(`hfn'-1)
        local lagrule "ar(`ar')"
    }

    if `maxlag'>=`Nhf' {
        di as error ///
            "requested maximum lag (`maxlag') exceeds available HF history (`Nhf' observations)"
        exit 198
    }

    // -----------------------------
    // Validate generated variable names
    // -----------------------------

    foreach v of local varlist {

        forvalues j=0/`maxlag' {
            local newvar "`v'_ld`j'"
            capture confirm new variable `newvar'
            if _rc {
                local rc = _rc
                di as error ///
                    "cannot create `newvar'; name is invalid or variable already exists"
                exit `rc'
            }
        }

        local newvar "`v'_ave"
        capture confirm new variable `newvar'
        if _rc {
            local rc = _rc
            di as error ///
                "cannot create `newvar'; name is invalid or variable already exists"
            exit `rc'
        }
    }

    // -----------------------------
    // Construct observed-HF lags
    // -----------------------------

    sort `hfindex'
    quietly tsset `hfindex'

    local outvars ""

    foreach v of local varlist {

        quietly gen double `v'_ld0 = `v'
        label variable `v'_ld0 "`v': latest available HF observation"
        local outvars "`outvars' `v'_ld0"

        if `maxlag'>0 {
            forvalues j=1/`maxlag' {
                quietly gen double `v'_ld`j' = L`j'.`v'
                label variable `v'_ld`j' "`v': observed-HF lag `j'"
                local outvars "`outvars' `v'_ld`j'"
            }
        }
    }

    // -----------------------------
    // Construct LF averages
    // -----------------------------

    foreach v of local varlist {
        bysort `lfperiod': egen double `v'_ave = mean(`v')
        label variable `v'_ave "`v': `frequency' average"
        local outvars "`outvars' `v'_ave"
    }

    // -----------------------------
    // Keep latest HF observation in each LF period
    // -----------------------------

    quietly bysort `lfperiod' (`date'): gen byte `eop' = (_n==_N)

    quietly keep if `eop'
    quietly keep `lfperiod' `outvars'

    quietly rename `lfperiod' `date'
    format `date' `lfformat'
    label variable `date' "`frequency' period"

    sort `date'
    isid `date'
    quietly tsset `date'

    local Nlf = _N

    // Dataset metadata
    char _dta[lf_frequency] "`frequency'"
    char _dta[hfn] "`hfn'"
    char _dta[maxlag] "`maxlag'"
    char _dta[anchor] "`anchor'"

    // Keep the collapsed data in memory on successful completion
    restore, not

    // -----------------------------
    // Returned results
    // -----------------------------

    return scalar hfmean    = `hfmean'
    return scalar hfn       = `hfn'
    return scalar maxlag    = `maxlag'
    return scalar N_hf      = `Nhf'
    return scalar N_lf      = `Nlf'
    return scalar N_dropped = `Ndropped'

    if `ar'!=-1 {
        return scalar ar = `ar'
    }

    return local frequency "`frequency'"
    return local anchor    "`anchor'"
    return local varlist   "`varlist'"
    return local date      "`date'"
    return local lagrule   "`lagrule'"

    // -----------------------------
    // Concise output
    // -----------------------------

    di as text "mfcollapse: " ///
        as result "`frequency'" ///
        as text " | anchor=" as result "`anchor'" ///
        as text " | mean HF/LF=" as result %6.2f `hfmean' ///
        as text " | n=" as result %3.0f `hfn' ///
        as text " | max lag=" as result %4.0f `maxlag'

    if `Ndropped'>0 {
        di as text "  omitted " as result `Ndropped' ///
            as text " observation(s) with missing `anchor'"
    }
end
