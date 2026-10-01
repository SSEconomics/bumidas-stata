{smcl}
{* *! version 0.2.0 1oct2026}{...}
{vieweralsosee "mfcollapse" "help mfcollapse"}{...}
{vieweralsosee "bumidas" "help bumidas"}{...}
{vieweralsosee "rmidas" "help rmidas"}{...}
{vieweralsosee "regress" "help regress"}{...}
{vieweralsosee "predict" "help predict"}{...}

{title:Title}

{phang}
{bf:umidas} {hline 2} Unrestricted mixed-data sampling regression with fixed or information-criterion-selected orders


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:umidas} {it:depvar} {ifin}{cmd:,}
{opt hfpredictors(stublist)}
[{opt hfn(numlist)}
 {opt pmax(#)}
 {opt search(block|common)}
 {opt ic(bic|hqic|aic)}
 {opt porder(#)}
 {opt porders(numlist)}
 {opt controls(varlist)}
 {opt horizon(#)}
 {opt noconstant}
 {opt regression}
 {opt trace}]

{pstd}
The data must be {cmd:tsset} before {cmd:umidas} is used.


{marker installation}{...}
{title:Files required}

{pstd}
A complete UMIDAS installation contains {cmd:umidas.ado}, {cmd:umidas_p.ado},
and {cmd:umidas.sthlp}.  The files must be visible on the Stata adopath.


{marker description}{...}
{title:Description}

{pstd}
{cmd:umidas} estimates direct unrestricted mixed-data sampling (UMIDAS)
regressions for a lower-frequency dependent variable using unrestricted
higher-frequency predictor terms and lower-frequency lags of the dependent
variable.

{pstd}
All predictor blocks supplied in {cmd:hfpredictors()} are retained in the
baseline UMIDAS model.  Their orders are therefore positive.  The command can
estimate a fixed common order, a fixed block-specific order vector, or select
orders by AIC, HQIC, or BIC.

{pstd}
For predictor block {it:j}, order {it:p_j} and sampling ratio {it:n_j} imply
exactly

{pmore}
{it:K_j} = {it:p_j}({it:n_j}-1)

{pstd}
unrestricted higher-frequency coefficients.  If
{it:K_j}=40, for example, suffixes 0 through 39 are included; suffix 40 is not.


{marker choose}{...}
{title:Choosing among bumidas, umidas, and rmidas}

{phang}
{help bumidas:{cmd:bumidas}} exploits the bottom-up state dimension and is the
natural benchmark when the relevant higher-frequency target information is
observed or recoverable.

{phang}
{cmd:umidas} keeps the higher-frequency lag coefficients unrestricted and is
therefore the most flexible of the three parameterizations for a given lag
window.

{phang}
{help rmidas:{cmd:rmidas}} imposes Almon, step, Legendre, exponential-Almon, or
Beta restrictions to reduce the dimension of the higher-frequency lag
coefficients.


{marker data}{...}
{title:Data organization and higher-frequency stubs}

{pstd}
Each element of {cmd:hfpredictors()} is a stub for consecutively numbered
higher-frequency variables.  For example, the stub {cmd:wti_ld} refers to

{phang2}
{cmd:wti_ld0 wti_ld1 wti_ld2 ...}

{pstd}
Indexed variables must be numeric and contiguous beginning with suffix 0.
{cmd:umidas} checks the available range before constructing candidate models.

{pstd}
The usual workflow is to construct mixed-frequency variables with
{help mfcollapse:{cmd:mfcollapse}}, merge any separately collapsed predictor
blocks, {cmd:tsset} the lower-frequency data, and then estimate {cmd:umidas}.


{marker model}{...}
{title:UMIDAS block construction}

{pstd}
Let {it:y_t} denote the lower-frequency dependent variable.  For positive order
vector ({it:p_y},{it:p_1},...,{it:p_J}), {cmd:umidas} includes target lags

{pmore}
{cmd:L}{it:h}{cmd:.y}, ..., {cmd:L}{it:h+p_y-1}{cmd:.y}

{pstd}
and, for each higher-frequency predictor {it:j}, exactly
{it:p_j}({it:n_j}-1) unrestricted terms beginning with suffix 0.

{pstd}
For example, if {it:p_j}=2 and {it:n_j}=21, the higher-frequency block uses
suffixes 0 through 39, for 40 coefficients.


{marker options}{...}
{title:Options}

{phang}
{opt hfpredictors(stublist)} specifies one or more higher-frequency predictor
blocks and is required.

{phang}
{opt hfn(numlist)} supplies {it:n_j}, the source-to-target sampling ratio for
the higher-frequency blocks.  One value applies to all blocks; otherwise
supply one value per stub in {cmd:hfpredictors()} order.

{pmore}
If {cmd:hfn()} is omitted, {cmd:umidas} first looks for block-specific metadata
attached to {cmd:stub0}.  With one higher-frequency block, it then falls back
to the dataset characteristic {cmd:_dta[hfn]} stored by {cmd:mfcollapse}.
After independently collapsed datasets are merged, specify {cmd:hfn()}
explicitly unless the block-specific metadata are available.

{phang}
{opt pmax(#)} specifies the largest positive order considered by information-
criterion selection.  It may not be combined with {cmd:porder()} or
{cmd:porders()}.  If omitted, the largest common feasible order implied by the
available indexed variables and {cmd:hfn()} is used.

{phang}
{opt search(block|common)} specifies the IC search structure.  The default is
{cmd:search(block)}.

{pmore}
{cmd:search(block)} searches the complete positive grid
({it:p_y},{it:p_1},...,{it:p_J}), with every component ranging from 1 through
{it:pmax}.

{pmore}
{cmd:search(common)} imposes
{it:p_y}={it:p_1}=...={it:p_J}={it:p} and searches only
{it:p}=1,...,{it:pmax}.

{phang}
{opt ic(bic|hqic|aic)} specifies the information criterion.  The default is
{cmd:ic(bic)}.  The criteria are computed from the Gaussian OLS log likelihood
and estimated parameter rank:

{p 12 16 2}
AIC = -2 ln L + 2k,

{p 12 16 2}
HQIC = -2 ln L + 2 ln(ln N) k,

{p 12 16 2}
BIC = -2 ln L + ln(N) k.

{phang}
{opt porder(#)} estimates a fixed common-order UMIDAS model.  The model uses
# lower-frequency target lags and #({it:n_j}-1) unrestricted terms for each
higher-frequency predictor.  The order must be positive.

{phang}
{opt porders(numlist)} estimates a fixed block-specific positive order vector.
Supply one value for the lower-frequency target followed by one positive value
for each higher-frequency predictor in {cmd:hfpredictors()} order.

{pmore}
For example,

{phang2}
{cmd:. umidas y, hfpredictors(wti_ld bcpi_ld) hfn(21 5) porders(2 1 3)}

{pmore}
estimates {it:p_y}=2, {it:p_WTI}=1, and {it:p_BCPI}=3, giving 2 target lags,
20 WTI terms, and 12 BCPI terms.

{phang}
{opt controls(varlist)} specifies additional regressors included unchanged in
every candidate model.  Numeric variables, time-series operators, and
factor-variable notation are allowed.

{phang}
{opt horizon(#)} specifies the direct forecast horizon.  The default is 1.
See {help umidas##timing:Forecast timing}.

{phang}
{opt noconstant} suppresses the regression constant.

{phang}
{opt regression} displays the full coefficient table for the final selected or
fixed regression.  The final regression remains the active estimation result.

{phang}
{opt trace} reports IC-search progress.  For {cmd:search(common)}, every
candidate common order is displayed.  For {cmd:search(block)}, only new
incumbent-best order vectors are displayed.  The auxiliary exclusion diagnostic
is summarized only if exclusion improves the requested IC.


{marker selection}{...}
{title:Information-criterion selection}

{pstd}
Under {cmd:search(block)}, with {it:J} higher-frequency predictors, the baseline
grid contains {it:pmax}^({it:J}+1) candidate models.  If the grid exceeds
10,000 candidates, {cmd:umidas} displays a note before estimation but does not
impose an arbitrary hard limit.

{pstd}
Under {cmd:search(common)}, only {it:pmax} baseline candidate models are
evaluated.

{pstd}
All baseline candidates are compared on the same estimation sample.  The common
sample is determined by the largest admissible model before IC values are
computed.  The selected model is re-estimated on that same sample.  This avoids
selecting among orders merely because their usable samples differ.

{pstd}
If IC values are tied to numerical tolerance, {cmd:umidas} first prefers the
model with fewer estimated parameters.  Any remaining tie is resolved
lexicographically using the order vector
({it:p_y},{it:p_1},...,{it:p_J}), producing deterministic results.


{marker diagnostic}{...}
{title:Higher-frequency block exclusion diagnostic}

{pstd}
The baseline UMIDAS search treats every predictor supplied in
{cmd:hfpredictors()} as part of the model, so no higher-frequency order is set
to zero.  After IC selection, {cmd:umidas} performs an auxiliary diagnostic on
the same common sample that permits higher-frequency blocks to be excluded.

{pstd}
For {cmd:search(block)}, the auxiliary search keeps {it:p_y} in
1,...,{it:pmax} but permits each higher-frequency order to range from 0 through
{it:pmax}.  For {cmd:search(common)}, it keeps a common positive order for the
lower-frequency target and all retained higher-frequency blocks while allowing
subsets of higher-frequency blocks to be excluded.

{pstd}
If the auxiliary specification has a lower IC than the baseline UMIDAS model,
the command reports the improving exclusion.  This is diagnostic only.  The
stored coefficients, selected orders, predictions, and {cmd:e(icvalue)} remain
those of the baseline UMIDAS model containing all supplied predictor blocks.


{marker timing}{...}
{title:Forecast timing}

{pstd}
{cmd:umidas} estimates a direct forecast at horizon {it:h}.  For
{cmd:horizon(h)}, lower-frequency target lags begin at
{cmd:L}{it:h}{cmd:.depvar}; subsequent target lags are
{cmd:L}{it:h+1}{cmd:.depvar}, and so on.  Every higher-frequency predictor term
is aligned using the same lower-frequency lag operator {cmd:L}{it:h}.

{pstd}
This timing convention matches {help bumidas} and {help rmidas}.


{marker examples}{...}
{title:Examples}

{pstd}
Block-specific BIC search with one higher-frequency predictor:

{phang2}
{cmd:. umidas fx_ave, hfpredictors(wti_ld) pmax(3) ic(bic)}

{pstd}
Block-specific BIC search with two predictors having different source
frequencies:

{phang2}
{cmd:. umidas fx_ave, hfpredictors(wti_ld bcpi_ld) hfn(21 5) pmax(3) ic(bic)}

{pstd}
The default block search considers
({it:p_y},{it:p_WTI},{it:p_BCPI}) independently over 1,2,3, giving 27 baseline
models.

{pstd}
Canonical common-order UMIDAS:

{phang2}
{cmd:. umidas fx_ave, hfpredictors(wti_ld bcpi_ld) hfn(21 5) pmax(3) search(common) ic(bic)}

{pstd}
This compares only (1,1,1), (2,2,2), and (3,3,3).

{pstd}
Fixed common order:

{phang2}
{cmd:. umidas fx_ave, hfpredictors(wti_ld bcpi_ld) hfn(21 5) porder(2)}

{pstd}
Fixed block-specific orders:

{phang2}
{cmd:. umidas fx_ave, hfpredictors(wti_ld bcpi_ld) hfn(21 5) porders(1 2 1)}

{pstd}
Direct two-period-ahead fixed-order UMIDAS:

{phang2}
{cmd:. umidas fx_ave, hfpredictors(wti_ld) hfn(21) porder(1) horizon(2)}

{pstd}
Display the full selected regression:

{phang2}
{cmd:. umidas, regression}

{pstd}
Generate fitted/direct forecast values and residuals:

{phang2}
{cmd:. predict double yhat}

{phang2}
{cmd:. predict double uhat, residuals}


{marker postestimation}{...}
{title:Postestimation}

{pstd}
{cmd:predict} after {cmd:umidas} supports fitted/direct forecast values and
residuals:

{phang2}
{cmd:. predict double yhat}

{phang2}
{cmd:. predict double yhat, xb}

{phang2}
{cmd:. predict double uhat, residuals}

{pstd}
As with standard Stata regression prediction, {cmd:predict} evaluates wherever
the selected model's regressors are available.  Use {cmd:if e(sample)} to
restrict predictions to the estimation sample.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:umidas} is an e-class estimation command.  The final selected or fixed
regression remains active and retains standard {cmd:regress} results including
{cmd:e(b)}, {cmd:e(V)}, {cmd:e(N)}, {cmd:e(ll)}, {cmd:e(rank)}, and
{cmd:e(sample)}.

{synoptset 30 tabbed}{...}
{synopt:{cmd:e(cmd)}}{cmd:umidas}{p_end}
{synopt:{cmd:e(depvar)}}dependent variable{p_end}
{synopt:{cmd:e(horizon)}}direct forecast horizon{p_end}
{synopt:{cmd:e(selection)}}{cmd:ic} or {cmd:fixed}{p_end}
{synopt:{cmd:e(search)}}{cmd:block}, {cmd:common}, or {cmd:fixed}{p_end}
{synopt:{cmd:e(fixedtype)}}{cmd:common} or {cmd:block} for fixed-order models{p_end}
{synopt:{cmd:e(ic)}}information criterion{p_end}
{synopt:{cmd:e(icvalue)}}IC of the selected or fixed baseline model{p_end}
{synopt:{cmd:e(pmax)}}maximum order considered or corresponding fixed-order maximum{p_end}
{synopt:{cmd:e(p)}}selected common order when the final order vector is common{p_end}
{synopt:{cmd:e(common_selected)}}1 if the final positive order vector is common, 0 otherwise{p_end}
{synopt:{cmd:e(N_models)}}number of baseline models evaluated{p_end}
{synopt:{cmd:e(N_common)}}common IC-selection sample size{p_end}
{synopt:{cmd:e(orders)}}selected positive lower-/higher-frequency order vector{p_end}
{synopt:{cmd:e(maxorders)}}maximum feasible order vector used by the command{p_end}
{synopt:{cmd:e(hfn)}}sampling ratios {it:n_j}{p_end}
{synopt:{cmd:e(hfterms)}}selected higher-frequency term counts{p_end}
{synopt:{cmd:e(hfavailable)}}available indexed higher-frequency term counts{p_end}
{synopt:{cmd:e(drop_improves)}}1 if allowing higher-frequency exclusion lowers IC, 0 otherwise{p_end}
{synopt:{cmd:e(ic_dropbest)}}best auxiliary IC allowing exclusion, for IC searches{p_end}
{synopt:{cmd:e(droporders)}}best auxiliary order vector allowing exclusion{p_end}
{synopt:{cmd:e(drop_blocks)}}higher-frequency blocks excluded in the improving diagnostic model{p_end}
{synopt:{cmd:e(N_dropmodels)}}auxiliary exclusion models evaluated{p_end}
{synopt:{cmd:e(rhs)}}RHS of the selected baseline model{p_end}
{synopt:{cmd:e(hfpredictors)}}higher-frequency predictor stubs{p_end}
{synopt:{cmd:e(controls)}}fixed controls{p_end}
{synopt:{cmd:e(order_names)}}names corresponding to entries in the order vector{p_end}
{synopt:{cmd:e(order_types)}}target or higher-frequency type for each order entry{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
UMIDAS can become high-dimensional quickly because each additional structural
order adds {it:n_j}-1 unrestricted coefficients for predictor {it:j}.  This is
especially important with daily-to-monthly or daily-to-quarterly data and short
estimation samples.

{pstd}
The higher-frequency exclusion diagnostic should not be confused with the
baseline selection rule.  It is reported to show when an information criterion
would prefer excluding a supplied predictor, while preserving the conventional
UMIDAS interpretation that supplied variables are included in the baseline
model.

{pstd}
For restricted lag-weight alternatives, see {help rmidas}.  For the bottom-up
mixed-frequency specification, see {help bumidas}.


{marker citation}{...}
{title:Citation guidance}

{pstd}
For UMIDAS, the principal methodological reference is Foroni, Marcellino, and
Schumacher (2015).  For the broader MIDAS framework, see Ghysels, Sinko, and
Valkanov (2007).

{pstd}
When comparing UMIDAS with restricted MIDAS specifications, cite the relevant
restriction-specific source: Almon (1965) for Almon polynomials; Forsberg and
Ghysels (2007) for step functions; Babii, Ghysels, and Striaukas (2022) for
Legendre polynomial restrictions; Ghysels, Santa-Clara, and Valkanov (2005)
for exponential Almon; and Ghysels, Santa-Clara, and Valkanov (2006) for Beta
weights.

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
