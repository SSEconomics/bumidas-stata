*! version 0.2.0 1oct2026
program define umidas, eclass
    version 11.0

    // Replay previously stored UMIDAS results
    if replay() {
        if "`e(cmd)'"!="umidas" error 301
        syntax [, REGression]
        _umidas_display
        if "`regression'"!="" ereturn display
        exit
    }

    local cmdline `"umidas `0'"'

    syntax varname(numeric) [if] [in] [, ///
        HFPREDICTORS(string asis) ///
        HFN(numlist integer >=2) ///
        PMAX(integer -1) ///
        PORDER(integer -1) ///
        PORDERS(numlist integer >=1) ///
        SEARCH(string) ///
        IC(string) ///
        CONTROLS(varlist numeric ts fv) ///
        HORIZON(integer 1) ///
        NOCONstant REGression TRACE]

    local depvar "`varlist'"
    local search = lower("`search'")
    local ic     = lower("`ic'")

    if "`search'"=="" local search "block"
    if "`ic'"==""     local ic "bic"
    local IC = upper("`ic'")

    // -------------------------------------------------------------------------
    // Validate general options and time-series setup
    // -------------------------------------------------------------------------

    if "`hfpredictors'"=="" {
        di as error "hfpredictors() is required"
        exit 198
    }

    if !inlist("`search'","block","common") {
        di as error "search() must be block or common"
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

    if `pmax'==0 | `pmax'<-1 {
        di as error "pmax() must be a positive integer"
        exit 198
    }

    if `porder'==0 | `porder'<-1 {
        di as error "porder() must be a positive integer"
        exit 198
    }

    local nfixed = (`porder'!=-1) + ("`porders'"!="")
    if `nfixed'>1 {
        di as error "specify only one of porder() or porders()"
        exit 198
    }

    if `pmax'!=-1 & `nfixed'>0 {
        di as error "pmax() may not be combined with porder() or porders()"
        exit 198
    }

    capture quietly tsset
    if _rc {
        di as error "data must be tsset before using umidas"
        exit 459
    }

    marksample touse

    // -------------------------------------------------------------------------
    // Validate HF predictor stubs and count available contiguous terms
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

        _umidas_stubinfo, stub(`s')
        local havail`j' = r(terms)
        local hstub`j' "`s'"
    }

    // -------------------------------------------------------------------------
    // Determine n_j for each HF predictor
    //
    // hfn() may contain one common value or one value per HF block.
    // Without hfn(), first look for block-specific metadata on stub0. With one
    // HF block, fall back to the dataset-level _dta[hfn] stored by mfcollapse.
    // With multiple merged blocks, dataset-level metadata are ambiguous and are
    // therefore not used automatically.
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
        local pavail`j'    = floor(`havail`j'' / `blocksize`j'')

        if `pavail`j''<1 {
            di as error ///
                "HF predictor `s' has only `havail`j'' available term(s); " ///
                "UMIDAS requires at least n-1=`blocksize`j'' terms for one HF block"
            exit 198
        }
    }

    // Common feasible maximum across HF blocks
    local pfeasible = .
    forvalues j=1/`nhfp' {
        if missing(`pfeasible') local pfeasible = `pavail`j''
        else local pfeasible = min(`pfeasible',`pavail`j'')
    }

    // -------------------------------------------------------------------------
    // Fixed-order specifications
    //
    // porder(#): common fixed order (p,p,...,p), p>=1
    // porders(): vector (p_y,p_1,...,p_J), every component >=1
    // -------------------------------------------------------------------------

    local fixed = (`nfixed'>0)

    if `porder'!=-1 {
        if `porder'>`pfeasible' {
            di as error "porder(`porder') requires more HF terms than are available"
            forvalues j=1/`nhfp' {
                local need = `porder'*`blocksize`j''
                di as error "  `hstub`j'': needs `need', available `havail`j''"
            }
            exit 198
        }

        forvalues b=1/`nblocks' {
            local fixedord`b' = `porder'
        }
        local psearchmax = `porder'
    }

    if "`porders'"!="" {
        local nporders : word count `porders'
        if `nporders'!=`nblocks' {
            di as error ///
                "porders() must contain `nblocks' positive values: LF target first, then one for each HF predictor"
            exit 198
        }

        forvalues b=1/`nblocks' {
            local ob : word `b' of `porders'
            local fixedord`b' = `ob'
        }

        forvalues j=1/`nhfp' {
            local b = `j'+1
            if `fixedord`b''>`pavail`j'' {
                local need = `fixedord`b''*`blocksize`j''
                di as error ///
                    "porders(): HF order `fixedord`b'' for `hstub`j'' needs `need' terms; " ///
                    "only `havail`j'' are available"
                exit 198
            }
        }

        local psearchmax = 1
        forvalues b=1/`nblocks' {
            if `fixedord`b''>`psearchmax' local psearchmax = `fixedord`b''
        }
    }

    // -------------------------------------------------------------------------
    // Search ranges
    //
    // search(block): p_y,p_j = 1,...,pmax independently
    // search(common): p=1,...,pmax with p_y=p_1=...=p_J=p
    //
    // UMIDAS treats all supplied blocks as included.  A separate diagnostic
    // search below reports whether IC would improve if HF blocks could be
    // excluded, but it does not change the selected UMIDAS specification.
    // -------------------------------------------------------------------------

    if !`fixed' {
        if `pmax'==-1 local pmax = `pfeasible'

        if `pmax'>`pfeasible' {
            di as error "pmax(`pmax') requires more HF terms than are available"
            forvalues j=1/`nhfp' {
                local need = `pmax'*`blocksize`j''
                di as error "  `hstub`j'': needs `need', available `havail`j''"
            }
            exit 198
        }

        local psearchmax = `pmax'
    }

    // Largest orders used to construct the common estimation sample
    if `fixed' {
        forvalues b=1/`nblocks' {
            local maxord`b' = `fixedord`b''
        }
    }
    else {
        forvalues b=1/`nblocks' {
            local maxord`b' = `psearchmax'
        }
    }

    // -------------------------------------------------------------------------
    // Common estimation sample from the largest admissible model
    // -------------------------------------------------------------------------

    local rhsmax "`controls'"

    // Block 1 is the LF target order p_y; p_y is always at least 1.
    local pymax = `maxord1'
    forvalues j=0/`=`pymax'-1' {
        local lag = `horizon' + `j'
        local rhsmax "`rhsmax' L`lag'.`depvar'"
    }

    // Blocks 2,... are HF predictor orders p_j; each is always at least 1.
    forvalues j=1/`nhfp' {
        local b = `j'+1
        local pj = `maxord`b''
        local s "`hstub`j''"
        local nterms = `pj' * `blocksize`j''

        forvalues k=0/`=`nterms'-1' {
            local rhsmax "`rhsmax' L`horizon'.`s'`k'"
        }
    }

    local regopts ""
    if "`noconstant'"!="" local regopts ", noconstant"

    tempvar sample
    capture quietly regress `depvar' `rhsmax' if `touse' `regopts'
    if _rc {
        di as error "largest UMIDAS model could not be estimated"
        di as error "check available lags, collinearity, and the requested sample"
        exit _rc
    }

    quietly gen byte `sample' = e(sample)
    quietly count if `sample'
    if r(N)==0 {
        di as error "largest UMIDAS model has no usable observations"
        exit 2000
    }
    local commonN = r(N)

    // -------------------------------------------------------------------------
    // Baseline UMIDAS search / fixed estimation
    // -------------------------------------------------------------------------

    tempname bestIC candIC
    scalar `bestIC' = .
    scalar `candIC' = .

    local bestRHS ""
    local bestk = .
    local Nmodels = 0
    local tol = 1e-10

    forvalues b=1/`nblocks' {
        local bestord`b' = .
    }

    // Number of baseline candidate models requested
    local requested = 1
    if !`fixed' & "`search'"=="common" {
        local requested = `psearchmax'
    }
    else if !`fixed' & "`search'"=="block" {
        local requested = (`psearchmax')^`nblocks'
    }

    if !`fixed' & "`search'"=="block" & `requested'>10000 {
        di as text "note: block search will evaluate up to " ///
            as result %12.0fc `requested' as text " candidate models"
    }

    local first = 1
    local last  = 1
    if !`fixed' & "`search'"=="common" {
        local first = 1
        local last  = `psearchmax'
    }
    else if !`fixed' & "`search'"=="block" {
        local first = 0
        local last  = `requested'-1
    }

    forvalues m=`first'/`last' {

        // -------------------------------------------------------------
        // Construct candidate order vector; all baseline orders >= 1
        // -------------------------------------------------------------

        if `fixed' {
            forvalues b=1/`nblocks' {
                local ord`b' = `fixedord`b''
            }
        }
        else if "`search'"=="common" {
            forvalues b=1/`nblocks' {
                local ord`b' = `m'
            }
        }
        else {
            // Decode model number in base pmax, then add 1.
            // Order vector is (p_y,p_1,...,p_J), each in 1,...,pmax.
            local code = `m'
            local base = `psearchmax'
            forvalues b=1/`nblocks' {
                local ord`b' = mod(`code',`base') + 1
                local code = floor(`code'/`base')
            }
        }

        // ---------------------------------------------------------
        // Construct candidate RHS
        // ---------------------------------------------------------

        local rhs "`controls'"

        local py = `ord1'
        forvalues j=0/`=`py'-1' {
            local lag = `horizon' + `j'
            local rhs "`rhs' L`lag'.`depvar'"
        }

        forvalues j=1/`nhfp' {
            local b = `j'+1
            local pj = `ord`b''
            local s "`hstub`j''"
            local nterms = `pj' * `blocksize`j''

            forvalues k=0/`=`nterms'-1' {
                local rhs "`rhs' L`horizon'.`s'`k'"
            }
        }

        local ordvec ""
        forvalues b=1/`nblocks' {
            if `b'==1 local ordvec "`ord`b''"
            else      local ordvec "`ordvec',`ord`b''"
        }

        capture quietly regress `depvar' `rhs' if `sample' `regopts'
        if _rc {
            di as error "UMIDAS candidate orders=(`ordvec') could not be estimated"
            exit _rc
        }
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
        else if abs(scalar(`candIC')-scalar(`bestIC'))<=`tol' {
            if `candk'<`bestk' {
                local choose = 1
            }
            else if `candk'==`bestk' {
                local decided = 0
                forvalues b=1/`nblocks' {
                    if !`decided' {
                        if `ord`b''<`bestord`b'' {
                            local choose = 1
                            local decided = 1
                        }
                        else if `ord`b''>`bestord`b'' {
                            local decided = 1
                        }
                    }
                }
            }
        }

        if "`trace'"!="" {
            if "`search'"=="common" | `fixed' {
                di as text "orders=(" as result "`ordvec'" as text ")" ///
                    as text "  k=" as result %4.0f e(rank) ///
                    as text "  N=" as result %6.0f e(N) ///
                    as text "  `IC'=" as result %12.6f scalar(`candIC')
            }
            else if `choose' {
                di as text "new best: orders=(" as result "`ordvec'" as text ")" ///
                    as text "  k=" as result %4.0f e(rank) ///
                    as text "  `IC'=" as result %12.6f scalar(`candIC')
            }
        }

        if `choose' {
            scalar `bestIC' = scalar(`candIC')
            local bestk = `candk'
            local bestRHS "`rhs'"
            forvalues b=1/`nblocks' {
                local bestord`b' = `ord`b''
            }
        }
    }

    if `Nmodels'==0 | missing(scalar(`bestIC')) {
        di as error "no admissible UMIDAS model could be estimated"
        exit 2000
    }

    // -------------------------------------------------------------------------
    // Auxiliary exclusion diagnostic
    //
    // Baseline UMIDAS always includes every supplied HF block (p_j>=1).
    // For IC-selected models only, evaluate whether IC could be lowered if one
    // or more HF blocks were allowed to have p_j=0.  LF target order remains
    // >=1.  The diagnostic uses the same common estimation sample and never
    // changes the selected UMIDAS model.
    // -------------------------------------------------------------------------

    tempname dropIC dropCandIC
    scalar `dropIC' = .
    scalar `dropCandIC' = .
    local dropk = .
    local dropRHS ""
    local Ndropmodels = 0
    local dropimproves = 0
    local dropblocks ""

    forvalues b=1/`nblocks' {
        local dropord`b' = .
    }

    if !`fixed' {
        if "`search'"=="block" {
            // p_y in 1,...,pmax; each HF p_j in 0,...,pmax.
            local droprequested = `psearchmax' * (`psearchmax'+1)^`nhfp'

            forvalues m=0/`=`droprequested'-1' {
                local code = `m'

                // LF target order is always positive.
                local dord1 = mod(`code',`psearchmax') + 1
                local code = floor(`code'/`psearchmax')

                forvalues j=1/`nhfp' {
                    local b = `j'+1
                    local dord`b' = mod(`code',`psearchmax'+1)
                    local code = floor(`code'/(`psearchmax'+1))
                }

                local hasdrop = 0
                forvalues j=1/`nhfp' {
                    local b = `j'+1
                    if `dord`b''==0 local hasdrop = 1
                }

                if `hasdrop' {
                    local rhs "`controls'"

                    forvalues q=0/`=`dord1'-1' {
                        local lag = `horizon' + `q'
                        local rhs "`rhs' L`lag'.`depvar'"
                    }

                    forvalues j=1/`nhfp' {
                        local b = `j'+1
                        local pj = `dord`b''
                        local s "`hstub`j''"
                        local nterms = `pj' * `blocksize`j''

                        if `nterms'>0 {
                            forvalues k=0/`=`nterms'-1' {
                                local rhs "`rhs' L`horizon'.`s'`k'"
                            }
                        }
                    }

                    capture quietly regress `depvar' `rhs' if `sample' `regopts'
                    if _rc {
                        di as error "UMIDAS HF-exclusion diagnostic model could not be estimated"
                        exit _rc
                    }
                    local ++Ndropmodels

                    if "`ic'"=="aic" {
                        scalar `dropCandIC' = -2*e(ll) + 2*e(rank)
                    }
                    else if "`ic'"=="hqic" {
                        scalar `dropCandIC' = -2*e(ll) + 2*ln(ln(e(N)))*e(rank)
                    }
                    else {
                        scalar `dropCandIC' = -2*e(ll) + ln(e(N))*e(rank)
                    }

                    local candk = e(rank)
                    local choose = 0
                    if missing(scalar(`dropIC')) {
                        local choose = 1
                    }
                    else if scalar(`dropCandIC') < scalar(`dropIC') - `tol' {
                        local choose = 1
                    }
                    else if abs(scalar(`dropCandIC')-scalar(`dropIC'))<=`tol' {
                        if `candk'<`dropk' {
                            local choose = 1
                        }
                        else if `candk'==`dropk' {
                            local decided = 0
                            forvalues b=1/`nblocks' {
                                if !`decided' {
                                    if `dord`b''<`dropord`b'' {
                                        local choose = 1
                                        local decided = 1
                                    }
                                    else if `dord`b''>`dropord`b'' {
                                        local decided = 1
                                    }
                                }
                            }
                        }
                    }

                    if `choose' {
                        scalar `dropIC' = scalar(`dropCandIC')
                        local dropk = `candk'
                        local dropRHS "`rhs'"
                        forvalues b=1/`nblocks' {
                            local dropord`b' = `dord`b''
                        }
                    }
                }
            }
        }
        else {
            // search(common): for each common p, included HF blocks have p and
            // excluded blocks have 0.  LF target always has the common p.
            local subsets = 2^`nhfp'

            forvalues p=1/`psearchmax' {
                forvalues mask=0/`=`subsets'-2' {
                    // mask=subsets-1 would keep every HF block and is baseline.
                    local dord1 = `p'
                    local rhs "`controls'"

                    forvalues q=0/`=`p'-1' {
                        local lag = `horizon' + `q'
                        local rhs "`rhs' L`lag'.`depvar'"
                    }

                    forvalues j=1/`nhfp' {
                        local b = `j'+1
                        local keep = mod(floor(`mask'/(2^(`j'-1))),2)
                        if `keep' local dord`b' = `p'
                        else      local dord`b' = 0

                        local pj = `dord`b''
                        local s "`hstub`j''"
                        local nterms = `pj' * `blocksize`j''

                        if `nterms'>0 {
                            forvalues k=0/`=`nterms'-1' {
                                local rhs "`rhs' L`horizon'.`s'`k'"
                            }
                        }
                    }

                    capture quietly regress `depvar' `rhs' if `sample' `regopts'
                    if _rc {
                        di as error "UMIDAS HF-exclusion diagnostic model could not be estimated"
                        exit _rc
                    }
                    local ++Ndropmodels

                    if "`ic'"=="aic" {
                        scalar `dropCandIC' = -2*e(ll) + 2*e(rank)
                    }
                    else if "`ic'"=="hqic" {
                        scalar `dropCandIC' = -2*e(ll) + 2*ln(ln(e(N)))*e(rank)
                    }
                    else {
                        scalar `dropCandIC' = -2*e(ll) + ln(e(N))*e(rank)
                    }

                    local candk = e(rank)
                    local choose = 0
                    if missing(scalar(`dropIC')) {
                        local choose = 1
                    }
                    else if scalar(`dropCandIC') < scalar(`dropIC') - `tol' {
                        local choose = 1
                    }
                    else if abs(scalar(`dropCandIC')-scalar(`dropIC'))<=`tol' {
                        if `candk'<`dropk' {
                            local choose = 1
                        }
                        else if `candk'==`dropk' {
                            local decided = 0
                            forvalues b=1/`nblocks' {
                                if !`decided' {
                                    if `dord`b''<`dropord`b'' {
                                        local choose = 1
                                        local decided = 1
                                    }
                                    else if `dord`b''>`dropord`b'' {
                                        local decided = 1
                                    }
                                }
                            }
                        }
                    }

                    if `choose' {
                        scalar `dropIC' = scalar(`dropCandIC')
                        local dropk = `candk'
                        local dropRHS "`rhs'"
                        forvalues b=1/`nblocks' {
                            local dropord`b' = `dord`b''
                        }
                    }
                }
            }
        }

        if !missing(scalar(`dropIC')) & scalar(`dropIC') < scalar(`bestIC') - `tol' {
            local dropimproves = 1
            forvalues j=1/`nhfp' {
                local b = `j'+1
                if `dropord`b''==0 {
                    if "`dropblocks'"=="" local dropblocks "`hstub`j''"
                    else local dropblocks "`dropblocks' `hstub`j''"
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Re-estimate selected/fixed UMIDAS model on the common sample
    // -------------------------------------------------------------------------

    quietly regress `depvar' `bestRHS' if `sample' `regopts'

    // -------------------------------------------------------------------------
    // Matrices describing selected orders, n_j, and HF term counts
    // -------------------------------------------------------------------------

    tempname orders hfnmat termsmat availmat maxorders droporders
    matrix `orders'    = J(1,`nblocks',.)
    matrix `maxorders' = J(1,`nblocks',.)
    matrix `hfnmat'    = J(1,`nhfp',.)
    matrix `termsmat'  = J(1,`nhfp',.)
    matrix `availmat'  = J(1,`nhfp',.)
    matrix `droporders'= J(1,`nblocks',.)

    local ordernames ""
    local ordertypes ""
    local ocnames ""
    local usedcnames ""

    // LF target block
    matrix `orders'[1,1]    = `bestord1'
    matrix `maxorders'[1,1] = `maxord1'
    if !`fixed' matrix `droporders'[1,1] = `dropord1'
    local ordernames "`depvar'"
    local ordertypes "lftarget"
    local base "LF_`depvar'"
    local cname = substr("`base'",1,32)
    local ocnames "`cname'"
    local usedcnames "`cname'"

    // HF blocks
    local hcnames ""
    forvalues j=1/`nhfp' {
        local b = `j'+1
        local s "`hstub`j''"

        matrix `orders'[1,`b']    = `bestord`b''
        matrix `maxorders'[1,`b'] = `maxord`b''
        if !`fixed' matrix `droporders'[1,`b'] = `dropord`b''
        matrix `hfnmat'[1,`j']    = `hfn`j''
        matrix `termsmat'[1,`j']  = `bestord`b'' * `blocksize`j''
        matrix `availmat'[1,`j']  = `havail`j''

        local ordernames "`ordernames' `s'"
        local ordertypes "`ordertypes' hfpredictor"

        local base "HF_`s'"
        local cname = substr("`base'",1,32)
        if strpos(" `usedcnames' "," `cname' ") {
            local suffix "_`b'"
            local keep = 32-strlen("`suffix'")
            local cname = substr("`base'",1,`keep') + "`suffix'"
        }
        local ocnames "`ocnames' `cname'"
        local usedcnames "`usedcnames' `cname'"
        local hcnames "`hcnames' `s'"
    }

    matrix colnames `orders'     = `ocnames'
    matrix colnames `maxorders'  = `ocnames'
    matrix colnames `droporders' = `ocnames'
    matrix rownames `orders'     = selected
    matrix rownames `maxorders'  = maximum
    matrix rownames `droporders' = exclusion_diagnostic

    matrix colnames `hfnmat'   = `hcnames'
    matrix colnames `termsmat' = `hcnames'
    matrix colnames `availmat' = `hcnames'
    matrix rownames `hfnmat'   = n
    matrix rownames `termsmat' = selected_terms
    matrix rownames `availmat' = available_terms

    // Determine whether selected vector is common
    local selectedcommon = 1
    forvalues b=2/`nblocks' {
        if `bestord`b''!=`bestord1' local selectedcommon = 0
    }

    // Add UMIDAS metadata without disturbing regress e(b), e(V), e(sample)
    ereturn scalar horizon  = `horizon'
    ereturn scalar pmax     = `psearchmax'
    ereturn scalar icvalue  = scalar(`bestIC')
    ereturn scalar N_models = `Nmodels'
    ereturn scalar N_common = `commonN'
    ereturn scalar common_selected = `selectedcommon'
    ereturn scalar drop_improves = `dropimproves'
    ereturn scalar N_dropmodels = `Ndropmodels'

    if !`fixed' & !missing(scalar(`dropIC')) {
        ereturn scalar ic_dropbest = scalar(`dropIC')
        ereturn matrix droporders = `droporders'
    }

    if `selectedcommon' ereturn scalar p = `bestord1'

    ereturn matrix orders      = `orders'
    ereturn matrix maxorders   = `maxorders'
    ereturn matrix hfn         = `hfnmat'
    ereturn matrix hfterms     = `termsmat'
    ereturn matrix hfavailable = `availmat'

    if `fixed' ereturn local selection "fixed"
    else       ereturn local selection "ic"

    if `fixed' {
        if `porder'!=-1 ereturn local fixedtype "common"
        else            ereturn local fixedtype "block"
        ereturn local search "fixed"
    }
    else {
        ereturn local search "`search'"
    }

    ereturn local ic           "`ic'"
    ereturn local rhs          "`bestRHS'"
    ereturn local hfpredictors "`hfpredictors'"
    ereturn local controls     "`controls'"
    ereturn local order_names  "`ordernames'"
    ereturn local order_types  "`ordertypes'"
    ereturn local drop_blocks  "`dropblocks'"
    ereturn local predict      "umidas_p"
    ereturn local title        "Unrestricted MIDAS regression"
    ereturn local cmdline      `"`cmdline'"'
    ereturn local cmd          "umidas"

    // -------------------------------------------------------------------------
    // Display
    // -------------------------------------------------------------------------

    _umidas_display

    if "`regression'"!="" {
        ereturn display
    }
