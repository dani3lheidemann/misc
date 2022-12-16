
<#
 .SYNOPSIS
    Powershell Script to check and set correct Azure AD group as admin on found Azure SQL Server and configure Azure AD Auth only.
    This script is executed as a "deployment script" as part of a an Azure Policy. 

 .NOTES
    Author:         Daniel Heidemann
    Mail:           daniel.heidemann@the-architect.cloud
    Company:        Heidemann Cloud Consulting Services
    Created:        30 November 2022
    SDK (tested):   PowerShell Core 7.2 // PowerShell Azure Module 8.0.0
#>


### ------------------------------------------------------------------------------------------------
### ------------------------------------------------------------------------------------------------
### PARAMS

Param (        
    [Parameter(Mandatory = $true)][string]$p_alz_name,
    [Parameter(Mandatory = $true)][array]$p_alz_engineers_upn
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




# # TEST
# $lzengineerGroupName = "grp-nexis-app-owner"

# $p_alz_name = "lz-danieltest-dev"

# $p_alz_engineers_upn = @("daniel.heidemann@nexis-pm.de", "Mathias.Walko@nexis-pm.de", "stefan.krecher@nexis-pm.de")





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

foreach ($engineer in $p_alz_engineers_upn) {

    $payload = @{
        'members@odata.bind' = @("https://graph.microsoft.com/v1.0/users/$($engineer)")
    }

    $addMembersToGroup = Invoke-AzRestMethod "https://graph.microsoft.com/v1.0/groups/$($lzengineerGroup.id)" -Method PATCH -Payload ($payload | ConvertTo-Json)

    Write-Output "Successfully added [$engineer] to Landing Zone Engineer group [Name: $($lzengineerGroup.displayName)]."
}


Write-Output "Azure AD group Setup for Azure Landing Zone $p_alz_name finished."