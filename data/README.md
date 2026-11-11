# Data

- `raw/annual/<FRED_CODE>.csv`: annual observations downloaded directly from FRED.
- `raw/annual/series_metadata.csv`: original and downloaded frequencies, units, source links, download date, and file checksums.
- `us_fertility_annual.csv`: one annual dataset for R, with `year`, `tfr`, and 33 predictors.
- `annual_coverage.csv`: availability of each series/year, not a full-year completeness test.
- [variables.md](variables.md): the 34 series and their original frequencies.

## Run

Use the repository root as the R working directory. Put your replacement API key alone in local `secret.txt`, or set `FRED_API_KEY`.

```r
source("scripts/01_download_fred.R")
source("scripts/02_clean_merge.R")
```

Script 01 installs `httr2` if needed and requests `frequency = "a"`, `aggregation_method = "avg"`, and `units = "lin"` from the [FRED API](https://fred.stlouisfed.org/docs/api/fred/series_observations.html). This is Annual/Average in the FRED interface. Annual source series pass through unchanged. The current unfinished calendar year is excluded.

Script 02 checks the files and joins by year, from 1960 through the latest available TFR year. It preserves FRED's annual values and missingness, without averaging or interpolation. Predictors retain their FRED codes as column names. It makes no network requests.

The previous native-frequency downloads in `raw/` are preserved. The updated scripts use only `raw/annual/`; rerun both scripts once to switch over. Future runs refresh the annual downloads and merged outputs.

## Interpretation

FRED applies its own [missing-value rules](https://fred.stlouisfed.org/help/data/understanding-the-data/how-are-missing-values-treated-in-average-sum-and-end-of-period-aggregation-methods-2/) and [first/last-period thresholds](https://fred.stlouisfed.org/help/data/understanding-the-data/how-are-missing-values-determined-for-the-first-and-last-observations-3). An annual value can use fewer than a full year's observations: weekly boundary years require 39 observations, and interior missing values are ignored. Thus early mortgage and consumer-sentiment values may appear where the previous script returned `NA`.

FRED also [rounds aggregated values](https://fred.stlouisfed.org/help/data/understanding-the-data/how-is-the-number-of-decimal-places-determined-for-aggregated-values), so small differences from the previous R averages are expected. All units are preserved: CPI is an index, rates are percentages, and annual `ICSA` is average weekly claims.

The merged file retains source levels; script 03 creates growth rates, ratios, and forecast lags separately. These are revised data as of the recorded download date; calendar-year alignment does not establish real-time availability.

## Forecasting features and split

After scripts 01 and 02, run:

```r
source("scripts/03_features_split.R")
```

- Main target: TFR in year t. Secondary target: 100 * (TFR_t / TFR_(t-1) - 1).
- Every predictor uses calendar year t-1. Split by outcome year: training 1961-2004, trial 2005-2014, test 2015-2024.
- The held-out periods will contain successive one-year-ahead forecasts using each preceding year's observations, not a ten-year forecast made at one starting date.
- Four feature ideas: previous TFR, women's/men's weekly earnings ratio, log real disposable income per capita, and log inflation-adjusted house-price index.
- `forecast_data.csv` contains the aligned data. Use `predictor_dictionary.csv` to select inputs; do not include the outcome, year labels, or eligibility flags as predictors.
- The main input list has 27 predictors and 44/10/10 training/trial/test rows. The expanded list has 33 predictors but only 17/10/10 rows, because lagged house prices begin with outcome year 1988. Compare expanded and core specifications on the same shorter sample; use a small OLS specification, since unrestricted OLS cannot uniquely estimate 33 slopes from 17 observations.
- The earnings ratio compares aggregate weekly earnings among full-time workers; it is not an adjusted pay-gap estimate.
- Sentiment correlations and scatterplots use training outcomes only. A pre-specified coverage check starts with outcome year 1979, when the preceding year's sentiment has monthly observations.
- Retain shock years. Mark oil shocks, the Great Recession, and COVID on plots, and discuss any associated residuals or forecast errors after models are fixed; do not use knowledge of future shocks as forecast inputs.
- Fit scaling and any model tuning using training/trial information only. The revised annual histories make this a retrospective forecasting exercise, not a real-time vintage reconstruction.

Script 03 saves sample counts and correlations in `outputs/tables/` and a training scatterplot in `outputs/figures/`. Model estimation and final test evaluation are the next step.

## Sentiment and fertility graphs

Run `source("scripts/04_graphs.R")` from the repository root after script 02. It reads the merged annual data and aligns sentiment in t-1 with TFR in t. It saves two graphs in `outputs/figures/`: `umcsent_tfr_scatter.png` adds a descriptive OLS best-fit line; `umcsent_tfr_path.png` connects consecutive years with arrows. Both label every point with its TFR outcome year and use training outcomes 1961-2004 only. This standalone script uses base R and does not require script 03 or change any data files.

The chronological path shows changes in the paired observations, not causal direction. Sentiment's one-year lead is imposed by the alignment. A leftward segment means prior-year sentiment fell; a downward segment means current-year TFR fell. The fitted line is descriptive, not a forecasting-model evaluation.

The agreed main model comparison is OLS, LASSO, a small regression tree and random forest, plus a previous-TFR benchmark. Use the 27-predictor long-history list. The expanded preparation currently in script 03 is optional; separate expanded-analysis scripts will be added at the modelling stage if needed.

## Data notes for the draft

- The current merged sample has 65 years (1960-2024), TFR and 33 predictors. TFR and the 26 main macro predictors have complete coverage. The seven optional series have missing early years before their histories begin; no internal gaps were found. The merged values match the saved annual source files.
- UMCSENT has four native observations per year during 1960-1977 and twelve per year from 1978. The early annual averages therefore use fewer surveys. Retain the series and disclose this difference to the TA. It combines current conditions and expectations, rather than measuring fertility intentions.
- TFR is much higher in the early 1960s than later in the sample. The 2024 value (1.6265) is below the 1961-2004 training minimum (1.738), which limits the ability of standard regression trees and random forests to extrapolate to new lows.
- Keep genuine shock observations, including the large 2020 movements in unemployment, saving and claims. Mark events on suitable plots rather than adding future-shock information to forecasts.
- CPI, core CPI and rent CPI are price indices, not inflation rates. Annual ICSA is average weekly claims, not a yearly total. Payrolls and housing quantities are in thousands; income measures and nominal earnings retain their stated units.
- Keep the official indices as source data. If we use inflation as a predictor, derive annual percentage changes from the indices in feature preparation. To retain a 1961 outcome with lagged 1960 inflation, we would need the 1959 index observation. No new data or price transformations have been added for this graph update. See the [BLS explanation of CPI changes](https://www.bls.gov/cpi/technical-notes/).

## Checks to report with the first OLS

Use the training sample and the predictors actually included in the regression. Report a predictor correlation matrix, flag large absolute correlations, check for exact linear dependence, and report variance inflation factors (VIFs) where the model is full rank. Covariance magnitudes depend on units; correlations and VIFs are more useful for comparing overlap. Do not automatically remove a predictor solely because it exceeds a correlation threshold.

The initial check of source levels over predictor years 1960-2003 found correlations of 0.9994 for headline/core CPI, 0.9983 for women's 16+/25-54 participation, 0.9977 for real GDP/disposable income per capita, and 0.9918 for federal funds/3-month Treasury rates. Shared trends contribute. Recalculate diagnostics after choosing transformations and the OLS specification; these are preliminary descriptive checks, not model results.
