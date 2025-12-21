library(rvest)
library(dplyr)
library(stringr)

# URL
url <- "https://cros.ec.europa.eu/book-page/estp-programme-2026"

# Read page
page <- read_html(url)

# Extract table (3 columns)
tbl_raw <- page %>%
  html_element("table") %>%
  html_table(fill = TRUE) %>%
  mutate(across(everything(), str_squish))

colnames(tbl_raw) <- c("Col1", "Title", "Venue")

# Parse Col1 into Dates, Duration, Deadline
estp_df <- tbl_raw %>%
  mutate(
    `Dates (2026)` = str_extract(Col1, "^.*?(?=\\d+\\s*days)"),
    Duration = str_extract(Col1, "\\d+\\s*days"),
    Deadline = str_extract(Col1, "(?<=DEADLINE: )\\d{2}\\.\\d{2}\\.\\d{2,4}")
  ) %>%
  mutate(
    Organizer = "Eurostat"
  ) %>%
  select(`Dates (2026)`, Duration, Title, Venue, Deadline, Organizer)

print(estp_df)


# -----------------------------
# Compare with existing data
# -----------------------------

# Read existing estp_data
existing_estp_data <- "estp_data.csv"


if (!file.exists(existing_estp_data)) {
  write.csv(estp_df, existing_estp_data, row.names = FALSE)
  message("New data file created")
  quit(save = "ues")
} else {
  estp_existing_df <- read.csv(existing_estp_data)
  new_programs_df <- anti_join(estp_df, estp_existing_df)
}


if (nrow(new_programs_df) == 0) {
  message("No differences found")
} else {
  source("estp-notify-slack.R")
  message("New rows detected!")
  write.csv(estp_df, existing_estp_data, row.names = FALSE)
  msg <- paste0(nrow(new_programs_df), " New seminars added!")
  message(msg)
}