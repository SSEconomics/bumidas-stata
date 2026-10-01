*! version 0.2.0 1oct2026
// Stable nonlinear function evaluator for rmidas.
// Must reside in its own ado file because nl calls it as a standalone program.
// Exp-Almon and Beta weights are normalized with log-sum-exp at every
// optimizer evaluation; no bounds are imposed on the shape parameters.

program define nlrmidas_lse
    version 11.0
    syntax varlist(min=2) if, at(name) ///
        RMTYPE(string) RMPY(integer) RMNCTRL(integer) ///
        RMK(numlist integer >=1) RMCONST(integer)

    local wt = lower("`rmtype'")
    if !inlist("`wt'","expalmon","beta") exit 198
    if `rmpy'<1 | `rmnctrl'<0 | !inlist(`rmconst',0,1) exit 198

    local J : word count `rmk'
    if `J'<1 exit 198

    // Validate the evaluator layout before touching the dependent-variable copy.
    local expected = 1 + `rmpy' + `rmnctrl'
    foreach Kj of numlist `rmk' {
        local expected = `expected' + `Kj'
    }
    local got : word count `varlist'
    if `got'!=`expected' exit 198

    local npar = `rmconst' + `rmpy' + `rmnctrl' + 3*`J'
    if colsof(`at')!=`npar' exit 198

    local y : word 1 of `varlist'
    quietly replace `y' = 0 `if'

    local pp = 1
    local vv = 2
    tempname b bx c1 c2 maxv den cur a1 a2 m r1 r2 tol nmax

    // Constant, when requested.
    if `rmconst' {
        scalar `b' = `at'[1,`pp']
        quietly replace `y' = scalar(`b') `if'
        local pp = `pp' + 1
    }

    // LF target lags.
    forvalues q=1/`rmpy' {
        local xv : word `vv' of `varlist'
        scalar `b' = `at'[1,`pp']
        quietly replace `y' = `y' + scalar(`b')*`xv' `if'
        local pp = `pp' + 1
        local vv = `vv' + 1
    }

    // Fixed unrestricted controls.
    forvalues c=1/`rmnctrl' {
        local xv : word `vv' of `varlist'
        scalar `b' = `at'[1,`pp']
        quietly replace `y' = `y' + scalar(`b')*`xv' `if'
        local pp = `pp' + 1
        local vv = `vv' + 1
    }

    // Restricted HF blocks.
    forvalues j=1/`J' {
        local Kj : word `j' of `rmk'

        scalar `bx' = `at'[1,`pp']
        scalar `c1' = `at'[1,`=`pp'+1']
        scalar `c2' = `at'[1,`=`pp'+2']
        local pp = `pp' + 3

        if missing(scalar(`bx')) | missing(scalar(`c1')) | missing(scalar(`c2')) exit 480

        if "`wt'"=="expalmon" {
            // eta_j = c1*j + c2*j^2.  Subtract max eta before exponentiating,
            // so at least one unnormalized weight is exactly one and den>=1.
            scalar `maxv' = .
            forvalues jj=1/`Kj' {
                scalar `cur' = scalar(`c1')*`jj' + scalar(`c2')*(`jj'^2)
                if missing(scalar(`cur')) exit 480
                if missing(scalar(`maxv')) | scalar(`cur')>scalar(`maxv') ///
                    scalar `maxv' = scalar(`cur')
            }

            scalar `den' = 0
            forvalues jj=1/`Kj' {
                scalar `cur' = exp(scalar(`c1')*`jj' + scalar(`c2')*(`jj'^2) - scalar(`maxv'))
                scalar `den' = scalar(`den') + scalar(`cur')
            }
            if missing(scalar(`den')) | scalar(`den')<=0 exit 480

            forvalues jj=1/`Kj' {
                local xv : word `vv' of `varlist'
                scalar `cur' = exp(scalar(`c1')*`jj' + scalar(`c2')*(`jj'^2) - scalar(`maxv'))/scalar(`den')
                quietly replace `y' = `y' + scalar(`bx')*scalar(`cur')*`xv' `if'
                local vv = `vv' + 1
            }
        }
        else {
            // Beta kernel on x_j=j/(K+1):
            //   log w_j = (exp(c1)-1)log(x_j) + (exp(c2)-1)log(1-x_j).
            // For representable exp(c), evaluate those log weights directly and
            // normalize by log-sum-exp.  If c exceeds the range where exp(c) is
            // representable as a double, use the exact machine-precision limit:
            // all normalized mass lies on the maximizer(s) of the dominant
            // scaled log kernel.  This is a computational overflow treatment,
            // NOT a bound or constraint on c1/c2.
            if scalar(`c1')<=700 & scalar(`c2')<=700 {
                scalar `a1' = exp(scalar(`c1')) - 1
                scalar `a2' = exp(scalar(`c2')) - 1

                scalar `maxv' = .
                forvalues jj=1/`Kj' {
                    scalar `cur' = scalar(`a1')*ln(`jj'/(`Kj'+1)) + ///
                        scalar(`a2')*ln(1-`jj'/(`Kj'+1))
                    if missing(scalar(`cur')) exit 480
                    if missing(scalar(`maxv')) | scalar(`cur')>scalar(`maxv') ///
                        scalar `maxv' = scalar(`cur')
                }

                scalar `den' = 0
                forvalues jj=1/`Kj' {
                    scalar `cur' = scalar(`a1')*ln(`jj'/(`Kj'+1)) + ///
                        scalar(`a2')*ln(1-`jj'/(`Kj'+1)) - scalar(`maxv')
                    scalar `den' = scalar(`den') + exp(scalar(`cur'))
                }
                if missing(scalar(`den')) | scalar(`den')<=0 exit 480

                forvalues jj=1/`Kj' {
                    local xv : word `vv' of `varlist'
                    scalar `cur' = scalar(`a1')*ln(`jj'/(`Kj'+1)) + ///
                        scalar(`a2')*ln(1-`jj'/(`Kj'+1)) - scalar(`maxv')
                    scalar `cur' = exp(scalar(`cur'))/scalar(`den')
                    quietly replace `y' = `y' + scalar(`bx')*scalar(`cur')*`xv' `if'
                    local vv = `vv' + 1
                }
            }
            else {
                // At least one exp(c) exceeds floating-point range.  Factor out
                // exp(max(c1,c2)); the remaining scaled coefficients are <=1.
                // In this regime finite nonmaximal weights are below machine
                // precision, so the normalized kernel is its limiting mass on
                // the discrete maximizer(s).  Symmetric ties share mass equally.
                scalar `m'  = max(scalar(`c1'),scalar(`c2'))
                scalar `r1' = exp(scalar(`c1')-scalar(`m'))
                scalar `r2' = exp(scalar(`c2')-scalar(`m'))

                scalar `maxv' = .
                forvalues jj=1/`Kj' {
                    scalar `cur' = scalar(`r1')*ln(`jj'/(`Kj'+1)) + ///
                        scalar(`r2')*ln(1-`jj'/(`Kj'+1))
                    if missing(scalar(`maxv')) | scalar(`cur')>scalar(`maxv') ///
                        scalar `maxv' = scalar(`cur')
                }

                scalar `tol' = 1e-14*max(1,abs(scalar(`maxv')))
                scalar `nmax' = 0
                forvalues jj=1/`Kj' {
                    scalar `cur' = scalar(`r1')*ln(`jj'/(`Kj'+1)) + ///
                        scalar(`r2')*ln(1-`jj'/(`Kj'+1))
                    if abs(scalar(`cur')-scalar(`maxv'))<=scalar(`tol') ///
                        scalar `nmax' = scalar(`nmax') + 1
                }
                if scalar(`nmax')<=0 exit 480

                forvalues jj=1/`Kj' {
                    local xv : word `vv' of `varlist'
                    scalar `cur' = scalar(`r1')*ln(`jj'/(`Kj'+1)) + ///
                        scalar(`r2')*ln(1-`jj'/(`Kj'+1))
                    if abs(scalar(`cur')-scalar(`maxv'))<=scalar(`tol') ///
                        scalar `cur' = 1/scalar(`nmax')
                    else scalar `cur' = 0
                    quietly replace `y' = `y' + scalar(`bx')*scalar(`cur')*`xv' `if'
                    local vv = `vv' + 1
                }
            }
        }
    }
end
