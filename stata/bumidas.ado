*! version 0.2.0 1oct2026
program define bumidas, eclass
    version 11.0

    // Replay previously stored bumidas results
    if replay() {
        if "`e(cmd)'"!="bumidas" error 301
        syntax [, REGression]
        _bumidas_display
        if "`regression'"!="" ereturn display
        exit
    }

    local cmdline `"bumidas `0'"'

    syntax varname(numeric) [if] [in] [, ///
         HFTARGET(string asis) ///
         HFPREDICTORS(string asis) ///
         HFMAX(integer -1) ///
         LFYMAX(integer -1) ///
         LFPREDICTORS(varlist numeric) ///
         LFXMAX(integer -1) ///
         CONTROLS(varlist numeric ts fv) ///
         HORIZON(integer 1) ///
         SEARCH(string) ///
         IC(string) ///
         HFORDERS(numlist integer >=0) ///
         LFYORDER(integer -1) ///
         LFXORDERS(numlist integer >=0) ///
         NOCONstant REGression TRACE]

    local depvar "`varlist'"
    local search = lower("`search'")
    local ic     = lower("`ic'")

    if "`search'"=="" local search "full"
    if "`ic'"==""     local ic "bic"
    local IC = upper("`ic'")

    // -----------------------------
    // Validate general options
    // -----------------------------

    if !inlist("`search'","full","recursive","none") {
        di as error "search() must be full, recursive, or none"
        exit 198
    }

    if !inlist("`ic'","bic","hqic","aic") {
        di as error "ic() must be bic, hqic, or aic"
        exit 198
    }

    if `horizon'<1 {
        di as error "horizon() must be an integer greater than or equal to 1"
        exit 198
    }

    if `hfmax'==0 | `hfmax'<-1 {
        di as error "hfmax() must be a positive integer"
        exit 198
    }

    if `lfymax'<-1 {
        di as error "lfymax() must be a nonnegative integer"
        exit 198
    }

    if `lfxmax'<-1 {
        di as error "lfxmax() must be a nonnegative integer"
        exit 198
    }

    if `lfyorder'<-1 {
        di as error "lfyorder() must be a nonnegative integer"
        exit 198
    }

    // Verify that time-series operators can be used
    capture quietly tsset
    if _rc {
        di as error "data must be tsset before using bumidas"
        exit 459
    }

    marksample touse

    // -----------------------------
    // Validate HF stubs
    // -----------------------------

    // hftarget() contains required HF blocks (minimum order 1).
    // hfpredictors() contains optional HF blocks (minimum order 0).
    // Either option may be omitted, and each may contain multiple stubs.
    local nhft : word count `hftarget'
    local nhfp : word count `hfpredictors'
    local nhfblocks = `nhft' + `nhfp'

    // HF stubs must be unique across both options.
    local seen ""
    local i = 0
    foreach s in `hftarget' `hfpredictors' {
        if strpos(" `seen' "," `s' ") {
            di as error "HF stub `s' is specified more than once"
            exit 198
        }
        local seen "`seen' `s'"

        local ++i
        _bumidas_stubinfo, stub(`s')
        local havail`i' = r(terms)
        local hstub`i' "`s'"
    }

    // -----------------------------
    // Search-mode option validation
    // -----------------------------

    if inlist("`search'","full","recursive") {

        if "`hforders'"!="" | `lfyorder'!=-1 | "`lfxorders'"!="" {
            di as error ///
                "hforders(), lfyorder(), and lfxorders() require search(none)"
            exit 198
        }

        if `hfmax'!=-1 & `nhfblocks'==0 {
            di as error "hfmax() requires hftarget() or hfpredictors()"
            exit 198
        }

        if "`lfpredictors'"!="" & `lfxmax'==-1 {
            di as error "lfxmax() is required when lfpredictors() is specified"
            exit 198
        }

        if "`lfpredictors'"=="" & `lfxmax'!=-1 {
            di as error "lfxmax() requires lfpredictors()"
            exit 198
        }

        if `lfxmax'==0 & "`lfpredictors'"!="" {
            di as error "lfxmax() must be positive when lfpredictors() is specified"
            exit 198
        }

        // lfymax(0) is equivalent to omitting the LF target block
        if `lfymax'==-1 local lfymax 0
    }
    else {

        if `hfmax'!=-1 | `lfymax'!=-1 | `lfxmax'!=-1 {
            di as error ///
                "hfmax(), lfymax(), and lfxmax() are not allowed with search(none)"
            exit 198
        }

        if `nhfblocks'>0 & "`hforders'"=="" {
            di as error ///
                "hforders() is required for HF blocks with search(none)"
            exit 198
        }

        if `nhfblocks'==0 & "`hforders'"!="" {
            di as error ///
                "hforders() requires hftarget() or hfpredictors()"
            exit 198
        }

        if "`lfpredictors'"!="" & "`lfxorders'"=="" {
            di as error ///
                "lfxorders() is required when lfpredictors() is used with search(none)"
            exit 198
        }

        if "`lfpredictors'"=="" & "`lfxorders'"!="" {
            di as error "lfxorders() requires lfpredictors()"
            exit 198
        }
    }

    // -----------------------------
    // Define model-selection blocks
    // -----------------------------

    local nblocks = 0

    // hforders() follows the HF block order:
    // all hftarget() stubs first, then all hfpredictors() stubs.
    if "`search'"=="none" {
        local nord : word count `hforders'
        if `nord'!=`nhfblocks' {
            di as error ///
                "hforders() must contain `nhfblocks' value(s): hftarget() blocks first, then hfpredictors()"
            exit 198
        }
    }

    local hindex = 0

    // Required HF blocks: minimum order is always 1
    if `nhft'>0 {
        forvalues j=1/`nhft' {
            local ++hindex
            local s : word `j' of `hftarget'

            local ++nblocks
            local btype`nblocks' "hftarget"
            local bname`nblocks' "`s'"
            local bmin`nblocks' 1

            if "`search'"=="none" {
                local ord : word `hindex' of `hforders'

                if `ord'<1 {
                    di as error ///
                        "the hftarget() order for `s' in hforders() must be at least 1"
                    exit 198
                }

                if `ord'>`havail`hindex'' {
                    di as error ///
                        "requested order `ord' for `s' exceeds `havail`hindex'' available term(s)"
                    exit 198
                }

                local bmin`nblocks' `ord'
                local bmax`nblocks' `ord'
            }
            else {
                local mx = `havail`hindex''
                if `hfmax'!=-1 local mx = min(`mx',`hfmax')
                local bmax`nblocks' `mx'
            }
        }
    }

    // Optional HF predictor blocks: minimum order is 0
    if `nhfp'>0 {
        forvalues j=1/`nhfp' {
            local ++hindex
            local s : word `j' of `hfpredictors'

            local ++nblocks
            local btype`nblocks' "hfpredictor"
            local bname`nblocks' "`s'"
            local bmin`nblocks' 0

            if "`search'"=="none" {
                local ord : word `hindex' of `hforders'

                if `ord'>`havail`hindex'' {
                    di as error ///
                        "requested order `ord' for `s' exceeds `havail`hindex'' available term(s)"
                    exit 198
                }

                local bmin`nblocks' `ord'
                local bmax`nblocks' `ord'
            }
            else {
                local mx = `havail`hindex''
                if `hfmax'!=-1 local mx = min(`mx',`hfmax')
                local bmax`nblocks' `mx'
            }
        }
    }

    // LF target block
    if "`search'"=="none" {
        if `lfyorder'!=-1 {
            local ++nblocks
            local btype`nblocks' "lftarget"
            local bname`nblocks' "`depvar'"
            local bmin`nblocks' `lfyorder'
            local bmax`nblocks' `lfyorder'
        }
    }
    else if `lfymax'>0 {
        local ++nblocks
        local btype`nblocks' "lftarget"
        local bname`nblocks' "`depvar'"
        local bmin`nblocks' 0
        local bmax`nblocks' `lfymax'
    }

    // Other LF predictor blocks
    local nlfp : word count `lfpredictors'

    if `nlfp'>0 {
        if "`search'"=="none" {
            local nlfxo : word count `lfxorders'
            if `nlfxo'!=`nlfp' {
                di as error ///
                    "lfxorders() must contain one value for each variable in lfpredictors()"
                exit 198
            }
        }

        forvalues j=1/`nlfp' {
            local x : word `j' of `lfpredictors'

            local ++nblocks
            local btype`nblocks' "lfpredictor"
            local bname`nblocks' "`x'"

            if "`search'"=="none" {
                local ord : word `j' of `lfxorders'
                local bmin`nblocks' `ord'
                local bmax`nblocks' `ord'
            }
            else {
                local bmin`nblocks' 0
                local bmax`nblocks' `lfxmax'
            }
        }
    }

    // -----------------------------
    // Largest-model common sample
    // -----------------------------

    local rhsmax "`controls'"

    forvalues b=1/`nblocks' {
        local typ "`btype`b''"
        local nm  "`bname`b''"
        local ord = `bmax`b''

        if inlist("`typ'","hftarget","hfpredictor") {
            if `ord'>0 {
                forvalues j=0/`=`ord'-1' {
                    local rhsmax "`rhsmax' L`horizon'.`nm'`j'"
                }
            }
        }
        else {
            if `ord'>0 {
                forvalues j=0/`=`ord'-1' {
                    local lag = `horizon'+`j'
                    local rhsmax "`rhsmax' L`lag'.`nm'"
                }
            }
        }
    }

    tempvar sample
    local regopts ""
    if "`noconstant'"!="" local regopts ", noconstant"

    capture quietly regress `depvar' `rhsmax' if `touse' `regopts'
    if _rc {
        di as error "largest candidate model could not be estimated"
        di as error "check available lags, collinearity, and the requested sample"
        exit _rc
    }

    quietly gen byte `sample' = e(sample)

    quietly count if `sample'
    if r(N)==0 {
        di as error "largest candidate model has no usable observations"
        exit 2000
    }

    local commonN = r(N)

    // -----------------------------
    // Model selection
    // -----------------------------

    tempname bestIC candIC currentIC
    scalar `bestIC' = .
    scalar `candIC' = .
    scalar `currentIC' = .

    local bestk = .
    local bestRHS ""
    local Nmodels = 0
    local tol = 1e-10

    // =========================================================
    // Full Cartesian grid
    // =========================================================

    if "`search'"=="full" {

        local gridmodels = 1
        forvalues b=1/`nblocks' {
            local width = `bmax`b'' - `bmin`b'' + 1
            local gridmodels = `gridmodels' * `width'
        }

        if `gridmodels'>100000 {
            di as text ///
                "note: full grid contains " as result %12.0fc `gridmodels' ///
                as text " candidate models"
        }

        local lastmodel = `gridmodels'-1
        forvalues m=0/`lastmodel' {

            // Decode m into the mixed-radix block-order vector.
            // Last block varies fastest, giving deterministic
            // lexicographic ordering.
            local rem = `m'

            forvalues bb=`nblocks'(-1)1 {
                local width = `bmax`bb'' - `bmin`bb'' + 1
                local ord`bb' = `bmin`bb'' + mod(`rem',`width')
                local rem = floor(`rem'/`width')
            }

            local rhs "`controls'"

            forvalues b=1/`nblocks' {
                local typ "`btype`b''"
                local nm  "`bname`b''"
                local ord = `ord`b''

                if inlist("`typ'","hftarget","hfpredictor") {
                    if `ord'>0 {
                        forvalues j=0/`=`ord'-1' {
                            local rhs "`rhs' L`horizon'.`nm'`j'"
                        }
                    }
                }
                else {
                    if `ord'>0 {
                        forvalues j=0/`=`ord'-1' {
                            local lag = `horizon'+`j'
                            local rhs "`rhs' L`lag'.`nm'"
                        }
                    }
                }
            }

            quietly regress `depvar' `rhs' if `sample' `regopts'
            local ++Nmodels

            if "`ic'"=="aic" {
                scalar `candIC' = -2*e(ll) + 2*e(rank)
            }
            else if "`ic'"=="hqic" {
                scalar `candIC' = -2*e(ll) + 2*ln(ln(e(N)))*e(rank)
            }
            else {
                scalar `candIC' = -2*e(ll) + ln(e(N))*e(rank)
            }

            local candk = e(rank)
            local choose = 0

            if missing(scalar(`bestIC')) {
                local choose = 1
            }
            else if scalar(`candIC') < scalar(`bestIC') - `tol' {
                local choose = 1
            }
            else if abs(scalar(`candIC')-scalar(`bestIC'))<=`tol' ///
                & `candk'<`bestk' {
                local choose = 1
            }

            if `choose' {
                scalar `bestIC' = scalar(`candIC')
                local bestk = `candk'
                local bestRHS "`rhs'"

                forvalues b=1/`nblocks' {
                    local bestord`b' = `ord`b''
                }

                if "`trace'"!="" {
                    local otext ""
                    forvalues b=1/`nblocks' {
                        local otext "`otext' `bestord`b''"
                    }
                    di as text "new best: (" ///
                        as result strtrim("`otext'") ///
                        as text ")  `IC' = " ///
                        as result %12.6f scalar(`bestIC')
                }
            }
        }
    }

    // =========================================================
    // Recursive forward block-order search
    // =========================================================

    else if "`search'"=="recursive" {

        // Start at minimum admissible orders
        forvalues b=1/`nblocks' {
            local curord`b' = `bmin`b''
        }

        // Build and estimate starting model
        local rhs "`controls'"

        forvalues b=1/`nblocks' {
            local typ "`btype`b''"
            local nm  "`bname`b''"
            local ord = `curord`b''

            if inlist("`typ'","hftarget","hfpredictor") {
                if `ord'>0 {
                    forvalues j=0/`=`ord'-1' {
                        local rhs "`rhs' L`horizon'.`nm'`j'"
                    }
                }
            }
            else {
                if `ord'>0 {
                    forvalues j=0/`=`ord'-1' {
                        local lag = `horizon'+`j'
                        local rhs "`rhs' L`lag'.`nm'"
                    }
                }
            }
        }

        quietly regress `depvar' `rhs' if `sample' `regopts'
        local ++Nmodels

        if "`ic'"=="aic" {
            scalar `currentIC' = -2*e(ll) + 2*e(rank)
        }
        else if "`ic'"=="hqic" {
            scalar `currentIC' = -2*e(ll) + 2*ln(ln(e(N)))*e(rank)
        }
        else {
            scalar `currentIC' = -2*e(ll) + ln(e(N))*e(rank)
        }

        local currentk = e(rank)
        local currentRHS "`rhs'"

        // Path matrix: one column per block plus IC
        tempname path
        matrix `path' = J(1,`nblocks'+1,.)
        forvalues b=1/`nblocks' {
            matrix `path'[1,`b'] = `curord`b''
        }
        matrix `path'[1,`=`nblocks'+1'] = scalar(`currentIC')

        if "`trace'"!="" {
            local otext ""
            forvalues b=1/`nblocks' {
                local otext "`otext' `curord`b''"
            }
            di as text "step 0: (" ///
                as result strtrim("`otext'") ///
                as text ")  `IC' = " ///
                as result %12.6f scalar(`currentIC')
        }

        local step = 0
        local keepgoing = 1

        while `keepgoing' {

            scalar `bestIC' = .
            local bestk = .
            local bestblock = 0
            local bestRHS ""

            // Iterate right-to-left so equal-IC/equal-k ties retain
            // the lexicographically smaller order vector.
            forvalues b=`nblocks'(-1)1 {

                if `curord`b'' < `bmax`b'' {

                    local rhs "`controls'"

                    forvalues c=1/`nblocks' {
                        local typ "`btype`c''"
                        local nm  "`bname`c''"
                        local ord = `curord`c''
                        if `c'==`b' local ord = `ord'+1

                        if inlist("`typ'","hftarget","hfpredictor") {
                            if `ord'>0 {
                                forvalues j=0/`=`ord'-1' {
                                    local rhs "`rhs' L`horizon'.`nm'`j'"
                                }
                            }
                        }
                        else {
                            if `ord'>0 {
                                forvalues j=0/`=`ord'-1' {
                                    local lag = `horizon'+`j'
                                    local rhs "`rhs' L`lag'.`nm'"
                                }
                            }
                        }
                    }

                    quietly regress `depvar' `rhs' if `sample' `regopts'
                    local ++Nmodels

                    if "`ic'"=="aic" {
                        scalar `candIC' = -2*e(ll) + 2*e(rank)
                    }
                    else if "`ic'"=="hqic" {
                        scalar `candIC' = -2*e(ll) + 2*ln(ln(e(N)))*e(rank)
                    }
                    else {
                        scalar `candIC' = -2*e(ll) + ln(e(N))*e(rank)
                    }

                    local candk = e(rank)
                    local choose = 0

                    if missing(scalar(`bestIC')) {
                        local choose = 1
                    }
                    else if scalar(`candIC') < scalar(`bestIC') - `tol' {
                        local choose = 1
                    }
                    else if abs(scalar(`candIC')-scalar(`bestIC'))<=`tol' ///
                        & `candk'<`bestk' {
                        local choose = 1
                    }

                    if `choose' {
                        scalar `bestIC' = scalar(`candIC')
                        local bestk = `candk'
                        local bestblock = `b'
                        local bestRHS "`rhs'"
                    }
                }
            }

            // No admissible one-step expansions remain
            if `bestblock'==0 {
                local keepgoing = 0
            }
            // Accept only a strict IC improvement, or an IC tie with fewer
            // estimated parameters
            else {
                local accept = 0

                if scalar(`bestIC') < scalar(`currentIC') - `tol' {
                    local accept = 1
                }
                else if abs(scalar(`bestIC')-scalar(`currentIC'))<=`tol' ///
                    & `bestk'<`currentk' {
                    local accept = 1
                }

                if !`accept' {
                    local keepgoing = 0
                }
                else {
                    local curord`bestblock' = `curord`bestblock'' + 1
                    scalar `currentIC' = scalar(`bestIC')
                    local currentk = `bestk'
                    local currentRHS "`bestRHS'"
                    local ++step

                    matrix `path' = `path' \ J(1,`nblocks'+1,.)
                    local prow = rowsof(`path')
                    forvalues b=1/`nblocks' {
                        matrix `path'[`prow',`b'] = `curord`b''
                    }
                    matrix `path'[`prow',`=`nblocks'+1'] = scalar(`currentIC')

                    if "`trace'"!="" {
                        local otext ""
                        forvalues b=1/`nblocks' {
                            local otext "`otext' `curord`b''"
                        }
                        di as text "step `step': (" ///
                            as result strtrim("`otext'") ///
                            as text ")  `IC' = " ///
                            as result %12.6f scalar(`currentIC')
                    }
                }
            }
        }

        forvalues b=1/`nblocks' {
            local bestord`b' = `curord`b''
        }

        scalar `bestIC' = scalar(`currentIC')
        local bestRHS "`currentRHS'"

        if "`trace'"!="" {
            di as text "no further improvement"
        }
    }

    // =========================================================
    // Fixed orders
    // =========================================================

    else {

        local bestRHS "`controls'"

        forvalues b=1/`nblocks' {
            local bestord`b' = `bmax`b''
            local typ "`btype`b''"
            local nm  "`bname`b''"
            local ord = `bestord`b''

            if inlist("`typ'","hftarget","hfpredictor") {
                if `ord'>0 {
                    forvalues j=0/`=`ord'-1' {
                        local bestRHS "`bestRHS' L`horizon'.`nm'`j'"
                    }
                }
            }
            else {
                if `ord'>0 {
                    forvalues j=0/`=`ord'-1' {
                        local lag = `horizon'+`j'
                        local bestRHS "`bestRHS' L`lag'.`nm'"
                    }
                }
            }
        }

        quietly regress `depvar' `bestRHS' if `sample' `regopts'
        local Nmodels = 1

        if "`ic'"=="aic" {
            scalar `bestIC' = -2*e(ll) + 2*e(rank)
        }
        else if "`ic'"=="hqic" {
            scalar `bestIC' = -2*e(ll) + 2*ln(ln(e(N)))*e(rank)
        }
        else {
            scalar `bestIC' = -2*e(ll) + ln(e(N))*e(rank)
        }
    }

    // -----------------------------
    // Final selected/fixed regression
    // -----------------------------

    quietly regress `depvar' `bestRHS' if `sample' `regopts'

    // Build order matrix and metadata
    // Stored matrix prefixes:
    //   HT_ = required HF block from hftarget()
    //   HP_ = optional HF block from hfpredictors()
    //   LY_ = LF target block
    //   LP_ = LF predictor block
    tempname orders
    matrix `orders' = J(1,`nblocks',.)

    local ordernames ""
    local ordertypes ""
    local cnames ""
    local usedcnames ""

    forvalues b=1/`nblocks' {
        matrix `orders'[1,`b'] = `bestord`b''
        local ordernames "`ordernames' `bname`b''"
        local ordertypes "`ordertypes' `btype`b''"

        local typ "`btype`b''"
        local nm  "`bname`b''"

        if "`typ'"=="hftarget" {
            local base "HT_`nm'"
        }
        else if "`typ'"=="hfpredictor" {
            local base "HP_`nm'"
        }
        else if "`typ'"=="lftarget" {
            local base "LY_`nm'"
        }
        else {
            local base "LP_`nm'"
        }

        local cname = substr("`base'",1,32)

        // Guarantee unique legal matrix column names even after truncation.
        if strpos(" `usedcnames' "," `cname' ") {
            local suffix "_`b'"
            local keep = 32-strlen("`suffix'")
            local cname = substr("`base'",1,`keep') + "`suffix'"
        }

        local cnames "`cnames' `cname'"
        local usedcnames "`usedcnames' `cname'"
    }

    matrix colnames `orders' = `cnames'
    matrix rownames `orders' = selected

    // Label recursive path columns and rows
    if "`search'"=="recursive" {
        local pnames "`cnames' ic"
        matrix colnames `path' = `pnames'

        local rnames ""
        local npath = rowsof(`path')
        forvalues r=1/`npath' {
            local step = `r'-1
            local rnames "`rnames' step`step'"
        }
        matrix rownames `path' = `rnames'
    }

    // Add bumidas metadata without disturbing regress e(b), e(V), e(sample)
    ereturn scalar horizon  = `horizon'
    ereturn scalar icvalue  = scalar(`bestIC')
    ereturn scalar N_models = `Nmodels'
    ereturn scalar N_common = `commonN'

    ereturn matrix orders = `orders'
    if "`search'"=="recursive" {
        ereturn matrix path = `path'
    }

    ereturn local search       "`search'"
    ereturn local ic           "`ic'"
    ereturn local rhs          "`bestRHS'"
    ereturn local hftarget     "`hftarget'"
    ereturn local hfpredictors "`hfpredictors'"
    ereturn local lfpredictors "`lfpredictors'"
    ereturn local controls     "`controls'"
    ereturn local order_names  "`ordernames'"
    ereturn local order_types  "`ordertypes'"
    ereturn local predict      "bumidas_p"
    ereturn local title        "Bottom-Up MIDAS regression"
    ereturn local cmdline      `"`cmdline'"'
    ereturn local cmd          "bumidas"

    // -----------------------------
    // Display
    // -----------------------------

    _bumidas_display

    if "`regression'"!="" {
        ereturn display
    }
