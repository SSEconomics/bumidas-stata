*! version 0.2.0 1oct2026
program define rmidas_p
    version 11.0

    if "`e(cmd)'"!="rmidas" error 301

    syntax newvarname [if] [in] [, XB Residuals]

    if "`xb'"!="" & "`residuals'"!="" {
        di as error "specify only one of xb or residuals"
        exit 198
    }

    marksample touse, novarlist

    local depvar "`e(depvar)'"
    local hfpredictors "`e(hfpredictors)'"
    local controls "`e(controls)'"

    tempvar fit
    quietly gen double `fit' = e(constant) if `touse'

    // LF target contribution
    tempname LF W T C
    matrix `LF' = e(lfcoef)
    matrix `W'  = e(weights)
    matrix `T'  = e(hfterms)

    local py = colsof(`LF')
    forvalues q=1/`py' {
        local lag = e(horizon) + `q' - 1
        local b = `LF'[1,`q']
        quietly replace `fit' = `fit' + `b'*L`lag'.`depvar' if `touse'
    }

    // HF predictor contribution using effective underlying coefficients
    local h = e(horizon)
    local nhfp : word count `hfpredictors'
    forvalues j=1/`nhfp' {
        local s : word `j' of `hfpredictors'
        local Kj = `T'[1,`j']
        forvalues jj=1/`Kj' {
            local k = `jj'-1
            local b = `W'[`j',`jj']
            quietly replace `fit' = `fit' + `b'*L`h'.`s'`k' if `touse'
        }
    }

    // Fixed controls
    local nctrl : word count `controls'
    if `nctrl'>0 {
        matrix `C' = e(controlcoef)
        forvalues c=1/`nctrl' {
            local cv : word `c' of `controls'
            local b = `C'[1,`c']
            quietly replace `fit' = `fit' + `b'*(`cv') if `touse'
        }
    }

    local outtype "`typlist'"
    if "`outtype'"=="" local outtype "float"

    if "`residuals'"!="" {
        generate `outtype' `varlist' = `depvar' - `fit' if `touse'
    }
    else {
        generate `outtype' `varlist' = `fit' if `touse'
    }
end
