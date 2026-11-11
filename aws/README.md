# AWS

Connects one AWS account to Vulnara with a read-only IAM role.

## What it creates

| Resource | Purpose |
|---|---|
| IAM OIDC provider for the issuer URL | Lets IAM verify tokens from Vulnara. Skipped when the account already has one for the same URL |
| IAM role `VulnaraScanner` | Assumable only through that provider, only by the subject Vulnara gave you, with audience `sts.amazonaws.com` |
| AWS managed policies `SecurityAudit` and `ViewOnlyAccess` | Read access to configuration metadata |
| Inline policy `VulnaraDenySecretsAndData` | An explicit deny on secret and data reads (below) |

Sessions last at most one hour.

## What is denied

The AWS read-only policies include some actions that return secrets or data. The role denies
them explicitly, and an explicit deny wins over any allow, including allows AWS adds to its
managed policies later:

- Secrets Manager secret values, SSM parameter values and history, KMS decrypt
- S3 object contents, DynamoDB items
- Lambda code and configuration (environment variables)
- EC2 password data, instance attributes (user data), launch template data, console output and
  screenshots
- CloudFormation templates, CodeBuild projects, Batch job definitions, ECS task definitions,
  Data Pipeline definitions (all can carry environment variables or inline secrets)
- ECR image layers
- API Gateway API key values

Checks that would need any of these are not run.

## Deploy

Download the template or the script from Vulnara: the issuer and the subject for your connection
are already filled in. The copies in this repository hold the placeholders `{{VULNARA_ISSUER}}`
and `{{VULNARA_SUBJECT}}`; with those, pass `--issuer` and `--subject` to the script, or fill in
`IssuerUrl` and `Subject` in the console, using the values Vulnara shows.

With the AWS CLI, for example in AWS CloudShell:

```bash
./deploy.sh
```

Or in the CloudFormation console: **Create stack**, **Upload a template file**, and choose
`vulnara-scanner.cfn.yaml`.
Set `CreateOidcProvider` to `false` if the account already has a provider for that URL.

Paste the `RoleArn` output into Vulnara.

## Remove access

Delete the stack (`aws cloudformation delete-stack --stack-name vulnara-scanner`). If another
connection still uses the OIDC provider, deploy that connection's stack with
`CreateOidcProvider=false` first, or keep the provider.
