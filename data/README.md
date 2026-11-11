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

Growth rates, ratios, and forecast lags come later. These are revised data as of the recorded download date; calendar-year alignment does not establish real-time availability.
