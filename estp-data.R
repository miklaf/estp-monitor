#install.packages(c("rvest", "dplyr", "digest", "httr", "glue"))

# Load required libraries
library(rvest)
library(dplyr)
library(stringr)

# URL of the ESTP programme 2026 page
url <- "https://cros.ec.europa.eu/book-page/estp-programme-2026"

# Read the page
page <- read_html(url)

# Extract the rows from the table structure
rows <- page %>% html_nodes("table") %>% html_nodes("tr")

# Parse rows into a tidy data frame
estp_df <- rows %>% 
  html_nodes("td") %>%
  html_text(trim = TRUE) %>%
  matrix(ncol = 5, byrow = TRUE) %>%
  as.data.frame(stringsAsFactors = FALSE)

# Name columns
colnames(estp_df) <- c("Dates", "Duration", "Deadline", "Title", "Venue_Organizer")

# Clean Venue and Organizer
estp_df <- estp_df %>%
  mutate(
    Venue = word(Venue_Organizer, 1, sep = "\\n"),
    Organizer = word(Venue_Organizer, -1, sep = "\\n")
  ) %>%
  select(-Venue_Organizer)

# Print the table
print(estp_df)
