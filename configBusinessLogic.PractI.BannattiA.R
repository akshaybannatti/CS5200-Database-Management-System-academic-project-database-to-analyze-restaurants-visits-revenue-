# configBusinessLogic.PractI.BannattiA.R
# Practicum I – Spring 2026
# Author: Akshay Ashok Bannatti
# Description: Creates stored procedures storeNewServer and updateServer in MySQL,
#              and runs a testing harness to verify both procedures.

for (pkg in c("RMySQL", "DBI")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}
library(DBI); library(RMySQL)

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
cat("Connected.\n")

run_sql <- function(con, sql) {
  tryCatch(dbExecute(con, sql),
           error = function(e) cat("SQL Error:", conditionMessage(e), "\n"))
}

run_sql(mydb, "DROP PROCEDURE IF EXISTS storeNewServer;")
run_sql(mydb, "DROP PROCEDURE IF EXISTS updateServer;")

run_sql(mydb, "
CREATE PROCEDURE storeNewServer(
  IN  p_emp_id          INT,
  IN  p_server_name     VARCHAR(100),
  IN  p_start_date      DATE,
  IN  p_end_date        DATE,
  IN  p_hourly_rate     DECIMAL(6,2),
  IN  p_birth_date      DATE,
  IN  p_ssn             CHAR(11),
  IN  p_restaurant_id   INT,
  OUT p_status          VARCHAR(200)
)
BEGIN
  DECLARE v_exists INT DEFAULT 0;

  SELECT COUNT(*) INTO v_exists
  FROM servers
  WHERE server_name = p_server_name
    AND birth_date  = p_birth_date;

  IF v_exists > 0 THEN
    SET p_status = CONCAT('ERROR: Server ', p_server_name,
                          ' born on ', p_birth_date, ' already exists.');
  ELSE
    INSERT INTO servers (emp_id, server_name, start_date_hired, end_date_hired,
                         hourly_rate, birth_date, ssn, restaurant_id)
    VALUES (p_emp_id, p_server_name, p_start_date, p_end_date,
            p_hourly_rate, p_birth_date, p_ssn, p_restaurant_id);
    SET p_status = CONCAT('SUCCESS: Server ', p_server_name, ' added with emp_id=', p_emp_id);
  END IF;
END;
")


run_sql(mydb, "
CREATE PROCEDURE updateServer(
  IN  p_emp_id          INT,
  IN  p_server_name     VARCHAR(100),
  IN  p_start_date      DATE,
  IN  p_end_date        DATE,
  IN  p_hourly_rate     DECIMAL(6,2),
  IN  p_birth_date      DATE,
  IN  p_ssn             CHAR(11),
  IN  p_restaurant_id   INT,
  OUT p_status          VARCHAR(200)
)
BEGIN
  DECLARE v_exists     INT DEFAULT 0;
  DECLARE v_rest_valid INT DEFAULT 0;

  -- Check server exists
  SELECT COUNT(*) INTO v_exists FROM servers WHERE emp_id = p_emp_id;
  IF v_exists = 0 THEN
    SET p_status = CONCAT('ERROR: No server with emp_id=', p_emp_id, ' found.');
  -- Check restaurant exists
  ELSEIF p_restaurant_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_rest_valid
    FROM restaurants WHERE restaurant_id = p_restaurant_id;
    IF v_rest_valid = 0 THEN
      SET p_status = CONCAT('ERROR: restaurant_id=', p_restaurant_id, ' does not exist.');
    -- Validate hourly rate
    ELSEIF p_hourly_rate IS NOT NULL AND p_hourly_rate <= 0 THEN
      SET p_status = 'ERROR: hourly_rate must be positive.';
    ELSE
      UPDATE servers
      SET server_name = COALESCE(p_server_name,   server_name),
          start_date_hired = COALESCE(p_start_date,    start_date_hired),
          end_date_hired = p_end_date,
          hourly_rate = COALESCE(p_hourly_rate,   hourly_rate),
          birth_date = COALESCE(p_birth_date,    birth_date),
          ssn = COALESCE(p_ssn,           ssn),
          restaurant_id = COALESCE(p_restaurant_id, restaurant_id)
      WHERE emp_id = p_emp_id;
      SET p_status = CONCAT('SUCCESS: Server emp_id=', p_emp_id, ' updated.');
    END IF;
  ELSE
    -- restaurant_id is NULL — still allow other field updates
    UPDATE servers
    SET server_name = COALESCE(p_server_name,   server_name),
        start_date_hired = COALESCE(p_start_date,    start_date_hired),
        end_date_hired  = p_end_date,
        hourly_rate = COALESCE(p_hourly_rate,   hourly_rate),
        birth_date = COALESCE(p_birth_date,    birth_date),
        ssn = COALESCE(p_ssn,           ssn)
    WHERE emp_id = p_emp_id;
    SET p_status = CONCAT('SUCCESS: Server emp_id=', p_emp_id, ' updated (restaurant unchanged).');
  END IF;
END;
")

cat("Stored procedures created.\n\n")

run_sp_and_report <- function(con, call_sql, expected_contains, test_label) {
  tryCatch({
    dbExecute(con, call_sql)
    status <- dbGetQuery(con, "SELECT @status AS status;")$status
    passed <- grepl(expected_contains, status, ignore.case = TRUE)
    cat(sprintf("[%s] %s\n  Result: %s\n\n",
                if (passed) "PASS" else "FAIL", test_label, status))
  }, error = function(e) {
    cat(sprintf("[FAIL] %s\n  Error: %s\n\n", test_label, conditionMessage(e)))
  })
}

cat("===== storeNewServer Tests =====\n\n")

run_sp_and_report(mydb,
                  "CALL storeNewServer(99999, 'Test, Person', '2024-01-01', NULL,
                        15.00, '1990-05-20', '000-00-0000', 100, @status);",
                  "SUCCESS",
                  "Add new server (expect SUCCESS)")

run_sp_and_report(mydb,
                  "CALL storeNewServer(99998, 'Test, Person', '2024-01-01', NULL,
                        15.00, '1990-05-20', '000-00-0001', 100, @status);",
                  "ERROR",
                  "Add duplicate server (expect ERROR)")

