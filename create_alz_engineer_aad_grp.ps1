
<#
 .SYNOPSIS
    Powershell Script to check whether a specific Azure AD group exists for Azure Landing Zone Subscription. If not, the group will be created.
    All users metioned in $p_alz_engineers_upn will be added to the group.
    This script is executed as a "deployment script" as part of a an Azure Policy with a Managed Identity. 

 .NOTES
    Author:         Daniel Heidemann
    Mail:           daniel.heidemann@the-architect.cloud
    Company:        Heidemann Cloud Consulting Services
    Created:        16 Dezember 2022
    SDK (tested):   PowerShell Core 7.2 // PowerShell Azure Module 8.0.0
#>


### ------------------------------------------------------------------------------------------------
### ------------------------------------------------------------------------------------------------
### PARAMS

Param (        
    [Parameter(Mandatory = $true)][string]$p_alz_name,
    [Parameter(Mandatory = $true)][array]$p_alz_engineers_upn,
    [Parameter(Mandatory = $true)][string]$p_alz_managed_identity_objectId
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------ LOGIN --------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------------------------------------- #
# Necessary PowerShell Modules

$modules = @(
    "Az.Accounts"
)

foreach ($module in $modules) {
    Install-Module -Name $module -Force
}


Connect-azaccount -Identity


# ---------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------ Script -------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------- #

# -------------------------------
# Check if group already exists

$lzengineerGroupName = "grp-az-$p_alz_name-lzengineer"
$lzengineerGroup = ((Invoke-AzRestMethod "https://graph.microsoft.com/v1.0/groups?`$filter=displayName+eq+'$lzengineerGroupName'" -Method GET).Content | ConvertFrom-Json).value

# -------------------------------
# Create new AAD ALZ group for specific Subscription in case there was no group found in AAD 

if (-not $lzengineerGroup) {

    Write-Output "No Azure AD group found for Subscription $p_alz_name. Create one now."

    $payload = @{
        description     = "Members of this group are allowed to contribute on Azure Landing Zone $p_alz_name."
        displayName     = $lzengineerGroupName
        mailEnabled     = $false
        mailNickname    = $lzengineerGroupName
        securityEnabled = $true
    }

    $lzengineerGroup = ((Invoke-AzRestMethod "https://graph.microsoft.com/v1.0/groups" -Method POST -Payload ($payload | ConvertTo-Json))).Content | ConvertFrom-Json

    Write-Output "Created Azure AD group [Name: $($lzengineerGroup.displayName)] to contribute on Azure Landing Zone $p_alz_name."

}


# -------------------------------
# Add ALZ Engineers to ALZ AAD group

$groupMembers = $p_alz_engineers_upn + $p_alz_managed_identity_objectId

foreach ($engineer in $groupMembers) {

    $payload = @{
        'members@odata.bind' = @("https://graph.microsoft.com/v1.0/users/$($engineer)")
    }

    $addMembersToGroup = Invoke-AzRestMethod "https://graph.microsoft.com/v1.0/groups/$($lzengineerGroup.id)" -Method PATCH -Payload ($payload | ConvertTo-Json)

    Write-Output "Successfully added [$engineer] to Landing Zone Engineer group [Name: $($lzengineerGroup.displayName)]."
}


Write-Output "Azure AD group Setup for Azure Landing Zone $p_alz_name finished."


# ---------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------ Output -------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------- #


$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['lzengineerGroupId'] = $lzengineerGroup.id
