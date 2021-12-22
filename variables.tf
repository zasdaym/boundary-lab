variable "vault_addr" {
  type    = string
  default = "http://localhost:8200"
}

variable "vault_token" {
  type    = string
  default = "P@ssw0rd"
}

variable "boundary_addr" {
  type    = string
  default = "http://localhost:9200"
}

variable "boundary_auth_method_id" {
  type = string
}

variable "boundary_password_auth_method_login_name" {
  type    = string
  default = "admin"
}

variable "boundary_password_auth_method_password" {
  type    = string
  default = "P@ssw0rd"
}
