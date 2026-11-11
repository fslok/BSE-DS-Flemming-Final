# FRED series

Collection list: 1 target, 25 long-history candidate predictors, and 8 additional predictors. Final model subsets will be chosen in R.

## Target

| FRED code / source | Variable | Source frequency |
| --- | --- | --- |
| [SPDYNTFRTINUSA](https://fred.stlouisfed.org/series/SPDYNTFRTINUSA) | U.S. total fertility rate (births per woman) | Annual |

## Long-history predictors

| FRED code / source | Variable | Source frequency |
| --- | --- | --- |
| [A939RX0Q048SBEA](https://fred.stlouisfed.org/series/A939RX0Q048SBEA) | Real GDP per capita | Quarterly |
| [A229RX0](https://fred.stlouisfed.org/series/A229RX0) | Real disposable personal income per capita | Monthly |
| [PCECC96](https://fred.stlouisfed.org/series/PCECC96) | Real personal consumption expenditures | Quarterly |
| [PSAVERT](https://fred.stlouisfed.org/series/PSAVERT) | Personal saving rate | Monthly |
| [INDPRO](https://fred.stlouisfed.org/series/INDPRO) | Industrial production index | Monthly |
| [CUMFNS](https://fred.stlouisfed.org/series/CUMFNS) | Manufacturing capacity utilization (SIC) | Monthly |
| [UNRATE](https://fred.stlouisfed.org/series/UNRATE) | Unemployment rate | Monthly |
| [PAYEMS](https://fred.stlouisfed.org/series/PAYEMS) | Total nonfarm payroll employment | Monthly |
| [CIVPART](https://fred.stlouisfed.org/series/CIVPART) | Labor force participation rate | Monthly |
| [LNS11300002](https://fred.stlouisfed.org/series/LNS11300002) | Women's labor force participation rate (16+) | Monthly |
| [LRAC25FEUSA156N](https://fred.stlouisfed.org/series/LRAC25FEUSA156N) | Women's labor force participation rate (25–54) | Annual |
| [LNS14000002](https://fred.stlouisfed.org/series/LNS14000002) | Women's unemployment rate (16+) | Monthly |
| [LNS12300002](https://fred.stlouisfed.org/series/LNS12300002) | Women's employment-to-population ratio (16+) | Monthly |
| [LNS14000036](https://fred.stlouisfed.org/series/LNS14000036) | Unemployment rate (20–24, both sexes) | Monthly |
| [UEMPMEAN](https://fred.stlouisfed.org/series/UEMPMEAN) | Mean duration of unemployment | Monthly |
| [AWHMAN](https://fred.stlouisfed.org/series/AWHMAN) | Average weekly hours: manufacturing production and nonsupervisory workers | Monthly |
| [CPIAUCSL](https://fred.stlouisfed.org/series/CPIAUCSL) | Consumer price index: all items | Monthly |
| [CPILFESL](https://fred.stlouisfed.org/series/CPILFESL) | Consumer price index excluding food and energy | Monthly |
| [CUUR0000SEHA](https://fred.stlouisfed.org/series/CUUR0000SEHA) | Rent of primary residence CPI (not seasonally adjusted) | Monthly |
| [FEDFUNDS](https://fred.stlouisfed.org/series/FEDFUNDS) | Effective federal funds rate | Monthly |
| [GS10](https://fred.stlouisfed.org/series/GS10) | 10-year Treasury constant maturity rate | Monthly |
| [TB3MS](https://fred.stlouisfed.org/series/TB3MS) | 3-month Treasury bill rate (discount basis) | Monthly |
| [BAA](https://fred.stlouisfed.org/series/BAA) | Moody's seasoned Baa corporate bond yield | Monthly |
| [HOUST](https://fred.stlouisfed.org/series/HOUST) | Housing starts | Monthly |
| [PERMIT](https://fred.stlouisfed.org/series/PERMIT) | New privately owned housing units authorized by building permits | Monthly |

## Additional predictors with shorter or irregular histories

| FRED code / source | Variable | Source frequency |
| --- | --- | --- |
| [AHETPI](https://fred.stlouisfed.org/series/AHETPI) | Average hourly earnings: private production and nonsupervisory workers | Monthly |
| [ICSA](https://fred.stlouisfed.org/series/ICSA) | Initial unemployment insurance claims | Weekly |
| [MORTGAGE30US](https://fred.stlouisfed.org/series/MORTGAGE30US) | 30-year fixed mortgage rate | Weekly |
| [UMCSENT](https://fred.stlouisfed.org/series/UMCSENT) | University of Michigan consumer sentiment | Monthly; irregular before 1978 |
| [LEU0252882700Q](https://fred.stlouisfed.org/series/LEU0252882700Q) | Women's median usual weekly earnings: full-time workers (16+) | Quarterly |
| [LEU0252881800Q](https://fred.stlouisfed.org/series/LEU0252881800Q) | Men's median usual weekly earnings: full-time workers (16+) | Quarterly |
| [MEHOINUSA672N](https://fred.stlouisfed.org/series/MEHOINUSA672N) | Real median household income | Annual |
| [CSUSHPINSA](https://fred.stlouisfed.org/series/CSUSHPINSA) | S&P CoreLogic Case-Shiller U.S. National Home Price Index | Monthly |

Check actual coverage during collection. The annual aggregation rules are in [README.md](README.md).
