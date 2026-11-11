# BSE-DS-Flemming-Final

This is the dataset-codebase for the Intro to Data Science final project at BSE school year 2026-27

The aim of this project is to forecast TFR based on US macro variables from FRED.

Following the datathon as a guide, I create a GitHub [that you are in now] that should allow for no manual data downloads to run this entire project.

I use a list of variables at the bottom of this readme to test TFR

The motivation for this project specifically is to see not only which econometric method predicts best, but also to understand how different vars predict the outcome. 

I collect 'standard' macro variables commonly used in forecasting project like this one (GDP per capita, unemployment, Umich sentiment survey data) and try more unusual variables in separate regressions (womens/mens split incomes, 30y mortgage rate, case-schiller house price-index (which only begins about halfway through the training period, unfortunately)) 

I believe that allows this project to go from a straight forward data descriptive process measuring 'people do not have children because of economic stress' to a more interesting 'besides outright economic factors, is there an underlying sociology (housing loan pressures, household breadwinner dynamics, marriage rates) that we can measure to predict TFR?'
