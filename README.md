# ESTP Monitor

Automated monitoring of the European Statistical Training Programme (ESTP) for seminar tracking, reporting, and intelligent tagging with persistent database storage.

## 🎯 Overview

This project automates the ESTP monitoring workflow to:
- ✅ **Track changes** - Detect new seminars automatically using hash-based comparison
- 📊 **Generate reports** - Create multiple report formats (new seminars, by organizer, by venue, summary statistics)
- 🏷️ **Tag seminars** - Classify seminars as "possible", "interested", or "excluded" for review
- 💾 **Persistent storage** - Store data in SQLite database with full change logging
- 📱 **Send notifications** - Post updates to Slack channels
- 🔄 **Automated pipeline** - Orchestrate all features in a single integrated workflow

## 📁 Repository Structure

```
estp-monitor/
├── README.md                       # This file
├── estp_monitor.R                  # Main monitoring script (hash-based change detection)
├── estp-data-table.R               # Data extraction and HTML parsing
├── estp_reports.R                  # Report generation (multiple formats)
├── estp_tags.R                     # Tagging system for seminar classification
├── estp_db.R                       # SQLite database management module
├── estp_pipeline.R                 # Integrated pipeline orchestrator
├── estp-notify-slack.R             # Slack notifications (advanced)
├── estp-notify-slack-simple.R      # Slack notifications (simple)
├── estp_data.csv                   # Historical seminar data
├── estp_table_latest.csv           # Latest scraped seminars
├── estp_table_hash.txt             # Hash of last known data state
├── renv.lock                       # R package dependencies (renv)
│
├── .github/workflows/
│   ├── estp-monitor.yml            # Main scheduled workflow (Monday 08:00 UTC)
│   ├── estp-monitor-extended.yml   # Extended workflow (Monday 07:00 UTC)
│   └── estp-test.yml               # Manual test workflow
│
└── renv/                           # R environment snapshot
```

## 🚀 Quick Start

### Prerequisites
- R 4.0+
- Required packages: `rvest`, `dplyr`, `stringr`, `httr`, `glue`, `blastula`, `RSQLite`, `DBI`

### Installation

```bash
# Clone the repository
git clone https://github.com/miklaf/estp-monitor.git
cd estp-monitor

# Install R dependencies (using renv)
renv::restore()

# Or install manually
install.packages(c("rvest", "dplyr", "stringr", "httr", "glue", "blastula", "RSQLite", "DBI"))
```

### Basic Usage

#### 1. Initialize the Database
```r
source("estp_db.R")
init_estp_db()
```

#### 2. Run the Main Monitor
```r
source("estp_monitor.R")
# Detects changes and stores data
```

#### 3. Generate Reports
```r
source("estp_reports.R")
source("estp_db.R")

# Generate all reports
reports <- generate_all_reports(estp_df, output_dir = "reports")
```

#### 4. Tag Seminars
```r
source("estp_tags.R")
source("estp_db.R")

# Tag a seminar as "possible"
tag_seminar("Advanced Python for Official Statistics", "possible", notes = "Relevant for team")

# Get all tagged seminars
possible_seminars <- get_tagged_seminars("possible")
```

#### 5. Run Complete Pipeline
```r
source("estp_pipeline.R")
run_estp_pipeline(
  scrape = TRUE,          # Scrape ESTP website
  generate_reports = TRUE, # Create reports
  tag_new = TRUE,         # Tag new seminars
  notify_slack = FALSE    # Optional: send Slack notification
)
```

## 📦 Core Modules

### `estp_monitor.R` - Main Monitoring Script
Detects changes by comparing current ESTP data with a hash of the previous state.

```r
source("estp_monitor.R")
# Outputs: estp_table_latest.csv, estp_table_hash.txt
```

**Features:**
- Hash-based change detection
- Automatic data scraping
- CSV export

---

### `estp_reports.R` - Report Generation
Generates 4 different report types from seminar data.

```r
source("estp_reports.R")

# Generate all reports
reports <- generate_all_reports(estp_df)

# Individual reports
new_report <- generate_new_seminars_report(estp_df)
org_report <- generate_organizer_report(estp_df)
venue_report <- generate_venue_report(estp_df)
summary_report <- generate_summary_report(estp_df)
```

