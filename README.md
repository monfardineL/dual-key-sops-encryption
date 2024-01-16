# dual-key-sops-encryption

This article can also be found on my [dev.to](https://dev.to/monfardinel/encrypting-your-secrets-with-mozilla-sops-using-two-aws-kms-keys-1e3k).

## TL;DR

Just set two distinct KMS Keys ARN, comma separated, into the variable `SOPS_KMS_ARN` prior to using SOPS.

```bash
export SOPS_KMS_ARN="arn:aws:kms:us-east-1:656532927350:key/920aff2e-c5f1-4040-943a-047fa387b27e,arn:aws:kms:ap-southeast-1:656532927350:key/9006a8aa-0fa6-4c14-930e-a2dfb916de1d"
```

## Introduction

Sometimes pushing files to Git would be much easier than storing them in complex encryption management systems, but everyone knows it's not safe to push API Keys, passwords and private keys as plain text (neither base64) to Git, right?
To help on that mission, a very useful tool we can count on is Mozilla SOPS (read more below). And when you are working with multiple cloud accounts (like landing zone on AWS), or in different regions, you can include a extra layer of security by encrypting secrets with two distinct KMS keys. This way, if you ever lose access to one of your KMS keys, you will still be able to retrieve your secrets.

## Mozilla SOPS

[Mozilla SOPS](https://github.com/getsops/sops) (Secrets OPerationS) is an open-source command-line tool for managing and storing secrets. It uses secure encryption methods to encrypt secrets at rest and decrypt them at runtime. SOPS supports a variety of key management systems, including AWS KMS, GCP KMS, Azure Key Vault, and PGP. It's particularly useful in a DevOps context where sensitive data like API keys, passwords, or certificates need to be securely managed and seamlessly integrated into application workflows.

## Setting things up

This example uses Terraform to configure AWS KMS Keys with a policy that permits them to be accessible by other AWS accounts. The same can be done with CloudFormation, directly on AWS Console or even AWS CLI.

Starting by the "root" account, the one that will store our "emergency" key, we gonna need:

- A KMS Key dedicated to SOPS

```hcl
resource "aws_kms_key" "sops" {
  description             = "SOPS encryption KMS Key"
  deletion_window_in_days = 10

}

resource "aws_kms_alias" "sops" {
  name          = "alias/sops-key"
  target_key_id = aws_kms_key.sops.key_id
}
```

- And a policy that allows this key to be used by other accounts

```hcl
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
```

With the use of locals, we can concatenate multiple accounts, so if you have a Platform team managing accounts for your company, new accounts can be easily included there.

```hcl
locals {
  principals = concat(["arn:aws:iam::${var.accountID}:root"], [for id in var.kms_principals_acc_ids : "arn:aws:iam::${id}:root"])
}
```

Now we need a KMS Key in our main account, that don't need to be shared for this use case, and the standard code will work

```hcl
resource "aws_kms_key" "sops" {
  description             = "SOPS encryption KMS Key"
  deletion_window_in_days = 10

}

resource "aws_kms_alias" "sops" {
  name          = "alias/sops-key"
  target_key_id = aws_kms_key.sops.key_id
}
```

## Usage

Now that we have both keys created, getting their ARNs is the next step. In this approach, our KMS keys ARN have the same alias, being the `account ID` the only value that will change between them. So, assuming our Account A has the ID `123456789012` and our account B has the ID `012345678901`, our matching Keys would be:

```text
Account A: arn:aws:kms:eu-west-1:123456789012:alias/sops-key
Account B: arn:aws:kms:eu-west-1:012345678901:alias/sops-key
```

Next step is export both ARNs, comma-separated, as value of `SOPS_KMS_ARN` variable.

```bash
export SOPS_KMS_ARN=arn:aws:kms:eu-west-1:123456789012:alias/sops-key,arn:aws:kms:eu-west-1:012345678901:alias/sops-key
```

Last, just run SOPS, specifying the file you want to create or edit. SOPS supports YAML and JSON, and will always encrypt the values, but not the keys in your file.
The following command creates a new file:

```bash
sops example.yaml.enc
```

And then we can store our values.

```yaml
data:
  - some
  - array
  - elements
```

After closing the editor, our file will look something like this:

```yaml
data:
    - ENC[AES256_GCM,data:v8jQ=,iv:HBE=,aad:21c=,tag:gA==]
    - ENC[AES256_GCM,data:X10=,iv:o8=,aad:CQ=,tag:Hw==]
    - ENC[AES256_GCM,data:KN=,iv:160=,aad:fI4=,tag:tNw==]
sops:
    kms:
        - created_at: 1441570389.775376
          enc: CiC....Pm1Hm
          arn: arn:aws:kms:eu-west-1:123456789012:alias/sops-key
        - created_at: 1441570391.925734
          enc: Ci...awNx
          arn: arn:aws:kms:eu-west-1:012345678901:alias/sops-key
```

And it will be ready to be pushed to your Git repository, with no risk to the integrity of the data.  

Hint: for fast decryption, you can use `-d` parameter and get the file contents printed into the console, or redirected to another file.

```bash
sops -d example.yaml.enc > example.yaml
```

## Protecting Terraform variables

Assuming we could have sensitive values in our Terraform variables, we can make use of SOPS to protect these variables, making them readable locally or in a pipeline only for users with access to our KMS Keys. To do that the first step is to convert our variables file from HCL to JSON, which is a file format supported by both Terraform and SOPS.  
Once the values are stored as JSON, the procedure is the same as above.

```bash
sops variables/production.tfvars.json.enc
```

With the decripted values, Terraform will accept them as input, just like the HCL:

```bash
sops -d variables/production.tfvars.json.enc > variables/production.tfvars.json

terraform plan -var-file=variables/production.tfvars.json -out tfplan
```

## Tips

### Use VSCode as editor

SOPS supports many text editors to manipulate your secrets. If you are a lover of VSCode, the following command will bring it up as editor for the SOPS file you want to edit:

```bash
EDITOR="code --wait" sops variables/production.tfvars.json.enc
```

### Dynamic accounts

In my use cases, my Account A always tends to be static, but the ID for Account B usually changes. The code below can help getting the right account ID, along with the static one, in such case. The only requirements are AWS CLI, previous AWS authentication and the jq tool.

```bash
export SOPS_KMS_ARN="arn:aws:kms:eu-west-1:$(aws sts get-caller-identity --output json | jq '.Account' -r):alias/sops-key,arn:aws:kms:eu-west-1:123456789012:alias/sops-key"
```

### hcl2json

If you have a big HCL file that you want to convert to JSON, [hcl2json](https://github.com/tmccombs/hcl2json) may be the perfect tool to help you on that task.
