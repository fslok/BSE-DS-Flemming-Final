# BSE Intro to Data Science final project - Flemming Slok
# One-year-ahead US fertility forecasts with annual expanding-window refits.
# Does adding 26 macro indicators improve on forecasts using last year's TFR?
# Run this entire file from any folder. The assembled CSV is the only input.
# Results, diagnostics and figures are saved in BSE_TFR_results.

############################ GET THE CSV ######################################
# Fixed data snapshot from the project repository, downloaded 11 November 2026.
# These are revised annual observations. Historical release dates differ by series.
data_url <- "https://raw.githubusercontent.com/fslok/BSE-DS-Flemming-Final/034567e5ec7d7fc7c7596d96cabd3fa3007932e7/data/us_fertility_annual.csv"
annual <- read.csv(data_url)

# Choose a writable results folder automatically.
output_dir <- file.path(getwd(), "BSE_TFR_results")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(output_dir) || file.access(output_dir, 2) != 0) {
  output_dir <- file.path(tempdir(), "BSE_TFR_results")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}
message("Results folder: ", normalizePath(output_dir, winslash = "/"))

# Install missing packages in a writable library with a specified CRAN mirror.
packages <- c("glmnet", "rpart", "randomForest")
missing_pkgs <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  lib <- Sys.getenv("R_LIBS_USER")
  if (!nzchar(lib)) lib <- file.path(tempdir(), "BSE_R_packages")
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  if (file.access(lib, 2) != 0) {
    lib <- file.path(tempdir(), "BSE_R_packages")
    dir.create(lib, showWarnings = FALSE)
  }
  .libPaths(c(lib, .libPaths()))
  install.packages(missing_pkgs, lib = lib, repos = "https://cloud.r-project.org")
}
stopifnot(all(vapply(packages, requireNamespace, logical(1), quietly = TRUE)))

########################### 1. CLEANING #######################################
annual <- annual[order(annual$year), ]
stopifnot(identical(annual$year, 1960:2024), !anyDuplicated(annual$year),
          ncol(annual) == 35, all(vapply(annual, is.numeric, logical(1))))
na_share <- colMeans(is.na(annual))
missingness <- data.frame(variable = names(na_share), missing_share = na_share)
write.csv(missingness, file.path(output_dir, "missingness.csv"), row.names = FALSE)
print(missingness[missingness$missing_share > 0, ], row.names = FALSE)

# Twenty-six macro series have complete coverage. Keep observed shock years.
# CPI variables enter as price indices; the optional shorter series remain in the
# input CSV. The following list specifies the long-history analysis.
# UMCSENT combines current conditions and expectations. Its annual averages use
# four surveys per year before 1978 and twelve per year from 1978.
########################### 2. FEATURE ENGINEERING ############################
# Each row pairs the outcome in year t with observed predictors from t-1.
# The pinned CSV contains revised annual observations.
macro <- c("A939RX0Q048SBEA", "A229RX0", "PCECC96", "PSAVERT", "INDPRO", "CUMFNS",
           "UNRATE", "PAYEMS", "CIVPART", "LNS11300002", "LRAC25FEUSA156N", "LNS14000002",
           "LNS12300002", "LNS14000036", "UEMPMEAN", "AWHMAN", "CPIAUCSL", "CPILFESL",
           "CUUR0000SEHA", "FEDFUNDS", "GS10", "TB3MS", "BAA", "HOUST", "PERMIT", "UMCSENT")
this_year <- annual[-1, ]
last_year <- annual[-nrow(annual), ]
stopifnot(all(this_year$year == last_year$year + 1L), all(annual$tfr > 0),
          all(last_year$A229RX0 > 0))
d <- data.frame(year = this_year$year, tfr = this_year$tfr, tfr_lag1 = last_year$tfr)
d$tfr_yoy_pct <- 100 * (d$tfr / d$tfr_lag1 - 1)
for (v in setdiff(macro, "A229RX0")) d[[paste0(v, "_lag1")]] <- last_year[[v]]
d$log_income_lag1 <- log(last_year$A229RX0)

