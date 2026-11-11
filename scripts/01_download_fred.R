# Run from the repository root: source("scripts/01_download_fred.R")
# Downloads annual observations from FRED; FRED calculates the averages.
# API reference: https://fred.stlouisfed.org/docs/api/fred/series_observations.html

if (!file.exists("data/variables.md")) stop("Set the working directory to the repository root.")
if (!requireNamespace("httr2", quietly = TRUE)) {
  install.packages("httr2", repos = "https://cloud.r-project.org")
}

download_fred <- function() {
  # Use FRED_API_KEY from the environment, or a local secret.txt containing only the key.
  api_key <- trimws(Sys.getenv("FRED_API_KEY"))
  if (!nzchar(api_key) && file.exists("secret.txt")) {
    api_key <- trimws(paste(readLines("secret.txt", warn = FALSE), collapse = ""))
  }
  if (!grepl("^[a-z0-9]{32}$", api_key)) {
    stop("Set FRED_API_KEY or put your replacement FRED key in local secret.txt.", call. = FALSE)
  }

  # Same 34 series as data/variables.md: target, 25 core, 8 additional.
  series_ids <- c(
    "SPDYNTFRTINUSA",    # Total fertility rate
    "A939RX0Q048SBEA",   # Real GDP per capita
    "A229RX0",          # Real disposable income per capita
    "PCECC96",          # Real consumption
    "PSAVERT",          # Saving rate
    "INDPRO",           # Industrial production
    "CUMFNS",           # Manufacturing capacity utilization
    "UNRATE",           # Unemployment
    "PAYEMS",           # Nonfarm payrolls
    "CIVPART",          # Labor force participation
    "LNS11300002",      # Women's participation, 16+
    "LRAC25FEUSA156N",   # Women's participation, 25-54
    "LNS14000002",      # Women's unemployment
    "LNS12300002",      # Women's employment/population
    "LNS14000036",      # Unemployment, 20-24
    "UEMPMEAN",         # Unemployment duration
    "AWHMAN",           # Weekly manufacturing hours
    "CPIAUCSL",         # Headline CPI
    "CPILFESL",         # Core CPI
    "CUUR0000SEHA",     # Rent CPI, NSA
    "FEDFUNDS",         # Federal funds rate
    "GS10",             # 10-year Treasury yield
    "TB3MS",            # 3-month Treasury bill rate
    "BAA",              # Baa corporate bond yield
    "HOUST",            # Housing starts
    "PERMIT",           # Housing permits
    "AHETPI",           # Hourly earnings
    "ICSA",             # Weekly initial claims
    "MORTGAGE30US",      # 30-year mortgage rate
    "UMCSENT",          # Consumer sentiment
    "LEU0252882700Q",   # Women's weekly earnings
    "LEU0252881800Q",   # Men's weekly earnings
    "MEHOINUSA672N",    # Real median household income
    "CSUSHPINSA"        # Case-Shiller national house price index
  )
  groups <- c("target", rep("core", 25), rep("additional", 8))
  start_date <- "1960-01-01"
  as_of_date <- as.character(Sys.Date())
  end_date <- paste0(as.integer(format(Sys.Date(), "%Y")) - 1L, "-12-31")
  retrieved_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  # Keep the previous native-frequency downloads untouched in data/raw/.
  raw_dir <- file.path("data", "raw", "annual")
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

  # Keep the key and full request URLs out of messages and saved files.
  fred_get <- function(endpoint, id, ...) {
    Sys.sleep(0.6)
    tryCatch({
      request <- httr2::request(paste0("https://api.stlouisfed.org/fred/", endpoint))
      request <- httr2::req_url_query(
        request, api_key = api_key, series_id = id, file_type = "json",
        realtime_start = as_of_date, realtime_end = as_of_date, ...
      )
      request <- httr2::req_timeout(request, 60)
      request <- httr2::req_retry(request, max_tries = 3, retry_on_failure = TRUE)
      response <- httr2::req_perform(request)
      httr2::resp_body_json(response, simplifyVector = TRUE)
    }, error = function(e) {
      stop("FRED request failed for ", id, " (", endpoint,
           "). Check the key, connection, or series availability.", call. = FALSE)
    })
  }

  observations <- metadata <- vector("list", length(series_ids))
  for (i in seq_along(series_ids)) {
    id <- series_ids[i]
    message("[", i, "/", length(series_ids), "] ", id)
    info <- fred_get("series", id)$seriess
    result <- fred_get(
      "series/observations", id, observation_start = start_date,
      observation_end = end_date, units = "lin", frequency = "a",
      aggregation_method = "avg", sort_order = "asc", limit = 100000
    )
    x <- result$observations
    if (!is.data.frame(info) || nrow(info) != 1L || info$id != id ||
        !is.data.frame(x) || nrow(x) == 0L || nrow(x) != result$count) {
      stop("Empty, incomplete, or unexpected API response for ", id, call. = FALSE)
    }
    if (!info$frequency_short %in% c("A", "Q", "M", "W")) {
      stop("Unsupported frequency for ", id, ": ", info$frequency_short, call. = FALSE)
    }
    if (!all(c("date", "value", "realtime_start", "realtime_end") %in% names(x)) ||
        anyDuplicated(x$date)) {
      stop("Unexpected observation columns or duplicate dates for ", id, call. = FALSE)
    }

    dates <- as.Date(x$date)
    years <- as.integer(format(dates, "%Y"))
    if (anyNA(dates) || anyDuplicated(years) || any(format(dates, "%m-%d") != "01-01")) {
      stop("FRED did not return one annual observation per year for ", id, call. = FALSE)
    }

    # Annual sources pass through unchanged. All other averages come from FRED.
    # Preserve FRED's rounding and missing-value rules; do not recalculate here.
    observations[[i]] <- x[c("date", "value", "realtime_start", "realtime_end")]
    usable <- !is.na(x$value) & x$value != "."
    metadata[[i]] <- data.frame(
      series_id = id, group = groups[i], title = info$title,
      frequency = "Annual", frequency_short = "A", aggregation_method = "avg",
      native_frequency = info$frequency, native_frequency_short = info$frequency_short,
      units = info$units, seasonal_adjustment = info$seasonal_adjustment,
      last_updated = info$last_updated, as_of_date = as_of_date,
      retrieved_at_utc = retrieved_at, requested_start = start_date, requested_end = end_date,
      observations = nrow(x), nonmissing = sum(usable),
      first_nonmissing = if (any(usable)) min(x$date[usable]) else NA_character_,
      last_nonmissing = if (any(usable)) max(x$date[usable]) else NA_character_,
      source_url = paste0("https://fred.stlouisfed.org/series/", id)
    )
  }

  # Only replace files after every API request has succeeded.
  metadata <- do.call(rbind, metadata)
  paths <- file.path(raw_dir, paste0(series_ids, ".csv"))
  for (i in seq_along(paths)) {
    write.csv(observations[[i]], paths[i], row.names = FALSE, na = ".")
  }
  metadata$md5 <- unname(tools::md5sum(paths))
  write.csv(metadata, file.path(raw_dir, "series_metadata.csv"), row.names = FALSE, na = "")
  message("Saved ", length(series_ids), " annual FRED series in ", raw_dir, ".")
}

download_fred()
