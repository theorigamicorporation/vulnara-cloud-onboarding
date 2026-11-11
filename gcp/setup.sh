#!/usr/bin/env bash
# Give Vulnara read-only access to one Google Cloud project.
# Runs in Cloud Shell or anywhere gcloud is signed in as a project owner.
#
#   ./setup.sh --project <project-id> [--subject vulnara:conn:<id>] [--issuer <url>]
#              [--audience <provider audience>]
#   Downloaded from Vulnara, the subject and issuer are already filled in.
#   [--pool vulnara] [--provider vulnara]
#              [--service-account vulnara-scanner]
set -euo pipefail

project=""
subject="{{VULNARA_SUBJECT}}"
issuer="{{VULNARA_ISSUER}}"
audience="{{VULNARA_AUDIENCE}}"
pool="vulnara"
provider="vulnara"
sa_name="vulnara-scanner"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) project="$2"; shift 2 ;;
    --subject) subject="$2"; shift 2 ;;
    --issuer) issuer="$2"; shift 2 ;;
    --audience) audience="$2"; shift 2 ;;
    --pool) pool="$2"; shift 2 ;;
    --provider) provider="$2"; shift 2 ;;
    --service-account) sa_name="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$project" ]]; then
  echo "--project is required" >&2
  exit 2
fi
if [[ ! "$issuer" =~ ^https:// ]]; then
  echo "--issuer must be the https URL shown in Vulnara" >&2
  exit 2
fi
if [[ ! "$subject" =~ ^vulnara:conn:[0-9a-f-]{36}$ ]]; then
  echo "--subject must look like vulnara:conn:<id>, as shown in Vulnara" >&2
  exit 2
fi

project_number="$(gcloud projects describe "$project" --format='value(projectNumber)')"
sa_email="${sa_name}@${project}.iam.gserviceaccount.com"
provider_resource="projects/${project_number}/locations/global/workloadIdentityPools/${pool}/providers/${provider}"
if [[ -z "$audience" || "$audience" == "{{"* ]]; then
  audience="//iam.googleapis.com/${provider_resource}"
fi
principal="principal://iam.googleapis.com/projects/${project_number}/locations/global/workloadIdentityPools/${pool}/subject/${subject}"

echo "Enabling the APIs the scan reads through..."
gcloud services enable --project "$project" \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  cloudresourcemanager.googleapis.com \
  cloudasset.googleapis.com \
  serviceusage.googleapis.com

if ! gcloud iam workload-identity-pools describe "$pool" \
    --project "$project" --location global >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "$pool" \
    --project "$project" --location global \
    --display-name "Vulnara"
fi

condition="assertion.sub == '${subject}'"
if gcloud iam workload-identity-pools providers describe "$provider" \
    --project "$project" --location global \
    --workload-identity-pool "$pool" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers update-oidc "$provider" \
    --project "$project" --location global \
    --workload-identity-pool "$pool" \
    --issuer-uri "$issuer" \
    --allowed-audiences "$audience" \
    --attribute-mapping "google.subject=assertion.sub" \
    --attribute-condition "$condition"
else
  gcloud iam workload-identity-pools providers create-oidc "$provider" \
    --project "$project" --location global \
    --workload-identity-pool "$pool" \
    --display-name "Vulnara" \
    --issuer-uri "$issuer" \
    --allowed-audiences "$audience" \
    --attribute-mapping "google.subject=assertion.sub" \
    --attribute-condition "$condition"
fi

if ! gcloud iam service-accounts describe "$sa_email" --project "$project" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$sa_name" \
    --project "$project" \
    --display-name "Vulnara scanner (read-only)"
fi

for role in \
  roles/iam.securityReviewer \
  roles/cloudasset.viewer \
  roles/browser \
  roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding "$project" \
    --member "serviceAccount:${sa_email}" \
    --role "$role" \
    --condition None \
    --quiet >/dev/null
done

gcloud iam service-accounts add-iam-policy-binding "$sa_email" \
  --project "$project" \
  --role roles/iam.workloadIdentityUser \
  --member "$principal" \
  --quiet >/dev/null

echo
echo "Paste these into Vulnara:"
echo "  Project number:  $project_number"
echo "  Pool:            $pool"
echo "  Provider:        $provider"
echo "  Service account: $sa_email"
