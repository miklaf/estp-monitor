library(dplyr)
library(stringr)
library(glue)

# ============================================================================
# ESTP Tagging System
# Solves Issue #2: Create shortlist of possible seminars with tags
# ============================================================================

TAGS_FILE <- "estp_seminar_tags.csv"

#' Initialize Tags File
#'
#' Create tags file if it doesn't exist
#'
#' @param tags_file Path to tags file
#'
initialize_tags_file <- function(tags_file = TAGS_FILE) {
  if (!file.exists(tags_file)) {
    tags_df <- data.frame(
      Title = character(),
      Tag = character(),
      Status = character(),
      Notes = character(),
      Tagged_Date = character(),
      stringsAsFactors = FALSE
    )
    write.csv(tags_df, tags_file, row.names = FALSE)
    message(glue("Created tags file: {tags_file}"))
  }
}

#' Mark Seminar as Possible
#'
#' Tag a seminar as a possible candidate for participation
#'
#' @param title Seminar title to match
#' @param notes Optional notes for this tag
#' @param tags_file Path to tags file
#'
#' @return Invisible TRUE if successful
#'
mark_as_possible <- function(
  title,
  notes = "",
  tags_file = TAGS_FILE
) {
  mark_seminar_tag(title, "possible", notes, tags_file)
}

#' Mark Seminar as Interested
#'
#' Tag a seminar as interested/interesting
#'
#' @param title Seminar title to match
#' @param notes Optional notes for this tag
#' @param tags_file Path to tags file
#'
#' @return Invisible TRUE if successful
#'
mark_as_interested <- function(
  title,
  notes = "",
  tags_file = TAGS_FILE
) {
  mark_seminar_tag(title, "interested", notes, tags_file)
}

#' Mark Seminar as Excluded
#'
#' Tag a seminar as excluded/not relevant
#'
#' @param title Seminar title to match
#' @param notes Optional notes for this tag
#' @param tags_file Path to tags file
#'
#' @return Invisible TRUE if successful
#'
mark_as_excluded <- function(
  title,
  notes = "",
  tags_file = TAGS_FILE
) {
  mark_seminar_tag(title, "excluded", notes, tags_file)
}

#' Internal Function: Mark Seminar Tag
#'
#' Core function to add or update a tag
#'
#' @param title Seminar title
#' @param tag Tag to apply ("possible", "interested", "excluded")
#' @param notes Optional notes
#' @param tags_file Path to tags file
#'
#' @return Invisible TRUE
#'
mark_seminar_tag <- function(
  title,
  tag,
  notes = "",
  tags_file = TAGS_FILE
) {
  
  initialize_tags_file(tags_file)
  
  tags_df <- read.csv(tags_file, stringsAsFactors = FALSE)
  
  # Check if seminar already tagged
  existing_row <- which(tolower(tags_df$Title) == tolower(title))
  
  if (length(existing_row) > 0) {
    # Update existing tag
    tags_df[existing_row, "Tag"] <- tag
    tags_df[existing_row, "Status"] <- tag
    tags_df[existing_row, "Notes"] <- notes
    tags_df[existing_row, "Tagged_Date"] <- as.character(Sys.Date())
    message(glue("✓ Updated tag for: {title}"))
  } else {
    # Add new tag
    new_row <- data.frame(
      Title = title,
      Tag = tag,
      Status = tag,
      Notes = notes,
      Tagged_Date = as.character(Sys.Date()),
      stringsAsFactors = FALSE
    )
    tags_df <- rbind(tags_df, new_row)
    message(glue("✓ Tagged as '{tag}': {title}"))
  }
  
  write.csv(tags_df, tags_file, row.names = FALSE)
  invisible(TRUE)
}

#' Get Seminars by Tag
#'
#' Retrieve all seminar titles with a specific tag
#'
#' @param tag Tag to search for
#' @param tags_file Path to tags file
#'
#' @return Character vector of seminar titles
#'
get_seminars_by_tag <- function(tag, tags_file = TAGS_FILE) {
  
  initialize_tags_file(tags_file)
  
  tags_df <- read.csv(tags_file, stringsAsFactors = FALSE)
  
  matching <- tags_df %>%
    filter(tolower(Tag) == tolower(tag)) %>%
    pull(Title)
  
  if (length(matching) == 0) {
    message(glue("No seminars tagged as '{tag}'"))
    return(character())
  }
  
  return(matching)
}

#' Get Tagged Seminars with Details
#'
#' Retrieve tagged seminars joined with full ESTP data
#'
#' @param estp_df ESTP data frame
#' @param tag Optional: filter by specific tag
#' @param tags_file Path to tags file
#'
#' @return Data frame with tagged seminars and details
#'
get_tagged_seminars_with_details <- function(
  estp_df,
  tag = NULL,
  tags_file = TAGS_FILE
) {
  
  initialize_tags_file(tags_file)
  
  tags_df <- read.csv(tags_file, stringsAsFactors = FALSE)
  
  if (nrow(tags_df) == 0) {
    message("No tags recorded yet")
    return(data.frame())
  }
  
  if (!is.null(tag)) {
    tags_df <- tags_df %>%
      filter(tolower(Tag) == tolower(tag))
  }
  
  result <- tags_df %>%
    left_join(
      estp_df,
      by = c("Title" = "Title")
    ) %>%
    select(
      Title,
      Tag,
      Notes,
      Tagged_Date,
      Dates_2026,
      Duration,
      Venue,
      Organizer,
      Deadline
    )
  
  return(result)
}

