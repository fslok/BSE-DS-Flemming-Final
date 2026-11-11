# Run from the repository root: source("scripts/03_features_split.R")
# Predict TFR in year t using calendar-year t-1 data (revised-data exercise).
# This prepares features and training-only exploration; it does not fit forecast models.

input <- "data/us_fertility_annual.csv"
metadata_path <- "data/raw/annual/series_metadata.csv"
if (!file.exists(input) || !file.exists(metadata_path)) stop("Run scripts 01 and 02 first.")
d <- read.csv(input, check.names = FALSE)
metadata <- read.csv(metadata_path, stringsAsFactors = FALSE)
predictor_ids <- metadata$series_id[metadata$group != "target"]
core_ids <- metadata$series_id[metadata$group == "core"]
if (anyNA(d$year) || anyDuplicated(d$year) || length(predictor_ids) != 33L ||
    length(core_ids) != 25L || !all(c("year", "tfr", predictor_ids) %in% names(d))) {
  stop("Unexpected merged data or variable list.")
}
d <- d[order(d$year), ]
if (!all(1960:2024 %in% d$year)) stop("Expected every year from 1960 through 2024.")

# Match years explicitly: never use a row shift across a missing calendar year.
previous <- match(d$year - 1L, d$year)
positive_ids <- c("tfr", "A229RX0", "CPIAUCSL", "CSUSHPINSA",
                  "LEU0252882700Q", "LEU0252881800Q")
if (any(vapply(d[positive_ids], function(x) any(x <= 0, na.rm = TRUE), logical(1)))) {
  stop("A log, ratio, or percentage-change input is nonpositive; inspect it first.")
}
forecast <- data.frame(
  year = d$year, predictor_year = d$year - 1L,
  tfr = d$tfr,
  tfr_yoy_pct = 100 * (d$tfr / d$tfr[previous] - 1)
)
for (id in predictor_ids) forecast[[paste0(id, "_lag1")]] <- d[[id]][previous]

# Four feature ideas, all measured at t-1.
forecast$tfr_lag1 <- d$tfr[previous]
forecast$female_male_earnings_ratio_lag1 <-
  d$LEU0252882700Q[previous] / d$LEU0252881800Q[previous]
forecast$log_real_disposable_income_pc_lag1 <- log(d$A229RX0[previous])
forecast$log_real_house_price_index_lag1 <-
  log(d$CSUSHPINSA[previous] / (d$CPIAUCSL[previous] / 100))

# Split by the TFR OUTCOME year, not the predictor year.
forecast <- forecast[forecast$year >= 1961 & forecast$year <= 2024, ]
forecast$period <- ifelse(forecast$year <= 2004, "train",
                           ifelse(forecast$year <= 2014, "trial", "test"))
forecast <- forecast[c("year", "predictor_year", "period", "tfr", "tfr_yoy_pct",
                       setdiff(names(forecast), c("year", "predictor_year", "period",
                                                 "tfr", "tfr_yoy_pct")))]
stopifnot(nrow(forecast) == 64L, !anyNA(forecast$tfr), !anyNA(forecast$tfr_yoy_pct))

# Keep 20+ candidate predictors. Transformations replace their source levels in
# model input lists; retained raw lagged columns are for tracing the calculations.
main_predictors <- c(
  paste0(setdiff(core_ids, "A229RX0"), "_lag1"),
  "UMCSENT_lag1", "tfr_lag1", "log_real_disposable_income_pc_lag1"
)
expanded_predictors <- c(
  paste0(setdiff(predictor_ids, c("A229RX0", "CSUSHPINSA",
                                 "LEU0252882700Q", "LEU0252881800Q")), "_lag1"),
  "tfr_lag1", "female_male_earnings_ratio_lag1",
  "log_real_disposable_income_pc_lag1", "log_real_house_price_index_lag1"
)
features <- setdiff(names(forecast), c("year", "predictor_year", "period", "tfr", "tfr_yoy_pct"))
dictionary <- data.frame(
  feature = features,
  use_main = features %in% main_predictors,
  use_expanded = features %in% expanded_predictors,
  description = c(paste0(metadata$title[match(predictor_ids, metadata$series_id)], " in t-1"),
                  "TFR in t-1",
                  "Women's / men's median weekly nominal earnings in t-1; full-time workers",
                  "Log real disposable income per capita in t-1 (chained 2017 dollars)",
                  "Log of house-price index divided by CPI/100 in t-1; index scale is arbitrary")
)
forecast$eligible_main <- complete.cases(forecast[c("tfr", "tfr_yoy_pct", main_predictors)])
forecast$eligible_expanded <- complete.cases(forecast[c("tfr", "tfr_yoy_pct", expanded_predictors)])
stopifnot(length(main_predictors) == 27L, length(expanded_predictors) == 33L,
          all(forecast$eligible_main),
          !any(c("tfr", "tfr_yoy_pct", "year", "period") %in% dictionary$feature))

# Do not impute missing early years, clip shocks, or standardize using the full sample.
# Model-specific scaling will be fitted on training data in the modelling script.
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
write.csv(forecast, "data/forecast_data.csv", row.names = FALSE, na = "NA")
write.csv(dictionary, "data/predictor_dictionary.csv", row.names = FALSE)
sample_counts <- do.call(rbind, lapply(c("train", "trial", "test"), function(period) {
  x <- forecast[forecast$period == period, ]
  data.frame(period = period, first_outcome_year = min(x$year), last_outcome_year = max(x$year),
             main_n = sum(x$eligible_main), expanded_n = sum(x$eligible_expanded))
}))
write.csv(sample_counts, "outputs/tables/sample_counts.csv", row.names = FALSE)

# Explore the sentiment hypothesis using TRAINING outcomes only.
# UMCSENT mixes current conditions with expectations; it is not a fertility-intentions survey.
training <- forecast[forecast$period == "train", ]
summarise_sentiment <- function(x, label) {
  data.frame(sample = label, n = nrow(x),
             first_outcome_year = min(x$year), last_outcome_year = max(x$year),
             correlation_tfr_level = cor(x$UMCSENT_lag1, x$tfr),
             correlation_tfr_yoy_pct = cor(x$UMCSENT_lag1, x$tfr_yoy_pct))
}
sentiment_results <- rbind(
  summarise_sentiment(training, "All training years"),
  summarise_sentiment(training[training$predictor_year >= 1978, ],
                      "Regular-monthly survey coverage")
)
write.csv(sentiment_results, "outputs/tables/sentiment_training_correlations.csv", row.names = FALSE)

plot_sentiment <- function(x) {
  png("outputs/figures/sentiment_training.png", width = 1600, height = 700, res = 140)
  on.exit(dev.off())
  par(mfrow = c(1, 2), mar = c(5, 4, 4, 1))
  plot(x$UMCSENT_lag1, x$tfr, pch = 19, col = "#245678",
       xlab = "Consumer sentiment in t-1", ylab = "TFR in t (births per woman)",
       main = "TFR level: training 1961-2004")
  plot(x$UMCSENT_lag1, x$tfr_yoy_pct, pch = 19, col = "#245678",
       xlab = "Consumer sentiment in t-1", ylab = "TFR annual change (%)",
       main = "TFR change: training 1961-2004")
  abline(h = 0, lty = 2, col = "grey60")
}
plot_sentiment(training)
print(sample_counts, row.names = FALSE)
print(sentiment_results, row.names = FALSE)
message("Prepared 64 forecast pairs. Use predictor_dictionary.csv to select model inputs.")
message("No forecast model or test-set score has been calculated.")
