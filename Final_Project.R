########################### GET THE CSV ########################################
# BSE Intro to Data Science: one-year-ahead US fertility forecasting.
# Run this whole file from any folder. No setwd(), API key or local inputs needed.
# This follows the datathon's read.csv(GitHub URL) approach.
rm(list = ls())
data <- read.csv("https://raw.githubusercontent.com/fslok/BSE-DS-Flemming-Final/034567e5ec7d7fc7c7596d96cabd3fa3007932e7/data/us_fertility_annual.csv")

# The URL fixes the data snapshot, so later repository edits cannot change results.
# FRED annual averages, downloaded 11 November 2026. One row = one calendar year.
# Target: TFR (births per woman). Source data: 1960-2024, 33 candidate macro series.
# These are revised histories, so this is retrospective forecasting, not real time.

# Save outputs automatically; no working-directory change is required.
output_dir <- file.path(getwd(), "BSE_TFR_results")
dir.create(output_dir, showWarnings = FALSE)
if (!dir.exists(output_dir) || file.access(output_dir, 2) != 0) {
  output_dir <- file.path(tempdir(), "BSE_TFR_results")
  dir.create(output_dir, showWarnings = FALSE)
}
message("Results folder: ", normalizePath(output_dir, winslash = "/"))

########################### 1. CLEANING ########################################
# Inspect missingness before selecting variables. Missing early years in optional
# series are left missing; we do not interpolate, impute or replace them with zero.
print(dim(data))
print(head(data[, c("year", "tfr", "UMCSENT", "UNRATE", "A229RX0")]))
na_share <- colMeans(is.na(data))
print(na_share[na_share > 0])
write.csv(data.frame(variable = names(na_share), missing_share = na_share),
          file.path(output_dir, "missingness.csv"), row.names = FALSE)

data <- data[order(data$year), ]
stopifnot(identical(data$year, 1960:2024), !anyDuplicated(data$year),
          all(vapply(data, is.numeric, logical(1))))

# Main analysis: the 26 macro series with complete long histories.
# Activity/income: GDP per capita, disposable income per capita, consumption,
# saving, industrial production and manufacturing capacity utilisation.
# Labour: unemployment, payrolls, participation (including women), employment,
# unemployment duration and weekly manufacturing hours.
# Prices/rates/housing: three CPIs, four interest rates, starts and permits.
macro_vars <- c("A939RX0Q048SBEA", "A229RX0", "PCECC96", "PSAVERT", "INDPRO", "CUMFNS",
                "UNRATE", "PAYEMS", "CIVPART", "LNS11300002", "LRAC25FEUSA156N",
                "LNS14000002", "LNS12300002", "LNS14000036", "UEMPMEAN", "AWHMAN",
                "CPIAUCSL", "CPILFESL", "CUUR0000SEHA", "FEDFUNDS", "GS10", "TB3MS",
                "BAA", "HOUST", "PERMIT", "UMCSENT")
stopifnot(all(is.finite(as.matrix(data[, c("tfr", macro_vars)]))),
          all(data$tfr > 0), all(data$A229RX0 > 0))

# Keep real shock observations. CPI values remain PRICE INDICES, not inflation.
# Converting them to lagged inflation while keeping the first 1961 forecast would
# require 1959 prices. That extension is not part of this fixed-data draft.
# UMCSENT uses four surveys per year before 1978 and twelve from 1978 onward.
# It combines current conditions and expectations, not fertility intentions.

# Feature engineering: align predictors in t-1 with TFR in outcome year t.
previous <- match(data$year - 1, data$year)
forecast <- data.frame(year = data$year, tfr = data$tfr,
                      tfr_lag1 = data$tfr[previous],
                      tfr_yoy_pct = 100 * (data$tfr / data$tfr[previous] - 1))
for (v in macro_vars) forecast[[paste0(v, "_lag1")]] <- data[[v]][previous]
forecast$log_income_lag1 <- log(forecast$A229RX0_lag1)