full_inputs <- c(paste0(setdiff(macro, "A229RX0"), "_lag1"), "log_income_lag1", "tfr_lag1")
input_sets <- list(TFR_only = "tfr_lag1", TFR_plus_macro = full_inputs)
stopifnot(length(full_inputs) == 27, all(is.finite(as.matrix(d))))
train <- d[d$year <= 2004, ]
trial <- d[d$year >= 2005 & d$year <= 2014, ]
test  <- d[d$year >= 2015, ]
stopifnot(nrow(train) == 44, nrow(trial) == 10, nrow(test) == 10)

write.csv(d, file.path(output_dir, "model_data.csv"), row.names = FALSE)
sample_counts <- data.frame(period = c("train", "trial", "test"),
  first_year = c(1961, 2005, 2015), last_year = c(2004, 2014, 2024),
  observations = c(nrow(train), nrow(trial), nrow(test)))
write.csv(sample_counts, file.path(output_dir, "sample_counts.csv"), row.names = FALSE)
print(sample_counts, row.names = FALSE)

########################### 3. TRAINING DIAGNOSTICS ############################
# Correlations use the actual lagged and transformed predictors.
correlations <- cor(train[, full_inputs])
write.csv(correlations, file.path(output_dir, "training_correlations.csv"))
high <- which(abs(correlations) > 0.95 & upper.tri(correlations), arr.ind = TRUE)
high_correlations <- data.frame(variable_1 = rownames(correlations)[high[, 1]],
  variable_2 = colnames(correlations)[high[, 2]], correlation = correlations[high])
write.csv(high_correlations, file.path(output_dir, "high_correlations.csv"), row.names = FALSE)

# VIF measures how much each input overlaps with the other 26.
design <- model.matrix(reformulate(full_inputs), data = train)
stopifnot(qr(design)$rank == ncol(design))
vif <- rep(NA_real_, length(full_inputs))
for (j in seq_along(full_inputs)) {
  auxiliary <- lm(reformulate(full_inputs[-j], response = full_inputs[j]), data = train)
  vif[j] <- 1 / (1 - summary(auxiliary)$r.squared)
}
vif_table <- data.frame(predictor = full_inputs, VIF = vif)
vif_table <- vif_table[order(vif_table$VIF, decreasing = TRUE), ]
write.csv(vif_table, file.path(output_dir, "training_vif.csv"), row.names = FALSE)
print(head(vif_table), row.names = FALSE)

# Training-only descriptive sentiment regression and survey-frequency check.
sentiment_fit <- lm(tfr ~ UMCSENT_lag1, data = train)
capture.output(summary(sentiment_fit),
               file = file.path(output_dir, "sentiment_training_regression.txt"))
write.csv(data.frame(term = names(coef(sentiment_fit)), coefficient = coef(sentiment_fit)),
          file.path(output_dir, "sentiment_coefficients.csv"), row.names = FALSE)
sentiment_samples <- list(All_training_years = train,
                         Regular_monthly_survey = train[train$year >= 1979, ])
sentiment_results <- data.frame()
for (sample_name in names(sentiment_samples)) {
  x <- sentiment_samples[[sample_name]]
  sentiment_results <- rbind(sentiment_results, data.frame(sample = sample_name, n = nrow(x),
    first_outcome_year = min(x$year), last_outcome_year = max(x$year),
    correlation_tfr_level = cor(x$UMCSENT_lag1, x$tfr),
    correlation_tfr_yoy_pct = cor(x$UMCSENT_lag1, x$tfr_yoy_pct)))
}
write.csv(sentiment_results, file.path(output_dir, "sentiment_training_correlations.csv"),
          row.names = FALSE)

