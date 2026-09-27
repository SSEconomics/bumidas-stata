*! version 0.1.1 27sep2026
program define bumidas_p
    version 11.0

    if "`e(cmd)'"!="bumidas" error 301

    syntax newvarname [if] [in] [, XB Residuals]

    if "`xb'"!="" & "`residuals'"!="" {
        di as error "specify only one of xb or residuals"
        exit 198
    }

    if "`residuals'"!="" {
        tempvar xbhat
        quietly _predict double `xbhat' `if' `in', xb
        generate `typlist' `varlist' = `e(depvar)' - `xbhat' `if' `in'
    }
    else {
        _predict `typlist' `varlist' `if' `in', xb
    }
end
