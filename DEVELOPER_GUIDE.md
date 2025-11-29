# Developer Guide (short)

## Getting access (dev)
Developers in `dev` can get a kubeconfig if their IP is whitelisted and they have Azure AD access:
```bash
bash scripts/get-kubeconfig.sh <resource-group> <cluster-name> ~/.kube/config-dev
```

Assign RBAC in cluster with Azure AD groups and Kubernetes RoleBindings. Example:
- Azure AD group `dev-team` -> Kubernetes `edit` role in `dev` namespace.

## CI/CD
Stage and Prod should be deployed via CI/CD (GitHub Actions or Azure DevOps):
- CI builds images and pushes to ACR (use service principal or managed identity).
- CD uses kubectl/helm and secrets fetched from Key Vault or an external-secrets operator.

## Secrets
- Application secrets stored in Key Vault.
- For runtime in cluster, use Azure Key Vault Provider for Secrets Store CSI Driver, or sync secrets with External Secrets.

## Terraform scripts

We provide small helper scripts to run Terraform using workspace-specific tfvars and to automatically detect the Azure subscription when possible.

- `scripts/terraform.sh` — Bash helper (Linux/macOS/Git Bash):
	- Detects the current Terraform workspace (falls back to `dev` when workspace is `default`).
	- Appends `-var-file=envs/<workspace>/terraform.tfvars` to Terraform commands so you don't need to type the var-file path each time.
	- If `ARM_SUBSCRIPTION_ID` is not set, tries to detect it using `az account show` and exports it for Terraform; the script will not print the raw subscription id.
	- Usage examples:
		- `./scripts/terraform.sh plan`
		- `./scripts/terraform.sh apply -auto-approve`
		- `./scripts/terraform.sh destroy -auto-approve`

- `scripts/terraform.ps1` — PowerShell equivalent (Windows PowerShell / PowerShell Core):
	- Same behavior as the Bash script: workspace detection, var-file handling and subscription detection via Azure CLI.
	- Usage examples (PowerShell):
		- `.\\scripts\\terraform.ps1 plan`
		- `.\scripts\terraform.ps1 apply -auto-approve`

Notes:
- Both scripts rely on the Azure CLI for subscription detection; run `az login` first if you use interactive authentication.
- If you prefer to supply a subscription id explicitly, set the `ARM_SUBSCRIPTION_ID` environment variable before running the script.
- The scripts append the `-var-file` argument automatically.

