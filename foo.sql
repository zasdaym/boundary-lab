REVOKE CREATE ON SCHEMA public FROM PUBLIC;

CREATE ROLE dba noinherit;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL PRIVILEGES ON TABLES TO dba;

CREATE ROLE reader noinherit;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO reader;