########################### 4. REGRESSIONS ####################################
# Expanding window: use outcomes from 1961 through t-1 to forecast year t.
# The predictor row for t contains only measurements from t-1.
# These are revised-data forecasts, not forecasts using historical data vintages.
as_tfr <- function(prediction, target, lag_tfr) {
  if (target == "tfr_yoy_pct") return(lag_tfr * (1 + prediction / 100))
  as.numeric(prediction)
}
trial_rmse <- function(prediction, target) {
  predicted <- as_tfr(prediction, target, trial$tfr_lag1)
  sqrt(mean((trial$tfr - predicted)^2))
}

settings <- expand.grid(target = c("tfr", "tfr_yoy_pct"), inputs = names(input_sets),
                        stringsAsFactors = FALSE)
settings$minbucket <- settings$mtry <- NA_integer_
settings$lambda <- NA_real_

# Construct each LASSO grid using only the initial training sample.
# Reuse exactly this grid at every origin, with scaling fitted anew each time.
lambda_paths <- list()
for (target in c("tfr", "tfr_yoy_pct")) {
  initial_lasso <- glmnet::glmnet(as.matrix(train[, full_inputs]), train[[target]],
                                 alpha = 1, standardize = TRUE, maxit = 1000000)
  stopifnot(initial_lasso$jerr == 0)
  lambda_paths[[target]] <- initial_lasso$lambda
}

forecast_schedule <- data.frame(
  period = c(rep("trial", nrow(trial)), rep("test", nrow(test))),
  year = c(trial$year, test$year))
forecast_schedule$fit_start <- min(d$year)
forecast_schedule$fit_through <- forecast_schedule$year - 1L
forecast_schedule$n_train <- forecast_schedule$fit_through - min(d$year) + 1L
forecast_schedule$input_year <- forecast_schedule$year - 1L
write.csv(forecast_schedule, file.path(output_dir, "forecast_schedule.csv"), row.names = FALSE)

forecasts <- ar_coefficients <- data.frame()
tuning_results <- trial_candidate_forecasts <- data.frame()
linear_coefficients <- lasso_coefficients <- data.frame()
final_models <- list()
tree_rules <- character()

