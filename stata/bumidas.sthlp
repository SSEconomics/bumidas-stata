{smcl}
{* *! version 0.1.2 26sep2026}{...}

{title:Title}

{phang}
{bf:bumidas} {hline 2} Estimate and select Bottom-Up Mixed-Frequency Data Sampling regressions


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:bumidas} {depvar} {ifin}{cmd:,}
[{opt hftarget(stublist)}
{opt hfpredictors(stublist)}
{opt hfmax(#)}
{opt lfymax(#)}
{opt lfpredictors(varlist)}
{opt lfxmax(#)}
{opt controls(varlist)}
{opt horizon(#)}
{opt search(full|recursive|none)}
{opt ic(bic|hqic|aic)}
{opt hforders(numlist)}
{opt lfyorder(#)}
{opt lfxorders(numlist)}
{opt noconstant}
{opt regression}
{opt trace}]

{pstd}
Replay:

{p 8 17 2}
{cmd:bumidas} [{cmd:,} {opt regression}]

{pstd}
Defaults are {cmd:search(full)}, {cmd:ic(bic)}, {cmd:horizon(1)}, and inclusion
of a constant.


{marker description}{...}
{title:Description}

{pstd}
{cmd:bumidas} estimates direct Bottom-Up Mixed-Frequency Data Sampling
(BUMIDAS) regressions using preconstructed high-frequency lag blocks and
optional low-frequency regressors.

{pstd}
The command supports three estimation modes: exhaustive information-criterion
selection over the full admissible grid, recursive forward block-order
selection, and fixed-order estimation. High-frequency and low-frequency blocks
may be combined in the same regression, and each block may have its own
selected lag order.

{pstd}
{cmd:bumidas} is an estimation command. It does not construct mixed-frequency
data or perform economic transformations. Higher-frequency data may first be
collapsed using {help mfcollapse}, after which any desired transformations
should be created explicitly before calling {cmd:bumidas}.

{pstd}
The data must be declared as time-series data using {help tsset}.


{marker hfblocks}{...}
{title:High-frequency blocks}

{pstd}
High-frequency blocks are identified by a {it:stub}. A stub represents a
sequence of variables whose names end in consecutive nonnegative integers.

{pstd}
For example, the stub {cmd:lle} represents

{p 12 16 2}
{cmd:lle0 lle1 lle2 ...}

{pstd}
The block order is the number of high-frequency terms included. Thus,

{p2colset 9 24 26 2}{...}
{p2col:order 0}block omitted{p_end}
{p2col:order 1}{cmd:lle0}{p_end}
{p2col:order 2}{cmd:lle0 lle1}{p_end}
{p2col:order 3}{cmd:lle0 lle1 lle2}{p_end}
{p2colreset}{...}

{pstd}
Therefore, order p includes terms {cmd:stub0} through
{cmd:stub}{it:(p-1)}. An order refers to the number of included terms, not the
largest numeric suffix.

{pstd}
For forecast horizon h, {cmd:bumidas} applies the low-frequency lag operator
{cmd:Lh.} to each included high-frequency term. For example,
{cmd:horizon(3)} with order 2 for stub {cmd:lle} includes

{p 12 16 2}
{cmd:L3.lle0 L3.lle1}.


{marker requiredhf}{...}
{title:Required and optional high-frequency blocks}

{pstd}
{opt hftarget(stublist)} specifies {it:required} high-frequency blocks.
Each listed block must have order at least 1, so its most recent
high-frequency term, {cmd:stub0}, is included in every candidate model.

{pstd}
For example,

{phang2}
{cmd:. bumidas y, hftarget(lle llo) hfmax(20)}

{pstd}
requires both {cmd:lle0} and {cmd:llo0} to appear in every model. Their
remaining high-frequency terms may still be selected by the information
criterion.

{pstd}
Despite the option name, {cmd:hftarget()} may contain any high-frequency block
whose most recent observation must be included. A listed block need not
literally represent the forecast target.

{pstd}
{opt hfpredictors(stublist)} specifies {it:optional} high-frequency blocks.
Each listed block may have order 0 and therefore may be excluded entirely by
model selection.

{pstd}
For example,

{phang2}
{cmd:. bumidas y, hfpredictors(lle llo) hfmax(20)}

{pstd}
allows either block to be excluded. If a block is included, its order starts
at 1 with {cmd:stub0}.

{pstd}
Both {cmd:hftarget()} and {cmd:hfpredictors()} are optional and each may
contain multiple stubs. A given stub may appear only once across the two
options.

{pstd}
For each stub, {cmd:bumidas} verifies that variables exist consecutively from
{cmd:stub0} through the largest available numeric suffix. An internal gap such
as

{p 12 16 2}
{cmd:x0 x1 x3}

{pstd}
causes an error because {cmd:x2} is missing.


{marker lfblocks}{...}
{title:Low-frequency blocks}

{pstd}
{opt lfymax(#)} adds a searchable low-frequency lag block of the dependent
variable. The admissible orders are 0 through #. Order 0 omits the block.

{pstd}
At forecast horizon h, LF target order r includes

{p 12 16 2}
{cmd:Lh.depvar L(h+1).depvar ... L(h+r-1).depvar}.

{pstd}
For example, {cmd:horizon(3) lfymax(2)} allows the LF target block to be
omitted, to contain {cmd:L3.depvar}, or to contain
{cmd:L3.depvar L4.depvar}.

{pstd}
{opt lfpredictors(varlist)} specifies additional low-frequency predictors
whose lag-block orders are selected independently.

{pstd}
With full or recursive search, {opt lfxmax(#)} is required when
{cmd:lfpredictors()} is specified. Each LF predictor is searched independently
over orders 0 through #.

{pstd}
At horizon h, order r for low-frequency predictor x includes

{p 12 16 2}
{cmd:Lh.x L(h+1).x ... L(h+r-1).x}.


{marker horizon}{...}
{title:Forecast horizon}

{pstd}
{opt horizon(#)} specifies the direct forecast horizon and must be an integer
greater than or equal to 1. The default is {cmd:horizon(1)}.

{pstd}
The horizon is applied automatically to high-frequency blocks and to
low-frequency lag blocks generated by {cmd:bumidas}. Thus, at
{cmd:horizon(3)},

{p2colset 9 36 38 2}{...}
{p2col:HF order 2 for {cmd:lle}}{cmd:L3.lle0 L3.lle1}{p_end}
{p2col:LF order 2 for {cmd:x}}{cmd:L3.x L4.x}{p_end}
{p2colreset}{...}

{pstd}
The option {cmd:horizon(0)} is not supported.


{marker search}{...}
{title:Search methods}

{marker full}{...}
{title:Full grid search}

{pstd}
{cmd:search(full)} performs an exhaustive Cartesian search over all admissible
block-order combinations. This is the default search method.

{pstd}
Required HF blocks are searched from order 1 to their maximum. Optional HF
blocks and searchable LF blocks are searched from order 0 to their maximum.

{pstd}
For example, with one required HF block and one optional HF block, each capped
at 20 terms, the full grid contains

{p 12 16 2}
20 x 21 = 420 candidate models.

{pstd}
Orders are selected independently across blocks.

{pstd}
The number of candidate models can grow quickly as additional blocks are
added. For large search spaces, {cmd:search(recursive)} may be much faster.


{marker recursive}{...}
{title:Recursive forward search}

{pstd}
{cmd:search(recursive)} performs forward block-order selection.

{pstd}
The search begins at the minimum admissible model:

{p2colset 9 30 32 2}{...}
{p2col:required HF block}order 1{p_end}
{p2col:optional HF block}order 0{p_end}
{p2col:LF target block}order 0{p_end}
{p2col:LF predictor block}order 0{p_end}
{p2colreset}{...}

{pstd}
At each step, the command estimates every admissible model obtained by
increasing exactly one block order by one. The one-step expansion with the
lowest information criterion is accepted only if it improves on the current
model. The procedure continues until no one-step expansion improves the
criterion or all maximum orders have been reached.

{pstd}
This is recursive {it:model search}, not recursive forecast estimation.

{pstd}
Because recursive search is a greedy forward procedure, it does not guarantee
the global information-criterion minimum obtained by {cmd:search(full)}.


{marker fixed}{...}
{title:Fixed-order estimation}

{pstd}
{cmd:search(none)} estimates a prespecified BUMIDAS regression without
searching over block orders.

{pstd}
When HF blocks are specified, {opt hforders(numlist)} is required. Orders are
listed in the following sequence:

{p 12 16 2}
all {cmd:hftarget()} blocks from left to right,

{p 12 16 2}
followed by all {cmd:hfpredictors()} blocks from left to right.

{pstd}
For example,

{phang2}
{cmd:. bumidas y, hftarget(lle llo) hfpredictors(llb) hforders(3 1 0) search(none)}

{pstd}
sets {cmd:lle} to order 3, {cmd:llo} to order 1, and omits {cmd:llb}.

{pstd}
Orders corresponding to {cmd:hftarget()} must be at least 1. Orders
corresponding to {cmd:hfpredictors()} may be 0.

{pstd}
{opt lfyorder(#)} specifies a fixed LF target order. If omitted, no fixed LF
target block is added.

{pstd}
{opt lfxorders(numlist)} gives fixed orders for the variables in
{cmd:lfpredictors()} from left to right. One value is required for each LF
predictor.


{marker common}{...}
{title:Common estimation sample}

{pstd}
For model selection, {cmd:bumidas} determines one common estimation sample
before the search begins. The sample is defined using the largest admissible
candidate specification and is then held fixed for every candidate model.

{pstd}
This ensures that AIC, HQIC, and BIC are compared over the same observations
within a given search.

{pstd}
Changing {cmd:hftarget()}, {cmd:hfpredictors()}, {cmd:hfmax()},
{cmd:lfymax()}, {cmd:lfpredictors()}, {cmd:lfxmax()}, {cmd:controls()}, or
{cmd:horizon()} can change the common sample. Information-criterion values
from different searches therefore should not generally be compared unless
their estimation samples are identical.


{marker ic}{...}
{title:Information criteria}

{pstd}
{opt ic(bic|hqic|aic)} specifies the information criterion. The default is
{cmd:ic(bic)}.

{pstd}
The criteria are calculated as

{p 12 16 2}
AIC = -2 ll + 2k,

{p 12 16 2}
HQIC = -2 ll + 2 ln(ln(N)) k,

{p 12 16 2}
BIC = -2 ll + ln(N) k,

{pstd}
where ll is the regression log likelihood, k is {cmd:e(rank)}, and N is the
common-sample number of observations.

{pstd}
If candidate models have information-criterion values equal within numerical
tolerance, {cmd:bumidas} prefers the model with fewer estimated parameters.
Remaining ties are resolved deterministically.


{marker options}{...}
{title:Options}

{phang}
{opt hftarget(stublist)} specifies one or more required HF blocks. Each block
must have order at least 1, so {cmd:stub0} is always included. The option may
be omitted.

{phang}
{opt hfpredictors(stublist)} specifies one or more optional HF blocks. Each
block may have order 0 and therefore may be excluded. The option may be
omitted.

{phang}
{opt hfmax(#)} caps the maximum number of included terms for every specified
HF block. The maximum for a block is the smaller of # and the number of
consecutive available variables for that stub. If {cmd:hfmax()} is omitted,
all consecutive available terms are eligible. {cmd:hfmax()} is used only with
{cmd:search(full)} or {cmd:search(recursive)}.

{phang}
{opt lfymax(#)} sets the maximum searchable LF target order. Orders 0 through
# are admissible. Omitting the option omits the searchable LF target block.
This option is used only with {cmd:search(full)} or
{cmd:search(recursive)}.

{phang}
{opt lfpredictors(varlist)} specifies LF predictors whose lag-block orders are
to be selected or fixed independently.

{phang}
{opt lfxmax(#)} sets the maximum searchable order for each variable in
{cmd:lfpredictors()}. Orders 0 through # are admissible. It is required with
{cmd:lfpredictors()} under {cmd:search(full)} or
{cmd:search(recursive)}.

{phang}
{opt controls(varlist)} specifies regressors included in every candidate and
final model exactly as written. Time-series and factor-variable notation are
allowed. Controls are not automatically shifted by {cmd:horizon()}.

{phang}
{opt horizon(#)} specifies the direct forecast horizon. The default is 1 and
# must be at least 1.

{phang}
{opt search(full|recursive|none)} specifies the selection method. The default
is {cmd:search(full)}.

{phang2}
{cmd:full} exhaustively evaluates the admissible Cartesian grid.

{phang2}
{cmd:recursive} uses forward one-block-at-a-time order selection.

{phang2}
{cmd:none} estimates fixed orders supplied through {cmd:hforders()},
{cmd:lfyorder()}, and {cmd:lfxorders()} as applicable.

{phang}
{opt ic(bic|hqic|aic)} specifies the information criterion. The default is
{cmd:bic}.

{phang}
{opt hforders(numlist)} specifies fixed HF block orders under
{cmd:search(none)}. Values correspond first to all {cmd:hftarget()} blocks and
then to all {cmd:hfpredictors()} blocks.

{phang}
{opt lfyorder(#)} specifies a fixed LF target order under
{cmd:search(none)}.

{phang}
{opt lfxorders(numlist)} specifies fixed LF predictor orders under
{cmd:search(none)}. Values correspond to {cmd:lfpredictors()} from left to
right.

{phang}
{opt noconstant} suppresses the regression constant.

{phang}
{opt regression} displays the complete final {cmd:regress} coefficient table
after the compact {cmd:bumidas} output. The final regression is estimated and
stored regardless of whether this option is specified.

{phang}
{opt trace} displays additional search information. Under
{cmd:search(full)}, the command reports each new incumbent best model. Under
{cmd:search(recursive)}, it reports the accepted search path.


{marker output}{...}
{title:Output}

{pstd}
By default, {cmd:bumidas} displays a compact summary containing the forecast
horizon, search method and information criterion, common-sample observations,
number of models evaluated, selected block orders, and final criterion value.

{pstd}
Selected blocks are labeled as

{p2colset 9 26 28 2}{...}
{p2col:Required HF}block specified in {cmd:hftarget()}{p_end}
{p2col:Optional HF}block specified in {cmd:hfpredictors()}{p_end}
{p2col:LF target}dependent-variable LF lag block{p_end}
{p2col:LF predictor}additional LF predictor block{p_end}
{p2colreset}{...}

{pstd}
Specify {cmd:regression} to display the full final regression table.


{marker replay}{...}
{title:Replay}

{pstd}
After estimation,

{phang2}
{cmd:. bumidas}

{pstd}
redisplays the compact BUMIDAS results.

{pstd}
To replay both the compact results and the underlying regression table, type

{phang2}
{cmd:. bumidas, regression}


{marker predict}{...}
{title:Prediction}

{pstd}
After {cmd:bumidas}, the following postestimation commands are supported:

{p 8 17 2}
{cmd:predict} {newvar}

{p 8 17 2}
{cmd:predict} {newvar}{cmd:, xb}

{p 8 17 2}
{cmd:predict} {newvar}{cmd:, residuals}

{pstd}
The default is {cmd:xb}.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:bumidas} is an e-class command. It retains the standard OLS regression
results from the final selected or fixed model, including {cmd:e(b)},
{cmd:e(V)}, {cmd:e(N)}, {cmd:e(ll)}, {cmd:e(rank)}, and {cmd:e(sample)}.

{pstd}
It additionally stores:

{synoptset 25 tabbed}{...}
{synopt:{cmd:e(horizon)}}forecast horizon{p_end}
{synopt:{cmd:e(icvalue)}}selected/fixed model information-criterion value{p_end}
{synopt:{cmd:e(N_models)}}number of candidate regressions evaluated{p_end}
{synopt:{cmd:e(N_common)}}common-sample number of observations{p_end}
{synopt:{cmd:e(search)}}search method{p_end}
{synopt:{cmd:e(ic)}}information criterion{p_end}
{synopt:{cmd:e(rhs)}}final regression right-hand side{p_end}
{synopt:{cmd:e(hftarget)}}required HF stubs{p_end}
{synopt:{cmd:e(hfpredictors)}}optional HF stubs{p_end}
{synopt:{cmd:e(lfpredictors)}}LF predictor variables{p_end}
{synopt:{cmd:e(controls)}}fixed controls{p_end}
{synopt:{cmd:e(order_names)}}block names corresponding to selected orders{p_end}
{synopt:{cmd:e(order_types)}}block types corresponding to selected orders{p_end}
{synopt:{cmd:e(orders)}}matrix of final selected/fixed block orders{p_end}
{synopt:{cmd:e(path)}}accepted recursive-search path; recursive search only{p_end}

{pstd}
Column prefixes in {cmd:e(orders)} and {cmd:e(path)} are

{p2colset 9 22 24 2}{...}
{p2col:{cmd:HT_}}required HF block from {cmd:hftarget()}{p_end}
{p2col:{cmd:HP_}}optional HF block from {cmd:hfpredictors()}{p_end}
{p2col:{cmd:LY_}}LF target block{p_end}
{p2col:{cmd:LP_}}LF predictor block{p_end}
{p2colreset}{...}

{pstd}
For example,

{phang2}
{cmd:. matrix list e(orders)}

{pstd}
might display

{p 12 42 2}
{cmd:          HT_lle   HP_llo}

{p 12 42 2}
{cmd:selected       3        2}

{pstd}
For recursive search, {cmd:e(path)} contains one row for the initial model and
each accepted expansion, with an additional {cmd:ic} column.


{marker examples}{...}
{title:Examples}

{title:Basic BUMIDAS-BIC}

{pstd}
Require the HF target-history block and allow the HF predictor block to be
excluded:

{phang2}
{cmd:. bumidas y, hftarget(lle) hfpredictors(llo) hfmax(20) noconstant}


{title:Require multiple HF blocks}

{pstd}
Force the most recent observation of both HF blocks into every model:

{phang2}
{cmd:. bumidas y, hftarget(lle llo) hfmax(20) search(full) ic(bic)}


{title:Make all HF blocks optional}

{pstd}
Allow either HF block to be excluded:

{phang2}
{cmd:. bumidas y, hfpredictors(lle llo) hfmax(20) search(full)}


{title:Recursive search}

{pstd}
Select among several HF blocks using the faster recursive search:

{phang2}
{cmd:. bumidas y, hftarget(lle) hfpredictors(llo llb llr) ///}

{phang2}
{cmd:      hfmax(20) search(recursive) ic(bic)}


{title:Add LF target and LF predictors}

{phang2}
{cmd:. bumidas y, hftarget(lle) hfpredictors(llo) hfmax(20) ///}

{phang2}
{cmd:      lfymax(3) lfpredictors(x1 x2) lfxmax(3) ///}

{phang2}
{cmd:      search(recursive) ic(bic)}


{title:Alternative information criterion}

{phang2}
{cmd:. bumidas y, hftarget(lle) hfpredictors(llo) ///}

{phang2}
{cmd:      hfmax(20) search(full) ic(hqic)}


{title:Three-period-ahead direct forecast}

{phang2}
{cmd:. bumidas y, hftarget(lle) hfpredictors(llo) ///}

{phang2}
{cmd:      hfmax(20) horizon(3) search(recursive)}


{title:Fixed orders}

{pstd}
Set two required HF blocks to orders 3 and 1 and omit the optional HF block:

{phang2}
{cmd:. bumidas y, hftarget(lle llo) hfpredictors(llb) ///}

{phang2}
{cmd:      hforders(3 1 0) search(none)}


{title:Fixed controls}

{pstd}
Include {cmd:L.z} and seasonal indicators in every candidate model:

{phang2}
{cmd:. bumidas y, hftarget(lle) hfpredictors(llo) hfmax(20) ///}

{phang2}
{cmd:      controls(L.z i.month) search(full)}


{title:Display the final regression}

{phang2}
{cmd:. bumidas y, hftarget(lle) hfpredictors(llo) ///}

{phang2}
{cmd:      hfmax(20) regression}


{title:Trace model selection}

{phang2}
{cmd:. bumidas y, hftarget(lle) hfpredictors(llo llb) ///}

{phang2}
{cmd:      hfmax(20) search(recursive) trace}


{title:Prediction}

{phang2}
{cmd:. predict double yhat}

{phang2}
{cmd:. predict double uhat, residuals}


{marker workflow}{...}
{title:Typical workflow}

{pstd}
A typical workflow is

{p 12 16 2}
1. prepare higher-frequency data;

{p 12 16 2}
2. use {help mfcollapse} when temporal aggregation is required;

{p 12 16 2}
3. create the desired economic transformations explicitly;

{p 12 16 2}
4. call {cmd:bumidas} using the transformed HF stubs and optional LF blocks;

{p 12 16 2}
5. use {cmd:predict} or an external forecasting loop for forecast construction
and evaluation.

{pstd}
For example, if {cmd:mfcollapse} creates {cmd:wti_ld0},
{cmd:wti_ld1}, ..., a user may first construct transformed variables
{cmd:llo0}, {cmd:llo1}, ... and then supply the stub {cmd:llo} to
{cmd:bumidas}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:bumidas} does not import data, construct mixed-frequency observations,
transform variables, estimate restricted MIDAS weighting functions, or
evaluate forecasts.

{pstd}
Full-grid search can become computationally expensive when many blocks have
large maximum orders. Recursive search is often substantially faster, but
because it is a forward greedy procedure it need not find the global
information-criterion minimum.

{pstd}
Changing the maximum candidate orders can change the common estimation sample
even when the same final order is selected. This can change the reported
information-criterion value because the final model is re-estimated on the
new common sample.

{pstd}
The command currently supports direct horizons greater than or equal to 1.
Horizon-zero nowcasting is not implemented.


{marker references}{...}
{title:References}

{phang}
Lee, S., and S. Snudden. 2025. {it:Bottom-Up Mixed-Frequency Data Sampling}.
Working paper.

{phang}
Benmoussa, A., R. Ellwanger, and S. Snudden. 2026.  
{it:Carpe Diem: Can daily oil prices improve model-based forecasts of the real price of crude oil?}
International Journal of Forecasting 42(1): 281-295.


{marker author}{...}
{title:Author}

{pstd}
Stephen Snudden

{pstd}
Wilfrid Laurier University

{pstd}
Website: {browse "https://stephensnudden.com/"}

{pstd}
GitHub: {browse "https://github.com/SSEconomics"}

{pstd}
YouTube: {browse "https://youtube.com/@ssnudden"}


{marker alsosee}{...}
{title:Also see}

{psee}
Manual:  {help regress}, {help predict}, {help tsset}

{psee}
Related: {help mfcollapse}
