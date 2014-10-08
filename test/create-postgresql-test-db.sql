-- see the README file in this directory for more information about this script
-- more generally, you can execute this script via:
--    sudo su postgres -c "psql -Upostgres -f {FILENAME}"
CREATE USER sqlclient_test_user WITH CREATEDB PASSWORD 'password';
CREATE DATABASE sqlclient_test_db OWNER sqlclient_test_user;
