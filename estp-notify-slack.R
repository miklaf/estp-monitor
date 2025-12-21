library(dplyr)
library(glue)

library(httr)

# Example: new programs
# new_programs_df <- estp_df[1:2, ]  # demo
slack_webhook_url <- Sys.getenv("ESTPSLACK_WEBHOOK_URL")


msg <- paste(
  "*📢 New ESTP Programs Added:*\n",
  paste(
    apply(new_programs_df, 1, function(r) {
      glue("• *{r['Title']}* — {r['Dates (2026)']} ({r['Duration']}) at {r['Venue']} (Deadline: {r['Deadline']})")
    }),
    collapse = "\n"
  ),
  sep = "\n"
)

# Send to Slack
POST(
  url = slack_webhook_url,
  body = list(text = msg),
  encode = "json"
)
