# loadDB.PractI.BannattiA.R
# CS5200 Practicum I – Spring 2026
# Author: Akshay Ashok Bannatti
# Description: Loads data from the CSV and SQLite database into the cloud MySQL database.

for (pkg in c("RMySQL", "DBI", "RSQLite", "lubridate")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}
library(DBI); library(RMySQL); library(RSQLite); library(lubridate)

csv_path <- file.path("data", "restaurant-visits-209874.csv")
sqlite_path <- file.path("data", "restaurants-db-02102026.sqlitedb")

db_host <- Sys.getenv("MYSQL_HOST",     "mysql-28668c4b-dmspracticum.a.aivencloud.com")
db_port <- as.integer(Sys.getenv("MYSQL_PORT", "15136"))
db_name <- Sys.getenv("MYSQL_DBNAME",   "defaultdb")
db_user <- Sys.getenv("MYSQL_USER",     "avnadmin")
db_password <- Sys.getenv("MYSQL_PASSWORD", "AVNS_IViZllANiN9ObvmKOnU")
db_ssl_ca <- Sys.getenv("MYSQL_SSL_CA",   "C:/Users/admin/OneDrive/Documents/Practicum 1/CS5200.Practicum-I.BannattiA/CA Certificate.pem")

if (nchar(db_ssl_ca) > 0) {
  mydb <- dbConnect(RMySQL::MySQL(), host = db_host, port = db_port,
                    dbname = db_name, user = db_user, password = db_password,
                    ssl.ca = db_ssl_ca)
} else {
  mydb <- dbConnect(RMySQL::MySQL(), host = db_host, port = db_port,
                    dbname = db_name, user = db_user, password = db_password)
}
sqlite_con <- dbConnect(RSQLite::SQLite(), dbname = sqlite_path)
cat("Connected to both databases.\n")

batch_insert <- function(con, table, df, batch_size = 500) {
  if (nrow(df) == 0) return(invisible(NULL))
  cols <- paste0("`", colnames(df), "`", collapse = ", ")
  n_batches <- ceiling(nrow(df) / batch_size)
  for (i in seq_len(n_batches)) {
    start <- (i - 1) * batch_size + 1
    end   <- min(i * batch_size, nrow(df))
    chunk <- df[start:end, , drop = FALSE]
    vals  <- apply(chunk, 1, function(row) {
      escaped <- sapply(row, function(v) {
        if (is.na(v)) "NULL"
        else paste0("'", gsub("'", "''", as.character(v)), "'")
      })
      paste0("(", paste(escaped, collapse = ", "), ")")
    })
    sql <- paste0("INSERT INTO `", table, "` (", cols, ") VALUES ",
                  paste(vals, collapse = ",\n"), ";")
    tryCatch(dbExecute(con, sql),
             error = function(e) cat("Insert error batch", i, ":", conditionMessage(e), "\n"))
  }
  cat("Loaded", nrow(df), "rows into", table, "\n")
}

cat("Reading CSV...\n")
df.orig <- read.csv(csv_path, stringsAsFactors = FALSE, na.strings = c("", "NA"))
cat("Rows in CSV:", nrow(df.orig), "\n")

