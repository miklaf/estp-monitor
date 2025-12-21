#install.packages(c("rvest", "dplyr", "digest", "httr", "glue"))


library(rvest)
library(dplyr)
library(digest)
library(glue)

# -----------------------------
# Configuration
# -----------------------------
url <- "https://cros.ec.europa.eu/book-page/estp-programme-2026"
hash_file <- "estp_table_hash.txt"
data_file <- "estp_table_latest.csv"

# -----------------------------
# Scrape ESTP table
# -----------------------------
page <- read_html(url)

table <- page %>%
  html_node("table") %>%
  html_table(fill = TRUE)

estp_df <- table %>%
  mutate_all(trimws)

# -----------------------------
# Create hash of table content
# -----------------------------
current_hash <- digest(estp_df, algo = "sha256")

# -----------------------------
# First run (no previous hash)
# -----------------------------
if (!file.exists(hash_file)) {
  writeLines(current_hash, hash_file)
  write.csv(estp_df, data_file, row.names = FALSE)
  message("Initial snapshot saved. No comparison done.")
  quit(save = "no")
}

# -----------------------------
# Compare with previous version
# -----------------------------
old_hash <- readLines(hash_file)

if (current_hash != old_hash) {
  message("⚠️ ESTP programme has changed!")
  
  # Save new version
  writeLines(current_hash, hash_file)
  write.csv(estp_df, data_file, row.names = FALSE)
  
  # -----------------------------
  # OPTIONAL: SLACK notification
  # -----------------------------
  source("estp-notify-slack-simple.R")
  
} else {
  message("No changes detected.")
}
