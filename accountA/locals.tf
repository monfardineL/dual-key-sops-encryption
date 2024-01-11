locals {
  principals = concat(["arn:aws:iam::${var.accountID}:root"], [for id in var.kms_principals_acc_ids : "arn:aws:iam::${id}:root"])
}