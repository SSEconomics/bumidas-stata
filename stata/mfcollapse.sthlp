{smcl}
{* *! version 0.2.0 1oct2026}{...}

{title:Title}

{phang}
{bf:mfcollapse} {hline 2} Collapse high-frequency data to mixed-frequency low-frequency data


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:mfcollapse} {varlist} {ifin}{cmd:,}
{opt date(varname)}
{opt frequency(string)}
[{opt ar(#)}
{opt lags(#)}
{opt anchor(varname)}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:mfcollapse} converts high-frequency observations into a low-frequency
mixed-frequency dataset for MIDAS and related forecasting applications.

{pstd}
For each variable in {varlist}, the command constructs the latest available
high-frequency observation in each low-frequency period, its high-frequency
lags, and the low-frequency average. The data are then reduced to one
observation per low-frequency period.

{pstd}
High-frequency lags are defined in {it:observation time}, not calendar time.
Observations for which the anchor variable is missing are removed before the
high-frequency lag sequence is constructed. Thus, lag 1 refers to the previous
available observation rather than necessarily the previous calendar day.

{pstd}
Like {cmd:collapse}, {cmd:mfcollapse} replaces the dataset currently in memory.
Users wishing to retain the original high-frequency data should save the data
or use {cmd:preserve} before calling {cmd:mfcollapse}.


{marker options}{...}
{title:Options}

{phang}
{opt date(varname)} specifies the numeric Stata daily-date variable.
This option is required. The variable must uniquely identify the
high-frequency observations in the sample.

{phang}
{opt frequency(string)} specifies the desired low-frequency sampling
frequency. This option is required. Allowed values are
{cmd:weekly}, {cmd:monthly}, and {cmd:quarterly}.

{pstd}
The date variable retains the name specified in {cmd:date()} but is converted
to the corresponding Stata low-frequency date. The output is automatically
formatted as {cmd:%tw}, {cmd:%tm}, or {cmd:%tq}, and the resulting dataset is
declared as time-series data using that variable.

{phang}
{opt ar(#)} specifies the autoregressive order used to determine the maximum
high-frequency lag. Let n denote the inferred number of high-frequency
observations per low-frequency period. The maximum lag is

{p 12 16 2}
p(n-1),

{pstd}
where p is the value supplied in {cmd:ar()}. If neither {cmd:ar()} nor
{cmd:lags()} is specified, {cmd:ar(1)} is used.

{phang}
{opt lags(#)} directly specifies the maximum high-frequency lag to create.
For example, {cmd:lags(10)} creates lag variables 0 through 10.
{cmd:lags()} and {cmd:ar()} may not be specified together.

{phang}
{opt anchor(varname)} specifies the variable whose observed values define the
common high-frequency observation schedule. The default is the first variable
in {varlist}. All variables in {varlist} must have the same observed/missing
pattern as the anchor variable.


{marker generated}{...}
{title:Generated variables}

{pstd}
For each variable {it:x} in {varlist}, {cmd:mfcollapse} creates

{p2colset 9 28 30 2}{...}
{p2col:{cmd:x_ld0}}latest available high-frequency observation in the low-frequency period{p_end}
{p2col:{cmd:x_ld1}}previous available high-frequency observation{p_end}
{p2col:{cmd:x_ld2}}second previous available high-frequency observation{p_end}
{p2col:{cmd:...}}additional observed-HF lags through the selected maximum lag{p_end}
{p2col:{cmd:x_ave}}average of available high-frequency observations within the low-frequency period{p_end}
{p2colreset}{...}

{pstd}
The retained row for each low-frequency period corresponds to the latest
available high-frequency observation in that period. Therefore {cmd:x_ld0}
is the end-of-period information actually available for variable {it:x},
not necessarily an observation on the final calendar date of the period.


{marker hfn}{...}
{title:Inferring the high-frequency sampling rate}

{pstd}
{cmd:mfcollapse} counts the number of observed high-frequency observations in
each low-frequency period. The first and last low-frequency periods are
excluded from this calculation because they may be partial.

{pstd}
Let {it:hfmean} denote the mean number of observed high-frequency observations
per complete low-frequency period. The integer sampling frequency used by the
command is

{p 12 16 2}
n = ceil({it:hfmean}).

{pstd}
For example, daily financial data collapsed to monthly frequency may contain
an average of 21.7 observed trading days per month, implying n = 22.

{pstd}
The first and last periods are excluded only when estimating n. They remain in
the collapsed dataset.


{marker missing}{...}
{title:Missing high-frequency observations}

{pstd}
Missing calendar observations do not create gaps in the high-frequency lag
sequence. The anchor variable defines the observation clock. Rows for which
the anchor is missing are removed before the sequential high-frequency index
is created.

{pstd}
For example, suppose the observed series is

{p 12 22 2}
09feb1973     1.0002

{p 12 22 2}
12feb1973     missing

{p 12 22 2}
13feb1973     0.9941

{pstd}
The first high-frequency lag of the 13feb1973 observation is 1.0002.
The missing 12feb1973 calendar observation does not create a missing lag.

{pstd}
When multiple variables are supplied, they are assumed to share a common
observation schedule. If their observed/missing patterns differ from that of
the anchor variable, {cmd:mfcollapse} issues an error. Variables with different
observation schedules should be collapsed separately and merged after
aggregation.


{marker examples}{...}
{title:Examples}

{title:Basic use}

{pstd}
Collapse daily exchange-rate data to monthly frequency:

{phang2}
{cmd:. mfcollapse cad, date(time) frequency(monthly)}

{pstd}
The default is {cmd:ar(1)}. If the inferred monthly frequency is n = 22,
the command creates {cmd:cad_ld0} through {cmd:cad_ld21}, together with
{cmd:cad_ave}.


{title:Alternative low-frequency targets}

{pstd}
Collapse daily WTI data to weekly frequency:

{phang2}
{cmd:. mfcollapse wti, date(time) frequency(weekly)}

{pstd}
Collapse daily WTI data to quarterly frequency:

{phang2}
{cmd:. mfcollapse wti, date(time) frequency(quarterly)}


{title:Higher autoregressive order}

{pstd}
Create the lag block implied by p = 3:

{phang2}
{cmd:. mfcollapse cad, date(time) frequency(monthly) ar(3)}


{title:Explicit maximum lag}

{pstd}
Create lag variables 0 through 30 rather than using p(n-1):

{phang2}
{cmd:. mfcollapse wti, date(time) frequency(monthly) lags(30)}


{title:Multiple variables with a common observation schedule}

{pstd}
Collapse weekly commodity-price variables to monthly frequency:

{phang2}
{cmd:. mfcollapse bcpi bcne ener, date(time) frequency(monthly)}

{pstd}
The first variable, {cmd:bcpi}, is the default anchor. The same inferred
high-frequency frequency and lag length are used for all variables.


{title:Alternative anchor}

{pstd}
Specify the common observation schedule explicitly:

{phang2}
{cmd:. mfcollapse bcpi bcne ener, date(time) frequency(monthly) anchor(bcpi)}


{title:Restricting the sample}

{pstd}
Collapse observations beginning on 01jan2000:

{phang2}
{cmd:. mfcollapse cad if time>=td(01jan2000), date(time) frequency(monthly)}


{title:Using returned results}

{pstd}
Display the inferred sampling frequency and maximum lag:

{phang2}
{cmd:. mfcollapse wti, date(time) frequency(monthly) ar(1)}

{phang2}
{cmd:. return list}

{phang2}
{cmd:. display r(hfn)}

{phang2}
{cmd:. display r(maxlag)}

{pstd}
Returned values may be stored for later use:

{phang2}
{cmd:. local hfn = r(hfn)}

{phang2}
{cmd:. local maxlag = r(maxlag)}


{title:Merging collapsed HF data with an existing LF dataset}

{pstd}
Because {cmd:mfcollapse} operates only on the data currently in memory,
the collapsed dataset may be saved temporarily and merged into an existing
low-frequency dataset:

{phang2}
{cmd:. mfcollapse wti, date(time) frequency(monthly)}

{phang2}
{cmd:. tempfile wtimf}

{phang2}
{cmd:. save `wtimf'}

{phang2}
{cmd:. use monthlydata, clear}

{phang2}
{cmd:. merge 1:1 time using `wtimf', nogenerate}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mfcollapse} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{synopt:{cmd:r(hfmean)}}mean number of observed HF observations per complete LF period{p_end}
{synopt:{cmd:r(hfn)}}integer HF frequency, ceil({cmd:r(hfmean)}){p_end}
{synopt:{cmd:r(maxlag)}}maximum HF lag created{p_end}
{synopt:{cmd:r(N_hf)}}number of retained HF observations{p_end}
{synopt:{cmd:r(N_lf)}}number of resulting LF observations{p_end}
{synopt:{cmd:r(N_dropped)}}number of observations dropped because the anchor was missing{p_end}
{synopt:{cmd:r(ar)}}AR order, when {cmd:ar()} is used{p_end}
{synopt:{cmd:r(frequency)}}low-frequency sampling frequency{p_end}
{synopt:{cmd:r(anchor)}}anchor variable{p_end}
{synopt:{cmd:r(varlist)}}variables collapsed{p_end}
{synopt:{cmd:r(date)}}date variable{p_end}
{synopt:{cmd:r(lagrule)}}rule used to determine the maximum lag{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:mfcollapse} is a data-management command. It does not import external
data, merge datasets, transform economic variables, estimate MIDAS models,
or produce forecasts.

{pstd}
Transformations such as logarithms, growth rates, deflation, and differencing
should generally be performed separately so that the transformation used in
the forecasting model remains explicit.

{pstd}
Variables with different high-frequency observation schedules should generally
be processed in separate calls to {cmd:mfcollapse} and merged afterward at the
common low frequency.


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