# Replace income's level with its log. Keep 27 predictors including previous TFR.
# Explicit names keep year and BOTH outcome columns out of the input matrix.
predictors <- c(paste0(setdiff(macro_vars, "A229RX0"), "_lag1"),
                "log_income_lag1", "tfr_lag1")
forecast <- forecast[forecast$year >= 1961, ]
stopifnot(length(predictors) == 27,
          all(is.finite(as.matrix(forecast[, c("tfr", "tfr_yoy_pct", predictors)]))))

# Split by outcome year, in order. No random splitting of a time series.
train <- forecast[forecast$year <= 2004, ]
trial <- forecast[forecast$year >= 2005 & forecast$year <= 2014, ]
test <- forecast[forecast$year >= 2015 & forecast$year <= 2024, ]
stopifnot(nrow(train) == 44, nrow(trial) == 10, nrow(test) == 10)
print(c(training = nrow(train), trial = nrow(trial), test = nrow(test)))
write.csv(forecast, file.path(output_dir, "model_data.csv"), row.names = FALSE)

########################### 2. GRAPHING ########################################
# Explore TRAINING observations only. Every point is labelled with TFR year t.
# Sentiment is already lagged, so the path cannot identify causal direction.
sentiment_fit <- lm(tfr ~ UMCSENT_lag1, data = train)
label_pos <- rep(3, nrow(train)) # 1 below, 2 left, 3 above, 4 right
label_pos[train$year %in% c(1972, 1975, 1976, 1978, 1979, 1983,
                           1986, 1993, 1996, 1999, 2002)] <- 1
label_pos[train$year %in% c(1969, 1973, 1977, 1981, 1988, 1998)] <- 2
label_pos[train$year %in% c(1968, 1985, 1987, 1989, 1994, 1997, 2001)] <- 4

for (chart in c("scatter", "path")) {
  png(file.path(output_dir, paste0("umcsent_tfr_", chart, ".png")),
      width = 1800, height = 1300, res = 130)
  plot(train$UMCSENT_lag1, train$tfr, type = "n",
       xlim = c(60, 113), ylim = c(1.5, 3.8),
       xlab = "Consumer sentiment in t-1 (index)",
       ylab = "TFR in t (births per woman)",
       main = "Consumer sentiment and next-year fertility",
       sub = "Training sample: labels identify the TFR outcome year (1961-2004)")
  grid()
  if (chart == "scatter") {
    abline(sentiment_fit, col = "firebrick", lwd = 2)
    legend("topright", "OLS best-fit line (descriptive)",
           col = "firebrick", lty = 1, lwd = 2, bty = "n")
  }
  if (chart == "path") {
    arrows(head(train$UMCSENT_lag1, -1), head(train$tfr, -1),
           tail(train$UMCSENT_lag1, -1), tail(train$tfr, -1),
           length = 0.06, angle = 20, col = "grey55", lwd = 1)
    legend("topright", "Arrows connect consecutive years",
           col = "grey55", lty = 1, bty = "n")
  }
  points(train$UMCSENT_lag1, train$tfr, col = "darkblue", pch = 20)
  text(train$UMCSENT_lag1, train$tfr, labels = train$year,
       pos = label_pos, offset = 0.6, cex = 0.7, col = "darkblue")
  dev.off()
}

png(file.path(output_dir, "tfr_training_distribution.png"),
    width = 1000, height = 700, res = 120)
hist(train$tfr, breaks = 10, col = "lightblue", border = "white",
     main = "TFR distribution: training years 1961-2004",
     xlab = "TFR (births per woman)")
dev.off()

