#!/usr/bin/env bash
# Deploy the Vulnara read-only role into the current AWS account.
# Runs in AWS CloudShell or anywhere the AWS CLI is signed in.
#
#   ./deploy.sh [--subject vulnara:conn:<id>] [--issuer <url>]
#   Downloaded from Vulnara, the subject and issuer are already filled in.
#  
#               [--existing-provider] [--stack-name vulnara-scanner] [--region us-east-1]
set -euo pipefail

issuer="{{VULNARA_ISSUER}}"
subject="{{VULNARA_SUBJECT}}"
create_provider="true"
stack_name="vulnara-scanner"
region="${AWS_REGION:-us-east-1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issuer) issuer="$2"; shift 2 ;;
    --subject) subject="$2"; shift 2 ;;
    --existing-provider) create_provider="false"; shift ;;
    --stack-name) stack_name="$2"; shift 2 ;;
    --region) region="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ ! "$subject" =~ ^vulnara:conn:[0-9a-f-]{36}$ ]]; then
  echo "--subject must look like vulnara:conn:<id>, as shown in Vulnara" >&2
  exit 2
fi
if [[ ! "$issuer" =~ ^https:// ]]; then
  echo "--issuer must be the https URL shown in Vulnara" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template="$script_dir/vulnara-scanner.cfn.yaml"
if [[ ! -f "$template" ]]; then
  echo "Template not found next to this script: $template" >&2
  exit 1
fi

issuer_host="${issuer#https://}"
if [[ "$create_provider" == "true" ]] && aws iam list-open-id-connect-providers \
    --query "OpenIDConnectProviderList[].Arn" --output text \
    | tr '\t' '\n' | grep -q "oidc-provider/${issuer_host}\$"; then
  echo "An OIDC provider for $issuer already exists in this account; reusing it."
  create_provider="false"
fi

aws cloudformation deploy \
  --region "$region" \
  --stack-name "$stack_name" \
  --template-file "$template" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    "IssuerUrl=$issuer" \
    "Subject=$subject" \
    "CreateOidcProvider=$create_provider"

role_arn="$(aws cloudformation describe-stacks \
  --region "$region" \
  --stack-name "$stack_name" \
  --query "Stacks[0].Outputs[?OutputKey=='RoleArn'].OutputValue" \
  --output text)"

echo
echo "Paste this into Vulnara:"
echo "  Role ARN: $role_arn"
