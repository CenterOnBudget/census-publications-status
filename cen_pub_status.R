library(tidyverse)
library(fs)
library(httr2)



# Functions ---------------------------------------------------------------

# Given a URL prefix, find all the URLs that were ever captured by the Internet
# Archive (via Wayback CDX server)
# https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server#readme
# Returns a tibble with 3 columns:
#   `url`
#   `timestamp` (of first wayback capture)
#   `date` (of first wayback capture)

get_url_list <- function(url_prefix) {
  
  params <- list(
    matchType = "prefix",
    output = "json",
    filter = "statuscode:200",      # Successful captures only
    filter = "mimetype:text/html",  # HTML pages only (no images, PDFs, etc.)
    collapse = "urlkey"             # First capture per unique URL
  )
  
  req <- request("https://web.archive.org/cdx/search/cdx") |>
    req_url_query(url = url_prefix, !!!params)
  
  resp <- req |>
    req_perform()
  
  resp_json <- resp_body_json(resp, simplifyVector = TRUE)
  colnames(resp_json) <- resp_json[1, ]
  resp_df <- as_tibble(resp_json)
  resp_df <- resp_df[-1, ]
  
  url_info <- resp_df |>
    filter(
      !str_detect(original, "\\?"),  # Remove URLs with query string
      path_ext(original) == "html"   # Remove base URLs
    ) |>
    mutate(
      date = parse_date(timestamp, "%Y%m%d%H%M%S"),
      url = original
    ) |>
    select(url, date, timestamp) |>
    # There shouldn't be duplicates but just in case, keep the first capture per
    # unique URL
    arrange(url, timestamp) |>
    distinct(url, .keep_all = TRUE)
  
  return(url_info)
  
}

# Take the output of `get_url_list`, iterate through the URLs and find their
# current HTTP status
# Returns a tibble with 4 columns:
#   Existing 3 columns from `url_info` 
#   `cur_status` (URL's current HTTP status code)

check_url_status <- function(url_info) {
  
  if (nrow(url_info) > 0) {
    
    reqs <- map(
      pull(url_info, url),
      \(url) request(url) |>
        req_method("HEAD") |>
        req_error(is_error = \(x) FALSE) |>
        # Follow least restrictive crawl delay in https://www.census.gov/robots.txt
        req_throttle(rate = 1 / 3)
    )
    
    resps <- req_perform_sequential(reqs)
    
    cur_status <- map(
      resps,
      \(x) tibble(url = resp_url(x), cur_status = resp_status(x))
    ) |>
      list_rbind()
    
    url_info_status <- left_join(
      url_info,
      cur_status,
      by = "url"
    )
    
    return(url_info_status)
    
  }
  
  if (nrow(url_info) == 0) {
    return(url_info)
  }
  
}


# Scope -------------------------------------------------------------------

# 2018 to 2025 YTD
# 3 kinds of Census publications for each year:
# Working papers, America Counts stories, and publications (reports, briefs, etc.)

years <- c(2018:2025)
pub_types <- c("working-papers", "stories", "publications")

params <- expand_grid(year = years, pub_type = pub_types) |>
  mutate(
    url_prefix = paste(
      "https://www.census.gov/library",
      pub_type,
      year,
      sep = "/"
    ),
    url_file = paste0(
      "data/urls/",
      pub_type, "_", year, ".csv"
    ),
    status_file = paste0(
      "data/status/",
      pub_type, "_", year, ".csv"
    ),
  )


# Get list of Census publications -----------------------------------------

pwalk(
  params,
  \(url_prefix, url_file, ...) {
    if (!file_exists(url_file)) {
      get_url_list(url_prefix) |>
        write_csv(url_file, na = "", progress = FALSE)
    }
  }
)


# Check status of Census publications -------------------------------------

pwalk(
  params,
  \(url_file, status_file, ...) {
    if (!file_exists(status_file)) {
      url_file |>
        read_csv(show_col_types = FALSE, progress = FALSE) |>
        check_url_status() |>
        write_csv(status_file)
    }
  }
) 


# Make list of removed Census publications --------------------------------

# Some of these pages may have been moved or deleted for benign reasons

removed_cen_pubs <- dir_ls(
  "data/status", glob = "*.csv"
) |>
  map(\(x) read_csv(x, show_col_types = FALSE, progress = FALSE)) |>
  list_rbind() |>
  filter(cur_status != "200") |>
  mutate(
    wayback_url = paste(
      "https://web.archive.org/web",
      timestamp,
      url,
      sep = "/"
    ),
    short_url = str_remove(url, "https://www.census.gov/library/"),
    pub_type = str_extract(url, "stories|working-paper|publication"),
    pub_type = case_match(
      pub_type, 
      "stories" ~ "america-counts-story", 
      .default = pub_type
    )
  ) |>
  arrange(date, url) |>
  select(
    pub_type, url, short_url, wayback_date = date, wayback_url
  )

write_csv(
  removed_cen_pubs, 
  paste0("data/removed_cen_pubs.csv"),
  na = "",
  progress = FALSE
)