# Trial selects settings using pooled errors across ten yearly refits.
# Test keeps those settings fixed but also refits before every forecast.
# The test years have already been examined in the earlier project version.
for (period in c("trial", "test")) {
  tuning <- period == "trial"
  upcoming <- if (tuning) trial else test
  forecasts <- rbind(forecasts, data.frame(period, year = upcoming$year, target = "tfr",
    inputs = "TFR_only", model = "Persistence", actual = upcoming$tfr,
    predicted = upcoming$tfr_lag1))

  for (i in seq_len(nrow(settings))) {
    target <- settings$target[i]
    inputs <- settings$inputs[i]
    vars <- input_sets[[inputs]]
    formula <- reformulate(vars, response = target)
    linear_name <- if (inputs == "TFR_only" && target == "tfr") "AR(1)" else "OLS"
    buckets <- if (tuning) c(15L, 10L, 5L) else settings$minbucket[i]
    mtry <- if (inputs == "TFR_only") 1L else c(3L, 9L, 27L)
    if (!tuning) mtry <- settings$mtry[i]
    candidates <- list()
    candidates[[linear_name]] <- matrix(NA_real_, nrow(upcoming), 1)
    if (inputs == "TFR_plus_macro") {
      penalties <- if (tuning) lambda_paths[[target]] else settings$lambda[i]
      candidates$LASSO <- matrix(NA_real_, nrow(upcoming), length(penalties))
    }
    candidates$Tree <- matrix(NA_real_, nrow(upcoming), length(buckets))
    candidates$Random_forest <- matrix(NA_real_, nrow(upcoming), length(mtry))

    for (k in seq_len(nrow(upcoming))) {
      next_year <- upcoming[k, , drop = FALSE]
      year <- next_year$year
      fit_data <- d[d$year < year, ]
      fit_through <- max(fit_data$year)
      stopifnot(fit_through == year - 1L, min(fit_data$year) == 1961L,
                nrow(fit_data) == year - 1961L)
      x <- as.matrix(fit_data[, vars, drop = FALSE])
      new_x <- as.matrix(next_year[, vars, drop = FALSE])

      # OLS with lagged TFR alone and a level target is the fitted AR(1).
      linear_fit <- lm(formula, data = fit_data)
      candidates[[linear_name]][k, 1] <- predict(linear_fit, newdata = next_year)
      linear_coefficients <- rbind(linear_coefficients, data.frame(
        period, year, fit_through, target, inputs, model = linear_name,
        term = names(coef(linear_fit)), coefficient = unname(coef(linear_fit))))
      if (linear_name == "AR(1)") {
        ar_coefficients <- rbind(ar_coefficients, data.frame(period, year, fit_through,
          alpha = unname(coef(linear_fit)[1]), rho = unname(coef(linear_fit)["tfr_lag1"])))
      }
      if (inputs == "TFR_plus_macro" && tuning && k == 1L) {
        capture.output(summary(linear_fit),
          file = file.path(output_dir, paste0("ols_training_", target, ".txt")))
      }
      if (!tuning) final_models[[paste(inputs, target, linear_name, sep = "__")]] <- linear_fit

      if (inputs == "TFR_plus_macro") {
        lasso <- glmnet::glmnet(x, fit_data[[target]], alpha = 1, standardize = TRUE,
                               lambda = lambda_paths[[target]], maxit = 1000000)
        stopifnot(lasso$jerr == 0, length(lasso$lambda) == length(lambda_paths[[target]]))
        candidates$LASSO[k, ] <- as.numeric(predict(lasso, newx = new_x, s = penalties))
        if (!tuning) {
          beta <- as.matrix(coef(lasso, s = settings$lambda[i]))
          lasso_coefficients <- rbind(lasso_coefficients, data.frame(
            period, year, fit_through, target, term = rownames(beta), coefficient = beta[, 1]))
          final_models[[paste(inputs, target, "LASSO", sep = "__")]] <- lasso
        }
      }

      # Shallow tree, with leaf size chosen in the trial period.
      for (j in seq_along(buckets)) {
        tree <- rpart::rpart(formula, data = fit_data, method = "anova",
          control = rpart::rpart.control(maxdepth = 2, minbucket = buckets[j],
                                        minsplit = 2 * buckets[j], cp = 0, xval = 0))
        candidates$Tree[k, j] <- predict(tree, newdata = next_year)
      }
      if (!tuning) {
        final_models[[paste(inputs, target, "Tree", sep = "__")]] <- tree
        if (inputs == "TFR_plus_macro" && target == "tfr_yoy_pct") {
          tree_rules <- c(tree_rules, paste("Forecast year:", year, "- fit through:", fit_through),
                          capture.output(print(tree)), "")
        }
      }

      # Forests use the same reproducible seed for every fitted candidate.
      for (j in seq_along(mtry)) {
        set.seed(2026)
        forest <- randomForest::randomForest(x = x, y = fit_data[[target]],
          ntree = 500, mtry = mtry[j], nodesize = 5)
        candidates$Random_forest[k, j] <- predict(forest, newdata = new_x)
      }
      if (!tuning) final_models[[paste(inputs, target, "Random_forest", sep = "__")]] <- forest
    }

    # Select settings only after collecting all ten trial forecasts per candidate.
    for (model in names(candidates)) {
      best <- 1L
      if (model %in% c("LASSO", "Tree", "Random_forest") && tuning) {
        values <- switch(model, LASSO = penalties, Tree = buckets, Random_forest = mtry)
        parameter <- switch(model, LASSO = "lambda", Tree = "minbucket", Random_forest = "mtry")
        errors <- apply(candidates[[model]], 2, trial_rmse, target = target)
        best <- which.min(errors)
        settings[[parameter]][i] <- values[best]
        tuning_results <- rbind(tuning_results, data.frame(
          inputs, target, model, parameter, value = values, trial_RMSE = errors))
        for (j in seq_along(values)) {
          trial_candidate_forecasts <- rbind(trial_candidate_forecasts, data.frame(
            inputs, target, model, parameter, value = values[j], year = upcoming$year,
            actual = upcoming$tfr,
            predicted = as_tfr(candidates[[model]][, j], target, upcoming$tfr_lag1)))
        }
      }
      forecasts <- rbind(forecasts, data.frame(period, year = upcoming$year, target, inputs, model,
        actual = upcoming$tfr,
        predicted = as_tfr(candidates[[model]][, best], target, upcoming$tfr_lag1), row.names = NULL))
    }
    message(period, ": ", inputs, " / ", target, " - completed ", nrow(upcoming), " yearly refits")
  }

  # Freeze model, target and input-set choice before entering the test loop.
  if (tuning) {
    trial_rows <- forecasts[forecasts$period == "trial", ]
    trial_rows$error <- trial_rows$actual - trial_rows$predicted
    trial_scores <- aggregate(error ~ target + inputs + model, data = trial_rows,
                             FUN = function(e) sqrt(mean(e^2)))
    names(trial_scores)[names(trial_scores) == "error"] <- "RMSE"
    winner <- which.min(trial_scores$RMSE)
    chosen_target <- trial_scores$target[winner]
    chosen_inputs <- trial_scores$inputs[winner]
    chosen_model <- trial_scores$model[winner]
    message("Selected on trial: ", chosen_model, " / ", chosen_target, " / ", chosen_inputs)
  }
}

