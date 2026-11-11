# Azure

Connects one Azure subscription to Vulnara with a read-only managed identity.

## What it creates

| Resource | Purpose |
|---|---|
| Resource group `vulnara-scanner` | Holds the identity |
| User-assigned managed identity `vulnara-scanner` | The identity Vulnara acts as |
| Federated identity credential `vulnara` on it | Trusts Vulnara's issuer for the subject Vulnara gave you, with audience `api://AzureADTokenExchange`, and nothing else |
| `Reader` role assignment on the subscription | Read access to resource configuration |

## What is not granted

`Reader` cannot list storage account keys, read app settings or connection strings, or read Key
Vault secrets, because those are separate list and data actions. Before every scan Vulnara reads
the identity's own permissions on the subscription and refuses to scan if it holds any data action
or key-listing action.

Directory (Entra ID) checks are not included: they need Microsoft Graph permissions, which this
template does not grant.

## Deploy

Download the script or the Bicep file from Vulnara: the issuer and the subject for your
connection are already filled in. The copies in this repository hold the placeholders
`{{VULNARA_ISSUER}}` and `{{VULNARA_SUBJECT}}`; with those, pass `--issuer` and `--subject` to
the script, or `issuer=` and `subject=` to the deployment, using the values Vulnara shows.

With the Azure CLI, for example in Azure Cloud Shell:

```bash
./deploy.sh --subscription <subscription-id>
```

Or as a deployment at subscription scope:

```bash
az deployment sub create --location westeurope --template-file main.bicep
```

Paste the printed tenant ID and client ID into Vulnara.

## Remove access

Delete the resource group (`az group delete --name vulnara-scanner`) and the `Reader` role
assignment for the identity on the subscription. Deleting the identity alone also stops access.
