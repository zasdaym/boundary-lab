provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}

resource "vault_policy" "boundary" {
  name = "boundary"

  policy = <<EOT
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

path "sys/leases/renew" {
  capabilities = ["update"]
}

path "sys/leases/revoke" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}

path "database/creds/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_mount" "database" {
  path = "database"
  type = "database"
}

data "vault_generic_secret" "neu" {
  path = "secret/neu"
}

resource "vault_database_secret_backend_connection" "neu" {
  backend       = vault_mount.database.path
  name          = "neu"
  allowed_roles = ["foo-reader", "foo-dba"]

  postgresql {
    connection_url = "postgres://${data.vault_generic_secret.neu.data["POSTGRES_USER"]}:${data.vault_generic_secret.neu.data["POSTGRES_PASSWORD"]}@foo-postgres:5432/neu?sslmode=disable"
  }
}

resource "vault_database_secret_backend_role" "neu_reader" {
  backend     = vault_mount.database.path
  name        = "foo-reader"
  db_name     = vault_database_secret_backend_connection.neu.name
  default_ttl = 1800
  max_ttl     = 3600

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' inherit",
    "GRANT reader TO \"{{name}}\"",
  ]
}

resource "vault_database_secret_backend_role" "neu_dba" {
  backend = vault_mount.database.path
  name    = "foo-dba"
  db_name = vault_database_secret_backend_connection.neu.name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' inherit",
    "GRANT dba TO \"{{name}}\"",
  ]
}

provider "boundary" {
  addr                            = var.boundary_addr
  auth_method_id                  = var.boundary_auth_method_id
  password_auth_method_login_name = var.boundary_password_auth_method_login_name
  password_auth_method_password   = var.boundary_password_auth_method_password
}

resource "boundary_scope" "global" {
  global_scope = true
  scope_id     = "global"
}

resource "boundary_scope" "fazz_org" {
  name                     = "fazz"
  description              = "Fazz Organization"
  scope_id                 = boundary_scope.global.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "neu_project" {
  name                   = "neu"
  description            = "Neu Project"
  scope_id               = boundary_scope.fazz_org.id
  auto_create_admin_role = true
}

resource "boundary_scope" "post_project" {
  name                   = "post"
  description            = "POST. Project"
  scope_id               = boundary_scope.fazz_org.id
  auto_create_admin_role = true
}

resource "boundary_host_catalog" "neu_default" {
  name        = "default"
  description = "Neu default host catalog"
  scope_id    = boundary_scope.neu_project.id
  type        = "static"
}

resource "boundary_host" "neu_postgres_0" {
  name            = "foo-postgres-0"
  description     = "Neu Postgres instance"
  address         = "foo-postgres"
  host_catalog_id = boundary_host_catalog.neu_default.id
  type            = "static"
}

resource "boundary_host_set" "neu_postgres" {
  name            = "foo-postgres"
  host_catalog_id = boundary_host_catalog.neu_default.id
  type            = "static"

  host_ids = [
    boundary_host.neu_postgres_0.id,
  ]
}

resource "boundary_target" "neu_postgres" {
  name         = "foo-postgres"
  type         = "tcp"
  default_port = "5432"
  scope_id     = boundary_scope.neu_project.id

  host_source_ids = [
    boundary_host_set.neu_postgres.id
  ]
}