########################### 5. RESULTS ########################################
forecasts$fit_through <- forecast_schedule$fit_through[match(forecasts$year, forecast_schedule$year)]
forecasts$n_train <- forecast_schedule$n_train[match(forecasts$year, forecast_schedule$year)]
stopifnot(all(forecasts$fit_through == forecasts$year - 1L),
          all(forecasts$n_train == forecasts$year - 1961L))
forecasts$error <- forecasts$actual - forecasts$predicted
stopifnot(all(is.finite(forecasts$error)))
scores <- aggregate(error ~ target + inputs + model + period, data = forecasts,
                    FUN = function(e) sqrt(mean(e^2)))
names(scores)[names(scores) == "error"] <- "RMSE"
comparison <- reshape(scores, idvar = c("target", "inputs", "model"),
                      timevar = "period", direction = "wide")
comparison <- comparison[, c("target", "inputs", "model", "RMSE.trial", "RMSE.test")]
comparison <- comparison[order(comparison$RMSE.trial), ]
print(comparison, row.names = FALSE, digits = 5)
comparison$selected_on_trial <- comparison$target == chosen_target &
  comparison$inputs == chosen_inputs & comparison$model == chosen_model
print(ar_coefficients, row.names = FALSE, digits = 5)

stopifnot(nrow(comparison) == 15, nrow(forecasts) == 300,
          sum(comparison$selected_on_trial) == 1)
write.csv(comparison, file.path(output_dir, "model_comparison.csv"), row.names = FALSE)
write.csv(forecasts, file.path(output_dir, "annual_forecasts.csv"), row.names = FALSE)
write.csv(ar_coefficients, file.path(output_dir, "ar1_coefficients.csv"), row.names = FALSE)
write.csv(settings, file.path(output_dir, "selected_settings.csv"), row.names = FALSE)
write.csv(tuning_results, file.path(output_dir, "tuning_results.csv"), row.names = FALSE)
write.csv(trial_candidate_forecasts, file.path(output_dir, "trial_candidate_forecasts.csv"),
          row.names = FALSE)
