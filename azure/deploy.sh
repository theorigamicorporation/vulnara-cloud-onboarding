#!/usr/bin/env bash
# Give Vulnara read-only access to one Azure subscription.
# Runs in Azure Cloud Shell or anywhere the Azure CLI is signed in with rights
# to create a managed identity and assign roles on the subscription.
#
#   ./deploy.sh --subscription <id> [--subject vulnara:conn:<id>] [--issuer <url>]
#   Downloaded from Vulnara, the subject and issuer are already filled in.
#   [--resource-group vulnara-scanner]
#              [--location westeurope] [--identity vulnara-scanner]
set -euo pipefail

subscription=""
subject="{{VULNARA_SUBJECT}}"
issuer="{{VULNARA_ISSUER}}"
resource_group="vulnara-scanner"
location="westeurope"
identity="vulnara-scanner"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription) subscription="$2"; shift 2 ;;
    --subject) subject="$2"; shift 2 ;;
    --issuer) issuer="$2"; shift 2 ;;
    --resource-group) resource_group="$2"; shift 2 ;;
    --location) location="$2"; shift 2 ;;
    --identity) identity="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$subscription" ]]; then
  echo "--subscription is required" >&2
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

az account set --subscription "$subscription"

az group create --name "$resource_group" --location "$location" \
  --tags managed-by=vulnara-cloud-onboarding --output none

az identity create --name "$identity" --resource-group "$resource_group" \
  --location "$location" --tags managed-by=vulnara-cloud-onboarding --output none

az identity federated-credential create \
  --name vulnara \
  --identity-name "$identity" \
  --resource-group "$resource_group" \
  --issuer "$issuer" \
  --subject "$subject" \
  --audiences api://AzureADTokenExchange \
  --output none

principal_id="$(az identity show --name "$identity" --resource-group "$resource_group" --query principalId -o tsv)"
client_id="$(az identity show --name "$identity" --resource-group "$resource_group" --query clientId -o tsv)"
tenant_id="$(az account show --query tenantId -o tsv)"

az role assignment create \
  --assignee-object-id "$principal_id" \
  --assignee-principal-type ServicePrincipal \
  --role Reader \
  --scope "/subscriptions/${subscription}" \
  --output none

echo
echo "Paste these into Vulnara:"
echo "  Tenant ID:       $tenant_id"
echo "  Client ID:       $client_id"
echo "  Subscription ID: $subscription"
