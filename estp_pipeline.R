library(rvest)
library(dplyr)
library(digest)
library(stringr)
library(glue)

# ============================================================================
# ESTP Integrated Pipeline
# Combines monitoring, reporting, tagging, and notifications
# ============================================================================

source("estp_reports.R")
source("estp_tags.R")

#' Main ESTP Pipeline
#'
#' Complete automation combining:
#' - Data scraping and change detection
#' - Report generation (Issue #1)
#' - Seminar tagging (Issue #2)
#' - Slack notifications
#'
#' @param data_file Path to estp_data.csv
#' @param hash_file Path to hash file
#' @param tags_file Path to tags file
#' @param output_dir Directory for report exports
#' @param notify_slack Send Slack notification
#'
#' @return List with pipeline results
#'
main_estp_pipeline <- function(
  data_file = "estp_data.csv",
  hash_file = "estp_table_hash.txt",
  tags_file = "estp_seminar_tags.csv",
  output_dir = "reports",
  notify_slack = FALSE
) {
  
  message("=" %>% rep(70) %>% paste(collapse = ""))
  message("🚀 Starting ESTP Pipeline")
  message("=" %>% rep(70) %>% paste(collapse = ""))
  message(glue("Timestamp: {Sys.time()}\n"))
  
  result <- list(
    success = FALSE,
    timestamp = Sys.time(),
    changes_detected = FALSE,
    new_seminars = 0,
    reports_generated = 0,
    tags_updated = 0,
    message = ""
  )
  
  tryCatch({
    # Step 1: Fetch and parse ESTP data
    message("Step 1: Fetching ESTP data...")
    url <- "https://cros.ec.europa.eu/book-page/estp-programme-2026"
    
    page <- tryCatch(
      read_html(url),
      error = function(e) stop("Failed to fetch ESTP page: ", e$message)
    )
    
    tbl_raw <- page %>%
      html_element("table") %>%
      html_table(fill = TRUE) %>%
      mutate(across(everything(), str_squish))
    
    colnames(tbl_raw) <- c("Col1", "Title", "Venue_Organizer")
    
    # Parse the data
    estp_df <- tbl_raw %>%
      mutate(
        Dates_2026 = str_extract(Col1, "^.*?(?=\\d+\\s*days)"),
        Duration = str_extract(Col1, "\\d+\\s*days"),
        Deadline = str_extract(Col1, "(?<=DEADLINE: )\\d{2}\\.\\d{2}\\.\\d{2,4}"),
        Venue = str_extract(Venue_Organizer, "^.+?(?=ORGANIZER)"),
        Organizer = str_remove(Venue_Organizer, "^.*ORGANIZER:\\s+")
      ) %>%
      select(Dates_2026, Duration, Title, Venue, Deadline, Organizer)
    
    message(glue("  ✓ Fetched {nrow(estp_df)} seminars"))
    
    # Step 2: Check for changes
    message("\nStep 2: Checking for changes...")
    current_hash <- digest(estp_df, algo = "sha256")
    
    if (!file.exists(hash_file)) {
      message("  • First run - saving initial snapshot")
      writeLines(current_hash, hash_file)
      write.csv(estp_df, data_file, row.names = FALSE)
      result$message <- "Initial snapshot saved"
      result$success <- TRUE
      return(result)
    }
    
    old_hash <- readLines(hash_file)
    
    if (current_hash != old_hash) {
      message("  ✓ Changes detected!")
      result$changes_detected <- TRUE
      
      # Load existing data to find new seminars
      estp_existing_df <- read.csv(data_file)
      new_programs_df <- anti_join(estp_df, estp_existing_df)
      
      result$new_seminars <- nrow(new_programs_df)
      message(glue("  • {nrow(new_programs_df)} new seminar(s) found"))
      
      # Update files
      writeLines(current_hash, hash_file)
      write.csv(estp_df, data_file, row.names = FALSE)
      
    } else {
      message("  • No changes detected")
      result$success <- TRUE
      result$message <- "No updates needed"
      return(result)
    }
    
    # Step 3: Generate Reports (Issue #1)
    message("\nStep 3: Generating reports...")
    tryCatch({
      export_reports(estp_df, new_df = new_programs_df, output_dir = output_dir)
      result$reports_generated <- 4  # 4 reports generated
      message("  ✓ Reports generated successfully")
    }, error = function(e) {
      message(glue("  ⚠ Warning generating reports: {e$message}"))
    })
    
    # Step 4: Update Tags (Issue #2)
    message("\nStep 4: Updating seminar tags...")
    if (nrow(new_programs_df) > 0) {
      tryCatch({
        bulk_tag_new_seminars(new_programs_df, default_tag = "possible")
        result$tags_updated <- nrow(new_programs_df)
        
        # Export tags report
        export_tags(output_dir = output_dir)
        message("  ✓ Tags updated and exported")
      }, error = function(e) {
        message(glue("  ⚠ Warning updating tags: {e$message}"))
      })
    }
    
    # Step 5: Slack Notification (Optional)
    if (notify_slack && nrow(new_programs_df) > 0) {
      message("\nStep 5: Sending Slack notification...")
      tryCatch({
        slack_webhook_url <- Sys.getenv("ESTPSLACK_WEBHOOK_URL")
        
        if (slack_webhook_url != "") {
          # Build formatted message
          msg <- glue(
            "*📢 ESTP Program Update*\n",
            "{nrow(new_programs_df)} new seminar(s) added!\n\n"
          )
          
          for (i in seq_len(min(nrow(new_programs_df), 5))) {
            r <- new_programs_df[i, ]
            msg <- paste0(msg, glue(
              "• *{r$Title}*\n",
              "  📅 {r$Dates_2026} ({r$Duration})\n",
              "  📍 {r$Venue}\n",
              "  ⏰ Deadline: {r$Deadline}\n\n"
            ))
          }
          
          if (nrow(new_programs_df) > 5) {
            msg <- paste0(msg, 
              glue("...and {nrow(new_programs_df) - 5} more seminar(s)\n"))
          }
          
          msg <- paste0(msg, glue(
            "\n🔗 View full report in: {output_dir}/\n",
            "🏷️ Tag seminars as 'possible' in estp_seminar_tags.csv"
          ))
          
          httr::POST(
            url = slack_webhook_url,
            body = list(text = msg),
            encode = "json"
          )
          
          message("  ✓ Slack notification sent")
        } else {
          message("  ⚠ Slack webhook URL not configured")
        }
      }, error = function(e) {
        message(glue("  ⚠ Warning sending Slack notification: {e$message}"))
      })
    }
    
    result$success <- TRUE
    result$message <- "Pipeline completed successfully"
    
  }, error = function(e) {
    message(glue("\n❌ Error: {e$message}"))
    result$success <<- FALSE
    result$message <<- e$message
  })
  
  return(result)
}