write.csv(linear_coefficients, file.path(output_dir, "linear_coefficients.csv"), row.names = FALSE)
write.csv(lasso_coefficients, file.path(output_dir, "lasso_coefficients.csv"), row.names = FALSE)

for (period in c("trial", "test")) {
  period_scores <- scores[scores$period == period, c("target", "inputs", "model", "RMSE")]
  period_scores$selected <- period_scores$target == chosen_target &
    period_scores$inputs == chosen_inputs & period_scores$model == chosen_model
  write.csv(period_scores, file.path(output_dir, paste0(period, "_scores.csv")), row.names = FALSE)
  write.csv(forecasts[forecasts$period == period, ],
            file.path(output_dir, paste0(period, "_predictions.csv")), row.names = FALSE)
}

chosen <- forecasts[forecasts$period == "test" & forecasts$target == chosen_target &
                   forecasts$inputs == chosen_inputs & forecasts$model == chosen_model, ]
write.csv(chosen, file.path(output_dir, "selected_model_test_forecasts.csv"), row.names = FALSE)

# Each year's growth-tree forecast comes from that year's own fitted tree.
writeLines(tree_rules, file.path(output_dir, "tree_rules_tfr_yoy_pct.txt"))
tree_forecasts <- forecasts[forecasts$period == "test" &
  forecasts$inputs == "TFR_plus_macro" & forecasts$target == "tfr_yoy_pct" &
  forecasts$model == "Tree", ]
tree_forecasts <- tree_forecasts[match(test$year, tree_forecasts$year), ]
tree_forecasts$predicted_change_pct <- 100 * (tree_forecasts$predicted / test$tfr_lag1 - 1)
write.csv(tree_forecasts, file.path(output_dir, "tree_test_forecasts.csv"), row.names = FALSE)

# These supplementary summaries describe only the last fit, through 2023,
# used to forecast 2024. The yearly coefficients are saved separately above.
for (target in c("tfr", "tfr_yoy_pct")) {
  last_linear <- linear_coefficients[linear_coefficients$period == "test" &
    linear_coefficients$year == max(test$year) & linear_coefficients$target == target &
    linear_coefficients$inputs == "TFR_plus_macro", ]
  write.csv(last_linear, file.path(output_dir, paste0("ols_coefficients_", target, ".csv")),
            row.names = FALSE)
  forest <- final_models[[paste("TFR_plus_macro", target, "Random_forest", sep = "__")]]
  importance <- randomForest::importance(forest)
  write.csv(data.frame(year = max(test$year), fit_through = max(test$year) - 1L,
    predictor = rownames(importance), importance = importance[, 1]),
    file.path(output_dir, paste0("forest_importance_", target, ".csv")), row.names = FALSE)
}

############################ 6. GRAPHS ########################################
# The figures use the already assembled data and forecasts.
# Save the same plots as PNG for viewing and PDF for Overleaf.
figure_dir <- file.path(output_dir, "figures")
dir.create(figure_dir, showWarnings = FALSE)
open_figure <- function(name, width, height, format) {
  path <- file.path(figure_dir, paste0(name, ".", format))
  if (format == "png") {
    png(path, width = width, height = height, units = "in", res = 200,
        pointsize = 11, bg = "white")
  } else {
    pdf(path, width = width, height = height, pointsize = 11, useDingbats = FALSE)
  }
}

# The fitted descriptive line uses only the 44 training outcomes.
label_pos <- rep(3, nrow(train)) # 1 below, 2 left, 3 above, 4 right
label_pos[train$year %in% c(1972, 1975, 1976, 1978, 1979, 1983,
                           1986, 1993, 1996, 1999, 2002)] <- 1
label_pos[train$year %in% c(1969, 1973, 1977, 1981, 1988, 1998)] <- 2
label_pos[train$year %in% c(1968, 1985, 1987, 1989, 1994, 1997, 2001)] <- 4

