-- see the README file in this directory for more information about this script
-- more generally, you can execute this script via:
--    mysql -u root -p < {FILENAME}
CREATE DATABASE IF NOT EXISTS sqlclient_test_db;
CREATE USER 'sqlclient_test_u'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON sqlclient_test_db . * TO 'sqlclient_test_u'@'localhost';
