library(DBI)
library(RSQLite)
library(dplyr)
library(glue)

# ============================================================================
# ESTP Database Management Module
# Provides SQLite-based persistent storage for seminars and tags
# ============================================================================

# Configuration
ESTP_DB_PATH <- "estp_monitor.db"

#' Initialize ESTP Database
#'
#' Creates database with schema for seminars, tags, and change log
#'
#' @param db_path Path to database file
#'
#' @return Invisible connection object
#'
init_estp_db <- function(db_path = ESTP_DB_PATH) {
  
  # Connect to database (creates if doesn't exist)
  conn <- dbConnect(SQLite(), db_path)
  
  # Create seminars table if doesn't exist
  if (!dbExistsTable(conn, "seminars")) {
    dbExecute(conn, "
      CREATE TABLE seminars (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT UNIQUE NOT NULL,
        dates_2026 TEXT,
        duration TEXT,
        venue TEXT,
        deadline TEXT,
        organizer TEXT,
        first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ")
    message("✓ Created 'seminars' table")
  }
  
  # Create tags table if doesn't exist
  if (!dbExistsTable(conn, "seminar_tags")) {
    dbExecute(conn, "
      CREATE TABLE seminar_tags (
        tag_id INTEGER PRIMARY KEY AUTOINCREMENT,
        seminar_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        status TEXT,
        notes TEXT,
        tagged_date DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (seminar_id) REFERENCES seminars(id),
        UNIQUE(seminar_id, tag)
      )
    ")
    message("✓ Created 'seminar_tags' table")
  }
  
  # Create change log table if doesn't exist
  if (!dbExistsTable(conn, "change_log")) {
    dbExecute(conn, "
      CREATE TABLE change_log (
        log_id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        action TEXT,
        seminar_title TEXT,
        details TEXT
      )
    ")
    message("✓ Created 'change_log' table")
  }
  
  dbDisconnect(conn)
  message(glue("✓ Database initialized: {db_path}"))
  
  invisible(conn)
}

#' Get Database Connection
#'
#' @param db_path Path to database file
#'
#' @return SQLite connection object
#'
get_db_connection <- function(db_path = ESTP_DB_PATH) {
  if (!file.exists(db_path)) {
    init_estp_db(db_path)
  }
  dbConnect(SQLite(), db_path)
}

#' Insert or Update Seminars
#'
#' Store seminars in database, updating if already exist
#'
#' @param seminars_df Data frame with seminar data
#' @param db_path Path to database file
#'
#' @return Data frame with insert results
#'
db_insert_seminars <- function(seminars_df, db_path = ESTP_DB_PATH) {
  
  conn <- get_db_connection(db_path)
  
  inserted <- 0
  updated <- 0
  
  for (i in seq_len(nrow(seminars_df))) {
    row <- seminars_df[i, ]
    
    # Check if seminar exists
    existing <- dbGetQuery(conn, 
      "SELECT id FROM seminars WHERE title = ?",
      params = list(row$Title)
    )
    
    if (nrow(existing) > 0) {
      # Update
      dbExecute(conn,
        "UPDATE seminars SET 
          dates_2026 = ?, duration = ?, venue = ?, 
          deadline = ?, organizer = ?, last_updated = CURRENT_TIMESTAMP
         WHERE id = ?",
        params = list(row$Dates_2026, row$Duration, row$Venue,
                     row$Deadline, row$Organizer, existing$id[1])
      )
      updated <- updated + 1
      
      # Log update
      dbExecute(conn,
        "INSERT INTO change_log (action, seminar_title, details) 
         VALUES (?, ?, ?)",
        params = list("UPDATE", row$Title, 
                     glue("Updated seminar details"))
      )
    } else {
      # Insert
      dbExecute(conn,
        "INSERT INTO seminars 
         (title, dates_2026, duration, venue, deadline, organizer)
         VALUES (?, ?, ?, ?, ?, ?)",
        params = list(row$Title, row$Dates_2026, row$Duration,
                     row$Venue, row$Deadline, row$Organizer)
      )
      inserted <- inserted + 1
      
      # Log insert
      dbExecute(conn,
        "INSERT INTO change_log (action, seminar_title, details) 
         VALUES (?, ?, ?)",
        params = list("INSERT", row$Title, "New seminar added")
      )
    }
  }
  
  dbDisconnect(conn)
  
  message(glue("✓ Database update: {inserted} inserted, {updated} updated"))
  
  invisible(data.frame(inserted = inserted, updated = updated))
}

#' Get Seminars from Database
#'
#' Query seminars with optional filtering
#'
#' @param organizer Filter by organizer (optional)
#' @param venue Filter by venue (optional)
#' @param db_path Path to database file
#'
#' @return Data frame of seminars
#'
db_get_seminars <- function(organizer = NULL, venue = NULL, db_path = ESTP_DB_PATH) {
  
  conn <- get_db_connection(db_path)
  
  query <- "SELECT * FROM seminars WHERE 1=1"
  params <- list()
  
  if (!is.null(organizer)) {
    query <- paste0(query, " AND organizer = ?")
    params <- append(params, organizer)
  }
  
  if (!is.null(venue)) {
    query <- paste0(query, " AND venue = ?")
    params <- append(params, venue)
  }
  
  query <- paste0(query, " ORDER BY deadline")
  
  result <- if (length(params) > 0) {
    dbGetQuery(conn, query, params = params)
  } else {
    dbGetQuery(conn, query)
  }
  
  dbDisconnect(conn)
  
  return(result)
}

#' Get New Seminars from Database
#'
#' Retrieve seminars added in the last N days
#'
#' @param days Number of days to look back (default: 7)
#' @param db_path Path to database file
#'
#' @return Data frame of new seminars
#'
db_get_new_seminars <- function(days = 7, db_path = ESTP_DB_PATH) {
  
  conn <- get_db_connection(db_path)
  
  result <- dbGetQuery(conn, 
    "SELECT * FROM seminars 
     WHERE first_seen >= datetime('now', '-' || ? || ' days')
     ORDER BY first_seen DESC",
    params = list(days)
  )
  
  dbDisconnect(conn)
  
  return(result)
}

#' Tag Seminar in Database
#'
#' Add or update tag for a seminar
#'
#' @param title Seminar title
#' @param tag Tag value (possible, interested, excluded)
#' @param notes Optional notes
#' @param db_path Path to database file
#'
#' @return Invisible TRUE
#'
db_tag_seminar <- function(title, tag, notes = "", db_path = ESTP_DB_PATH) {
  
  conn <- get_db_connection(db_path)
  
  # Get seminar ID
  seminar <- dbGetQuery(conn,
    "SELECT id FROM seminars WHERE title = ?",
    params = list(title)
  )
  
  if (nrow(seminar) == 0) {
    message(glue("✗ Seminar not found: {title}"))
    dbDisconnect(conn)
    return(invisible(FALSE))
  }
  
  seminar_id <- seminar$id[1]
  
  # Check if tag exists
  existing_tag <- dbGetQuery(conn,
    "SELECT tag_id FROM seminar_tags WHERE seminar_id = ? AND tag = ?",
    params = list(seminar_id, tag)
  )
  
  if (nrow(existing_tag) > 0) {
    # Update
    dbExecute(conn,
      "UPDATE seminar_tags SET notes = ?, tagged_date = CURRENT_TIMESTAMP 
       WHERE tag_id = ?",
      params = list(notes, existing_tag$tag_id[1])
    )
    message(glue("✓ Updated tag for: {title}"))
  } else {
    # Insert
    dbExecute(conn,
      "INSERT INTO seminar_tags (seminar_id, tag, status, notes) 
       VALUES (?, ?, ?, ?)",
      params = list(seminar_id, tag, tag, notes)
    )
    message(glue("✓ Tagged as '{tag}': {title}"))
  }
  
  dbDisconnect(conn)
  
  invisible(TRUE)
}

#' Get Tagged Seminars from Database
#'
#' Retrieve seminars with specific tag
#'
#' @param tag Tag to filter by
#' @param db_path Path to database file
#'
#' @return Data frame of tagged seminars with details
#'
db_get_tagged_seminars <- function(tag, db_path = ESTP_DB_PATH) {
  
  conn <- get_db_connection(db_path)
  
  result <- dbGetQuery(conn,
    "SELECT s.*, st.tag, st.notes, st.tagged_date
     FROM seminars s
     JOIN seminar_tags st ON s.id = st.seminar_id
     WHERE st.tag = ?
     ORDER BY st.tagged_date DESC",
    params = list(tag)
  )
  
  dbDisconnect(conn)
  
  return(result)
}

#' Get Database Statistics
#'
#' Calculate summary statistics from database
#'
#' @param db_path Path to database file
#'
#' @return Data frame with statistics
#'
db_get_statistics <- function(db_path = ESTP_DB_PATH) {
  
  conn <- get_db_connection(db_path)
  
  total <- dbGetQuery(conn, "SELECT COUNT(*) as count FROM seminars")$count
  
  by_organizer <- dbGetQuery(conn,
    "SELECT organizer, COUNT(*) as count FROM seminars 
     GROUP BY organizer ORDER BY count DESC"
  )
  
  by_tag <- dbGetQuery(conn,
    "SELECT tag, COUNT(DISTINCT seminar_id) as count FROM seminar_tags 
     GROUP BY tag ORDER BY count DESC"
  )
  
  recent_changes <- dbGetQuery(conn,
    "SELECT action, COUNT(*) as count FROM change_log 
     GROUP BY action"
  )
  
  dbDisconnect(conn)
  
  return(list(
    total_seminars = total,
    by_organizer = by_organizer,
    by_tag = by_tag,
    recent_changes = recent_changes
  ))
}

#' Export Database to CSV
#'
#' Export seminars and tags to timestamped CSV files
#'
#' @param output_dir Directory for exports
#' @param db_path Path to database file
#'
#' @return Invisible list of exported files
#'
db_export_to_csv <- function(output_dir = "reports", db_path = ESTP_DB_PATH) {
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  conn <- get_db_connection(db_path)
  
  timestamp <- format(Sys.Date(), "%Y%m%d")
  
  # Export seminars
  seminars <- dbGetQuery(conn, "SELECT * FROM seminars ORDER BY deadline")
  seminars_file <- glue("{output_dir}/seminars_db_{timestamp}.csv")
  write.csv(seminars, seminars_file, row.names = FALSE)
  message(glue("✓ Exported: {seminars_file}"))
  
  # Export tags
  tags <- dbGetQuery(conn,
    "SELECT s.title, st.tag, st.notes, st.tagged_date FROM seminar_tags st
     JOIN seminars s ON st.seminar_id = s.id ORDER BY st.tagged_date DESC"
  )
  tags_file <- glue("{output_dir}/tags_db_{timestamp}.csv")
  write.csv(tags, tags_file, row.names = FALSE)
  message(glue("✓ Exported: {tags_file}"))
  
  # Export change log
  changes <- dbGetQuery(conn, "SELECT * FROM change_log ORDER BY timestamp DESC")
  changes_file <- glue("{output_dir}/changes_log_{timestamp}.csv")
  write.csv(changes, changes_file, row.names = FALSE)
  message(glue("✓ Exported: {changes_file}"))
  
  dbDisconnect(conn)
  
  invisible(list(
    seminars = seminars_file,
    tags = tags_file,
    changes = changes_file
  ))
}

#' Print Database Statistics
#'
#' Display formatted database statistics
#'
#' @param db_path Path to database file
#'
print_db_statistics <- function(db_path = ESTP_DB_PATH) {
  
  stats <- db_get_statistics(db_path)
  
  message("\n" %>% rep(3) %>% paste(collapse = "\n"))
  message("=" %>% rep(70) %>% paste(collapse = ""))
  message("📊 ESTP Database Statistics")
  message("=" %>% rep(70) %>% paste(collapse = ""))
  
  message(glue("\n📈 Total Seminars: {stats$total_seminars}"))
  
  message("\n🏢 By Organizer (Top 10):")
  message("-" %>% rep(70) %>% paste(collapse = ""))
  org_display <- head(stats$by_organizer, 10)
  for (i in seq_len(nrow(org_display))) {
    message(glue("  {org_display[i, 'organizer']:40} | {org_display[i, 'count']:3}"))
  }
  
  message("\n🏷️ By Tag:")
  message("-" %>% rep(70) %>% paste(collapse = ""))
  for (i in seq_len(nrow(stats$by_tag))) {
    message(glue("  {stats$by_tag[i, 'tag']:40} | {stats$by_tag[i, 'count']:3}"))
  }
  
  message("\n📋 Recent Changes:")
  message("-" %>% rep(70) %>% paste(collapse = ""))
  for (i in seq_len(nrow(stats$recent_changes))) {
    message(glue("  {stats$recent_changes[i, 'action']:40} | {stats$recent_changes[i, 'count']:3}"))
  }
  
  message("\n" %>% rep(3) %>% paste(collapse = "\n"))
}

#' Backup Database
#'
#' Create backup copy of database with timestamp
#'
#' @param db_path Path to database file
#' @param backup_dir Directory for backups
#'
#' @return Path to backup file
#'
db_backup <- function(db_path = ESTP_DB_PATH, backup_dir = "backups") {
  
  if (!file.exists(db_path)) {
    message("Database does not exist")
    return(invisible(NULL))
  }
  
  if (!dir.exists(backup_dir)) {
    dir.create(backup_dir, recursive = TRUE)
  }
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- glue("{backup_dir}/estp_monitor_backup_{timestamp}.db")
  
  file.copy(db_path, backup_file)
  
  message(glue("✓ Database backed up: {backup_file}"))
  
  invisible(backup_file)
}