# The diagnostic figure uses the candidate chosen during the trial loop.
target_label <- if (chosen_target == "tfr") "TFR level" else "Annual TFR change"
input_label <- if (chosen_inputs == "TFR_only") "TFR only" else "Macro inputs"

for (format in c("png", "pdf")) {
  # Annual TFR, with the same scale and endpoint labels as the original figure.
  open_figure("us_tfr_1960_2024", 8.5, 4.8, format)
  par(mar = c(4.85, 4.5, 2.8, 1), mgp = c(2.5, 0.6, 0), tcl = -0.22,
      family = "sans", col.axis = "grey25", col.lab = "grey15")
  plot(annual$year, annual$tfr, type = "n", axes = FALSE, xaxs = "i", yaxs = "i",
       xlim = c(1959, 2028), ylim = c(1.45, 3.95),
       xlab = "Year", ylab = "Births per woman")
  title("U.S. total fertility rate", adj = 0, line = 0.75)
  ticks <- seq(1.5, 3.5, by = 0.5)
  abline(h = ticks, col = "grey90", lwd = 0.8)
  axis(2, at = ticks, labels = sprintf("%.1f", ticks), las = 1, lwd = 0)
  axis(1, at = c(seq(1960, 2020, by = 10), 2024), gap.axis = 0, col = "grey70")
  lines(annual$year, annual$tfr, col = "#215678", lwd = 2.4)
  ends <- c(1, nrow(annual))
  points(annual$year[ends], annual$tfr[ends], pch = 16, col = "#215678", cex = 0.7)
  text(annual$year[ends], annual$tfr[ends], labels = sprintf("%.2f", annual$tfr[ends]),
       pos = c(3, 4), offset = 0.45, cex = 0.85, col = "#215678")
  mtext("Source: World Bank via FRED (SPDYNTFRTINUSA).", side = 1,
        line = 3.65, adj = 0, cex = 0.70, col = "grey35")
  dev.off()

  open_figure("tfr_training_distribution", 8.3, 5.8, format)
  hist(train$tfr, breaks = 10, col = "lightblue", border = "white",
       main = "TFR distribution: training years 1961-2004",
       xlab = "TFR (births per woman)")
  dev.off()

  # The labelled scatter and path have identical axes.
  for (chart in c("scatter", "path")) {
    open_figure(paste0("umcsent_tfr_", chart), 12, 8.7, format)
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

  # The training scatter for levels and changes from the feature script.
  open_figure("sentiment_training", 11.4, 5, format)
  par(mfrow = c(1, 2), mar = c(5, 4, 4, 1))
  plot(train$UMCSENT_lag1, train$tfr, pch = 19, col = "#245678",
       xlab = "Consumer sentiment in t-1", ylab = "TFR in t (births per woman)",
       main = "TFR level: training 1961-2004")
  plot(train$UMCSENT_lag1, train$tfr_yoy_pct, pch = 19, col = "#245678",
       xlab = "Consumer sentiment in t-1", ylab = "TFR annual change (%)",
       main = "TFR change: training 1961-2004")
  abline(h = 0, lty = 2, col = "grey60")
  dev.off()

  open_figure("selected_model_test", 13.8, 5, format)
  par(mfrow = c(1, 3), mar = c(5, 4, 4, 1))
  plot(chosen$year, chosen$actual, type = "o", pch = 20,
       ylim = range(chosen$actual, chosen$predicted),
       xlab = "TFR outcome year", ylab = "Births per woman",
       main = paste("Trial-selected", chosen_model, "\n", target_label, "-", input_label))
  lines(chosen$year, chosen$predicted, type = "o", pch = 20, col = "firebrick")
  abline(v = 2020, lty = 3, col = "grey55")
  legend("topright", c("Actual", "Forecast", "2020"),
         col = c("black", "firebrick", "grey55"), lty = c(1, 1, 3), bty = "n", cex = 0.8)
  plot(chosen$actual, chosen$predicted, pch = 20, col = "darkblue",
       xlim = range(chosen$actual, chosen$predicted),
       ylim = range(chosen$actual, chosen$predicted),
       xlab = "Actual TFR", ylab = "Predicted TFR", main = "Predicted versus actual")
  abline(0, 1, lty = 2)
  plot(chosen$year, chosen$error, type = "o", pch = 20, col = "darkblue",
       xlab = "TFR outcome year", ylab = "Actual minus forecast",
       main = "Expanding-window forecast errors")
  abline(h = 0, lty = 2)
  dev.off()

  # Importance describes the final annual refit, not every test forecast.
  open_figure("forest_importance", 13.8, 5.5, format)
  par(mfrow = c(1, 2), mar = c(5, 12, 4, 1))
  for (target in c("tfr", "tfr_yoy_pct")) {
    key <- paste("TFR_plus_macro", target, "Random_forest", sep = "__")
    importance <- randomForest::importance(final_models[[key]])[, 1]
    importance <- sort(importance, decreasing = TRUE)[1:10]
    importance <- rev(importance)
    names(importance) <- sub("_lag1$", "", names(importance))
    barplot(importance, horiz = TRUE, las = 1, col = "#215678", border = NA,
            cex.names = 0.85, main = paste("Macro forest:", target, "\nFit through 2023; forecast 2024"),
            xlab = "Mean decrease in residual sum of squares")
  }
  dev.off()

  # A fixed supplementary comparison shows how forecasts follow annual movements.
  # Carry-forward, fitted AR(1), and the macro change tree all use observed lags.
  benchmark <- forecasts[forecasts$period == "test" &
                           forecasts$model == "Persistence", ]
  autoregression <- forecasts[forecasts$period == "test" &
                                forecasts$model == "AR(1)", ]
  macro_tree <- forecasts[forecasts$period == "test" &
                           forecasts$inputs == "TFR_plus_macro" &
                           forecasts$target == "tfr_yoy_pct" &
                           forecasts$model == "Tree", ]
  benchmark <- benchmark[match(test$year, benchmark$year), ]
  autoregression <- autoregression[match(test$year, autoregression$year), ]
  macro_tree <- macro_tree[match(test$year, macro_tree$year), ]
  compared <- cbind(Actual = test$tfr, Carry_forward = benchmark$predicted,
                   AR1 = autoregression$predicted, Macro_change_tree = macro_tree$predicted)
  changes <- 100 * (compared / test$tfr_lag1 - 1)
  colors <- c("black", "grey55", "#C2761C", "#215678")
  open_figure("benchmark_comparison", 12, 5.2, format)
  par(mfrow = c(1, 2), mar = c(5, 4, 3, 1))
  matplot(test$year, compared, type = "l", lty = c(1, 2, 3, 1),
          lwd = c(2, 1.5, 1.5, 2), col = colors,
          xlab = "TFR outcome year", ylab = "Births per woman",
          main = "Expanding-window test forecasts")
  legend("topright", c("Actual", "Carry-forward", "AR(1)", "Macro change tree"),
         col = colors, lty = c(1, 2, 3, 1), lwd = c(2, 1.5, 1.5, 2),
         bty = "n", cex = 0.85)
  matplot(test$year, changes, type = "l", lty = c(1, 2, 3, 1),
          lwd = c(2, 1.5, 1.5, 2), col = colors,
          xlab = "TFR outcome year", ylab = "Annual TFR change (%)",
          main = "Actual and forecast annual changes")
  abline(h = 0, lty = 3, col = "grey70")
  dev.off()
}

capture.output(sessionInfo(), file = file.path(output_dir, "sessionInfo.txt"))
message("Finished: 15 expanding-window forecast specifications and 8 figures in PNG and PDF.")
message("Tables and estimates: ", normalizePath(output_dir, winslash = "/"))
message("Figures: ", normalizePath(figure_dir, winslash = "/"))
