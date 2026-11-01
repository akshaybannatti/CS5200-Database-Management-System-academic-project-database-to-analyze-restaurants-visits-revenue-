# createDB.PractI.BannattiA.R
# Practicum I – Spring 2026
# Author: Akshay Ashok Bannatti
# Description: Creates the normalized 3NF MySQL schema for restaurant visits data.

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
                    host     = db_host,
                    port     = db_port,
                    dbname   = db_name,
                    user     = db_user,
                    password = db_password,
                    ssl.ca   = db_ssl_ca)
} else {
  mydb <- dbConnect(RMySQL::MySQL(),
                    host     = db_host,
                    port     = db_port,
                    dbname   = db_name,
                    user     = db_user,
                    password = db_password)
}

cat("Connected to MySQL database successfully.\n")

run_sql <- function(con, sql) {
  tryCatch({
    dbExecute(con, sql)
  }, error = function(e) {
    cat("SQL Error:", conditionMessage(e), "\n")
    cat("Statement:", sql, "\n")
  })
}

# Create Tables 

# 1. Restaurants
run_sql(mydb, "
CREATE TABLE IF NOT EXISTS restaurants (
  restaurant_id     INT          NOT NULL,
  restaurant_name   VARCHAR(100) NOT NULL DEFAULT '',
  city              VARCHAR(100) NOT NULL DEFAULT '',
  state             CHAR(2)      NOT NULL DEFAULT '',
  has_table_service TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (restaurant_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
")

# 2. Servers 
run_sql(mydb, "
CREATE TABLE IF NOT EXISTS servers (
  emp_id          INT          NOT NULL,
  server_name     VARCHAR(100) NOT NULL DEFAULT '',
  start_date_hired DATE        DEFAULT NULL,
  end_date_hired   DATE        DEFAULT NULL,
  hourly_rate      DECIMAL(6,2) NOT NULL DEFAULT 0.00,
  birth_date       DATE         DEFAULT NULL,
  ssn              CHAR(11)     DEFAULT NULL,
  restaurant_id    INT          NOT NULL,
  PRIMARY KEY (emp_id),
  CONSTRAINT fk_servers_restaurant FOREIGN KEY (restaurant_id)
    REFERENCES restaurants(restaurant_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
")

# 3. Customers
run_sql(mydb, "
CREATE TABLE IF NOT EXISTS customers (
  customer_id    INT          NOT NULL AUTO_INCREMENT,
  customer_name  VARCHAR(150) DEFAULT NULL,
  customer_phone VARCHAR(20)  DEFAULT NULL,
  customer_email VARCHAR(150) DEFAULT NULL,
  loyalty_member TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (customer_id),
  UNIQUE KEY uq_customer_phone (customer_phone),
  UNIQUE KEY uq_customer_email (customer_email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
")

# 4. Meal Types
run_sql(mydb, "
CREATE TABLE IF NOT EXISTS meal_types (
  meal_type_id   INT          NOT NULL AUTO_INCREMENT,
  meal_type_name VARCHAR(50)  NOT NULL,
  PRIMARY KEY (meal_type_id),
  UNIQUE KEY uq_meal_type_name (meal_type_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
")

# 5. Payment Methods 
run_sql(mydb, "
CREATE TABLE IF NOT EXISTS payment_methods (
  payment_method_id   INT         NOT NULL AUTO_INCREMENT,
  payment_method_name VARCHAR(50) NOT NULL,
  PRIMARY KEY (payment_method_id),
  UNIQUE KEY uq_pay_method_name (payment_method_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
")

# 6. Visits
run_sql(mydb, "
CREATE TABLE IF NOT EXISTS visits (
  visit_id           INT            NOT NULL AUTO_INCREMENT,
  restaurant_id      INT            NOT NULL,
  emp_id             INT            DEFAULT NULL,
  customer_id        INT            DEFAULT NULL,
  visit_date         DATE           NOT NULL,
  visit_time         TIME           DEFAULT NULL,
  meal_type_id       INT            NOT NULL,
  party_size         TINYINT        DEFAULT NULL,
  wait_time          SMALLINT       NOT NULL DEFAULT 0,
  food_bill          DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  tip_amount         DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  food_discount_pct  DECIMAL(5,4)   NOT NULL DEFAULT 0.0000,
  payment_method_id  INT            NOT NULL,
  ordered_alcohol    TINYINT(1)     NOT NULL DEFAULT 0,
  alcohol_bill       DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  PRIMARY KEY (visit_id),
  CONSTRAINT fk_visits_restaurant   FOREIGN KEY (restaurant_id)     REFERENCES restaurants(restaurant_id),
  CONSTRAINT fk_visits_server       FOREIGN KEY (emp_id)            REFERENCES servers(emp_id),
  CONSTRAINT fk_visits_customer     FOREIGN KEY (customer_id)       REFERENCES customers(customer_id),
  CONSTRAINT fk_visits_meal_type    FOREIGN KEY (meal_type_id)      REFERENCES meal_types(meal_type_id),
  CONSTRAINT fk_visits_pay_method   FOREIGN KEY (payment_method_id) REFERENCES payment_methods(payment_method_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
")

cat("All tables created successfully.\n")

dbDisconnect(mydb)
cat("Disconnected from MySQL.\n")
