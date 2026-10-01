{smcl}
{* *! version 0.2.0 1oct2026}{...}
{vieweralsosee "mfcollapse" "help mfcollapse"}{...}
{vieweralsosee "bumidas" "help bumidas"}{...}
{vieweralsosee "umidas" "help umidas"}{...}
{vieweralsosee "regress" "help regress"}{...}
{vieweralsosee "nl" "help nl"}{...}
{vieweralsosee "predict" "help predict"}{...}

{title:Title}

{phang}
{bf:rmidas} {hline 2} Restricted mixed-data sampling regression


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:rmidas} {it:depvar} {ifin}{cmd:,}
{opt hfpredictors(stublist)}
{opt method(family)}
[{opt hfn(numlist)}
 {opt porder(#)}
 {opt porders(numlist)}
 {opt degree(#)}
 {opt steps(#)}
 {opt controls(varlist)}
 {opt horizon(#)}
 {opt noconstant}
 {opt regression}
 {opt trace}]

{pstd}
{it:family} is one of {cmd:almon}, {cmd:step}, {cmd:legendre},
{cmd:expalmon}, or {cmd:beta}.

{pstd}
The data must be {cmd:tsset} before {cmd:rmidas} is used.


{marker installation}{...}
{title:Files required}

{pstd}
A complete RMIDAS installation contains {cmd:rmidas.ado}, {cmd:rmidas_p.ado},
and {cmd:rmidas.sthlp}.  The nonlinear methods {cmd:expalmon} and {cmd:beta}
also require the standalone evaluator {cmd:nlrmidas_lse.ado}.  All ado files
must be visible on the Stata adopath.


{marker description}{...}
{title:Description}

{pstd}
{cmd:rmidas} estimates direct restricted mixed-data sampling (RMIDAS)
regressions for a lower-frequency dependent variable using one or more
higher-frequency predictor blocks.  The coefficients on each higher-frequency
block are restricted by a user-selected lag-weight family.

{pstd}
All predictor blocks supplied in {cmd:hfpredictors()} remain in the model.
{cmd:rmidas} performs no information-criterion search and no variable selection.
The lag order, restriction family, polynomial degree, and number of step groups
are researcher choices.

{pstd}
For higher-frequency predictor block {it:j}, let {it:n_j} denote the
source-to-target sampling ratio and {it:p_j} its fixed order.  The command uses
exactly

{pmore}
{it:K_j} = {it:p_j}({it:n_j}-1)

{pstd}
underlying higher-frequency regressors, indexed
{cmd:stub0},...,{cmd:stub(K_j-1)}.  The next indexed variable is not included.
The lower-frequency target order {it:p_y} is also fixed and strictly positive.


{marker choose}{...}
{title:Choosing among bumidas, umidas, and rmidas}

{pstd}
The three commands impose different structures on the higher-frequency
information set.

{phang}
{help bumidas:{cmd:bumidas}} exploits the bottom-up state dimension and is the
natural benchmark when the relevant higher-frequency target information is
observed or recoverable.

{phang}
{help umidas:{cmd:umidas}} estimates unrestricted coefficients on the included
higher-frequency terms and can select fixed or information-criterion-based lag
orders.

{phang}
{cmd:rmidas} replaces unrestricted higher-frequency coefficients with a
low-dimensional parametric or grouped lag-weight restriction.  This can reduce
parameter proliferation when the higher-frequency history is long.


{marker data}{...}
{title:Data organization and higher-frequency stubs}

{pstd}
Each element of {cmd:hfpredictors()} is a stub for consecutively numbered
higher-frequency variables.  For example, the stub {cmd:wti_ld} refers to

{phang2}
{cmd:wti_ld0 wti_ld1 wti_ld2 ...}

{pstd}
The variables must be numeric and contiguous beginning with suffix 0.
{cmd:rmidas} checks that enough indexed variables exist for the requested order
and sampling ratio.

{pstd}
The usual workflow is to construct mixed-frequency variables with
{help mfcollapse:{cmd:mfcollapse}}, merge any separately collapsed predictor
blocks, {cmd:tsset} the lower-frequency data, and then estimate {cmd:rmidas}.


{marker orders}{...}
{title:Orders}

{phang}
{opt porder(#)} sets one common positive order for the lower-frequency target
and every higher-frequency predictor.  If neither {cmd:porder()} nor
{cmd:porders()} is specified, {cmd:porder(1)} is used.

{phang}
{opt porders(numlist)} specifies the fixed vector

{pmore}
({it:p_y},{it:p_1},...,{it:p_J}),

{pstd}
with the lower-frequency target order first and one positive order for each
predictor in {cmd:hfpredictors()}.

{pstd}
For example, with {cmd:hfn(21 5)} and {cmd:porders(1 2 1)}, the target uses one
lower-frequency lag, the first predictor uses 40 higher-frequency terms, and
the second predictor uses 4.


{marker hfn}{...}
{title:Sampling ratios and hfn()}

{phang}
{opt hfn(numlist)} supplies {it:n_j}.  A single value applies to all predictor
blocks; otherwise provide one value per block in {cmd:hfpredictors()} order.

{pstd}
If {cmd:hfn()} is omitted, {cmd:rmidas} first looks for block-specific metadata
attached to {cmd:stub0}.  With one higher-frequency block, it can also use the
dataset-level {cmd:_dta[hfn]} characteristic created by {help mfcollapse}.

{pstd}
After separately collapsed datasets have been merged, dataset-level metadata
may describe only the master dataset.  In that case, specify {cmd:hfn()}
explicitly.  With several higher-frequency blocks, {cmd:rmidas} does not guess
sampling ratios when the metadata are ambiguous.


{marker options}{...}
{title:Options}

{phang}
{opt hfpredictors(stublist)} specifies one or more higher-frequency predictor
blocks and is required.

{phang}
{opt method(family)} specifies the lag-weight family and is required.
See {help rmidas##weights:Weight families}.

{phang}
{opt porder(#)} specifies a fixed common positive order.  It may not be combined
with {cmd:porders()}.

{phang}
{opt porders(numlist)} specifies a fixed block-specific positive order vector,
with the lower-frequency target order first.

{phang}
{opt degree(#)} specifies the polynomial degree for {cmd:method(almon)} or
{cmd:method(legendre)}.  The default is 2 for Almon and 3 for Legendre.
For either method, every higher-frequency block must contain at least
{it:degree}+1 terms.

{phang}
{opt steps(#)} specifies the number of contiguous groups for
{cmd:method(step)}.  The default is 3.  The number of steps may not exceed the
number of higher-frequency terms in any block.

{phang}
{opt controls(varlist)} adds fixed unrestricted numeric or time-series controls.
The controls are not part of the MIDAS restriction.  Factor-variable notation
is not accepted directly by {cmd:rmidas}; generate indicator or interaction
variables first if required.

{phang}
{opt horizon(#)} specifies the direct forecast horizon.  The default is 1.
See {help rmidas##timing:Forecast timing}.

{phang}
{opt noconstant} suppresses the intercept.

{phang}
{opt regression} displays the complete underlying OLS or nonlinear
least-squares coefficient table after the compact RMIDAS output.

{phang}
{opt trace} displays the resolved {it:n_j}, {it:p_j}, {it:K_j}, and restriction
dimension for each higher-frequency block.  For nonlinear families it also
reports successful convergence.


{marker weights}{...}
{title:Weight families}

{dlgtab:Almon}

{pstd}
{cmd:method(almon)} uses the polynomial basis

{pmore}
1, {it:r}, {it:r}^2, ..., {it:r}^d,   {it:r}=1,...,{it:K_j}.

{pstd}
Each predictor receives its own polynomial coefficients.  The model is linear
in these coefficients and is estimated by {help regress}.  The default is
{cmd:degree(2)}, corresponding to the quadratic Almon benchmark.

{dlgtab:Step}

{pstd}
{cmd:method(step)} divides each predictor's {it:K_j} positions into {it:S}
approximately equal contiguous groups and assigns one coefficient to each
group.  Group {it:g} contains positions

{pmore}
floor(({it:g}-1){it:K_j}/{it:S})+1,...,floor({it:gK_j}/{it:S}).

{pstd}
The default is {cmd:steps(3)}.  The model is estimated by {help regress}.

{dlgtab:Legendre}

{pstd}
{cmd:method(legendre)} scales position {it:r} to

{pmore}
{it:z_r} = -1 + 2({it:r}-1)/({it:K_j}-1)

{pstd}
and uses Legendre polynomial basis functions
{it:P_0(z_r)},...,{it:P_d(z_r)}.  The default is {cmd:degree(3)}.
The model is estimated by {help regress}.

{dlgtab:Exponential Almon}

{pstd}
For {cmd:method(expalmon)}, the normalized shape weight for block {it:j} at
position {it:r} is proportional to

{pmore}
exp({it:c_1 r}+{it:c_2 r^2}),   {it:r}=1,...,{it:K_j}.

{pstd}
A separate scale coefficient multiplies the normalized weighted aggregate.
Each higher-frequency block receives its own scale and two shape parameters.
Starting values are scale=0.5, {it:c_1}=-2, and {it:c_2}=0.

{dlgtab:Beta}

{pstd}
For {cmd:method(beta)}, define the interior grid

{pmore}
{it:x_r} = {it:r}/({it:K_j}+1).

{pstd}
The unnormalized kernel is

{pmore}
{it:x_r}^(exp({it:c_1})-1) (1-{it:x_r})^(exp({it:c_2})-1).

{pstd}
The kernel is normalized to sum to one and multiplied by a block-specific
scale coefficient.  Starting values are scale=0.5, {it:c_1}=0, and
{it:c_2}=0.


{marker nonlinear}{...}
{title:Nonlinear estimation and numerical stability}

{pstd}
The exponential-Almon and Beta models are estimated by nonlinear least squares
using {help nl}.  Their objective functions are evaluated by the standalone
program {cmd:nlrmidas_lse.ado}, which must be installed on the Stata adopath
alongside {cmd:rmidas.ado}.

{pstd}
At every optimizer iteration, the nonlinear weights are normalized using a
max-shifted log-sum-exp calculation.  This avoids overflow or underflow when the
shape parameters imply highly concentrated weights.  No artificial bounds are
imposed on the shape parameters.

{pstd}
For Beta weights whose shape parameters exceed the range in which exp({it:c})
is representable as a double, the evaluator uses the corresponding
machine-precision limiting normalized mass on the maximizing discrete lag
position or positions.  This is a numerical evaluation rule, not a parameter
constraint.

{pstd}
Nonlinear lag shapes can be weakly identified in finite samples.  If a
shape-parameter standard error is missing, or if essentially all normalized
weight is placed on one higher-frequency observation, {cmd:rmidas} displays a
warning and stores {cmd:e(shape_warning)}=1.  A converged model is retained.


{marker timing}{...}
{title:Forecast timing}

{pstd}
{cmd:rmidas} estimates a direct forecast at horizon {it:h}.  For
{cmd:horizon(h)}, lower-frequency target lags begin at
{cmd:L}{it:h}{cmd:.depvar}; subsequent target lags are
{cmd:L}{it:h+1}{cmd:.depvar}, and so on.  Every underlying higher-frequency
regressor is shifted by the same lower-frequency lag operator
{cmd:L}{it:h}.

{pstd}
This timing convention matches {help bumidas} and {help umidas}.


{marker examples}{...}
{title:Examples}

{pstd}
Quadratic Almon with daily WTI and weekly-like BCPI predictors:

{phang2}
{cmd:. rmidas ae, hfpredictors(llo llb) hfn(21 5) porder(1) method(almon) degree(2)}

{pstd}
Step-3:

{phang2}
{cmd:. rmidas ae, hfpredictors(llo llb) hfn(21 5) porder(1) method(step) steps(3)}

{pstd}
Legendre-3:

{phang2}
{cmd:. rmidas ae, hfpredictors(llo llb) hfn(21 5) porder(1) method(legendre) degree(3)}

{pstd}
Exponential Almon:

{phang2}
{cmd:. rmidas ae, hfpredictors(llo llb) hfn(21 5) porder(1) method(expalmon)}

{pstd}
Beta:

{phang2}
{cmd:. rmidas ae, hfpredictors(llo llb) hfn(21 5) porder(1) method(beta)}

{pstd}
Block-specific fixed orders:

{phang2}
{cmd:. rmidas ae, hfpredictors(llo llb) hfn(21 5) porders(1 2 1) method(almon)}

{pstd}
Direct two-period-ahead forecast model:

{phang2}
{cmd:. rmidas ae, hfpredictors(llo) hfn(21) porder(1) method(almon) horizon(2)}

{pstd}
Generate fitted/direct forecast values and residuals:

{phang2}
{cmd:. predict double yhat}

{phang2}
{cmd:. predict double uhat, residuals}

{pstd}
Replay compact or full output:

{phang2}
{cmd:. rmidas}

{phang2}
{cmd:. rmidas, regression}


{marker postestimation}{...}
{title:Postestimation}

{pstd}
{cmd:predict} after {cmd:rmidas} supports fitted/direct forecast values and
residuals:

{phang2}
{cmd:. predict double yhat}

{phang2}
{cmd:. predict double yhat, xb}

{phang2}
{cmd:. predict double uhat, residuals}

{pstd}
Predictions are reconstructed from the lower-frequency coefficients, controls,
and the effective underlying higher-frequency coefficients stored in
{cmd:e(weights)}.  Predictions may therefore be generated outside
{cmd:e(sample)} whenever all required regressors are available.  Use
{cmd:if e(sample)} to restrict prediction to the estimation sample.


{marker weightsstored}{...}
{title:Implied higher-frequency coefficients}

{pstd}
{cmd:e(weights)} contains the effective coefficient multiplying each underlying
higher-frequency observation.  Rows correspond to predictor blocks and columns
to lag positions.  If blocks have different {it:K_j}, unused cells are missing.

{pstd}
For {cmd:expalmon} and {cmd:beta}, {cmd:e(shapeweights)} contains the normalized
shape weights before multiplication by the block-specific scale coefficient,
and {cmd:e(shapeparams)} contains the scale, {it:c_1}, and {it:c_2} parameters.

{phang2}
{cmd:. matrix list e(weights)}

{phang2}
{cmd:. matrix list e(shapeweights)}

{phang2}
{cmd:. matrix list e(shapeparams)}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:rmidas} is an e-class estimation command.  In addition to the standard
results from {cmd:regress} or {cmd:nl}, it stores:

{synoptset 28 tabbed}{...}
{synopt:{cmd:e(cmd)}}{cmd:rmidas}{p_end}
{synopt:{cmd:e(depvar)}}dependent variable{p_end}
{synopt:{cmd:e(N)}}number of estimation observations{p_end}
{synopt:{cmd:e(horizon)}}direct forecast horizon{p_end}
{synopt:{cmd:e(rmtype)}}restriction family{p_end}
{synopt:{cmd:e(weight)}}restriction family, alias of {cmd:e(rmtype)}{p_end}
{synopt:{cmd:e(engine)}}{cmd:ols} or {cmd:nl}{p_end}
{synopt:{cmd:e(hfpredictors)}}higher-frequency predictor stubs{p_end}
{synopt:{cmd:e(controls)}}fixed controls{p_end}
{synopt:{cmd:e(constant)}}estimated intercept, zero under {cmd:noconstant}{p_end}
{synopt:{cmd:e(p)}}common order when {cmd:porder()} is used{p_end}
{synopt:{cmd:e(degree)}}polynomial degree for Almon or Legendre{p_end}
{synopt:{cmd:e(steps)}}number of groups for Step{p_end}
{synopt:{cmd:e(orders)}}({it:p_y},{it:p_1},...,{it:p_J}){p_end}
{synopt:{cmd:e(hfn)}}sampling ratios {it:n_j} by higher-frequency block{p_end}
{synopt:{cmd:e(hfterms)}}{it:K_j}={it:p_j}({it:n_j}-1) by block{p_end}
{synopt:{cmd:e(lfcoef)}}coefficients on lower-frequency target lags{p_end}
{synopt:{cmd:e(controlcoef)}}coefficients on fixed controls, when present{p_end}
{synopt:{cmd:e(weights)}}effective coefficients on underlying higher-frequency observations{p_end}
{synopt:{cmd:e(shapeweights)}}normalized nonlinear shape weights, Exp-Almon or Beta{p_end}
{synopt:{cmd:e(shapeparams)}}block-specific scale, {it:c_1}, and {it:c_2}, Exp-Almon or Beta{p_end}
{synopt:{cmd:e(shape_warning)}}1 if nonlinear shape identification is flagged, 0 otherwise{p_end}
{synopt:{cmd:e(rhs)}}description of the restricted RHS specification{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
Restricted MIDAS reduces the dimension of the higher-frequency lag coefficients
by imposing a shape or grouping structure.  Forecast accuracy therefore
depends jointly on the information set, the lag window, and the chosen
restriction.  A more flexible restriction is not automatically preferable in
small samples.

{pstd}
The nonlinear families can have flat or boundary-like objective functions.
A convergence result should therefore be considered together with
{cmd:e(shape_warning)}, the implied weights, and the substantive forecast
application.  {cmd:rmidas} exits with an error if nonlinear least squares does
not converge; it does not silently return a failed fit.

{pstd}
For automatic unrestricted lag-order selection, see {help umidas}.  For the
bottom-up mixed-frequency specification, see {help bumidas}.


{marker citation}{...}
{title:Citation guidance}

{pstd}
When using a particular RMIDAS restriction, cite the methodological source for
that restriction.  The following mapping is recommended:

{phang}
{cmd:Almon}: Almon (1965).

{phang}
{cmd:Step}: Forsberg and Ghysels (2007).

{phang}
{cmd:Legendre}: Babii, Ghysels, and Striaukas (2022).

{phang}
{cmd:Exponential Almon}: Ghysels, Santa-Clara, and Valkanov (2005).

{phang}
{cmd:Beta}: Ghysels, Santa-Clara, and Valkanov (2006).

{phang}
For general MIDAS lag parameterizations, see Ghysels, Sinko, and Valkanov
(2007).  For UMIDAS, see Foroni, Marcellino, and Schumacher (2015).

{pstd}
For applications and comparisons involving bottom-up mixed-frequency forecasts,
see Benmoussa, Ellwanger, and Snudden (2026), Ellwanger and Snudden (2023), and
Lee and Snudden (2025).


{marker references}{...}
{title:References}

{phang}
Almon, S. (1965). The distributed lag between capital appropriations and
expenditures. {it:Econometrica} 33(1), 178-196.
{browse "https://doi.org/10.2307/1911894"}

{phang}
Babii, A., Ghysels, E., and Striaukas, J. (2022). Machine learning time series
regressions with an application to nowcasting. {it:Journal of Business &
Economic Statistics} 40(3), 1094-1106.
{browse "https://doi.org/10.1080/07350015.2021.1899933"}

{phang}
Benmoussa, A. A., Ellwanger, R., and Snudden, S. (2026). Carpe diem: Can daily
oil prices improve model-based forecasts of the real price of crude oil?
{it:International Journal of Forecasting} 42(1), 281-295.
{browse "https://doi.org/10.1016/j.ijforecast.2025.02.009"}

{phang}
Ellwanger, R., and Snudden, S. (2023). Forecasts of the real price of oil
revisited: Do they beat the random walk? {it:Journal of Banking & Finance} 154,
106962. {browse "https://doi.org/10.1016/j.jbankfin.2023.106962"}

{phang}
Foroni, C., Marcellino, M., and Schumacher, C. (2015). Unrestricted mixed data
sampling (MIDAS): MIDAS regressions with unrestricted lag polynomials.
{it:Journal of the Royal Statistical Society: Series A (Statistics in Society)}
178(1), 57-82.

{phang}
Forsberg, L., and Ghysels, E. (2007). Why do absolute returns predict
volatility so well? {it:Journal of Financial Econometrics} 5(1), 31-67.
{browse "https://doi.org/10.1093/jjfinec/nbl010"}

{phang}
Lee, Q., and Snudden, S. (2025). Bottom-Up Mixed-Frequency Data Sampling
(BUMIDAS). SSRN Working Paper 5312038.
{browse "https://doi.org/10.2139/ssrn.5312038"}

{phang}
Ghysels, E., Santa-Clara, P., and Valkanov, R. (2005). There is a risk-return
trade-off after all. {it:Journal of Financial Economics} 76(3), 509-548.

{phang}
Ghysels, E., Santa-Clara, P., and Valkanov, R. (2006). Predicting volatility:
Getting the most out of return data sampled at different frequencies.
{it:Journal of Econometrics} 131(1-2), 59-95.

{phang}
Ghysels, E., Sinko, A., and Valkanov, R. (2007). MIDAS regressions: Further
results and new directions. {it:Econometric Reviews} 26(1), 53-90.
{browse "https://doi.org/10.1080/07474930600972467"}


{marker author}{...}
{title:Author}

{pstd}
Stephen Snudden

{pstd}
Wilfrid Laurier University

{pstd}
Website: {browse "https://stephensnudden.com/"}
