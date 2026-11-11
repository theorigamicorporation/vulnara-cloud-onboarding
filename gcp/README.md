# Google Cloud

Connects one Google Cloud project to Vulnara with a read-only service account.

## What it creates

| Resource | Purpose |
|---|---|
| Workload identity pool `vulnara` | Holds the trust in Vulnara's issuer |
| OIDC provider `vulnara` in that pool | Accepts tokens from the issuer only when the subject equals the one Vulnara gave you |
| Service account `vulnara-scanner` | The identity Vulnara acts as |
| `roles/iam.workloadIdentityUser` on the service account | Lets only that exact subject act as it |

Project roles granted to the service account:

| Role | Why |
|---|---|
| `roles/iam.securityReviewer` | Read IAM policies |
| `roles/cloudasset.viewer` | Read the resource inventory |
| `roles/browser` | Read the project hierarchy |
| `roles/serviceusage.serviceUsageConsumer` | Call APIs billed to this project |

The script also enables the APIs these reads go through (IAM, IAM Credentials, STS, Resource
Manager, Cloud Asset, Service Usage).

## What is not granted

None of these roles can read Secret Manager values, Cloud Storage objects or function source.
Before every scan Vulnara asks Google Cloud whether the service account holds
`secretmanager.versions.access`, `storage.objects.get` or
`cloudfunctions.functions.sourceCodeGet`, and refuses to scan if it does. Some resource
descriptions, such as Cloud Run and Cloud Functions environment variables, can still come back
in inventory reads; Vulnara drops those values before storing anything.

## Deploy

Download the script from Vulnara: the issuer and the subject for your connection are already
filled in. The copy in this repository holds the placeholders `{{VULNARA_ISSUER}}`,
`{{VULNARA_SUBJECT}}` and `{{VULNARA_AUDIENCE}}`; with it, pass `--issuer` and `--subject` using
the values Vulnara shows. The audience is derived from your project when it is not filled in.

In Cloud Shell, or with `gcloud` signed in as a project owner:

```bash
./setup.sh --project <project-id>
```

Paste the printed project number, pool, provider and service account into Vulnara.

## Remove access

```bash
gcloud iam service-accounts delete vulnara-scanner@<project-id>.iam.gserviceaccount.com
gcloud iam workload-identity-pools delete vulnara --location global --project <project-id>
```

Deleting either one stops access. Remove the project role bindings as well to leave nothing
behind.