**Report Types:**
1. **New Seminars Report** - Recently added seminars with dates and deadlines
2. **Organizer Report** - Seminars grouped by organization
3. **Venue Report** - Seminars grouped by location
4. **Summary Report** - Statistics and key metrics

**Solves Issue #1:** ✅ Return various reports

---

### `estp_tags.R` - Tagging System
Classifies seminars for easy filtering and review.

```r
source("estp_tags.R")

# Tag a seminar
tag_seminar(
  title = "Advanced Python for Official Statistics",
  tag = "possible",
  notes = "Relevant for team skills"
)

# Retrieve tagged seminars
possible <- get_tagged_seminars("possible")
interested <- get_tagged_seminars("interested")
excluded <- get_tagged_seminars("excluded")

# Get all tags for a seminar
seminar_tags <- get_seminar_tags("Advanced Python for Official Statistics")
```

**Tag Values:**
- `"possible"` - Potentially relevant seminars
- `"interested"` - Definitely interested
- `"excluded"` - Not relevant

**Solves Issue #2:** ✅ Create shortlist of possible seminars

---

### `estp_db.R` - Database Management
SQLite-based persistent storage with automatic change logging.

```r
source("estp_db.R")

# Initialize database
init_estp_db()

# Insert/update seminars
db_insert_seminars(estp_df)

# Query seminars
all_seminars <- db_get_seminars()
by_organizer <- db_get_seminars(organizer = "UNSD")
by_venue <- db_get_seminars(venue = "Online")

# Get new seminars from last 7 days
new <- db_get_new_seminars(days = 7)

# Tag seminars (persistent)
db_tag_seminar("Seminar Title", "possible", notes = "Optional notes")

# Retrieve tagged seminars
tagged <- db_get_tagged_seminars("possible")

# Export to CSV
db_export_to_csv(output_dir = "reports")

# View statistics
print_db_statistics()

# Create backup
db_backup()
```

**Database Tables:**
- `seminars` - All tracked seminars with metadata
- `seminar_tags` - Tags and classifications for each seminar
- `change_log` - Audit trail of all changes

---

### `estp_pipeline.R` - Integrated Pipeline
Orchestrates all components into a single automated workflow.

```r
source("estp_pipeline.R")

run_estp_pipeline(
  scrape = TRUE,            # Step 1: Scrape ESTP website
  generate_reports = TRUE,  # Step 2: Generate all reports
  tag_new = TRUE,          # Step 3: Tag new seminars as "possible"
  notify_slack = FALSE,    # Step 4: Send Slack notification (optional)
  slack_webhook = Sys.getenv("ESTPSLACK_WEBHOOK_URL")
)
```

**Pipeline Steps:**
1. Scrape ESTP website
2. Detect changes
3. Store in database
4. Generate reports
5. Auto-tag new seminars
6. Send Slack notification (optional)
7. Print summary

---

### `estp-notify-slack.R` & `estp-notify-slack-simple.R` - Notifications
Send update notifications to Slack channels.

```r
source("estp-notify-slack-simple.R")

# Send simple notification
send_slack_notification(
  message = "3 new seminars detected!",
  webhook_url = Sys.getenv("ESTPSLACK_WEBHOOK_URL")
)
```

---

## 🤖 Automated Workflows

All workflows are defined in `.github/workflows/` and run automatically on GitHub Actions.

### Main Workflow: `estp-monitor.yml`
- **Trigger:** Every Monday at 08:00 UTC (or manually)
- **Task:** Run main monitor and generate reports
- **Command:** `Rscript estp_monitor.R`

### Extended Workflow: `estp-monitor-extended.yml`
- **Trigger:** Every Monday at 07:00 UTC (or manually)
- **Task:** Run extended data table analysis
- **Command:** `Rscript estp-data-table.R`

### Test Workflow: `estp-test.yml`
- **Trigger:** Manual trigger only
- **Task:** Test Slack notification integration
- **Command:** `Rscript estp-notify-slack-simple.R`

