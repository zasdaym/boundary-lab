output "fazz_auth_method_id" {
  value = boundary_auth_method.fazz_userpass.id
}

output "fazz_scope_id" {
  value = boundary_scope.fazz_org.id
}

output "foo_scope_id" {
  value = boundary_scope.foo_project.id
}