########################### REGRESSION SETUP ###################################
# Install missing packages automatically, with a specified CRAN mirror.
# A writable user library avoids requiring administrator rights.
packages <- c("glmnet", "rpart", "randomForest")
missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  package_dir <- Sys.getenv("R_LIBS_USER")
  if (package_dir == "") package_dir <- file.path(tempdir(), "BSE_R_packages")
  dir.create(package_dir, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(package_dir, .libPaths()))
  install.packages(missing_packages, lib = package_dir, repos = "https://cloud.r-project.org")
}
stopifnot(all(vapply(packages, requireNamespace, logical(1), quietly = TRUE)))

# Collinearity: examine the ACTUAL training predictors, including transformations.
# Correlation is comparable across units; raw covariance is not.
correlations <- cor(train[, predictors])
write.csv(correlations, file.path(output_dir, "training_correlations.csv"))
high <- which(abs(correlations) > 0.95 & upper.tri(correlations), arr.ind = TRUE)
high_correlations <- data.frame(variable_1 = rownames(correlations)[high[, 1]],
                                variable_2 = colnames(correlations)[high[, 2]],
                                correlation = correlations[high])
print(high_correlations, row.names = FALSE)
write.csv(high_correlations, file.path(output_dir, "high_correlations.csv"), row.names = FALSE)

# Check that OLS can estimate all coefficients. VIF = 1/(1-R-squared) from
# regressing each predictor on all the others; large values flag overlap.
design <- model.matrix(reformulate(predictors), data = train)
stopifnot(qr(design)$rank == ncol(design))
vif <- rep(NA_real_, length(predictors))
for (j in seq_along(predictors)) {
  auxiliary <- lm(reformulate(predictors[-j], response = predictors[j]), data = train)
  vif[j] <- 1 / (1 - summary(auxiliary)$r.squared)
}
vif_table <- data.frame(predictor = predictors, VIF = vif)
vif_table <- vif_table[order(vif_table$VIF, decreasing = TRUE), ]
print(vif_table, row.names = FALSE)
write.csv(vif_table, file.path(output_dir, "training_vif.csv"), row.names = FALSE)
# Keep the pre-specified predictor list; these checks do not select variables.

########################### 3. REGRESSION ######################################
# Fit on 1961-2004; choose settings on 2005-2014; evaluate once on 2015-2024.
# All methods use the same 27 predictors. OLS may be unstable with this many
# correlated predictors and only 44 training years; see the diagnostics above.
# We try TFR levels and annual percentage changes. Convert change forecasts back
# to TFR before scoring, so every RMSE is measured in births per woman.

targets <- c("tfr", "tfr_yoy_pct")
methods <- c("OLS", "LASSO", "Tree", "Random_forest")
X_train <- as.matrix(train[, predictors])
X_trial <- as.matrix(trial[, predictors])

# No-change benchmark: next year's TFR equals the last observed TFR.
trial_predictions <- data.frame(year = trial$year, target = "benchmark",
                                model = "Previous_TFR", actual = trial$tfr,
                                predicted = trial$tfr_lag1)
trial_scores <- data.frame(target = "benchmark", model = "Previous_TFR",
                          RMSE = sqrt(mean((trial$tfr - trial$tfr_lag1)^2)))
settings <- data.frame(target = targets, lambda = NA_real_,
                       minbucket = NA_integer_, mtry = NA_integer_)
tuning_results <- data.frame()
ols_training <- tree_training <- lambda_paths <- list()

