	export BOUNDARY_ADDR=http://localhost:9200
	export BOUNDARY_KEYRING_TYPE=secret-service
	export BOUNDARY_AUTH_METHOD_ID=$(terraform output -raw fazz_auth_method_id)
	export BOUNDARY_SCOPE_ID=$(terraform output -raw foo_scope_id)
