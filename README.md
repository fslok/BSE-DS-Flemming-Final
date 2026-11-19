# BSE-DS-Flemming-Final

## Run the submission

Open [Final_Project.R](Final_Project.R) and run it, or paste this into R:

```r
source("https://raw.githubusercontent.com/fslok/BSE-DS-Flemming-Final/main/Final_Project.R")
```

[Final_Project.R](Final_Project.R) is the single submission script. It reads the assembled CSV directly from a fixed GitHub snapshot, checks the data, constructs the lagged features, runs the regressions and creates all figures. Run it from any folder. Internet access is required, and missing R packages install automatically.

The comparison includes carry-forward, fitted AR(1), OLS, LASSO, a shallow regression tree and random forest. It evaluates 15 specifications using TFR alone or TFR plus 26 macro indicators, with both levels and annual percentage changes as targets. Initial training covers 1961–2004, trial 2005–2014 and test 2015–2024.

Every model is re-estimated before each one-year forecast using an expanding window: outcomes through 2004 predict 2005, outcomes through 2005 predict 2006, and so on. Trial RMSE selects tuning settings and the preferred specification. These choices remain fixed during the test period, while fitted parameters are updated annually through 2023 for the final 2024 forecast. LASSO's candidate penalty grid is constructed from the initial training sample, and its scaling is fitted separately at each origin. Historical publication delays and data revisions are not reproduced. These test years were examined in earlier project versions, so this is a revised evaluation.

Outputs go into `BSE_TFR_results` in the current folder, with a temporary-folder fallback when necessary. The script prints the location. It saves the combined RMSE table, 300 annual forecasts, selected settings, coefficients for each forecast year, training correlations/VIFs, yearly tree rules and R session information. `forecast_schedule.csv` records each estimation window; `trial_candidate_forecasts.csv` records the forecasts used to tune each candidate. Forest importance and the individual OLS coefficient summaries describe the last fit, through 2023, used to forecast 2024. The `figures` subfolder contains eight figures in PNG and PDF:

- Annual TFR, 1960–2024.
- Training TFR histogram.
- Lagged sentiment scatter with fitted line and year labels.
- Sentiment scatter connecting consecutive years.
- Training sentiment plots for TFR levels and changes.
- Trial-selected model's test forecasts and errors.
- Random-forest predictor importance.
- Carry-forward, AR(1) and macro change-tree forecasts.

The numbered scripts below record earlier collection and analysis steps. The submission runs entirely from `Final_Project.R`.

## Project

This is the dataset-codebase for the Intro to Data Science final project at BSE school year 2026-27

The aim of this project is to forecast TFR based on US macro variables from FRED.

Following the datathon as a guide, I create a GitHub [that you are in now] that should allow for no manual data downloads to run this entire project.

I use a list of variables at the bottom of this readme to test TFR

The motivation for this project specifically is to see not only which econometric method predicts best, but also to understand how different vars predict the outcome. 

I collect 'standard' macro variables commonly used in forecasting project like this one (GDP per capita, unemployment, Umich sentiment survey data) and try more unusual variables in separate regressions (womens/mens split incomes, 30y mortgage rate, case-schiller house price-index (which only begins about halfway through the training period, unfortunately)) 

I believe that allows this project to go from a straight forward data descriptive process measuring 'people do not have children because of economic stress' to a more interesting 'besides outright economic factors, is there an underlying sociology (housing loan pressures, household breadwinner dynamics, marriage rates) that we can measure to predict TFR?'

[Variable list and FRED sources](data/variables.md) · [Data preparation](data/README.md)

Collection scripts (not needed to run the complete project): [1. Download annual FRED data](scripts/01_download_fred.R) · [2. Check and merge](scripts/02_clean_merge.R). Review first; run in that order from the repository root if refreshing the source data.

[3. Prepare forecasting features and splits](scripts/03_features_split.R) creates the one-year-ahead dataset and training-only sentiment checks.

[4. Graph sentiment and fertility](scripts/04_graphs.R) creates two training-period plots of prior-year UMCSENT and current-year TFR: a scatter with a best-fit line and a chronological path, both labelled by TFR year. It can run directly after script 02. [Data notes](data/README.md#data-notes-for-the-draft) record coverage, units and survey limitations.

[Final_Project.R](Final_Project.R) contains the complete long-history analysis, including the autoregression comparisons and annual TFR graph. The shorter-history model remains an optional extension.
