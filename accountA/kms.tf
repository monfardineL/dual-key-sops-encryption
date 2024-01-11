resource "aws_kms_key" "sops" {
  description             = "SOPS encryption KMS Key"
  deletion_window_in_days = 10

}

resource "aws_kms_alias" "sops" {
  name          = "alias/sops-key"
  target_key_id = aws_kms_key.sops.key_id
}
