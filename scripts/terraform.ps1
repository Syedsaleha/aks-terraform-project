# terraform.ps1
# PowerShell equivalent of scripts/terraform.sh
# Usage: .\scripts\terraform.ps1 plan|apply|... (passes args to terraform)

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

# Determine current workspace
$envWorkspace = (& terraform workspace show) -replace "\r|\n", ""
if ($envWorkspace -eq "default") { $envWorkspace = "dev" }
Write-Host "Current workspace: $envWorkspace"

$varFile = "envs/$envWorkspace/terraform.tfvars"

# Ensure Azure subscription is available for the azurerm provider.
# If ARM_SUBSCRIPTION_ID isn't set, try to detect it from `az account show`.
if (-not $env:ARM_SUBSCRIPTION_ID) {
    if (Get-Command az -ErrorAction SilentlyContinue) {
        try {
            $detected = (az account show --query id -o tsv 2>$null) -replace "\r|\n", ""
        } catch {
            $detected = ""
        }
        if (-not [string]::IsNullOrEmpty($detected)) {
            $env:ARM_SUBSCRIPTION_ID = $detected.Trim()
            Write-Host "Detected Azure subscription."
        } else {
            Write-Error "ARM_SUBSCRIPTION_ID not set and no logged-in Azure account found. Run 'az login' to authenticate, or set the ARM_SUBSCRIPTION_ID environment variable."
            exit 1
        }
    } else {
        Write-Error "ARM_SUBSCRIPTION_ID not set and Azure CLI ('az') not found. Install Azure CLI or set ARM_SUBSCRIPTION_ID environment variable."
        exit 1
    }
}

# Build terraform args: take all remaining args and append -var-file
$tfArgs = @()
if ($RemainingArgs) { $tfArgs += $RemainingArgs }
$tfArgs += "-var-file=$varFile"

# Execute terraform with the assembled arguments
& terraform @tfArgs

# Forward exit code
exit $LASTEXITCODE
