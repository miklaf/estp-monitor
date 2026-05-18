library(dplyr)
library(stringr)
library(glue)
library(tidyr)

# ============================================================================
# ESTP Reports Generation Module
# Solves Issue #1: Return various reports with dates and details
# ============================================================================

#' Generate New Seminars Report
#'
#' Creates a report of newly added seminars with dates and deadlines
#'
#' @param new_df Data frame of new seminars
#'
#' @return Data frame formatted as report
#'
generate_new_seminars_report <- function(new_df) {
  
  if (nrow(new_df) == 0) {
    message("No new seminars to report")
    return(data.frame())
  }
  
  report <- new_df %>%
    mutate(
      Detected_Date = Sys.Date(),
      Days_to_Deadline = as.numeric(
        as.Date(paste0(Deadline, ".2026"), format = "%d.%m.%Y") - Sys.Date()
      )
    ) %>%
    select(
      Detected_Date,
      Title,
      Dates_2026,
      Duration,
      Deadline,
      Days_to_Deadline,
      Venue,
      Organizer
    ) %>%
    arrange(Deadline)
  
  return(report)
}

#' Generate Seminars by Organizer Report
#'
#' Groups seminars by organizer with counts and statistics
#'
#' @param estp_df Complete ESTP data frame
#'
#' @return Data frame with organizer summary
#'
generate_seminars_by_organizer_report <- function(estp_df) {
  
  report <- estp_df %>%
    filter(!is.na(Organizer)) %>%
    group_by(Organizer) %>%
    summarise(
      Total_Seminars = n(),
      Online_Seminars = sum(str_detect(Venue, "ONLINE|Virtual|Webinar"), na.rm = TRUE),
      In_Person_Seminars = Total_Seminars - Online_Seminars,
      Countries = paste(unique(
        str_extract(Venue, "[A-Z]{2,}")
      ), collapse = ", "),
      .groups = "drop"
    ) %>%
    arrange(desc(Total_Seminars))
  
  return(report)
}

#' Generate Seminars by Venue Report
#'
#' Groups seminars by venue/location
#'
#' @param estp_df Complete ESTP data frame
#'
#' @return Data frame with venue summary
#'
generate_seminars_by_venue_report <- function(estp_df) {
  
  report <- estp_df %>%
    filter(!is.na(Venue)) %>%
    group_by(Venue) %>%
    summarise(
      Seminars_Count = n(),
      Organizers = paste(unique(Organizer), collapse = ", "),
      .groups = "drop"
    ) %>%
    mutate(
      Type = if_else(
        str_detect(Venue, "ONLINE|Virtual|Webinar"),
        "Online",
        "In-Person"
      )
    ) %>%
    arrange(Type, Venue) %>%
    select(Venue, Type, Seminars_Count, Organizers)
  
  return(report)
}

#' Generate Comprehensive Report
#'
#' Overall statistics and summary of ESTP program
#'
#' @param estp_df Complete ESTP data frame
#'
#' @return Data frame with summary statistics
#'
generate_comprehensive_report <- function(estp_df) {
  
  online_count <- sum(str_detect(estp_df$Venue, "ONLINE|Virtual|Webinar"), na.rm = TRUE)
  in_person_count <- nrow(estp_df) - online_count
  
  report <- data.frame(
    Metric = c(
      "Total Seminars",
      "Online Seminars",
      "In-Person Seminars",
      "Unique Organizers",
      "Unique Venues",
      "Seminars with Deadline Info",
      "Seminars without Deadline",
      "Seminars with Date Info",
      "Seminars without Date Info",
      "Average Duration (days)"
    ),
    Value = c(
      nrow(estp_df),
      online_count,
      in_person_count,
      n_distinct(estp_df$Organizer),
      n_distinct(estp_df$Venue),
      sum(!is.na(estp_df$Deadline)),
      sum(is.na(estp_df$Deadline)),
      sum(!is.na(estp_df$Dates_2026)),
      sum(is.na(estp_df$Dates_2026)),
      round(mean(
        as.numeric(str_extract(estp_df$Duration, "\\d+")),
        na.rm = TRUE
      ), 2)
    )
  )
  
  return(report)
}

