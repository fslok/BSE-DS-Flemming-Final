# BSE-DS-Flemming-Final

## Run the complete project

Open [Final_Project.R](Final_Project.R) and run it, or paste this into R:

```r
source("https://raw.githubusercontent.com/fslok/BSE-DS-Flemming-Final/main/Final_Project.R")
```

It starts with `read.csv()` from GitHub, then runs the annotated cleaning, graphing and regression sections. No working-directory change, local input files or FRED API key is needed. Internet access is required; missing R packages install automatically. Results are saved in `BSE_TFR_results` under the current working folder (or a temporary folder if that is not writable); the script prints the full location.

The complete script uses the long-history sample and compares OLS, LASSO, a small regression tree and random forest with a previous-TFR benchmark. It tries both TFR levels and percentage changes, scoring forecasts in births per woman. Settings and the selected model are chosen on 2005-2014, then frozen before the 2015-2024 test. The CSV URL pins the collected data snapshot so everyone starts with the same values.

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

The standalone scripts above preserve the earlier preparation steps. [Final_Project.R](Final_Project.R) combines the main workflow and models in one file. Any optional shorter-history comparison will be kept separate.