end


// =============================================================================
// Validate a high-frequency stub and count contiguous terms stub0,...,stubK
// =============================================================================
program define _umidas_stubinfo, rclass
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
// Compact UMIDAS results display
// =============================================================================
program define _umidas_display
    version 11.0

    if "`e(cmd)'"!="umidas" error 301

    local IC = upper("`e(ic)'")

    di _newline as text "Unrestricted MIDAS regression"
    di as text "{hline 32}"
    di as text "Forecast horizon = " as result %6.0f e(horizon)

    if "`e(selection)'"=="fixed" {
        if "`e(fixedtype)'"=="common" {
            di as text "Specification    = " as result "fixed common order"
        }
        else {
            di as text "Specification    = " as result "fixed block orders"
        }
    }
    else {
        di as text "Selection        = " as result "`IC', `e(search)' search"
        di as text "Maximum order    = " as result %6.0f e(pmax)
    }

    di as text "Observations     = " as result %6.0f e(N)
    di as text "Models evaluated = " as result %10.0fc e(N_models)

    di _newline as text "Selected orders"

    tempname O H T
    matrix `O' = e(orders)
    matrix `H' = e(hfn)
    matrix `T' = e(hfterms)

    local dep "`e(depvar)'"
    di as text "  LF target (`dep')" ///
        _col(31) as result %5.0f `O'[1,1]

    local blocks "`e(hfpredictors)'"
    local nb : word count `blocks'
    forvalues j=1/`nb' {
        local s : word `j' of `blocks'
        local b = `j'+1
        di as text "  HF predictor (`s')" ///
            _col(31) as result %5.0f `O'[1,`b'] ///
            as text "   n=" as result %4.0f `H'[1,`j'] ///
            as text "   terms=" as result %5.0f `T'[1,`j']
    }

    di _newline as text "`IC' = " as result %12.6f e(icvalue)

    if "`e(selection)'"!="fixed" & e(drop_improves)==1 {
        di _newline as text "note: " as result "`IC'" as text ///
            " favors excluding HF block(s): " as result "`e(drop_blocks)'"
        di as text "      UMIDAS retains all supplied HF predictors by construction."
    }
end
