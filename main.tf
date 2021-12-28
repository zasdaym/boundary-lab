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

data "vault_generic_secret" "foo" {
  path = "secret/foo"
}

resource "vault_database_secret_backend_connection" "foo" {
  backend       = vault_mount.database.path
  name          = "foo"
  allowed_roles = ["foo-reader", "foo-dba"]

  postgresql {
    connection_url = "postgres://${data.vault_generic_secret.foo.data["POSTGRES_USER"]}:${data.vault_generic_secret.foo.data["POSTGRES_PASSWORD"]}@foo-postgres:5432/foo?sslmode=disable"
  }
}

resource "vault_database_secret_backend_role" "foo_reader" {
  backend     = vault_mount.database.path
  name        = "foo-reader"
  db_name     = vault_database_secret_backend_connection.foo.name
  default_ttl = 1800
  max_ttl     = 3600

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' inherit",
    "GRANT reader TO \"{{name}}\"",
  ]
}

resource "vault_database_secret_backend_role" "foo_dba" {
  backend = vault_mount.database.path
  name    = "foo-dba"
  db_name = vault_database_secret_backend_connection.foo.name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' inherit",
    "GRANT dba TO \"{{name}}\"",
  ]
}

resource "vault_token" "boundary" {
  display_name = "boundary-controller"
  renewable    = true
  no_parent    = true
  period       = "24h"

  policies = [
    vault_policy.boundary.name,
  ]
}

provider "boundary" {
  addr                            = var.boundary_addr
  auth_method_id                  = var.boundary_auth_method_id
  password_auth_method_login_name = var.boundary_password_auth_method_login_name
  password_auth_method_password   = var.boundary_password_auth_method_password
}

resource "boundary_scope" "global" {
  scope_id     = "global"
  global_scope = true
}

resource "boundary_scope" "fazz_org" {
  scope_id                 = boundary_scope.global.id
  name                     = "fazz"
  description              = "Fazz organization"
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_auth_method" "fazz_userpass" {
  scope_id = boundary_scope.fazz_org.id
  type     = "password"
}

resource "boundary_scope" "foo_project" {
  scope_id                 = boundary_scope.fazz_org.id
  name                     = "foo"
  description              = "Foo project"
  auto_create_admin_role   = true
  auto_create_default_role = true
}

locals {
  foo_dbas = [
    "arthur",
    "thomas",
  ]

  foo_engineers = [
    "alvin",
    "zasda",
  ]
}

resource "boundary_account" "foo_dbas" {
  for_each       = toset(local.foo_dbas)
  auth_method_id = boundary_auth_method.fazz_userpass.id
  type           = "password"
  login_name     = each.key
  password       = "P@ssw0rd"
}

resource "boundary_user" "foo_dbas" {
  for_each    = boundary_account.foo_dbas
  scope_id    = boundary_scope.fazz_org.id
  account_ids = [each.value.id]
}

resource "boundary_group" "foo_dba" {
  scope_id    = boundary_scope.fazz_org.id
  name        = "foo-dba"
  description = "Foo DBA"
  member_ids  = [for user in boundary_user.foo_dbas : user.id]
}

resource "boundary_role" "foo_dba" {
  scope_id       = boundary_scope.fazz_org.id
  name           = "foo-dba"
  grant_scope_id = boundary_scope.foo_project.id

  grant_strings = [
    "id=${boundary_target.foo_postgres_dba.id};actions=read,authorize-session",
    "id=*;type=target;actions=list",
    "id=*;type=session;actions=list",
  ]

  principal_ids = [boundary_group.foo_dba.id]
}

resource "boundary_account" "foo_engineers" {
  for_each       = toset(local.foo_engineers)
  auth_method_id = boundary_auth_method.fazz_userpass.id
  type           = "password"
  login_name     = each.key
  password       = "P@ssw0rd"
}

resource "boundary_user" "foo_engineers" {
  for_each    = boundary_account.foo_engineers
  scope_id    = boundary_scope.fazz_org.id
  account_ids = [each.value.id]
}

resource "boundary_group" "foo_engineer" {
  scope_id    = boundary_scope.fazz_org.id
  name        = "foo-engineer"
  description = "Foo Engineer"
  member_ids  = [for user in boundary_user.foo_engineers : user.id]
}

resource "boundary_role" "foo_engineer" {
  scope_id       = boundary_scope.fazz_org.id
  name           = "foo-engineer"
  grant_scope_id = boundary_scope.foo_project.id

  grant_strings = [
    "id=${boundary_target.foo_postgres_reader.id};actions=read,authorize-session",
    "id=*;type=target;actions=list",
    "id=*;type=session;actions=list",
  ]

  principal_ids = [boundary_group.foo_engineer.id]
}

resource "boundary_credential_store_vault" "primary" {
  scope_id = boundary_scope.foo_project.id
  name     = "Primary Vault"
  address  = "http://vault:8200"
  token    = vault_token.boundary.client_token
}

resource "boundary_credential_library_vault" "foo_dba" {
  name                = "foo-dba"
  credential_store_id = boundary_credential_store_vault.primary.id
  path                = "database/creds/foo-dba"
  http_method         = "GET"
}

resource "boundary_credential_library_vault" "foo_reader" {
  name                = "foo-reader"
  credential_store_id = boundary_credential_store_vault.primary.id
  path                = "database/creds/foo-reader"
  http_method         = "GET"
}

resource "boundary_host_catalog" "foo_default" {
  scope_id    = boundary_scope.foo_project.id
  name        = "default"
  description = "Foo default host catalog"
  type        = "static"
}

resource "boundary_host" "foo_postgres_0" {
  name            = "foo-postgres-0"
  address         = "foo-postgres"
  host_catalog_id = boundary_host_catalog.foo_default.id
  type            = "static"
}

resource "boundary_host_set" "foo_postgres" {
  name            = "foo-postgres"
  host_catalog_id = boundary_host_catalog.foo_default.id
  type            = "static"

  host_ids = [
    boundary_host.foo_postgres_0.id,
  ]
}

resource "boundary_target" "foo_postgres_dba" {
  scope_id                 = boundary_scope.foo_project.id
  name                     = "foo-postgres-dba"
  type                     = "tcp"
  default_port             = "5432"
  session_connection_limit = 100

  host_source_ids = [
    boundary_host_set.foo_postgres.id,
  ]

  application_credential_source_ids = [
    boundary_credential_library_vault.foo_dba.id,
  ]
}

resource "boundary_target" "foo_postgres_reader" {
  scope_id                 = boundary_scope.foo_project.id
  name                     = "foo-postgres-reader"
  type                     = "tcp"
  default_port             = "5432"
  session_connection_limit = 100

  host_source_ids = [
    boundary_host_set.foo_postgres.id,
  ]

  application_credential_source_ids = [
    boundary_credential_library_vault.foo_reader.id,
  ]
}