for (a in seq_along(targets)) {
  target <- targets[a]
  # Explicit predictor names prevent the other target or year entering the model.
  formula <- reformulate(predictors, response = target)
  y_train <- train[[target]]
  predictions <- matrix(NA_real_, nrow = nrow(trial), ncol = length(methods),
                         dimnames = list(NULL, methods))

  # OLS: estimate all coefficients using training observations only.
  ols_fit <- lm(formula, data = train)
  ols_training[[target]] <- ols_fit
  predictions[, "OLS"] <- predict(ols_fit, newdata = trial)

  # LASSO: glmnet learns standardisation from the training data internally.
  # Choose lambda on the chronological trial period, not random cross-validation.
  lasso_fit <- glmnet::glmnet(X_train, y_train, alpha = 1, standardize = TRUE)
  lambda_paths[[target]] <- lasso_fit$lambda
  lasso_pred <- predict(lasso_fit, newx = X_trial)
  lasso_rmse <- rep(NA_real_, length(lasso_fit$lambda))
  for (j in seq_along(lasso_fit$lambda)) {
    p <- lasso_pred[, j]
    if (target == "tfr_yoy_pct") p <- trial$tfr_lag1 * (1 + p / 100)
    lasso_rmse[j] <- sqrt(mean((trial$tfr - p)^2))
  }
  j_best <- which.min(lasso_rmse)
  settings$lambda[a] <- lasso_fit$lambda[j_best]
  predictions[, "LASSO"] <- lasso_pred[, j_best]
  tuning_results <- rbind(tuning_results, data.frame(
    target = target, model = "LASSO", parameter = "lambda",
    value = lasso_fit$lambda, trial_RMSE = lasso_rmse))

  # Small tree: at most two successive splits; tune minimum years per leaf.
  buckets <- c(5, 10, 15)
  tree_rmse <- rep(NA_real_, length(buckets))
  tree_pred <- matrix(NA_real_, nrow(trial), length(buckets))
  for (j in seq_along(buckets)) {
    tree_fit <- rpart::rpart(formula, data = train, method = "anova",
      control = rpart::rpart.control(maxdepth = 2, minbucket = buckets[j],
                                    minsplit = 2 * buckets[j], cp = 0, xval = 0))
    tree_pred[, j] <- predict(tree_fit, newdata = trial)
    p <- tree_pred[, j]
    if (target == "tfr_yoy_pct") p <- trial$tfr_lag1 * (1 + p / 100)
    tree_rmse[j] <- sqrt(mean((trial$tfr - p)^2))
  }
  # If scores tie, prefer the larger minimum leaf size.
  j_best <- max(which(tree_rmse == min(tree_rmse)))
  settings$minbucket[a] <- buckets[j_best]
  predictions[, "Tree"] <- tree_pred[, j_best]
  tree_training[[target]] <- rpart::rpart(formula, data = train, method = "anova",
    control = rpart::rpart.control(maxdepth = 2, minbucket = buckets[j_best],
                                  minsplit = 2 * buckets[j_best], cp = 0, xval = 0))
  tuning_results <- rbind(tuning_results, data.frame(
    target = target, model = "Tree", parameter = "minbucket",
    value = buckets, trial_RMSE = tree_rmse))

  # Random forest: average 500 trees; tune predictors considered at each split.
  # Out-of-bag scores are not used to choose settings for this forecasting task.
  mtry_values <- c(3, 9, 27)
  forest_rmse <- rep(NA_real_, length(mtry_values))
  forest_pred <- matrix(NA_real_, nrow(trial), length(mtry_values))
  for (j in seq_along(mtry_values)) {
    set.seed(2026)
    forest_fit <- randomForest::randomForest(x = X_train, y = y_train,
      ntree = 500, mtry = mtry_values[j], nodesize = 5)
    forest_pred[, j] <- predict(forest_fit, newdata = X_trial)
    p <- forest_pred[, j]
    if (target == "tfr_yoy_pct") p <- trial$tfr_lag1 * (1 + p / 100)
    forest_rmse[j] <- sqrt(mean((trial$tfr - p)^2))
  }
  j_best <- which.min(forest_rmse)
  settings$mtry[a] <- mtry_values[j_best]
  predictions[, "Random_forest"] <- forest_pred[, j_best]
  tuning_results <- rbind(tuning_results, data.frame(
    target = target, model = "Random_forest", parameter = "mtry",
    value = mtry_values, trial_RMSE = forest_rmse))

  for (method in methods) {
    p <- predictions[, method]
    if (target == "tfr_yoy_pct") p <- trial$tfr_lag1 * (1 + p / 100)
    trial_predictions <- rbind(trial_predictions, data.frame(
      year = trial$year, target = target, model = method,
      actual = trial$tfr, predicted = p))
    trial_scores <- rbind(trial_scores, data.frame(
      target = target, model = method, RMSE = sqrt(mean((trial$tfr - p)^2))))
  }
}

