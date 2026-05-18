# ESTP Monitor

Monitoring the ESTP program for changes and automating seminar tracking and reporting.

## Overview

This project automates monitoring of the European Statistical Training Programme (ESTP) to:
- Track new seminar additions
- Generate various reports with seminar details and dates
- Create a shortlist of possible seminars for review
- Send Slack notifications for updates

## Repository Structure

```
├── estp_monitor.R              # Main monitoring script (hash-based change detection)
├── estp-data-table.R           # Data extraction and parsing script
├── estp_reports.R              # Report generation functions (NEW)
├── estp_tags.R                 # Seminar tagging and classification system (NEW)
├── estp_pipeline.R             # Integrated pipeline combining all features (NEW)
├── estp-notify-slack.R         # Slack notification with formatted details
├── estp-notify-slack-simple.R  # Simple Slack notification
├── estp_data.csv               # Current ESTP seminars data
├── estp_table_latest.csv       # Latest scraped table
└── estp_table_hash.txt         # Hash of last known state
```

## Features

### 1. **Seminar Monitoring** (`estp_monitor.R`)
- Automatically scrapes ESTP website for updates
- Uses hash-based comparison to detect changes
- Triggers notifications on new seminars

### 2. **Report Generation** (`estp_reports.R`) - Issue #1 Solution
Generates comprehensive reports on seminars:
- **New Seminars Report**: Details of newly added seminars with dates and deadlines
- **Organizer Report**: Grouped by organizer with seminar counts
- **Venue Report**: Grouped by location/venue
- **Summary Report**: Overall statistics and key metrics

**Usage:**
```r
source("estp_reports.R")

# Generate all reports
export_reports(estp_df, new_df = new_programs_df, output_dir = "reports")

# Individual report generation
new_report <- generate_new_seminars_report(new_programs_df)
org_report <- generate_seminars_by_organizer_report(estp_df)
venue_report <- generate_seminars_by_venue_report(estp_df)
summary <- generate_comprehensive_report(estp_df)
```

### 3. **Seminar Tagging System** (`estp_tags.R`) - Issue #2 Solution
Marks seminars as "possible", "interested", or "excluded" for review:

**Key Functions:**
- `mark_as_possible(title, notes)` - Mark a seminar as potential candidate
- `mark_as_interested(title, notes)` - Mark as interested
- `mark_as_excluded(title, notes)` - Mark as excluded
- `get_seminars_by_tag(tag)` - Retrieve all seminars with a tag
- `get_tagged_seminars_with_details()` - Get tagged seminars with full data
- `bulk_tag_new_seminars(new_df, tag)` - Auto-tag new seminars
- `generate_tags_report()` - Generate report of all tagged seminars

**Usage:**
```r
source("estp_tags.R")

# Mark seminars
mark_as_possible("Advanced Python for Official Statistics", 
                 notes = "Relevant for data team")

# Get all possible seminars
possible_seminars <- get_seminars_by_tag("possible")

# Generate tags report
generate_tags_report()
```

### 4. **Integrated Pipeline** (`estp_pipeline.R`)
Complete automation combining all features:

```r
source("estp_pipeline.R")

# Run complete pipeline
result <- main_estp_pipeline(
  data_file = "estp_data.csv",
  tags_file = "estp_seminar_tags.csv",
  output_dir = "reports",
  notify_slack = TRUE
)

print_pipeline_summary(result)
```

**Pipeline Steps:**
1. Load ESTP data
2. Detect new seminars
3. Auto-tag new seminars as "possible"
4. Generate comprehensive reports
5. Send Slack notification

## Slack Integration

### Setup
Set the environment variable with your Slack webhook URL:
```bash
export ESTPSLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Notification Features
- Detailed new seminar notifications (with dates, venues, deadlines)
- Automatic trigger on content changes
- Formatted messages with key information

## Data Files

- **estp_data.csv** - Main data file with current seminars
- **estp_table_latest.csv** - Latest scraped version
- **estp_seminar_tags.csv** - Tagging records (auto-created)
- **reports/** - Generated reports directory (timestamped files)

## Output Examples

### Report Files Generated
- `reports/new_seminars_20260518.csv` - New seminars with dates
- `reports/seminars_by_organizer_20260518.csv` - Organizer grouping
- `reports/seminars_by_venue_20260518.csv` - Venue grouping
- `reports/summary_report_20260518.csv` - Summary statistics
- `reports/tagged_seminars_report_20260518.csv` - Tagged seminars

### Tags File Structure
```csv
Title,Tag,Status,Notes,Tagged_Date
"Advanced Python for Official Statistics","possible","possible","Relevant for team","2026-05-18"
"Introduction to AI for Official Statistics","interested","interested","ML research","2026-05-18"
```

## Scheduling

Run the pipeline on a schedule using:

**Linux/Mac (cron):**
```bash
0 8 * * * Rscript -e 'source("estp_pipeline.R"); main_estp_pipeline()'
```

**Windows (Task Scheduler):**
```
Rscript.exe -e "source('estp_pipeline.R'); main_estp_pipeline()"
```

## Requirements

R packages:
- `rvest` - Web scraping
- `dplyr` - Data manipulation
- `digest` - Hash generation
- `httr` - HTTP requests for Slack
- `glue` - String formatting
- `stringr` - String operations
- `tidyr` - Data tidying

Install with:
```r
install.packages(c("rvest", "dplyr", "digest", "httr", "glue", "stringr", "tidyr"))
```

Or use `renv`:
```r
renv::restore()
```

## Future Development

- [ ] Enhanced date parsing for flexible date formats
- [ ] Database integration for historical tracking
- [ ] Web dashboard for monitoring
- [ ] Email report generation
- [ ] Advanced filtering and search capabilities
- [ ] Automated recommendation system for seminars