end


// ============================================================================
// Validate a high-frequency stub and count contiguous terms stub0,...,stubK
// ============================================================================
program define _bumidas_stubinfo, rclass
    version 11.0
    syntax , STUB(name)

    capture confirm numeric variable `stub'0
    if _rc {
        di as error "HF stub `stub' requires numeric variable `stub'0"
        exit 111
    }

    quietly ds `stub'*
    local vars "`r(varlist)'"
    local maxidx = -1

    foreach v of local vars {
        local suffix = substr("`v'",strlen("`stub'")+1,.)
        if regexm("`suffix'","^[0-9]+$") {
            local idx = real("`suffix'")
            if `idx'>`maxidx' local maxidx = `idx'
        }
    }

    if `maxidx'<0 {
        di as error "no indexed variables found for HF stub `stub'"
        exit 111
    }

    forvalues j=0/`maxidx' {
        capture confirm numeric variable `stub'`j'
        if _rc {
            di as error ///
                "HF stub `stub' is not contiguous; variable `stub'`j' is missing"
            exit 459
        }
    }

    return scalar terms = `maxidx'+1
    return scalar maxindex = `maxidx'
end


// ============================================================================
// Compact bumidas results display
// ============================================================================
program define _bumidas_display
    version 11.0

    if "`e(cmd)'"!="bumidas" error 301

    local IC = upper("`e(ic)'")
    local search "`e(search)'"

    di _newline as text "Bottom-Up MIDAS regression"
    di as text "{hline 28}"

    if "`search'"=="none" {
        di as text "Forecast horizon = " as result %6.0f e(horizon)
        di as text "Search           = " as result "fixed orders"
        di as text "Criterion        = " as result "`IC'"
    }
    else {
        di as text "Forecast horizon = " as result %6.0f e(horizon)
        di as text "Selection        = " ///
            as result "`IC', `search'"
    }

    di as text "Observations     = " as result %10.0fc e(N)
    di as text "Models evaluated = " as result %10.0fc e(N_models)

    tempname O
    matrix `O' = e(orders)

    local names "`e(order_names)'"
    local types "`e(order_types)'"
    local nb = colsof(`O')

    di _newline as text "Selected orders"

    forvalues b=1/`nb' {
        local nm  : word `b' of `names'
        local typ : word `b' of `types'
        local ord = `O'[1,`b']

        if "`typ'"=="hftarget" {
            di as text "  Required HF (`nm')" ///
                _col(36) as result %5.0f `ord'
        }
        else if "`typ'"=="hfpredictor" {
            di as text "  Optional HF (`nm')" ///
                _col(36) as result %5.0f `ord'
        }
        else if "`typ'"=="lftarget" {
            di as text "  LF target (`nm')" ///
                _col(36) as result %5.0f `ord'
        }
        else {
            di as text "  LF predictor (`nm')" ///
                _col(36) as result %5.0f `ord'
        }
    }

    di _newline as text "`IC' = " ///
        as result %12.6f e(icvalue)
end
