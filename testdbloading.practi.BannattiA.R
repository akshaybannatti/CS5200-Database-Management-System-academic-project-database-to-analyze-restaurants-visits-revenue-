# testDBLoading.PractI.BannattiA.R
# Practicum I  Spring 2026
# Author: Akshay Ashok Bannatti
# Description: Tests that database loading matches source CSV data.

for (pkg in c("RMySQL", "DBI")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}
library(DBI); library(RMySQL)

csv_path <- file.path("data", "restaurant-visits-209874.csv")
db_host <- Sys.getenv("MYSQL_HOST",     "mysql-28668c4b-dmspracticum.a.aivencloud.com")
db_port <- as.integer(Sys.getenv("MYSQL_PORT", "15136"))
db_name <- Sys.getenv("MYSQL_DBNAME",   "defaultdb")
db_user <- Sys.getenv("MYSQL_USER",     "avnadmin")
db_password <- Sys.getenv("MYSQL_PASSWORD", "AVNS_IViZllANiN9ObvmKOnU")
db_ssl_ca <- Sys.getenv("MYSQL_SSL_CA",   "C:/Users/admin/OneDrive/Documents/Practicum 1/CS5200.Practicum-I.BannattiA/CA Certificate.pem")

if (nchar(db_ssl_ca) > 0) {
  mydb <- dbConnect(RMySQL::MySQL(), host = db_host, port = db_port,
                    dbname = db_name, user = db_user, password = db_password, ssl.ca = db_ssl_ca)
} else {
  mydb <- dbConnect(RMySQL::MySQL(), host = db_host, port = db_port,
                    dbname = db_name, user = db_user, password = db_password)
}

cat("Reading CSV...\n")
df.orig <- read.csv(csv_path, stringsAsFactors = FALSE, na.strings = c("", "NA"))
df.orig$PartySize[df.orig$PartySize == 99] <- NA

check_test <- function(description, csv_val, db_val, tol = 0.01) {
  pass <- abs(csv_val - db_val) <= tol
  status <- if (pass) "PASS" else "FAIL"
  cat(sprintf("[%s] %s\n  CSV: %s | DB: %s\n", status, description,
              formatC(csv_val, format = "f", digits = 2),
              formatC(db_val,  format = "f", digits = 2)))
}

check_count <- function(description, csv_val, db_val) {
  pass <- csv_val == db_val
  status <- if (pass) "PASS" else "FAIL"
  cat(sprintf("[%s] %s\n  CSV: %d | DB: %d\n", status, description,
              as.integer(csv_val), as.integer(db_val)))
}

cat("\n===== Data Loading Tests =====\n\n")

csv_rest <- length(unique(df.orig$RestaurantID[!is.na(df.orig$RestaurantID)]))
db_rest  <- dbGetQuery(mydb, "SELECT COUNT(*) AS n FROM restaurants")$n
check_count("Unique restaurants", csv_rest, db_rest)

csv_srv <- length(unique(df.orig$ServerEmpID[df.orig$ServerEmpID != "" & !is.na(df.orig$ServerEmpID)]))
db_srv  <- dbGetQuery(mydb, "SELECT COUNT(*) AS n FROM servers")$n
check_count("Unique servers (from SQLite)", csv_srv, db_srv)

cust_df  <- df.orig[!is.na(df.orig$CustomerPhone) | !is.na(df.orig$CustomerEmail), ]
csv_cust <- nrow(unique(cust_df[, c("CustomerPhone", "CustomerEmail")]))
db_cust  <- dbGetQuery(mydb, "SELECT COUNT(*) AS n FROM customers")$n

cat(sprintf("[INFO] Customers — CSV identifiable rows: %d | DB: %d\n", csv_cust, db_cust))

csv_visits <- nrow(df.orig[df.orig$VisitDate != "0000-00-00" & !is.na(df.orig$VisitDate), ])
db_visits  <- dbGetQuery(mydb, "SELECT COUNT(*) AS n FROM visits")$n
check_count("Total visits", csv_visits, db_visits)

csv_food <- sum(df.orig$FoodBill,    na.rm = TRUE)
csv_alcohol <- sum(df.orig$AlcoholBill, na.rm = TRUE)
csv_tips <- sum(df.orig$TipAmount,   na.rm = TRUE)

db_sums <- dbGetQuery(mydb,
                      "SELECT SUM(food_bill) AS food, SUM(alcohol_bill) AS alcohol, SUM(tip_amount) AS tips
   FROM visits")
db_food <- as.numeric(db_sums$food)
db_alcohol <- as.numeric(db_sums$alcohol)
db_tips <- as.numeric(db_sums$tips)

check_test("Total food bill",    csv_food,    db_food,    tol = 1.0)
check_test("Total alcohol bill", csv_alcohol, db_alcohol, tol = 1.0)
check_test("Total tips",         csv_tips,    db_tips,    tol = 1.0)

cat("\n===== Tests Complete =====\n")
dbDisconnect(mydb)