#' Bulk Tag New Seminars
#'
#' Automatically tag new seminars with a default tag
#'
#' @param new_df Data frame of new seminars
#' @param default_tag Default tag to apply
#' @param tags_file Path to tags file
#'
#' @return Invisible data frame of tagged seminars
#'
bulk_tag_new_seminars <- function(
  new_df,
  default_tag = "possible",
  tags_file = TAGS_FILE
) {
  
  if (nrow(new_df) == 0) {
    message("No new seminars to tag")
    return(data.frame())
  }
  
  message(glue("Tagging {nrow(new_df)} new seminar(s) as '{default_tag}'..."))
  
  for (i in seq_len(nrow(new_df))) {
    title <- new_df[[i, "Title"]]
    mark_seminar_tag(
      title,
      default_tag,
      glue("Auto-tagged as new seminar"),
      tags_file
    )
  }
  
  return(invisible(new_df))
}

#' Export Tags Report
#'
#' Export all tags to a timestamped CSV report
#'
#' @param output_dir Directory for report
#' @param tags_file Path to tags file
#'
#' @return Invisible path to exported file
#'
export_tags <- function(output_dir = "reports", tags_file = TAGS_FILE) {
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  initialize_tags_file(tags_file)
  
  tags_df <- read.csv(tags_file, stringsAsFactors = FALSE)
  
  timestamp <- format(Sys.Date(), "%Y%m%d")
  filename <- glue("{output_dir}/tagged_seminars_report_{timestamp}.csv")
  
  write.csv(tags_df, filename, row.names = FALSE)
  message(glue("✓ Exported tags report: {filename}"))
  
  invisible(filename)
}

#' Print Tags Summary
#'
#' Display summary of all tagged seminars
#'
#' @param tags_file Path to tags file
#'
print_tags_summary <- function(tags_file = TAGS_FILE) {
  
  initialize_tags_file(tags_file)
  
  tags_df <- read.csv(tags_file, stringsAsFactors = FALSE)
  
  message("\n" %>% rep(3) %>% paste(collapse = "\n"))
  message("=" %>% rep(70) %>% paste(collapse = ""))
  message("🏷️ Seminar Tags Summary")
  message("=" %>% rep(70) %>% paste(collapse = ""))
  
  if (nrow(tags_df) == 0) {
    message("No seminars tagged yet")
    return(invisible(NULL))
  }
  
  # Count by tag
  tag_summary <- tags_df %>%
    group_by(Tag) %>%
    summarise(Count = n(), .groups = "drop") %>%
    arrange(desc(Count))
  
  message(glue("\nTotal Tagged Seminars: {nrow(tags_df)}"))
  message("\nBreakdown by Tag:")
  message("-" %>% rep(70) %>% paste(collapse = ""))
  
  for (i in seq_len(nrow(tag_summary))) {
    tag <- tag_summary[[i, "Tag"]]
    count <- tag_summary[[i, "Count"]]
    message(glue("  • {tag}: {count}"))
  }
  
  # Show recent tags
  message(glue("\nRecent Tags:"))
  message("-" %>% rep(70) %>% paste(collapse = ""))
  
  recent <- tags_df %>%
    arrange(desc(Tagged_Date)) %>%
    slice_head(n = 5) %>%
    select(Title, Tag, Tagged_Date)
  
  for (i in seq_len(nrow(recent))) {
    row <- recent[i, ]
    message(glue("  {row$Tagged_Date} | {row$Tag:10} | {row$Title}"))
  }
  
  message("\n" %>% rep(3) %>% paste(collapse = "\n"))
  
  invisible(tag_summary)
}

#' List Seminars by Tag
#'
#' Pretty-print seminars for a specific tag
#'
#' @param tag Tag to list
#' @param estp_df ESTP data frame (optional for details)
#' @param tags_file Path to tags file
#'
list_seminars_by_tag <- function(
  tag,
  estp_df = NULL,
  tags_file = TAGS_FILE
) {
  
  initialize_tags_file(tags_file)
  
  message(glue("\n📋 Seminars tagged as '{tag}'"))
  message("=" %>% rep(70) %>% paste(collapse = ""))
  
  if (!is.null(estp_df)) {
    seminars <- get_tagged_seminars_with_details(estp_df, tag, tags_file)
    
    if (nrow(seminars) == 0) {
      message("No seminars found")
      return(invisible(NULL))
    }
    
    for (i in seq_len(nrow(seminars))) {
      row <- seminars[i, ]
      message(glue("\n{i}. {row$Title}"))
      message(glue("   📅 {row$Dates_2026} ({row$Duration})"))
      message(glue("   📍 {row$Venue}"))
      message(glue("   🏢 {row$Organizer}"))
      message(glue("   ⏰ Deadline: {row$Deadline}"))
      if (!is.na(row$Notes) && row$Notes != "") {
        message(glue("   📝 {row$Notes}"))
      }
    }
  } else {
    seminars <- get_seminars_by_tag(tag, tags_file)
    
    if (length(seminars) == 0) {
      message("No seminars found")
      return(invisible(NULL))
    }
    
    for (i in seq_len(length(seminars))) {
      message(glue("{i}. {seminars[i]}"))
    }
  }
  
  message("\n" %>% rep(3) %>% paste(collapse = "\n"))
  
  invisible(seminars)
}