cat("\n--- Loading restaurants ---\n")
rest_sqlite <- dbGetQuery(sqlite_con, "SELECT rID AS restaurant_id, RestaurantName AS restaurant_name,
                                              City AS city, State AS state,
                                              hasTableService AS has_table_service FROM restaurants")
rest_sqlite$has_table_service <- ifelse(
  tolower(rest_sqlite$has_table_service) == "yes", 1L, 0L)
batch_insert(mydb, "restaurants", rest_sqlite)

cat("\n--- Loading servers ---\n")
srv_sqlite <- dbGetQuery(sqlite_con,
                         "SELECT EmpID AS emp_id, ServerName AS server_name,
          StartDateHired AS start_date_hired, EndDateHired AS end_date_hired,
          HourlyRate AS hourly_rate, BirthDate AS birth_date,
          SSN AS ssn, CAST(rID AS INTEGER) AS restaurant_id
   FROM servers")

parse_date_col <- function(x) {
  x[x == ""] <- NA
  as.character(as.Date(x, tryFormats = c("%Y-%m-%d", "%m/%d/%Y")))
}
srv_sqlite$start_date_hired <- parse_date_col(srv_sqlite$start_date_hired)
srv_sqlite$end_date_hired <- parse_date_col(srv_sqlite$end_date_hired)
srv_sqlite$birth_date <- parse_date_col(srv_sqlite$birth_date)

batch_insert(mydb, "servers", srv_sqlite)

cat("\n--- Loading meal_types ---\n")
meal_names <- unique(df.orig$MealType[!is.na(df.orig$MealType)])
meal_df <- data.frame(meal_type_name = meal_names, stringsAsFactors = FALSE)
batch_insert(mydb, "meal_types", meal_df)
meal_map   <- dbGetQuery(mydb, "SELECT meal_type_id, meal_type_name FROM meal_types")

cat("\n--- Loading payment_methods ---\n")
pay_names <- unique(df.orig$PaymentMethod[!is.na(df.orig$PaymentMethod)])
pay_df <- data.frame(payment_method_name = pay_names, stringsAsFactors = FALSE)
batch_insert(mydb, "payment_methods", pay_df)
pay_map <- dbGetQuery(mydb, "SELECT payment_method_id, payment_method_name FROM payment_methods")

cat("\n--- Processing customers ---\n")
cust_df <- df.orig[!is.na(df.orig$CustomerPhone) | !is.na(df.orig$CustomerEmail), ]
cust_unique <- unique(cust_df[, c("CustomerName", "CustomerPhone", "CustomerEmail", "LoyaltyMember")])
colnames(cust_unique) <- c("customer_name", "customer_phone", "customer_email", "loyalty_member")
cust_unique$loyalty_member <- ifelse(cust_unique$loyalty_member %in% c("TRUE", "true", TRUE), 1L, 0L)

by_phone <- cust_unique[!is.na(cust_unique$customer_phone), ]
by_phone <- by_phone[!duplicated(by_phone$customer_phone), ]

by_email <- cust_unique[is.na(cust_unique$customer_phone) & !is.na(cust_unique$customer_email), ]
by_email <- by_email[!duplicated(by_email$customer_email), ]
cust_final <- rbind(by_phone, by_email)

batch_insert(mydb, "customers", cust_final)
cat("Customers loaded:", nrow(cust_final), "\n")

cust_map <- dbGetQuery(mydb,
                       "SELECT customer_id, customer_phone, customer_email FROM customers")

cat("\n--- Loading visits ---\n")

df <- df.orig 

df$PartySize[df$PartySize == 99] <- NA

df$VisitDate[df$VisitDate == "0000-00-00"] <- NA
df <- df[!is.na(df$VisitDate), ]

df$ordered_alcohol <- ifelse(tolower(df$orderedAlcohol) %in% c("yes", "true"), 1L, 0L)

meal_idx <- match(df$MealType, meal_map$meal_type_name)
df$meal_type_id <- meal_map$meal_type_id[meal_idx]

pay_idx <- match(df$PaymentMethod, pay_map$payment_method_name)
df$payment_method_id <- pay_map$payment_method_id[pay_idx]

df$emp_id <- suppressWarnings(as.integer(df$ServerEmpID))

valid_emp <- dbGetQuery(mydb, "SELECT emp_id FROM servers")$emp_id
df$emp_id[!(df$emp_id %in% valid_emp)] <- NA

phone_lookup <- setNames(cust_map$customer_id, cust_map$customer_phone)
email_lookup <- setNames(cust_map$customer_id, cust_map$customer_email)
df$customer_id <- phone_lookup[df$CustomerPhone]
missing_cust <- is.na(df$customer_id)
df$customer_id[missing_cust] <- email_lookup[df$CustomerEmail[missing_cust]]

visits_df <- data.frame(
  restaurant_id     = df$RestaurantID,
  emp_id            = df$emp_id,
  customer_id       = df$customer_id,
  visit_date        = df$VisitDate,
  visit_time        = ifelse(df$VisitTime == "" | is.na(df$VisitTime), NA, df$VisitTime),
  meal_type_id      = df$meal_type_id,
  party_size        = df$PartySize,
  wait_time         = ifelse(is.na(df$WaitTime), 0L, as.integer(df$WaitTime)),
  food_bill         = df$FoodBill,
  tip_amount        = df$TipAmount,
  food_discount_pct = df$FoodDiscountPercentage,
  payment_method_id = df$payment_method_id,
  ordered_alcohol   = df$ordered_alcohol,
  alcohol_bill      = df$AlcoholBill,
  stringsAsFactors  = FALSE
)

visits_df <- visits_df[!is.na(visits_df$restaurant_id) &
                         !is.na(visits_df$meal_type_id) &
                         !is.na(visits_df$payment_method_id), ]

cat("Visits to insert:", nrow(visits_df), "\n")
batch_insert(mydb, "visits", visits_df, batch_size = 1000)

dbDisconnect(mydb)
dbDisconnect(sqlite_con)
cat("\nAll data loaded. Disconnected.\n")
