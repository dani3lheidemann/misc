



param([string] $webappName)



$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------ LOGIN --------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------------------------------------- #
# Module // Login into Microsoft Graph

$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"
Connect-MgGraph -AccessToken $token.Token


# $webappName = "wrhrtzzjhwefs-test1"
$appReqName = "app-$webappName"
$description = "This AAD Application belongs to Azure App Service $webappName in Subscription: Id:$($subscription.Id), Name:$($subscription.Name)."
$subscription = (Get-AzContext).Subscription






# Microsoft Graph App ID (DON'T CHANGE)
$GraphAppId = "00000003-0000-0000-c000-000000000000"

# Check the Microsoft Graph documentation for the permission you need for the operation
$PermissionName = "User.Read.All"




# ref to -> https://codez.deedx.cz/posts/update-redirect-uris-from-azure-devops/

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
    description            = $description
    signInAudience         = "AzureADMyOrg"
    requiredResourceAccess = @(@{
        resourceAppId  = $GraphAppId
        resourceAccess = @(@{
            id   = $AppRole.Id
            type = "Role"
          })
      })
    web                    = @{
      redirectUris          = @("https://$webappName.azurewebsites.net/.auth/login/aad/callback")
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
  # Auto-Admin consent for App Registration for needed Permission
  
  $applicationReadWriteAll = @{
    Id   = $AppRole.Id # "User.Read.All"
    Type = "Role"
  }

  # AppId 00000003-0000-0000-c000-000000000000 is the Microsoft Graph application
  $graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$GraphAppId'"

  New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $appServicePrincipal.Id `
    -ResourceId $graphServicePrincipal.Id `
    -AppRoleId $applicationReadWriteAll.Id `
    -PrincipalId $appServicePrincipal.Id
}



$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['appId'] = $appRegistration.AppId