# Freeze the winning method AND target transformation before using test outcomes.
# Exact ties retain the first candidate (the benchmark is listed first).
winner <- which.min(trial_scores$RMSE)
chosen_target <- trial_scores$target[winner]
chosen_model <- trial_scores$model[winner]
trial_scores$selected <- seq_len(nrow(trial_scores)) == winner
write.csv(trial_scores, file.path(output_dir, "trial_scores.csv"), row.names = FALSE)
write.csv(trial_predictions, file.path(output_dir, "trial_predictions.csv"), row.names = FALSE)
write.csv(settings, file.path(output_dir, "selected_settings.csv"), row.names = FALSE)
write.csv(tuning_results, file.path(output_dir, "tuning_results.csv"), row.names = FALSE)
print(trial_scores, row.names = FALSE)
message("Selected on trial data: ", chosen_model, " / ", chosen_target)

########################### FINAL TEST ########################################
# Refit frozen specifications on training + trial years. Do not change settings
# or choose a different winner after inspecting the final test scores.
# These are successive one-year forecasts using observed t-1 predictors, including
# observed previous TFR. Coefficients stay fixed throughout each evaluation period.

train_trial <- rbind(train, trial)
X_train_trial <- as.matrix(train_trial[, predictors])
X_test <- as.matrix(test[, predictors])
test_predictions <- data.frame(year = test$year, target = "benchmark",
                               model = "Previous_TFR", actual = test$tfr,
                               predicted = test$tfr_lag1)
test_scores <- data.frame(target = "benchmark", model = "Previous_TFR",
                         RMSE = sqrt(mean((test$tfr - test$tfr_lag1)^2)))
final_models <- list()
lasso_coefficients <- data.frame()

for (a in seq_along(targets)) {
  target <- targets[a]
  formula <- reformulate(predictors, response = target)
  y_train_trial <- train_trial[[target]]
  predictions <- matrix(NA_real_, nrow = nrow(test), ncol = length(methods),
                         dimnames = list(NULL, methods))

  ols_fit <- lm(formula, data = train_trial)
  predictions[, "OLS"] <- predict(ols_fit, newdata = test)
  final_models[[paste(target, "OLS", sep = "_")]] <- ols_fit

  # Refit standardisation on train + trial. Reuse the lambda path for warm starts,
  # then predict at the previously selected lambda; no new tuning takes place.
  lasso_fit <- glmnet::glmnet(X_train_trial, y_train_trial, alpha = 1,
                            lambda = lambda_paths[[target]], standardize = TRUE)
  predictions[, "LASSO"] <- as.numeric(predict(lasso_fit, newx = X_test,
                                               s = settings$lambda[a]))
  final_models[[paste(target, "LASSO", sep = "_")]] <- lasso_fit
  beta <- as.matrix(coef(lasso_fit, s = settings$lambda[a]))
  lasso_coefficients <- rbind(lasso_coefficients, data.frame(
    target = target, term = rownames(beta), coefficient = beta[, 1]))

  tree_fit <- rpart::rpart(formula, data = train_trial, method = "anova",
    control = rpart::rpart.control(maxdepth = 2, minbucket = settings$minbucket[a],
      minsplit = 2 * settings$minbucket[a], cp = 0, xval = 0))
  predictions[, "Tree"] <- predict(tree_fit, newdata = test)
  final_models[[paste(target, "Tree", sep = "_")]] <- tree_fit

  set.seed(2026)
  forest_fit <- randomForest::randomForest(x = X_train_trial, y = y_train_trial,
    ntree = 500, mtry = settings$mtry[a], nodesize = 5)
  predictions[, "Random_forest"] <- predict(forest_fit, newdata = X_test)
  final_models[[paste(target, "Random_forest", sep = "_")]] <- forest_fit
  # Split-based importance is descriptive; correlated inputs can share importance.
  forest_importance <- randomForest::importance(forest_fit)
  write.csv(data.frame(predictor = rownames(forest_importance),
                       importance = forest_importance[, 1]),
            file.path(output_dir, paste0("forest_importance_", target, ".csv")), row.names = FALSE)

  for (method in methods) {
    p <- predictions[, method]
    if (target == "tfr_yoy_pct") p <- test$tfr_lag1 * (1 + p / 100)
    test_predictions <- rbind(test_predictions, data.frame(
      year = test$year, target = target, model = method,
      actual = test$tfr, predicted = p))
    test_scores <- rbind(test_scores, data.frame(
      target = target, model = method, RMSE = sqrt(mean((test$tfr - p)^2))))
  }
}