#' Export All Reports
#'
#' Generates and exports all reports to CSV files with timestamp
#'
#' @param estp_df Complete ESTP data frame
#' @param new_df Data frame of new seminars (optional)
#' @param output_dir Directory to save reports
#'
#' @return Invisible list of generated reports
#'
export_reports <- function(
  estp_df,
  new_df = NULL,
  output_dir = "reports"
) {
  
  # Create output directory if it doesn't exist
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    message(glue("Created directory: {output_dir}"))
  }
  
  timestamp <- format(Sys.Date(), "%Y%m%d")
  
  # Generate reports
  new_report <- if (!is.null(new_df) && nrow(new_df) > 0) {
    generate_new_seminars_report(new_df)
  } else {
    data.frame()
  }
  
  org_report <- generate_seminars_by_organizer_report(estp_df)
  venue_report <- generate_seminars_by_venue_report(estp_df)
  summary_report <- generate_comprehensive_report(estp_df)
  
  # Export to CSV
  if (nrow(new_report) > 0) {
    filename <- glue("{output_dir}/new_seminars_{timestamp}.csv")
    write.csv(new_report, filename, row.names = FALSE)
    message(glue("✓ Exported: {filename}"))
  }
  
  filename <- glue("{output_dir}/seminars_by_organizer_{timestamp}.csv")
  write.csv(org_report, filename, row.names = FALSE)
  message(glue("✓ Exported: {filename}"))
  
  filename <- glue("{output_dir}/seminars_by_venue_{timestamp}.csv")
  write.csv(venue_report, filename, row.names = FALSE)
  message(glue("✓ Exported: {filename}"))
  
  filename <- glue("{output_dir}/summary_report_{timestamp}.csv")
  write.csv(summary_report, filename, row.names = FALSE)
  message(glue("✓ Exported: {filename}"))
  
  invisible(list(
    new = new_report,
    organizer = org_report,
    venue = venue_report,
    summary = summary_report
  ))
}

#' Print Reports Summary
#'
#' Display all reports in readable format
#'
#' @param estp_df Complete ESTP data frame
#' @param new_df Data frame of new seminars (optional)
#'
print_reports_summary <- function(estp_df, new_df = NULL) {
  
  message("\n" %>% rep(3) %>% paste(collapse = "\n"))
  message("=" %>% rep(70) %>% paste(collapse = ""))
  message("📊 ESTP Reports Summary")
  message("=" %>% rep(70) %>% paste(collapse = ""))
  
  # New Seminars
  if (!is.null(new_df) && nrow(new_df) > 0) {
    message(glue("\n🆕 NEW SEMINARS ({nrow(new_df)})"))
    message("-" %>% rep(70) %>% paste(collapse = ""))
    new_report <- generate_new_seminars_report(new_df)
    print(new_report)
  }
  
  # By Organizer
  message(glue("\n🏢 BY ORGANIZER"))
  message("-" %>% rep(70) %>% paste(collapse = ""))
  org_report <- generate_seminars_by_organizer_report(estp_df)
  print(org_report)
  
  # By Venue
  message(glue("\n📍 BY VENUE (Top 10)"))
  message("-" %>% rep(70) %>% paste(collapse = ""))
  venue_report <- generate_seminars_by_venue_report(estp_df) %>%
    slice_head(n = 10)
  print(venue_report)
  
  # Summary
  message(glue("\n📈 SUMMARY STATISTICS"))
  message("-" %>% rep(70) %>% paste(collapse = ""))
  summary_report <- generate_comprehensive_report(estp_df)
  print(summary_report)
  
  message("\n" %>% rep(3) %>% paste(collapse = "\n"))
}
