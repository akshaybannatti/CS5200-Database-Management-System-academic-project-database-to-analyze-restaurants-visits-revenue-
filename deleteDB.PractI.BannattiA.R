# deleteDB.PractI.BannattiA.R
# Practicum I – Spring 2026
# Author: Akshay Ashok Bannatti
# Description: Drops all tables from the cloud MySQL database (use to re-initialize).

if (!requireNamespace("RMySQL", quietly = TRUE)) install.packages("RMySQL")
if (!requireNamespace("DBI",    quietly = TRUE)) install.packages("DBI")

library(DBI)
library(RMySQL)

db_host <- Sys.getenv("MYSQL_HOST",     "mysql-28668c4b-dmspracticum.a.aivencloud.com")
db_port <- as.integer(Sys.getenv("MYSQL_PORT", "15136"))
db_name <- Sys.getenv("MYSQL_DBNAME",   "defaultdb")
db_user <- Sys.getenv("MYSQL_USER",     "avnadmin")
db_password <- Sys.getenv("MYSQL_PASSWORD", "AVNS_IViZllANiN9ObvmKOnU")
db_ssl_ca <- Sys.getenv("MYSQL_SSL_CA",   "C:/Users/admin/OneDrive/Documents/Practicum 1/CS5200.Practicum-I.BannattiA/CA Certificate.pem")

if (nchar(db_ssl_ca) > 0) {
  mydb <- dbConnect(RMySQL::MySQL(),
                    host = db_host, port = db_port, dbname = db_name,
                    user = db_user, password = db_password, ssl.ca = db_ssl_ca)
} else {
  mydb <- dbConnect(RMySQL::MySQL(),
                    host = db_host, port = db_port, dbname = db_name,
                    user = db_user, password = db_password)
}

cat("Connected. Dropping tables...\n")

dbExecute(mydb, "SET FOREIGN_KEY_CHECKS = 0;")

tables_to_drop <- c("visits", "customers", "servers", "payment_methods",
                    "meal_types", "restaurants")

for (tbl in tables_to_drop) {
  tryCatch({
    dbExecute(mydb, paste0("DROP TABLE IF EXISTS ", tbl, ";"))
    cat("Dropped table:", tbl, "\n")
  }, error = function(e) {
    cat("Error dropping", tbl, ":", conditionMessage(e), "\n")
  })
}

dbExecute(mydb, "SET FOREIGN_KEY_CHECKS = 1;")

cat("All tables dropped.\n")
dbDisconnect(mydb)
cat("Disconnected.\n")