test_scores$selected <- test_scores$target == chosen_target &
                        test_scores$model == chosen_model
write.csv(test_scores, file.path(output_dir, "test_scores.csv"), row.names = FALSE)
write.csv(test_predictions, file.path(output_dir, "test_predictions.csv"), row.names = FALSE)
write.csv(lasso_coefficients, file.path(output_dir, "lasso_coefficients.csv"), row.names = FALSE)
print(test_scores, row.names = FALSE)

# Save coefficients and summaries for interpretation. They are predictive
# associations, not evidence that changing a variable causes fertility to change.
for (target in targets) {
  capture.output(summary(ols_training[[target]]),
                 file = file.path(output_dir, paste0("ols_training_", target, ".txt")))
  final_ols <- final_models[[paste(target, "OLS", sep = "_")]]
  write.csv(data.frame(term = names(coef(final_ols)), coefficient = coef(final_ols)),
            file.path(output_dir, paste0("ols_coefficients_", target, ".csv")), row.names = FALSE)
}

# Plot the TRIAL-selected candidate; do not switch to a test-period winner.
chosen <- test_predictions[test_predictions$target == chosen_target &
                            test_predictions$model == chosen_model, ]
chosen$error <- chosen$actual - chosen$predicted
write.csv(chosen, file.path(output_dir, "selected_model_test_forecasts.csv"), row.names = FALSE)

png(file.path(output_dir, "selected_model_test.png"), width = 1800, height = 650, res = 130)
par(mfrow = c(1, 3), mar = c(5, 4, 4, 1))
plot(chosen$year, chosen$actual, type = "o", pch = 20,
     ylim = range(chosen$actual, chosen$predicted),
     xlab = "TFR outcome year", ylab = "Births per woman",
     main = paste("Final test:", chosen_model, "\nTarget:", chosen_target))
lines(chosen$year, chosen$predicted, type = "o", pch = 20, col = "firebrick")
abline(v = 2020, lty = 3, col = "grey55") # COVID marker, not a forecast input
legend("topright", c("Actual", "Forecast", "2020"),
       col = c("black", "firebrick", "grey55"), lty = c(1, 1, 3), bty = "n", cex = 0.8)
plot(chosen$actual, chosen$predicted, pch = 20, col = "darkblue",
     xlim = range(chosen$actual, chosen$predicted), ylim = range(chosen$actual, chosen$predicted),
     xlab = "Actual TFR", ylab = "Predicted TFR", main = "Predicted versus actual")
abline(0, 1, lty = 2)
plot(chosen$year, chosen$error, type = "o", pch = 20, col = "darkblue",
     xlab = "TFR outcome year", ylab = "Actual minus forecast", main = "Final test forecast errors")
abline(h = 0, lty = 2)
dev.off()

capture.output(sessionInfo(), file = file.path(output_dir, "sessionInfo.txt"))
message("Finished. Selected on trial: ", chosen_model, " / ", chosen_target)
message("Tables, coefficients and graphs: ", normalizePath(output_dir, winslash = "/"))
