variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default     = "udacity"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default     = "westeurope"
}

variable "username" {
  description = "The username"
  default     = "jhon"
}

variable "password" {
  description = "The password to be used in the machine_count"
  default = ";$W+cD?Be=U3T}*x"
}

variable "machine_count" {
  description = "amount of machine_count"
  type        = number
  default     = "2"
}

