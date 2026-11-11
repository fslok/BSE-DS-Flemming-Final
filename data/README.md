# Data

- `raw/`: original FRED observations, with retrieval dates recorded alongside them.
- `us_fertility_annual.csv`: planned merged output for R; created after collection.
- [variables.md](variables.md): target and candidate predictors, with FRED source links.

## Merge rules

1. One row per calendar year, sorted by `year`, with no duplicate years.
2. Columns: `year`, `tfr` (FRED `SPDYNTFRTINUSA`), then one column per predictor named with its FRED code.
3. Keep annual sources unchanged. Average monthly, quarterly, and weekly observations within each calendar year; do not sum rates, indexes, or annualized flows.
4. Require 12 monthly or 4 quarterly observations for a complete annual value. Check weekly calendar coverage and flag incomplete years before aggregation. For `ICSA`, the result is average weekly claims, not total annual claims.
5. Keep unavailable values as `NA`. Do not interpolate or drop early years just because an additional series starts later. Check irregular early `UMCSENT` coverage separately.
6. Preserve source units in this CSV. Build growth rates, inflation rates, ratios, and forecast lags separately in R. Calendar-year alignment alone does not establish availability at the forecast date; check release timing before modelling.

Status: folder and variable list prepared; observations have not been downloaded or merged.
