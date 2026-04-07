library(rvest)
library(dplyr)
library(stringr)

# URL
url <- "https://cros.ec.europa.eu/book-page/estp-programme-2026"

# Read page
page <- tryCatch(read_html(url), 
                 error = function(e) stop("Failed to read page: ", e$message))

# Extract table (3 columns)
tbl_raw <- page %>%
  html_element("table") %>%
  html_table(fill = TRUE) %>%
  mutate(across(everything(), str_squish))

colnames(tbl_raw) <- c("Col1", "Title", "Venue_Organizer")

# Parse Col1 into Dates, Duration, Deadline
estp_df <- tbl_raw %>%
  mutate(
    Dates_2026 = str_extract(Col1, "^.*?(?=\\d+\\s*days)"),
    Duration = str_extract(Col1, "\\d+\\s*days"),
    Deadline = str_extract(Col1, "(?<=DEADLINE: )\\d{2}\\.\\d{2}\\.\\d{2,4}"),
    Venue = str_extract(Venue_Organizer, "^.+?(?=ORGANIZER)"),
    Organizer = str_remove(Venue_Organizer, "^.*ORGANIZER:\\s+")
  ) %>%
  select(Dates_2026, Duration, Title, Venue, Deadline, Organizer)

print(estp_df)


# ----------------------------
# Compare with existing data
# ----------------------------

# Read existing estp_data file
existing_estp_data_file <- "estp_data.csv"


if (!file.exists(existing_estp_data_file)) {
  write.csv(estp_df, existing_estp_data_file, row.names = FALSE)
  message("New data file created")
  quit(save = "ues")
} else {
  estp_existing_df <- read.csv(existing_estp_data_file)
  new_programs_df <- anti_join(estp_df, estp_existing_df)
}


if (nrow(new_programs_df) == 0) {
  message("No differences found")
} else {
  # notify via Slack
  source("estp-notify-slack.R")
  
  # update the existing file
  write.csv(estp_df, existing_estp_data_file, row.names = FALSE)
  msg <- paste0(nrow(new_programs_df), " New seminar(s) added!")
  message(msg)
}