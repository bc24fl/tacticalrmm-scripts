<#
.SYNOPSIS
    Syncs agents from Tactical RMM to Hudu.

.REQUIREMENTS
    - You will need an API key from Hudu and Tactical RMM which should be passed as parameters.  
    - DO NOT hard code API keys inside script.
    - This script imports/installs powershell module https://github.com/lwhitelock/HuduAPI which you may have to manually install on errors.

.NOTES
    - Ideally, this script should be run on the Tactical RMM server however since there is no linux agent, you'll have to run this on one of your trusted Windows devices.
    - This script compares Tactical's Client Name with Hudu's Company Names and syncs asset if there is a match (case sensitive).  Nothing will sync if a match is not found.  

.TODO
    - Add all tactical fields
    - On Hudu a Card should be created not a form
    - Reduce the amount of rest calls made
		
.VERSION
	- V1.0 Initial Release by https://github.com/bc24fl/tacticalrmm-scripts/
	
#>

param(
    $ApiKeyTactical,
    $ApiUrlTactical,
    $ApiKeyHudu,
    $ApiUrlHudu,
    $HuduAssetName
)

if ([string]::IsNullOrEmpty($ApiKeyTactical)) {
    Write-Output "ApiKeyTactical must be defined. Use -ApiKeyTactical <value> to pass it."
    Exit 1
}

if ([string]::IsNullOrEmpty($ApiUrlTactical)) {
    Write-Output "ApiUrlTactical without the https:// must be defined. Use -ApiUrlTactical <value> to pass it."
    Exit 1
}

if ([string]::IsNullOrEmpty($ApiKeyHudu)) {
    Write-Output "ApiKeyHudu must be defined. Use -ApiKeyHudu <value> to pass it."
    Exit 1
}

if ([string]::IsNullOrEmpty($ApiUrlHudu)) {
    Write-Output "ApiUrlHudu without the https:// must be defined. Use -ApiUrlHudu <value> to pass it."
    Exit 1
}

if ([string]::IsNullOrEmpty($HuduAssetName)) {
    Write-Output "HuduAssetName param not defined.  Using default name TacticalRMM Agents."
    $HuduAssetName = "TacticalRMM Agents"
}


try {
    if (Get-Module -ListAvailable -Name HuduAPI) {
        Import-Module HuduAPI 
    } else {
        Install-Module HuduAPI -Force
        Import-Module HuduAPI
    }
}
catch {
    Write-Host "Installation of HuduAPI failed.  Please install HuduAPI manually first by running: 'Install-Module HuduAPI' on server."
    Exit 1
}

$headers= @{
    'X-API-KEY' = $ApiKeyTactical
}

New-HuduAPIKey $ApiKeyHudu 
New-HuduBaseURL "https://$ApiUrlHudu" 

$huduAssetLayout = Get-HuduAssetLayouts -name $HuduAssetName

if (!$huduAssetLayout){
    $fields = @(
	@{
		label = 'Client Name'
		field_type = 'Text'
		position = 1
	},
	@{
		label = 'Site Name'
		field_type = 'Text'
		position = 2
	},
    @{
		label = 'Computer Name'
		field_type = 'Text'
		position = 3
	},
    @{
		label = 'Status'
		field_type = 'CheckBox'
        hint = 'Online/Offline'
		position = 4
	},
    @{
		label = 'Description'
		field_type = 'Text'
		position = 5
	},
    @{
		label = 'Patches Pending'
		field_type = 'CheckBox'
        hint = ''
		position = 6
	},
    @{
		label = 'Last Seen'
		field_type = 'Text'
		position = 7
	},
    @{
		label = 'Logged Username'
		field_type = 'Text'
		position = 8
	},
    @{
		label = 'Needs Reboot'
		field_type = 'CheckBox'
        hint = ''
		position = 9
	},
    @{
		label = 'Overdue Dashboard Alert'
		field_type = 'CheckBox'
        hint = ''
		position = 10
	},
    @{
		label = 'Overdue Email Alert'
		field_type = 'CheckBox'
        hint = ''
		position = 11
	},
    @{
		label = 'Overdue Text Alert'
		field_type = 'CheckBox'
        hint = ''
		position = 12
	},
    @{
		label = 'Pending Actions Count'
		field_type = 'Number'
        hint = ''
		position = 13
	},
    @{
		label = 'Agent Id'
		field_type = 'Text'
		position = 99
	})
    New-HuduAssetLayout -name $HuduAssetName -icon "fas fa-fire" -color "#5B17F2" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $fields
    Start-Sleep -s 5
    $huduAssetLayout = Get-HuduAssetLayouts -name $HuduAssetName
}

try {
    $agentsResult = Invoke-RestMethod -Method 'Get' -Uri "https://$ApiUrlTactical/agents" -Headers $headers -ContentType "application/json"
}
catch {
    Write-Host "Error invoking rest call on Tactical RMM with error: $($PSItem.ToString())"
    Exit 1
}

foreach ($agents in $agentsResult) {

    $fieldData = @(
	@{
		client_name             = $agents.client_name
		site_name               = $agents.site_name
		computer_name           = $agents.hostname
        status                  = $agents.status
        description             = $agents.description
        patches_pending         = $agents.has_patches_pending
        last_seen               = $agents.last_seen
        logged_username         = $agents.logged_username
        needs_reboot            = $agents.needs_reboot
        overdue_dashboard_alert = $agents.overdue_dashboard_alert
        overdue_email_alert     = $agents.overdue_email_alert
        overdue_text_alert      = $agents.overdue_text_alert
        pending_actions_count   = $agents.pending_actions_count
        agent_id                = $agents.agent_id
	})

    $huduCompaniesFiltered = Get-HuduCompanies -name $agents.client_name

    if ($huduCompaniesFiltered){
        
        $asset = Get-HuduAssets -name $agents.hostname -assetlayoutid $huduAssetLayout.id -companyid $huduCompaniesFiltered.id

        if ($asset){
            Set-HuduAsset -name $agents.hostname -company_id $huduCompaniesFiltered.id -asset_layout_id $huduAssetLayout.id -fields $fieldData -asset_id $asset.id
        } else {
            Write-Host "Asset does not exists in Hudu.  Creating $agents.hostname"
            New-HuduAsset -name $agents.hostname -company_id $huduCompaniesFiltered.id -asset_layout_id $huduAssetLayout.id -fields $fieldData
        }
    }
}