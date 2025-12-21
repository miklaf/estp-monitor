#install.packages("httr")


library(httr)
library(glue)

slack_webhook_url <- Sys.getenv("ESTPSLACK_WEBHOOK_URL")

msg <- glue("*📢 ESTP Program Monitor*\nThis is a automated notification that the ESTP program has new seminars.")

POST(
  url = slack_webhook_url,
  body = list(text = msg),
  encode = "json"
)
