# Data

- `raw/<FRED_CODE>.csv`: observations at their original frequency, from 1960 onward.
- `raw/series_metadata.csv`: frequencies, units, source links, download date, coverage, and file checksums.
- `us_fertility_annual.csv`: the merged annual dataset for R.
- `annual_coverage.csv`: completeness and observation counts for every series/year.
- [variables.md](variables.md): target and candidate predictors, with FRED source links.

## Run after reviewing the scripts

Use the repository root as the R working directory. Put your replacement API key alone in local `secret.txt`, or set the `FRED_API_KEY` environment variable. The key is never written to the downloaded files.

```r
source("scripts/01_download_fred.R")
source("scripts/02_clean_merge.R")
```

The download script installs `httr2` if needed and requests the 34 listed series through the [FRED observations API](https://fred.stlouisfed.org/docs/api/fred/series_observations.html), with [series metadata](https://fred.stlouisfed.org/docs/api/fred/series.html). Rerunning it refreshes the raw files. The cleaning script uses base R and makes no network requests.

## Merge rules

1. One row per calendar year, from 1960 through the latest nonmissing TFR year, capped at the last completed calendar year when downloaded. Years are sorted and unique.
2. Columns: `year`, `tfr` (FRED `SPDYNTFRTINUSA`), then one column per predictor named with its FRED code.
3. Keep annual sources unchanged. Average monthly, quarterly, and weekly observations within each calendar year; do not sum rates, indexes, or annualized flows.
4. Require all 12 distinct months, all 4 distinct quarters, or 1 annual observation, with no missing values. Weekly series need 52-53 nonmissing observations, dates in the first and last seven days of the year, and no gap over ten days. This conservative rule allows reporting weekday changes; failed years remain `NA` and are flagged in the coverage file. For `ICSA`, the result is average weekly claims, not total annual claims.
5. Keep unavailable values as `NA`. Do not interpolate or drop early years just because an additional series starts later. Check irregular early `UMCSENT` coverage separately.
6. Preserve source units in this CSV. Build growth rates, inflation rates, ratios, and forecast lags separately in R. Calendar-year alignment alone does not establish availability at the forecast date; check release timing before modelling.

The scripts are prepared for review; observations have not been downloaded or merged. These are revised data as of the recorded download date, not historical real-time vintages.
