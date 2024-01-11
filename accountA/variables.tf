variable "accountID" {
  type        = number
  description = "Current AWS Account ID"
}

variable "region" {
  default     = "eu-west-1"
  description = "AWS region"
}

variable "kms_principals_acc_ids" {
  type        = list(string)
  default     = ["111111111111"]
  description = "List of Account IDs of other accounts on same project to be included as principals on SOPS KMS Key usage"
}