**Configuration:**
All workflows are configured to:
- Install required R packages (including `RSQLite` and `DBI`)
- Auto-commit changes to the repository
- Use Slack webhook from GitHub Secrets

## 🔑 Configuration

### Slack Integration (Optional)

1. Create a Slack Webhook URL:
   - Go to your Slack workspace settings
   - Create an Incoming Webhook
   - Copy the webhook URL

2. Add to GitHub Secrets:
   - Go to repository → Settings → Secrets and variables → Actions
   - Create new secret: `ESTPSLACK_WEBHOOK_URL`
   - Paste your webhook URL

3. Enable in scripts:
```r
# In your R script
webhook_url <- Sys.getenv("ESTPSLACK_WEBHOOK_URL")
if (webhook_url != "") {
  send_slack_notification("Update message", webhook_url)
}
```

## 📊 Outputs

The system generates:

### CSV Files
- `reports/seminars_db_YYYYMMDD.csv` - All seminars in database
- `reports/tags_db_YYYYMMDD.csv` - All tagged seminars
- `reports/changes_log_YYYYMMDD.csv` - Change audit trail
- `reports/report_new_seminars_YYYYMMDD.csv` - New seminars only
- `reports/report_by_organizer_YYYYMMDD.csv` - Grouped by organizer
- `reports/report_by_venue_YYYYMMDD.csv` - Grouped by venue
- `reports/report_summary_YYYYMMDD.csv` - Summary statistics

### Database
- `estp_monitor.db` - SQLite database with all data and history
- `backups/` - Automatic timestamped backups

### Notifications
- Slack messages with summary of changes

## 📋 Issues Resolved

| Issue | Title | Solution |
|-------|-------|----------|
| **#1** | Return various reports | ✅ `estp_reports.R` - Generates 4 report types |
| **#2** | Create shortlist of possible seminars | ✅ `estp_tags.R` + `estp_db.R` - Persistent tagging system |

## 🔄 Workflow Examples

### Example 1: Monitor + Report + Notify
```r
# Full automated workflow
source("estp_pipeline.R")
run_estp_pipeline(
  scrape = TRUE,
  generate_reports = TRUE,
  tag_new = TRUE,
  notify_slack = TRUE
)
```

### Example 2: Tag and Export Specific Seminars
```r
source("estp_db.R")

# Get all seminars
all_seminars <- db_get_seminars()

# Tag Python seminars as "interested"
python_seminars <- all_seminars[grepl("Python", all_seminars$title), ]
for (title in python_seminars$title) {
  db_tag_seminar(title, "interested", notes = "Python training")
}

# Export tagged seminars
tagged_df <- db_get_tagged_seminars("interested")
write.csv(tagged_df, "python_seminars.csv", row.names = FALSE)
```

### Example 3: Generate Reports for a Specific Organizer
```r
source("estp_reports.R")
source("estp_db.R")

# Get seminars from specific organizer
unsd_seminars <- db_get_seminars(organizer = "UNSD")

# Generate report
report <- generate_organizer_report(unsd_seminars)
```

## 📚 Dependencies

| Package | Purpose |
|---------|---------|
| `rvest` | Web scraping HTML |
| `dplyr` | Data manipulation |
| `stringr` | String operations |
| `httr` | HTTP requests |
| `glue` | String interpolation |
| `blastula` | Email formatting (optional) |
| `RSQLite` | SQLite database interface |
| `DBI` | Database connectivity |

## 🛠️ Development

### Adding a New Feature
1. Create a new R file in the root directory
2. Source it in `estp_pipeline.R`
3. Update workflows if needed
4. Add documentation to README

### Testing Locally
```r
# Run pipeline with manual trigger
source("estp_pipeline.R")
run_estp_pipeline(scrape = TRUE, generate_reports = TRUE)

# Check database
source("estp_db.R")
print_db_statistics()
```

## 📝 License

This project is maintained for the ESTP monitoring automation.

## 👤 Author

**miklaf** - GitHub: https://github.com/miklaf

## 🐛 Issues & Feedback

- Report bugs or request features via GitHub Issues
- Check existing issues before creating duplicates
- All issues are tracked and prioritized

---

**Last Updated:** May 2026  
**Status:** ✅ Active & Maintained
