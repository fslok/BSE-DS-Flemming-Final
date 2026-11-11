# Run from the repository root: source("scripts/02_clean_merge.R")
# Reads local raw files only. Output: data/us_fertility_annual.csv.

start_year <- 1960L
target_id <- "SPDYNTFRTINUSA"
raw_dir <- file.path("data", "raw")
metadata_path <- file.path(raw_dir, "series_metadata.csv")
if (!file.exists(metadata_path)) stop("Run scripts/01_download_fred.R first.")
metadata <- read.csv(metadata_path, stringsAsFactors = FALSE)
required <- c("series_id", "frequency_short", "as_of_date", "md5")
if (!all(required %in% names(metadata)) || nrow(metadata) != 34L ||
    anyDuplicated(metadata$series_id) ||
    !target_id %in% metadata$series_id) {
  stop("Missing or inconsistent download metadata.")
}
if (metadata$frequency_short[match(target_id, metadata$series_id)] != "A") {
  stop("The fertility target must have annual frequency.")
}
ids <- metadata$series_id
paths <- file.path(raw_dir, paste0(ids, ".csv"))
if (!all(file.exists(paths))) {
  stop("Missing raw files: ", paste(ids[!file.exists(paths)], collapse = ", "))
}
if (anyNA(metadata$md5) || !all(unname(tools::md5sum(paths)) == metadata$md5)) {
  stop("Raw files differ from their download metadata. Rerun the download script.")
}
snapshot_dates <- unique(as.Date(metadata$as_of_date))
if (length(snapshot_dates) != 1L || anyNA(snapshot_dates)) {
  stop("Raw files must come from one download date.")
}
last_complete_year <- as.integer(format(snapshot_dates, "%Y")) - 1L

read_series <- function(path) {
  x <- read.csv(path, colClasses = "character", na.strings = c(".", "", "NA"))
  if (!all(c("date", "value") %in% names(x))) stop("Invalid raw file: ", basename(path))
  dates <- as.Date(x$date)
  values <- suppressWarnings(as.numeric(x$value))
  if (anyNA(dates) || anyDuplicated(dates) ||
      any(!is.na(x$value) & (is.na(values) | !is.finite(values)))) {
    stop("Invalid dates, duplicate dates, or nonnumeric values: ", basename(path))
  }
  x <- data.frame(date = dates, value = values, year = as.integer(format(dates, "%Y")))
  x[order(x$date), ]
}
raw <- setNames(lapply(paths, read_series), ids)
tfr <- raw[[target_id]]
available_years <- tfr$year[!is.na(tfr$value) & tfr$year >= start_year &
                            tfr$year <= last_complete_year]
if (length(available_years) == 0L) stop("No usable fertility years from 1960 onward.")
years <- seq.int(start_year, max(available_years))
merged <- data.frame(year = years)

# A partial year becomes NA; it is never averaged as if it were a full year.
annualize <- function(x, frequency, id, years) {
  if (!frequency %in% c("A", "Q", "M", "W")) stop("Unsupported frequency: ", id)
  rows <- lapply(years, function(year) {
    z <- x[x$year == year, ]
    n <- nrow(z)
    n_valid <- sum(!is.na(z$value))
    complete <- FALSE
    if (n > 0L && n_valid == n) {
      month <- as.integer(format(z$date, "%m"))
      complete <- switch(
        frequency,
        A = n == 1L,
        Q = n == 4L && length(unique((month - 1L) %/% 3L)) == 4L,
        M = n == 12L && length(unique(month)) == 12L,
        # Allow historical changes in the weekly reporting weekday.
        W = n %in% c(52L, 53L) &&
          min(z$date) <= as.Date(paste0(year, "-01-07")) &&
          max(z$date) >= as.Date(paste0(year, "-12-25")) &&
          max(as.numeric(diff(z$date))) <= 10
      )
    }
    data.frame(
      series_id = id, year = year, observations = n, nonmissing = n_valid,
      complete = complete,
      status = if (n == 0L) "no_observations" else if (complete) "complete" else "incomplete",
      value = if (complete) mean(z$value) else NA_real_
    )
  })
  do.call(rbind, rows)
}

# Target first, then predictors. All columns share exactly the same year grid.
ids <- c(target_id, setdiff(ids, target_id))
coverage <- vector("list", length(ids))
for (i in seq_along(ids)) {
  id <- ids[i]
  frequency <- metadata$frequency_short[match(id, metadata$series_id)]
  annual <- annualize(raw[[id]], frequency, id, years)
  column_name <- if (id == target_id) "tfr" else id
  merged[[column_name]] <- annual$value[match(merged$year, annual$year)]
  coverage[[i]] <- annual
}
coverage <- do.call(rbind, coverage)

# Original units: CPI stays an index; earnings stay in dollars; rates stay in percent.
# For ICSA, the annual mean is average weekly claims, NOT total annual claims.
# Growth rates, inflation, ratios, lags, and train/test splits belong in later scripts.
write.csv(merged, "data/us_fertility_annual.csv", row.names = FALSE, na = "NA")
write.csv(coverage, "data/annual_coverage.csv", row.names = FALSE, na = "NA")
message("Saved ", nrow(merged), " years (", min(years), "-", max(years),
        "), TFR, and ", ncol(merged) - 2L, " predictors.")
message("Missing annual cells: ", sum(is.na(merged[-1L])),
        ". See data/annual_coverage.csv for details.")