run_sql(mydb, "DELETE FROM servers WHERE emp_id = 99999;")

cat("===== updateServer Tests =====\n\n")

run_sql(mydb, "
INSERT IGNORE INTO servers (emp_id, server_name, start_date_hired, hourly_rate,
                              birth_date, ssn, restaurant_id)
VALUES (99990, 'UpdateTest, Sam', '2024-01-01', 12.00, '1985-03-15', '111-22-3333', 100);
")

run_sp_and_report(mydb,
                  "CALL updateServer(99990, 'UpdateTest, Sam', '2024-01-01', NULL,
                     16.50, '1985-03-15', '111-22-3333', 100, @status);",
                  "SUCCESS",
                  "Update existing server hourly rate (expect SUCCESS)")

run_sp_and_report(mydb,
                  "CALL updateServer(88888, 'Ghost, Person', '2024-01-01', NULL,
                     16.50, '1985-03-15', '111-22-3333', 100, @status);",
                  "ERROR",
                  "Update non-existent server (expect ERROR)")

run_sp_and_report(mydb,
                  "CALL updateServer(99990, 'UpdateTest, Sam', '2024-01-01', NULL,
                     -5.00, '1985-03-15', '111-22-3333', 100, @status);",
                  "ERROR",
                  "Update with negative hourly rate (expect ERROR)")

run_sp_and_report(mydb,
                  "CALL updateServer(99990, 'UpdateTest, Sam', '2024-01-01', NULL,
                     16.50, '1985-03-15', '111-22-3333', 9999, @status);",
                  "ERROR",
                  "Update with non-existent restaurant_id (expect ERROR)")

run_sql(mydb, "DELETE FROM servers WHERE emp_id = 99990;")

cat("===== All Tests Complete =====\n")
dbDisconnect(mydb)
cat("Disconnected.\n")
