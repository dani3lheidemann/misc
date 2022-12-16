
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
    [Parameter(Mandatory = $true)][string]$p_alz_engineers_upn,
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
    Write-Output "Successfully installed PowerShell Module $module."
}


Connect-azaccount -Identity


# ---------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------ Script -------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------- #

# -------------------------------
# Convert type of $p_alz_engineers_upn param (passing array as an input param was not 100% possible, so this is a workaround)

# $p_alz_engineers_upn = $p_alz_engineers_upn.Split(",")
# $aadGroupMembers = @($p_alz_engineers_upn, $p_alz_managed_identity_objectId)



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
    
    if ($lzengineerGroup.error) {
        Throw "An error occured -> code: $($lzengineerGroup.error.code); message: $($lzengineerGroup.error.message); innerError: $($lzengineerGroup.error.innerError)"
    }
    else {
        Write-Output "Created Azure AD group [Name: $($lzengineerGroup.displayName)] to contribute on Azure Landing Zone $p_alz_name."
    }
}
else {
    Write-Output "Azure AD group $lzengineerGroupName already exists. Take this group and add LZ Engineers now."
}




# -------------------------------
# Get ALZ Engineers Object IDs based on UPN

$groupMemberObjectIds = @()
foreach ($engineer in $p_alz_engineers_upn) {

    $groupMemberObjectIds += ((Invoke-AzRestMethod "https://graph.microsoft.com/v1.0/users/$engineer" -Method GET).Content | ConvertFrom-Json).id
}

# -------------------------------
# Add user-assigned Managed Identity to group

$groupMemberObjectIds += $p_alz_managed_identity_objectId





# -------------------------------
# Add ALZ Engineers to ALZ AAD group

foreach ($member in $groupMemberObjectIds) {

    $payload = @{
        '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$member"
    }

    $addMembersToGroup = (Invoke-AzRestMethod "https://graph.microsoft.com/v1.0/groups/$($lzengineerGroup.id)/members/`$ref" -Method POST -Payload ($payload | ConvertTo-Json)).Content | ConvertFrom-Json


    # Error Handling -> Continue on "error" that the UPN already exists in group.

    if ($addMembersToGroup.error -and $($addMembersToGroup.error.message -ne "One or more added object references already exist for the following modified properties: 'members'.")) {

        Throw "An error occured -> code: $($addMembersToGroup.error.code); message: $($addMembersToGroup.error.message); innerError: $($addMembersToGroup.error.innerError)"

    }
    else {
        Write-Output "Successfully added [$member] to Landing Zone Engineer group [Name: $($lzengineerGroup.displayName)]."
    }
}


Write-Output "Azure AD group Setup for Azure Landing Zone $p_alz_name finished."


# ---------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------ Output -------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------- #


$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['lzengineerGroupId'] = $lzengineerGroup.id
