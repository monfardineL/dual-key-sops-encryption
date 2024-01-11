resource "aws_kms_key_policy" "sops_kms_policy" {
  key_id = aws_kms_key.sops.id
  policy = jsonencode({
    Id = "sops-kms-foreign-accounts"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = local.principals
        }

        Resource = "*"
        Sid      = "Enable other accounts IAM Users to use this key"
      },
    ]
    Version = "2012-10-17"
  })
}