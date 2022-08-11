<#
 .SYNOPSIS
    Powershell Script to create an Azure AD App Registration and a corresponding Service Principal to attach it
    at an Azure App Service App or Container as authentication object to ensure AAD Authentication at every access attempt (Zero Trust).

 .DESCRIPTION
    Docs
      - https://codez.deedx.cz/posts/update-redirect-uris-from-azure-devops/
      - https://blog.nico-schiering.de/granting-azure-ad-admin-consent-programmatically/ (grant admin consent via code)

 .NOTES
    Author:         Daniel Heidemann
    Mail:           daniel.heidemann@the-architect.cloud
    Company:        Heidemann Cloud Consulting Services
    Created:        11 August 2022
    SDK (tested):   PowerShell Core 7.2 // PowerShell Azure Module 8.0.0
#>

param([string] $webappName)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------ LOGIN --------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------------------------------------- #
# Necessary PowerShell Modules

Install-Module -Name "Microsoft.Graph.Applications" -Force

# ---------------------------------------------------------------------------------------------------------- #
# Module // Login into Microsoft Graph

$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"
Connect-MgGraph -AccessToken $token.Token

# ---------------------------------------------------------------------------------------------------------- #
# -------------------------------------------- Global Parameters ------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------- #

# Microsoft Graph App ID (DON'T CHANGE)
$GraphAppId = "00000003-0000-0000-c000-000000000000"

# Check the Microsoft Graph documentation for the permission you need for the operation
$PermissionName = "User.Read.All"

# Azure AD App Registration infos
$appReqName = "app-$webappName"
$notes = "This AAD Application belongs to Azure App Service $webappName in Subscription: Id:$($subscription.Id), Name:$($subscription.Name)."
$subscription = (Get-AzContext).Subscription



# ---------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------ Script -------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------- #

### ------------------------------------------------
# Setup and configure Azure AD App Registration

# Check if app has already been deployed
$app_reg = Get-MgApplication -Filter "DisplayName eq '$appReqName'"

# Get Service Principal object in case app reg already exists
if ($app_reg) {

  $app_sp = Get-MgServicePrincipal -Filter "AppId eq '$($app_reg.AppId)'"
  Write-Host "Found AAD app registration $($app_reg.DisplayName). Skipping..." -ForegroundColor Yellow
  Write-Host "Found AAD service principal $($app_sp.AppDisplayName). Skipping..." -ForegroundColor Yellow

}
else {


  # ----------------------------------------------------
  # Get Microsoft Graph Service Principal Config

  $MsGraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$GraphAppId'"

  # Get Microsoft Graph Service Principal "User.Read.All" App Role

  $AppRole = $MsGraphServicePrincipal.AppRoles | Where-Object { $_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application" }

  # ----------------------------------------------------
  # Create app registration

  $params = @{
    displayName            = $appReqName
    notes                  = $notes
    signInAudience         = "AzureADMyOrg"
    requiredResourceAccess = @(
      @{
        resourceAppId  = $GraphAppId
        resourceAccess = @(
          @{
            id   = $AppRole.Id
            type = "Role"
          }
        )
      }
    )
    web                    = @{
      redirectUris          = @(
        ("https://$webappName.azurewebsites.net/.auth/login/aad/callback")
      )
      implicitGrantSettings = @{
        enableIdTokenIssuance     = $true
        enableAccessTokenIssuance = $false
      }
    }
  }

  $params = $params | ConvertTo-Json -Depth 5
  $appRegistration = New-MgApplication -BodyParameter $params




  # ----------------------------------------------------
  # Create corresponding service principal

  $appServicePrincipal = New-MgServicePrincipal -AppId $appRegistration.AppId -AdditionalProperties @{}

  # ----------------------------------------------------
  # MS Graph App ID
  
  $graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$GraphAppId'"

  # Grant admin consent to app registration for permission "User.Read"

  New-MgOauth2PermissionGrant -ResourceId $graphServicePrincipal.Id -Scope @($PermissionName) -ClientId $appServicePrincipal.Id -ConsentType "AllPrincipals"

}

# ----------------------------------------------------
# Output to deployment
$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['appId'] = $appRegistration.AppId






# az ad app permission grant --id "133cf7ab-9151-4cab-85da-9a63ef309195" --api "00000003-0000-0000-c000-000000000000" --scope "User.Read"