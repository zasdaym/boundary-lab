# HashiCorp Boundary Lab

This repository contains resources to play with HashiCorp Boundary. The scenario is to access a PostgreSQL database via Boundary with just-in-time credentials from Vault.

## Access matrix

Some users and groups are created to demonstrate RBAC feature of Boundary.

| User   | Group        | Access   |
|--------|--------------|----------|
| Alvin  | foo-engineer | Readonly |
| Zasda  | foo-engineer | Readonly |
| Arthur | foo-dba      | Full     |
| Thomas | foo-dba      | Full     |

## Quickstart

You can run `./init.sh start` run all the necessary components. The script will do some things:
1. Create necessary roles and permissions on `foo-postgres`. The roles will be used by Vault to create just-in-time credentials.
2. Init the database used by Boundary, and output the initial credentials to be used by Terraform.
3. Run the Boundary and Vault containers.
4. Write credentials to access `foo-postgres` to Vault. The credentials will be used to create just-in-time credentials.
5. Create necessary components on Boundary and Vault via Terraform.
6. Run `. ./source_vars.sh` to set necessary environment variables.
7. Open the Boundary web UI on http://localhost:9200 with user `admin` and password specified in `terraform.tfvars.json`.
