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

# Save the scatterplot. Run plot() and grid() alone to view it in RStudio.
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
png("outputs/figures/umcsent_tfr_scatter.png", width = 1000, height = 700, res = 120)

plot(data_train$UMCSENT_lag1, data_train$tfr,
     xlab = "Consumer sentiment in t-1 (index)",
     ylab = "TFR in t (births per woman)",
     main = "Consumer sentiment and next-year fertility",
     sub = "Training sample: TFR years 1961-2004",
     col = "darkblue", pch = 20, cex = 1.2)
grid()

dev.off()
