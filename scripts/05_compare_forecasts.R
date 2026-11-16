# One-year-ahead US fertility forecasts
# Does adding 26 macro indicators improve on forecasts using last year's TFR?
# Run the whole file from any folder. Results go to BSE_TFR_model_comparison.

############################ 1. GET THE DATA ##################################
data_url <- "https://raw.githubusercontent.com/fslok/BSE-DS-Flemming-Final/034567e5ec7d7fc7c7596d96cabd3fa3007932e7/data/us_fertility_annual.csv"
annual <- read.csv(data_url)
annual <- annual[order(annual$year), ]
stopifnot(identical(annual$year, 1960:2024))

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

########################### 2. ALIGN THE YEARS ################################
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

########################### 3. FIT THE MODELS #################################
# All errors are measured in births per woman. Convert percent-change forecasts
# back to levels using the TFR observed one year before each forecast.
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
lambda_paths <- list()
forecasts <- ar_coefficients <- data.frame()

# Trial: fit on 1961-2004 and select settings using forecasts for 2005-2014.
# Test: refit once through 2014 using those settings, then forecast 2015-2024.
# These test years have already been examined in the original project.
for (period in c("trial", "test")) {
  tuning <- period == "trial"
  fit_data <- if (tuning) train else rbind(train, trial)
  upcoming <- if (tuning) trial else test

  # Persistence forecasts this year's TFR by carrying forward last year's value.
  forecasts <- rbind(forecasts, data.frame(period, year = upcoming$year, target = "tfr",
    inputs = "TFR_only", model = "Persistence", actual = upcoming$tfr, predicted = upcoming$tfr_lag1))

  for (i in seq_len(nrow(settings))) {
    target <- settings$target[i]
    inputs <- settings$inputs[i]
    vars <- input_sets[[inputs]]
    formula <- reformulate(vars, response = target)
    x <- as.matrix(fit_data[, vars, drop = FALSE])
    new_x <- as.matrix(upcoming[, vars, drop = FALSE])
    predictions <- list()

    # In levels, OLS with one lag is the fitted AR(1): TFR[t] = alpha + rho * TFR[t-1] + error[t].
    # For percent change, the same predictor is last year's TFR level.
    if (inputs == "TFR_only" && target == "tfr") {
      linear_fit <- lm(tfr ~ tfr_lag1, data = fit_data)
      linear_name <- "AR(1)"
      ar_coefficients <- rbind(ar_coefficients, data.frame(period, fit_through = max(fit_data$year),
        alpha = unname(coef(linear_fit)[1]), rho = unname(coef(linear_fit)["tfr_lag1"])))
    } else {
      linear_fit <- lm(formula, data = fit_data)
      linear_name <- "OLS"
    }
    predictions[[linear_name]] <- predict(linear_fit, newdata = upcoming)

    # LASSO shrinks coefficients in the full 27-predictor model.
    if (inputs == "TFR_plus_macro") {
      if (tuning) {
        lasso <- glmnet::glmnet(x, fit_data[[target]], alpha = 1, standardize = TRUE)
        lambda_paths[[target]] <- lasso$lambda
        candidates <- predict(lasso, newx = new_x)
        best <- which.min(apply(candidates, 2, trial_rmse, target = target))
        settings$lambda[i] <- lasso$lambda[best]
        predictions$LASSO <- candidates[, best]
      } else {
        lasso <- glmnet::glmnet(x, fit_data[[target]], alpha = 1, standardize = TRUE,
                               lambda = lambda_paths[[target]])
        predictions$LASSO <- predict(lasso, newx = new_x, s = settings$lambda[i])[, 1]
      }
    }

    # Tree with up to two splits along any path. Ties favor larger leaves.
    buckets <- if (tuning) c(15L, 10L, 5L) else settings$minbucket[i]
    candidates <- matrix(NA_real_, nrow(upcoming), length(buckets))
    for (j in seq_along(buckets)) {
      tree <- rpart::rpart(formula, data = fit_data, method = "anova",
        control = rpart::rpart.control(maxdepth = 2, minbucket = buckets[j],
                                      minsplit = 2 * buckets[j], cp = 0, xval = 0))
      candidates[, j] <- predict(tree, newdata = upcoming)
    }
    best <- 1L
    if (tuning) best <- which.min(apply(candidates, 2, trial_rmse, target = target))
    settings$minbucket[i] <- buckets[best]
    predictions$Tree <- candidates[, best]

    # A one-predictor forest must use mtry = 1. The macro forest tries 3, 9, and 27.
    mtry <- if (inputs == "TFR_only") 1L else c(3L, 9L, 27L)
    if (!tuning) mtry <- settings$mtry[i]
    candidates <- matrix(NA_real_, nrow(upcoming), length(mtry))
    for (j in seq_along(mtry)) {
      set.seed(2026)
      forest <- randomForest::randomForest(x = x, y = fit_data[[target]],
        ntree = 500, mtry = mtry[j], nodesize = 5)
      candidates[, j] <- predict(forest, newdata = new_x)
    }
    best <- 1L
    if (tuning) best <- which.min(apply(candidates, 2, trial_rmse, target = target))
    settings$mtry[i] <- mtry[best]
    predictions$Random_forest <- candidates[, best]

    for (model in names(predictions)) {
      forecasts <- rbind(forecasts, data.frame(period, year = upcoming$year, target, inputs, model,
        actual = upcoming$tfr, predicted = as_tfr(predictions[[model]], target, upcoming$tfr_lag1),
        row.names = NULL))
    }
  }
}

########################### 4. COMPARE FORECASTS ###############################
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
comparison$selected_on_trial <- seq_len(nrow(comparison)) == 1L
print(ar_coefficients, row.names = FALSE, digits = 5)

out <- file.path(getwd(), "BSE_TFR_model_comparison")
dir.create(out, showWarnings = FALSE)
if (file.access(out, 2) != 0) {
  out <- file.path(tempdir(), "BSE_TFR_model_comparison")
  dir.create(out, showWarnings = FALSE)
}
write.csv(comparison, file.path(out, "model_comparison.csv"), row.names = FALSE)
write.csv(forecasts, file.path(out, "annual_forecasts.csv"), row.names = FALSE)
write.csv(ar_coefficients, file.path(out, "ar1_coefficients.csv"), row.names = FALSE)
write.csv(settings, file.path(out, "selected_settings.csv"), row.names = FALSE)
message("Results folder: ", normalizePath(out, winslash = "/"))
