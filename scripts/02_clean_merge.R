# Run from the repository root: source("scripts/02_clean_merge.R")
# Checks and merges annual FRED downloads. No averaging or interpolation in R.

start_year <- 1960L
target_id <- "SPDYNTFRTINUSA"
raw_dir <- file.path("data", "raw", "annual")
metadata_path <- file.path(raw_dir, "series_metadata.csv")
if (!file.exists(metadata_path)) stop("Run the updated scripts/01_download_fred.R first.")
metadata <- read.csv(metadata_path, stringsAsFactors = FALSE)
required <- c("series_id", "frequency_short", "aggregation_method", "native_frequency_short",
              "as_of_date", "md5")
if (!all(required %in% names(metadata)) || nrow(metadata) != 34L ||
    anyNA(metadata[required]) || anyDuplicated(metadata$series_id) ||
    !target_id %in% metadata$series_id) {
  stop("Missing or inconsistent annual download metadata. Rerun script 01.")
}
if (any(metadata$frequency_short != "A") || any(metadata$aggregation_method != "avg")) {
  stop("These files were not downloaded using FRED Annual/Average. Rerun script 01.")
}
ids <- metadata$series_id
paths <- file.path(raw_dir, paste0(ids, ".csv"))
if (!all(file.exists(paths))) {
  stop("Missing raw files: ", paste(ids[!file.exists(paths)], collapse = ", "))
}
if (!all(unname(tools::md5sum(paths)) == metadata$md5)) {
  stop("Raw files differ from their download metadata. Rerun script 01.")
}
snapshot_dates <- unique(as.Date(metadata$as_of_date))
if (length(snapshot_dates) != 1L || anyNA(snapshot_dates)) {
  stop("Raw files must come from one download date.")
}
last_complete_year <- as.integer(format(snapshot_dates, "%Y")) - 1L

read_annual <- function(path) {
  x <- read.csv(path, colClasses = "character", na.strings = c(".", "", "NA"))
  if (!all(c("date", "value") %in% names(x))) stop("Invalid raw file: ", basename(path))
  dates <- as.Date(x$date)
  years <- as.integer(format(dates, "%Y"))
  values <- suppressWarnings(as.numeric(x$value))
  if (anyNA(dates) || anyDuplicated(years) ||
      any(format(dates, "%m-%d") != "01-01") ||
      any(!is.na(x$value) & (is.na(values) | !is.finite(values)))) {
    stop("Expected unique annual dates and numeric values: ", basename(path))
  }
  data.frame(year = years, value = values)
}
annual <- setNames(lapply(paths, read_annual), ids)
tfr <- annual[[target_id]]
available_years <- tfr$year[!is.na(tfr$value) & tfr$year >= start_year &
                            tfr$year <= last_complete_year]
if (length(available_years) == 0L) stop("No usable fertility years from 1960 onward.")
years <- seq.int(start_year, max(available_years))
merged <- data.frame(year = years)

# Match by year, preserving FRED's values and missingness exactly.
ids <- c(target_id, setdiff(ids, target_id))
coverage <- vector("list", length(ids))
for (i in seq_along(ids)) {
  id <- ids[i]
  x <- annual[[id]]
  position <- match(years, x$year)
  values <- x$value[position]
  column_name <- if (id == target_id) "tfr" else id
  merged[[column_name]] <- values
  coverage[[i]] <- data.frame(
    series_id = id, year = years,
    status = ifelse(is.na(position), "not_returned",
                    ifelse(is.na(values), "missing_in_fred", "available")),
    value = values
  )
}

# "Available" means FRED returned a value, not that every month/week was observed.
# CPI remains an index; rates remain in percent; ICSA is average weekly claims.
# Growth rates, ratios, forecasting lags, and train/test splits come later.
write.csv(merged, "data/us_fertility_annual.csv", row.names = FALSE, na = "NA")
write.csv(do.call(rbind, coverage), "data/annual_coverage.csv", row.names = FALSE, na = "NA")
message("Saved ", nrow(merged), " years (", min(years), "-", max(years),
        "), TFR, and ", ncol(merged) - 2L, " predictors.")
message("Missing annual cells: ", sum(is.na(merged[-1L])),
        ". See data/annual_coverage.csv for availability.")
