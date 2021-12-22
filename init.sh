#!/usr/bin/env bash

set -o errexit

up() {
	docker-compose up --detach postgres
	docker-compose run --rm wait -c postgres:5432
	docker-compose run --rm boundary database init -config=/boundary/config.hcl -skip-scopes-creation -format=json \
		| jq '.auth_method | {boundary_auth_method_id: .auth_method_id, boundary_password_auth_method_password: .password}' \
		> terraform.tfvars.json
	docker-compose up --detach
	docker-compose exec vault vault login token=P@ssw0rd
	docker-compose exec vault vault kv put secret/neu POSTGRES_USER=neu POSTGRES_PASSWORD=P@ssw0rd
}

down() {
	docker-compose down --volumes
	rm terraform.tfvars.json
}

show_usage() {
	echo "Usage: $0 start|stop"
}

case $1 in
	start)
		up
		;;
	stop)
		down
		;;
	*)
		show_usage
		;;
esac
