*! version 0.2.0 1oct2026
program define rmidas, eclass
    version 11.0

    // Replay previously stored RMIDAS results
    if replay() {
        if "`e(cmd)'"!="rmidas" error 301
        syntax [, REGression]
        _rmidas_display
        if "`regression'"!="" ereturn display
        exit
    }

    local cmdline `"rmidas `0'"'

    syntax varname(numeric) [if] [in] [, ///
        HFPREDICTORS(string asis) ///
        HFN(numlist integer >=2) ///
        METHOD(string) ///
        PORDER(integer -1) ///
        PORDERS(numlist integer >=1) ///
        DEGREE(integer -1) ///
        STEPS(integer -1) ///
        CONTROLS(varlist numeric ts) ///
        HORIZON(integer 1) ///
        NOCONstant REGression TRACE]

    local depvar "`varlist'"
    local rmtype = lower("`method'")

    // -------------------------------------------------------------------------
    // Validate general options
    // -------------------------------------------------------------------------

    if "`hfpredictors'"=="" {
        di as error "hfpredictors() is required"
        exit 198
    }

    if !inlist("`rmtype'","almon","step","legendre","expalmon","beta") {
        di as error "method() must be almon, step, legendre, expalmon, or beta"
        exit 198
    }

    if `horizon'<1 {
        di as error "horizon() must be an integer greater than or equal to 1"
        exit 198
    }

    if `porder'==0 | `porder'<-1 {
        di as error "porder() must be a positive integer"
        exit 198
    }

    if `porder'!=-1 & "`porders'"!="" {
        di as error "specify only one of porder() or porders()"
        exit 198
    }

    // Default is common p=1
    if `porder'==-1 & "`porders'"=="" local porder 1

    // Restriction-specific defaults and validation
    if "`rmtype'"=="almon" {
        if `degree'==-1 local degree 2
        if `degree'<0 {
            di as error "degree() must be a nonnegative integer"
            exit 198
        }
        if `steps'!=-1 {
            di as error "steps() is only allowed with method(step)"
            exit 198
        }
    }
    else if "`rmtype'"=="legendre" {
        if `degree'==-1 local degree 3
        if `degree'<0 {
            di as error "degree() must be a nonnegative integer"
            exit 198
        }
        if `steps'!=-1 {
            di as error "steps() is only allowed with method(step)"
            exit 198
        }
    }
    else if "`rmtype'"=="step" {
        if `steps'==-1 local steps 3
        if `steps'<1 {
            di as error "steps() must be a positive integer"
            exit 198
        }
        if `degree'!=-1 {
            di as error "degree() is only allowed with method(almon) or method(legendre)"
            exit 198
        }
    }
    else {
        if `degree'!=-1 {
            di as error "degree() is only allowed with method(almon) or method(legendre)"
            exit 198
        }
        if `steps'!=-1 {
            di as error "steps() is only allowed with method(step)"
            exit 198
        }
    }

    capture quietly tsset
    if _rc {
        di as error "data must be tsset before using rmidas"
        exit 459
    }

    marksample touse

    // -------------------------------------------------------------------------
    // Validate HF predictor stubs
    // -------------------------------------------------------------------------

    local nhfp : word count `hfpredictors'
    local nblocks = `nhfp' + 1
    local seen ""

    forvalues j=1/`nhfp' {
        local s : word `j' of `hfpredictors'

        if strpos(" `seen' "," `s' ") {
            di as error "HF stub `s' is specified more than once"
            exit 198
        }
        local seen "`seen' `s'"

        _rmidas_stubinfo, stub(`s')
        local havail`j' = r(terms)
        local hstub`j' "`s'"
    }

    // -------------------------------------------------------------------------
    // Determine n_j for each HF block
    // -------------------------------------------------------------------------

    local nhfn : word count `hfn'
    if "`hfn'"!="" & `nhfn'!=1 & `nhfn'!=`nhfp' {
        di as error ///
            "hfn() must contain either one value or one value for each hfpredictors() stub"
        exit 198
    }

    local dta_hfn : char _dta[hfn]

    forvalues j=1/`nhfp' {
        local s "`hstub`j''"
        local nj ""

        if "`hfn'"!="" {
            if `nhfn'==1 local nj : word 1 of `hfn'
            else         local nj : word `j' of `hfn'
        }
        else {
            local v0 "`s'0"
            local nj : char `v0'[mfcollapse_hfn]
            if "`nj'"=="" local nj : char `v0'[hfn]
            if "`nj'"=="" & `nhfp'==1 local nj "`dta_hfn'"
        }

        if "`nj'"=="" {
            if `nhfp'>1 & "`hfn'"=="" {
                di as error "cannot safely determine n_j for multiple HF predictor blocks"
                di as error ///
                    "specify hfn() manually (one common value or one value per block)"
            }
            else {
                di as error "cannot determine n for HF predictor `s'"
                di as error "run mfcollapse first or specify hfn() manually"
            }
            exit 198
        }

        local njnum = real("`nj'")
        if missing(`njnum') | `njnum'<2 | `njnum'!=floor(`njnum') {
            di as error "invalid n=`nj' for HF predictor `s'; n must be an integer >= 2"
            exit 198
        }

        local hfn`j'       = `njnum'
        local blocksize`j' = `njnum' - 1
    }

    // -------------------------------------------------------------------------
    // Resolve fixed order vector (p_y,p_1,...,p_J), all >=1
    // -------------------------------------------------------------------------

    if "`porders'"!="" {
        local nporders : word count `porders'
        if `nporders'!=`nblocks' {
            di as error ///
                "porders() must contain `nblocks' positive values: LF target first, then one for each HF predictor"
            exit 198
        }

        forvalues b=1/`nblocks' {
            local ob : word `b' of `porders'
            local ord`b' = `ob'
        }
    }
    else {
        forvalues b=1/`nblocks' {
            local ord`b' = `porder'
        }
    }

    local py = `ord1'

    // Validate requested HF history and restriction dimensions
    local maxK = 0
    forvalues j=1/`nhfp' {
        local b = `j'+1
        local pj = `ord`b''
        local Kj = `pj' * `blocksize`j''
        local K`j' = `Kj'

        if `Kj'>`havail`j'' {
            di as error ///
                "HF predictor `hstub`j'' requires `Kj' terms for p=`pj' and n=`hfn`j'', but only `havail`j'' are available"
            exit 198
        }

        if inlist("`rmtype'","almon","legendre") & `Kj'<`degree'+1 {
            di as error ///
                "method(`rmtype') degree(`degree') requires at least `=`degree'+1' HF terms in each block; `hstub`j'' has `Kj'"
            exit 198
        }

        if "`rmtype'"=="step" & `steps'>`Kj' {
            di as error ///
                "steps(`steps') exceeds the `Kj' HF terms in block `hstub`j''"
            exit 198
        }

        if `Kj'>`maxK' local maxK = `Kj'
    }

    // -------------------------------------------------------------------------
    // Build LF target portion used by every family
    // -------------------------------------------------------------------------

    local lfrhs ""
    forvalues q=1/`py' {
        local lag = `horizon' + `q' - 1
        local lfrhs "`lfrhs' L`lag'.`depvar'"
    }

    local nctrl : word count `controls'
    local engine ""
    local rhs ""
    local shape_warning = 0

    // -------------------------------------------------------------------------
    // LINEAR RESTRICTIONS: Almon, Step, Legendre
    // -------------------------------------------------------------------------

    if inlist("`rmtype'","almon","step","legendre") {
        local engine "ols"
        local allbasis ""
        local oldbasis ""
        local newbasis ""

        forvalues j=1/`nhfp' {
            local s "`hstub`j''"
            local Kj = `K`j''
            local basislist`j' ""

            if inlist("`rmtype'","almon","legendre") {
                forvalues r=0/`degree' {
                    tempvar bv
                    quietly gen double `bv' = 0
                    local basislist`j' "`basislist`j'' `bv'"
                    local allbasis "`allbasis' `bv'"
                    local oldbasis "`oldbasis' `bv'"
                    if "`rmtype'"=="almon" local newbasis "`newbasis' HF`j'_A`r'"
                    else                     local newbasis "`newbasis' HF`j'_L`r'"
                }

                forvalues jj=1/`Kj' {
                    local k = `jj'-1

                    if "`rmtype'"=="almon" {
                        forvalues r=0/`degree' {
                            local pos = `r'+1
                            local bv : word `pos' of `basislist`j''
                            local val = `jj'^`r'
                            quietly replace `bv' = `bv' + `val'*L`horizon'.`s'`k'
                        }
                    }
                    else {
                        // Legendre basis matrix for this block.  The same
                        // matrix is retained and used later to reconstruct
                        // e(weights), eliminating any second evaluation path.
                        if `jj'==1 {
                            tempname LB
                            local legmat`j' "`LB'"
                            matrix `LB' = J(`=`degree'+1',`Kj',.)
                            forvalues cc=1/`Kj' {
                                if `Kj'==1 local z = 0
                                else       local z = -1 + 2*(`cc'-1)/(`Kj'-1)
                                matrix `LB'[1,`cc'] = 1
                                if `degree'>=1 matrix `LB'[2,`cc'] = `z'
                                if `degree'>=2 {
                                    local pm2 = 1
                                    local pm1 = `z'
                                    forvalues rr=2/`degree' {
                                        local pr = ((2*`rr'-1)*`z'*`pm1' - (`rr'-1)*`pm2')/`rr'
                                        matrix `LB'[`=`rr'+1',`cc'] = `pr'
                                        local pm2 = `pm1'
                                        local pm1 = `pr'
                                    }
                                }
                            }
                        }
                        local LBname "`legmat`j''"
                        forvalues r=0/`degree' {
                            local pos = `r'+1
                            local bv : word `pos' of `basislist`j''
                            local val = `LBname'[`pos',`jj']
                            quietly replace `bv' = `bv' + `val'*L`horizon'.`s'`k'
                        }
                    }
                }
            }
            else {
                // Step function: S approximately equal contiguous groups.
                // Group g is floor((g-1)K/S)+1,...,floor(gK/S).
                forvalues g=1/`steps' {
                    tempvar bv
                    quietly gen double `bv' = 0
                    local basislist`j' "`basislist`j'' `bv'"
                    local allbasis "`allbasis' `bv'"
                    local oldbasis "`oldbasis' `bv'"
                    local newbasis "`newbasis' HF`j'_S`g'"

                    local lo = floor((`g'-1)*`Kj'/`steps') + 1
                    local hi = floor(`g'*`Kj'/`steps')
                    forvalues jj=`lo'/`hi' {
                        local k = `jj'-1
                        quietly replace `bv' = `bv' + L`horizon'.`s'`k'
                    }
                }
            }

            if "`trace'"!="" {
                local b = `j'+1
                local pj = `ord`b''
                if "`rmtype'"=="step" {
                    di as text "`s': n=" as result `hfn`j'' ///
                        as text " p=" as result `pj' ///
                        as text " K=" as result `Kj' ///
                        as text ", steps=" as result `steps'
                }
                else {
                    di as text "`s': n=" as result `hfn`j'' ///
                        as text " p=" as result `pj' ///
                        as text " K=" as result `Kj' ///
                        as text ", degree=" as result `degree'
                }
            }
        }

        local rhs "`lfrhs' `allbasis' `controls'"
        local regopts ""
        if "`noconstant'"!="" local regopts ", noconstant"

        capture quietly regress `depvar' `rhs' if `touse' `regopts'
        if _rc {
            local rc = _rc
            di as error "RMIDAS linear restriction could not be estimated"
            exit `rc'
        }
    }

    // -------------------------------------------------------------------------
    // NONLINEAR RESTRICTIONS: Exponential Almon and Beta
    // -------------------------------------------------------------------------

    else {
        local engine "nl"
        local init ""
        local params ""
        local nlvars ""
        local Klist ""
        local hasconst = ("`noconstant'"=="")

        // Materialize every lagged input before calling nl.  The nonlinear
        // objective is evaluated by the standalone nlrmidas_lse evaluator, which normalizes the
        // Exp-Almon/Beta weights with log-sum-exp at EVERY optimizer
        // evaluation.  No bounds are imposed on c1 or c2.

        if `hasconst' {
            local params "`params' mu"
            local init   "`init' mu 0"
        }

        // Unrestricted LF target lags.
        forvalues q=1/`py' {
            local lag = `horizon' + `q' - 1
            tempvar lfv
            quietly gen double `lfv' = L`lag'.`depvar'
            local lftmp`q' "`lfv'"
            local nlvars "`nlvars' `lfv'"
            local params "`params' a`q'"
            if `q'==1 local init "`init' a`q' .5"
            else      local init "`init' a`q' 0"
        }

        // Unrestricted fixed controls.  Materializing them also permits
        // time-series operators in controls().
        forvalues c=1/`nctrl' {
            local cv : word `c' of `controls'
            tempvar ctv
            quietly gen double `ctv' = `cv'
            local ctrltmp`c' "`ctv'"
            local nlvars "`nlvars' `ctv'"
            local params "`params' d`c'"
            local init "`init' d`c' 0"
        }

        // Materialize all underlying HF observations.  Inputs are stored
        // block-by-block so the function evaluator can recover each block
        // from rmk().
        forvalues j=1/`nhfp' {
            local s "`hstub`j''"
            local Kj = `K`j''
            local Klist "`Klist' `Kj'"
            local xlist`j' ""

            forvalues jj=1/`Kj' {
                local k = `jj'-1
                tempvar xhv
                quietly gen double `xhv' = L`horizon'.`s'`k'
                local xlist`j' "`xlist`j'' `xhv'"
                local nlvars "`nlvars' `xhv'"
            }

            local params "`params' bx`j' c1`j' c2`j'"
            if "`rmtype'"=="expalmon" {
                local init "`init' bx`j' .5 c1`j' -2 c2`j' 0"
            }
            else {
                local init "`init' bx`j' .5 c1`j' 0 c2`j' 0"
            }

            if "`trace'"!="" {
                local b = `j'+1
                local pj = `ord`b''
                di as text "`s': n=" as result `hfn`j'' ///
                    as text " p=" as result `pj' ///
                    as text " K=" as result `Kj' ///
                    as text ", separate scale + 2 shape parameters"
            }
        }

        // Complete-case nonlinear sample based on the materialized inputs.
        tempvar nltouse
        quietly gen byte `nltouse' = `touse'
        markout `nltouse' `nlvars'

        quietly count if `nltouse'
        if r(N)==0 {
            di as error "no usable observations remain after accounting for nonlinear RMIDAS lags"
            exit 2000
        }

        if "`trace'"!="" {
            di as text "nonlinear estimation sample = " as result r(N)
        }

        // Function-evaluator form of nl.  The evaluator MUST be a standalone
        // ado-file program (nlrmidas_lse.ado); nl cannot call it when it is a
        // subprogram nested inside rmidas.ado.  Evaluator-specific options are
        // passed through by nl.  The parameter order here must match at().
        capture which nlrmidas_lse
        if _rc {
            di as error "required evaluator nlrmidas_lse.ado was not found on the Stata adopath"
            di as error "install or copy nlrmidas_lse.ado alongside rmidas.ado"
            exit 601
        }

        capture quietly nl rmidas_lse @ `depvar' `nlvars' if `nltouse', ///
            parameters(`params') initial(`init') ///
            rmtype(`rmtype') rmpy(`py') rmnctrl(`nctrl') ///
            rmk(`Klist') rmconst(`hasconst')

        if _rc {
            local rc = _rc
            di as error "RMIDAS `rmtype' nonlinear least squares failed (rc=`rc')"
            exit `rc'
        }
        if e(converged)!=1 {
            di as error "RMIDAS `rmtype' nonlinear least squares did not converge"
            exit 430
        }

        // Shape parameters can be weakly identified at boundary-like
        // solutions.  Flag missing shape-parameter standard errors, but
        // retain the converged model and its implied weights.
        forvalues j=1/`nhfp' {
            capture local sec1 = _se[/c1`j']
            if _rc local shape_warning = 1
            else if missing(`sec1') local shape_warning = 1

            capture local sec2 = _se[/c2`j']
            if _rc local shape_warning = 1
            else if missing(`sec2') local shape_warning = 1
        }

        local rhs "[stable nonlinear function evaluator]"

        if "`trace'"!="" {
            di as text "nonlinear least squares converged in " as result e(ic) as text " iteration(s)"
        }
    }

    // -------------------------------------------------------------------------
    // Extract model coefficients needed for common prediction code
    // -------------------------------------------------------------------------

    tempname LF C W SW P O H T

    matrix `LF' = J(1,`py',.)
    local lfcn ""
    forvalues q=1/`py' {
        local lag = `horizon' + `q' - 1
        if "`engine'"=="ols" matrix `LF'[1,`q'] = _b[L`lag'.`depvar']
        else                   matrix `LF'[1,`q'] = _b[/a`q']
        local lfcn "`lfcn' lag`q'"
    }
    matrix colnames `LF' = `lfcn'
    matrix rownames `LF' = coefficient

    if `nctrl'>0 {
        matrix `C' = J(1,`nctrl',.)
        local ccn ""
        forvalues c=1/`nctrl' {
            local cv : word `c' of `controls'
            if "`engine'"=="ols" matrix `C'[1,`c'] = _b[`cv']
            else                   matrix `C'[1,`c'] = _b[/d`c']
            local ccn "`ccn' c`c'"
        }
        matrix colnames `C' = `ccn'
        matrix rownames `C' = coefficient
    }

    local const = 0
    if "`noconstant'"=="" {
        if "`engine'"=="ols" local const = _b[_cons]
        else                   local const = _b[/mu]
    }

    // -------------------------------------------------------------------------
    // Reconstruct effective HF coefficients implied by each restriction
    // -------------------------------------------------------------------------

    matrix `W' = J(`nhfp',`maxK',.)
    if inlist("`rmtype'","expalmon","beta") {
        matrix `SW' = J(`nhfp',`maxK',.)
        matrix `P'  = J(`nhfp',3,.)
    }

    forvalues j=1/`nhfp' {
        local Kj = `K`j''

        if "`rmtype'"=="almon" {
            forvalues jj=1/`Kj' {
                local wij = 0
                forvalues r=0/`degree' {
                    local pos = `r'+1
                    local bv : word `pos' of `basislist`j''
                    local theta = _b[`bv']
                    local wij = `wij' + `theta'*(`jj'^`r')
                }
                matrix `W'[`j',`jj'] = `wij'
            }
        }
        else if "`rmtype'"=="legendre" {
            // Use the exact Legendre basis matrix that generated the OLS
            // transformed regressors above.  No basis is recomputed here.
            local LBname "`legmat`j''"
            forvalues jj=1/`Kj' {
                local wij = 0
                forvalues r=0/`degree' {
                    local pos = `r'+1
                    local bv : word `pos' of `basislist`j''
                    local theta = _b[`bv']
                    local val = `LBname'[`pos',`jj']
                    local wij = `wij' + `theta'*`val'
                }
                matrix `W'[`j',`jj'] = `wij'
            }
        }
        else if "`rmtype'"=="step" {
            forvalues g=1/`steps' {
                local bv : word `g' of `basislist`j''
                local theta = _b[`bv']
                local lo = floor((`g'-1)*`Kj'/`steps') + 1
                local hi = floor(`g'*`Kj'/`steps')
                forvalues jj=`lo'/`hi' {
                    matrix `W'[`j',`jj'] = `theta'
                }
            }
        }
        else if "`rmtype'"=="expalmon" {
            local bx = _b[/bx`j']
            local c1 = _b[/c1`j']
            local c2 = _b[/c2`j']
            matrix `P'[`j',1] = `bx'
            matrix `P'[`j',2] = `c1'
            matrix `P'[`j',3] = `c2'

            // Log-sum-exp stabilization.  Subtracting max(eta_j) leaves
            // normalized exponential-Almon weights mathematically unchanged.
            local maxeta = .
            forvalues jj=1/`Kj' {
                local eta = `c1'*`jj' + `c2'*(`jj'^2)
                if missing(`maxeta') | `eta'>`maxeta' local maxeta = `eta'
            }
            local den = 0
            forvalues jj=1/`Kj' {
                local eta = `c1'*`jj' + `c2'*(`jj'^2)
                local wk = exp(`eta'-`maxeta')
                local den = `den' + `wk'
            }
            forvalues jj=1/`Kj' {
                local eta = `c1'*`jj' + `c2'*(`jj'^2)
                local wk = exp(`eta'-`maxeta')
                local sw = `wk'/`den'
                matrix `SW'[`j',`jj'] = `sw'
                matrix `W'[`j',`jj']  = `bx'*`sw'
            }
        }
        else {
            local bx = _b[/bx`j']
            local c1 = _b[/c1`j']
            local c2 = _b[/c2`j']
            matrix `P'[`j',1] = `bx'
            matrix `P'[`j',2] = `c1'
            matrix `P'[`j',3] = `c2'

            // Match the optimizer's stabilized Beta evaluation exactly.
            // For representable exp(c), use log-sum-exp.  Beyond floating-point
            // range, use the normalized kernel's machine-precision limiting
            // mass on the discrete maximizer(s); c1/c2 themselves are unbounded.
            if `c1'<=700 & `c2'<=700 {
                local a1 = exp(`c1')-1
                local a2 = exp(`c2')-1
                local maxlogw = .
                forvalues jj=1/`Kj' {
                    local x = `jj'/(`Kj'+1)
                    local logwk = `a1'*ln(`x') + `a2'*ln(1-`x')
                    if missing(`maxlogw') | `logwk'>`maxlogw' local maxlogw = `logwk'
                }
                local den = 0
                forvalues jj=1/`Kj' {
                    local x = `jj'/(`Kj'+1)
                    local logwk = `a1'*ln(`x') + `a2'*ln(1-`x')
                    local wk = exp(`logwk'-`maxlogw')
                    local den = `den' + `wk'
                }
                forvalues jj=1/`Kj' {
                    local x = `jj'/(`Kj'+1)
                    local logwk = `a1'*ln(`x') + `a2'*ln(1-`x')
                    local wk = exp(`logwk'-`maxlogw')
                    local sw = `wk'/`den'
                    matrix `SW'[`j',`jj'] = `sw'
                    matrix `W'[`j',`jj']  = `bx'*`sw'
                }
            }
            else {
                local m = max(`c1',`c2')
                local r1 = exp(`c1'-`m')
                local r2 = exp(`c2'-`m')
                local maxg = .
                forvalues jj=1/`Kj' {
                    local x = `jj'/(`Kj'+1)
                    local g = `r1'*ln(`x') + `r2'*ln(1-`x')
                    if missing(`maxg') | `g'>`maxg' local maxg = `g'
                }
                local tol = 1e-14*max(1,abs(`maxg'))
                local nmax = 0
                forvalues jj=1/`Kj' {
                    local x = `jj'/(`Kj'+1)
                    local g = `r1'*ln(`x') + `r2'*ln(1-`x')
                    if abs(`g'-`maxg')<=`tol' local nmax = `nmax'+1
                }
                forvalues jj=1/`Kj' {
                    local x = `jj'/(`Kj'+1)
                    local g = `r1'*ln(`x') + `r2'*ln(1-`x')
                    if abs(`g'-`maxg')<=`tol' local sw = 1/`nmax'
                    else                         local sw = 0
                    matrix `SW'[`j',`jj'] = `sw'
                    matrix `W'[`j',`jj']  = `bx'*`sw'
                }
            }
        }
    }

    // Boundary concentration is itself a useful weak-identification
    // diagnostic even when nl reports finite standard errors.  Flag any
    // nonlinear block whose normalized shape places essentially all weight
    // on one HF observation.
    if inlist("`rmtype'","expalmon","beta") {
        forvalues j=1/`nhfp' {
            local Kj = `K`j''
            local maxsw = 0
            forvalues jj=1/`Kj' {
                local swj = `SW'[`j',`jj']
                if `swj'>`maxsw' local maxsw = `swj'
            }
            if `maxsw'>=.999999 local shape_warning = 1
        }
    }

    // Give OLS restriction coefficients readable names in e(b)/e(V).
    // Prediction uses e(weights), so postestimation does not depend on these names.
    if "`engine'"=="ols" {
        tempname bnice
        matrix `bnice' = e(b)
        local oldcn : colnames `bnice'
        local newcn ""
        foreach nm of local oldcn {
            local repl "`nm'"
            local ii = 0
            foreach ov of local oldbasis {
                local ++ii
                if "`nm'"=="`ov'" {
                    local repl : word `ii' of `newbasis'
                }
            }
            local newcn "`newcn' `repl'"
        }
        matrix colnames `bnice' = `newcn'
        ereturn repost b=`bnice', rename
    }

    local rnames ""
    forvalues j=1/`nhfp' {
        local rnames "`rnames' `hstub`j''"
    }
    matrix rownames `W' = `rnames'
    if inlist("`rmtype'","expalmon","beta") {
        matrix rownames `SW' = `rnames'
        matrix rownames `P'  = `rnames'
        matrix colnames `P'  = scale c1 c2
    }

    local wcn ""
    forvalues k=1/`maxK' {
        local wcn "`wcn' w`k'"
    }
    matrix colnames `W' = `wcn'
    if inlist("`rmtype'","expalmon","beta") matrix colnames `SW' = `wcn'

    // -------------------------------------------------------------------------
    // Order, sampling-rate, and term-count matrices
    // -------------------------------------------------------------------------

    // e(rhs) is deliberately descriptive.  The OLS basis variables are tempvars
    // and disappear after estimation, so storing their literal names would leave
    // unusable postestimation metadata.
    local rhsdesc "`lfrhs' [HF `rmtype': `hfpredictors']"
    if "`controls'"!="" local rhsdesc "`rhsdesc' `controls'"

    matrix `O' = J(1,`nblocks',.)
    matrix `O'[1,1] = `py'

    // Legal, robust matrix column names (Stata names are at most 32 characters).
    local base "LF_`depvar'"
    local cname = substr("`base'",1,32)
    local ocn "`cname'"
    local usedocn "`cname'"

    forvalues j=1/`nhfp' {
        local b = `j'+1
        matrix `O'[1,`b'] = `ord`b''

        local base "HF_`hstub`j''"
        local cname = substr("`base'",1,32)
        if strpos(" `usedocn' "," `cname' ") {
            local suffix "_`j'"
            local keep = 32-strlen("`suffix'")
            local cname = substr("`base'",1,`keep') + "`suffix'"
        }
        local ocn "`ocn' `cname'"
        local usedocn "`usedocn' `cname'"
    }
    matrix colnames `O' = `ocn'
    matrix rownames `O' = selected

    matrix `H' = J(1,`nhfp',.)
    matrix `T' = J(1,`nhfp',.)
    local hcn ""
    forvalues j=1/`nhfp' {
        matrix `H'[1,`j'] = `hfn`j''
        matrix `T'[1,`j'] = `K`j''
        local hcn "`hcn' `hstub`j''"
    }
    matrix colnames `H' = `hcn'
    matrix colnames `T' = `hcn'
    matrix rownames `H' = n
    matrix rownames `T' = selected_terms

    // -------------------------------------------------------------------------
    // Add RMIDAS metadata without disturbing underlying e(b), e(V), e(sample)
    // -------------------------------------------------------------------------

    ereturn scalar horizon = `horizon'
    ereturn scalar constant = `const'

    if "`rmtype'"=="almon" | "`rmtype'"=="legendre" {
        ereturn scalar degree = `degree'
    }
    if "`rmtype'"=="step" {
        ereturn scalar steps = `steps'
    }
    if "`porders'"=="" {
        ereturn scalar p = `porder'
    }

    ereturn matrix orders = `O'
    ereturn matrix hfn = `H'
    ereturn matrix hfterms = `T'
    ereturn matrix lfcoef = `LF'
    if `nctrl'>0 ereturn matrix controlcoef = `C'
    ereturn matrix weights = `W'
    if inlist("`rmtype'","expalmon","beta") {
        ereturn matrix shapeweights = `SW'
        ereturn matrix shapeparams = `P'
        ereturn scalar shape_warning = `shape_warning'
    }

    ereturn local engine       "`engine'"
    ereturn local rmtype       "`rmtype'"
    ereturn local weight       "`rmtype'"
    ereturn local hfpredictors "`hfpredictors'"
    ereturn local controls     "`controls'"
    ereturn local rhs          `"`rhsdesc'"'
    ereturn local predict      "rmidas_p"
    ereturn local title        "Restricted MIDAS regression"
    ereturn local cmdline      `"`cmdline'"'
    ereturn local cmd          "rmidas"

    // -------------------------------------------------------------------------
    // Display
    // -------------------------------------------------------------------------

    _rmidas_display
    if "`regression'"!="" ereturn display
end


// =============================================================================
// Validate a high-frequency stub and count contiguous terms stub0,...,stubK
// =============================================================================
program define _rmidas_stubinfo, rclass
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


// =============================================================================
// Compact results display
// =============================================================================
program define _rmidas_display
    version 11.0

    if "`e(cmd)'"!="rmidas" error 301

    local wt "`e(rmtype)'"
    if "`wt'"=="almon"         local wtitle "Almon polynomial"
    else if "`wt'"=="step"     local wtitle "Step function"
    else if "`wt'"=="legendre" local wtitle "Legendre polynomial"
    else if "`wt'"=="expalmon" local wtitle "Exponential Almon"
    else                          local wtitle "Beta"

    di _newline as text "Restricted MIDAS regression"
    di as text "{hline 28}"
    di as text "Forecast horizon = " as result %6.0f e(horizon)
    di as text "Weight function   = " as result "`wtitle'"

    if inlist("`wt'","almon","legendre") {
        di as text "Polynomial degree = " as result %5.0f e(degree)
    }
    else if "`wt'"=="step" {
        di as text "Steps             = " as result %5.0f e(steps)
    }

    di as text "Observations      = " as result %6.0f e(N)

    if inlist("`wt'","expalmon","beta") & e(shape_warning)==1 {
        di _newline as text ///
            "note: nonlinear weight-shape parameters are weakly identified;"
        di as text ///
            "      implied weights may be concentrated near the boundary."
    }

    tempname O H T
    matrix `O' = e(orders)
    matrix `H' = e(hfn)
    matrix `T' = e(hfterms)

    local nhfp : word count `e(hfpredictors)'

    di _newline as text "Orders"
    di as text "  LF target (`e(depvar)')" _col(36) as result %5.0f `O'[1,1]

    forvalues j=1/`nhfp' {
        local s : word `j' of `e(hfpredictors)'
        local b = `j'+1
        di as text "  HF predictor (`s')" _col(36) as result %5.0f `O'[1,`b'] ///
            as text "   n=" as result %4.0f `H'[1,`j'] ///
            as text "   terms=" as result %5.0f `T'[1,`j']
    }
end