#' Print Pipeline Summary
#'
#' Display formatted summary of pipeline execution
#'
#' @param result Result from main_estp_pipeline()
#'
print_pipeline_summary <- function(result) {
  
  message("\n" %>% rep(3) %>% paste(collapse = "\n"))
  message("=" %>% rep(70) %>% paste(collapse = ""))
  message("📊 ESTP Pipeline Summary")
  message("=" %>% rep(70) %>% paste(collapse = ""))
  
  status <- if (result$success) "✅ SUCCESS" else "❌ FAILED"
  message(glue("Status: {status}"))
  message(glue("Timestamp: {result$timestamp}"))
  message(glue("Changes Detected: {if(result$changes_detected) 'Yes ✓' else 'No'}"))
  
  if (result$changes_detected) {
    message(glue("  • New Seminars: {result$new_seminars}"))
    message(glue("  • Reports Generated: {result$reports_generated}"))
    message(glue("  • Tags Updated: {result$tags_updated}"))
  }
  
  if (result$message != "") {
    message(glue("Message: {result$message}"))
  }
  
  message("=" %>% rep(70) %>% paste(collapse = ""))
}

#' Run Pipeline (Wrapper)
#'
#' Simplified wrapper to run the complete pipeline
#'
#' @param ... Additional arguments passed to main_estp_pipeline()
#'
run_estp_pipeline <- function(...) {
  result <- main_estp_pipeline(...)
  print_pipeline_summary(result)
  return(invisible(result))
}

# Execute pipeline if run directly
if (!interactive()) {
  run_estp_pipeline(notify_slack = TRUE)
}
