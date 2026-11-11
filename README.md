# Vulnara cloud onboarding

Templates and scripts that connect an AWS account, a Google Cloud project or an Azure
subscription to Vulnara cloud scanning.

Each one gives Vulnara **read-only access to configuration**, through identity federation:

- **No keys.** You never create an access key, a service account key or a client secret. Your
  cloud trusts Vulnara's identity issuer for one connection only, identified by the subject
  Vulnara shows you (`vulnara:conn:<id>`).
- **Read configuration, never secrets or data.** Vulnara can see how your resources are set up.
  It cannot read secret values, object contents, database items, function code or environment
  variables. On AWS this is enforced by an explicit deny, because the AWS read-only policies
  alone include some secret-bearing reads.
- **Checked on every scan.** Before each scan Vulnara tests whether the access it was given can
  read secrets, without reading any. If it can, the scan does not run and Vulnara tells you which
  permission to remove.
- **You can revoke at any time** by deleting what the template created. Nothing on the Vulnara
  side needs to change.

| Cloud | Files | What it creates |
|---|---|---|
| AWS | [aws/](aws/) | An IAM OIDC provider and the role `VulnaraScanner` |
| Google Cloud | [gcp/](gcp/) | A workload identity pool and provider, and the service account `vulnara-scanner` |
| Azure | [azure/](azure/) | A resource group with the managed identity `vulnara-scanner`, and a `Reader` assignment |

Start in Vulnara: add a cloud account there first. Vulnara shows the subject and the issuer you
pass to these templates, then asks for the values they print.

Read the files before you run them. They are short on purpose.
