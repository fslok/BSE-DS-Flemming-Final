# Run from the repository root: source("scripts/04_graphs.R")
rm(list = ls())

# Read the annual data and match last year's sentiment to this year's TFR.
data <- read.csv("data/us_fertility_annual.csv")
data <- data[order(data$year), ]
data$UMCSENT_lag1 <- data$UMCSENT[match(data$year - 1, data$year)]

# Explore the training period only. Each point is one TFR outcome year.
data_train <- data[data$year >= 1961 & data$year <= 2004, ]
stopifnot(!anyDuplicated(data$year), nrow(data_train) == 44,
          !anyNA(data_train[, c("UMCSENT_lag1", "tfr")]))

# Descriptive best-fit line, using only the training observations.
fit <- lm(tfr ~ UMCSENT_lag1, data = data_train)

# Position year labels around the dots: 1 below, 2 left, 3 above, 4 right.
# These adjustments move only the labels, never the observations.
label_pos <- rep(3, nrow(data_train))
label_pos[data_train$year %in% c(1972, 1975, 1976, 1978, 1979, 1983,
                                1986, 1993, 1996, 1999, 2002)] <- 1
label_pos[data_train$year %in% c(1969, 1973, 1977, 1981, 1988, 1998)] <- 2
label_pos[data_train$year %in% c(1968, 1985, 1987, 1989, 1994, 1997, 2001)] <- 4

dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

# Two charts with identical axes: a fitted scatter and a chronological path.
for (chart in c("scatter", "path")) {
  png(paste0("outputs/figures/umcsent_tfr_", chart, ".png"),
      width = 1800, height = 1300, res = 130)

  plot(data_train$UMCSENT_lag1, data_train$tfr, type = "n",
       xlim = c(60, 113), ylim = c(1.5, 3.8),
       xlab = "Consumer sentiment in t-1 (index)",
       ylab = "TFR in t (births per woman)",
       main = "Consumer sentiment and next-year fertility",
       sub = "Training sample: labels identify the TFR outcome year (1961-2004)")
  grid()

  if (chart == "scatter") {
    abline(fit, col = "firebrick", lwd = 2)
    legend("topright", "OLS best-fit line (descriptive)",
           col = "firebrick", lty = 1, lwd = 2, bty = "n")
  }

  if (chart == "path") {
    arrows(head(data_train$UMCSENT_lag1, -1), head(data_train$tfr, -1),
           tail(data_train$UMCSENT_lag1, -1), tail(data_train$tfr, -1),
           length = 0.06, angle = 20, col = "grey55", lwd = 1)
    legend("topright", "Arrows connect consecutive years",
           col = "grey55", lty = 1, lwd = 1, bty = "n")
  }

  points(data_train$UMCSENT_lag1, data_train$tfr,
         col = "darkblue", pch = 20, cex = 1)
  text(data_train$UMCSENT_lag1, data_train$tfr, labels = data_train$year,
       pos = label_pos, offset = 0.6, cex = 0.7, col = "darkblue")
  dev.off()
}
