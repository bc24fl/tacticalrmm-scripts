<#
.SYNOPSIS
    Set all Preview updates to ignore across all agents using the API and without installing any 3rd party libraries.

.REQUIREMENTS
    - You will need an API key from Tactical RMM which should be passed as parameters (DO NOT hard code in script).  Do not run this on each agent (see notes).  

.NOTES
    - This script is designed to run on a single computer.  Ideally, it should be run on the Tactical RMM server or other trusted device.
    - This script cycles through each agent setting Preview updates to ignore.

.PARAMETERS
    - $ApiKeyTactical   - Tactical API Key
    - $ApiUrlTactical   - Tactical API Url
   
.EXAMPLE
    - Win_KB_Ignore_All_Preview.ps1 -ApiKeyTactical 1234567 -ApiUrlTactical api.yourdomain.com
		
.VERSION
    - v1.0 Initial Release by https://github.com/bc24fl/tacticalrmm-scripts/
#>

param(
    [string] $ApiKeyTactical,
    [string] $ApiUrlTactical
)

if ([string]::IsNullOrEmpty($ApiKeyTactical)) {
    throw "ApiKeyTactical must be defined. Use -ApiKeyTactical <value> to pass it."
}

if ([string]::IsNullOrEmpty($ApiUrlTactical)) {
    throw "ApiUrlTactical must be defined. Use -ApiUrlTactical <value> to pass it."
}

$headers= @{
    'X-API-KEY' = $ApiKeyTactical
}

# Get all agents
try {
    $agentsResult = Invoke-RestMethod -Method 'Get' -Uri "https://$ApiUrlTactical/agents" -Headers $headers -ContentType "application/json"
}
catch {
    throw "Error invoking get all agents on Tactical RMM with error: $($PSItem.ToString())"
}

foreach ($agents in $agentsResult) {

    $agentId        = $agents.agent_id
    $agentHostname  = $agents.hostname

    # Get agent updates
    try {
        $agentUpdateResult = Invoke-RestMethod -Method 'Get' -Uri "https://$ApiUrlTactical/winupdate/$agentId/" -Headers $headers -ContentType "application/json"
    }
    catch {
        Write-Error "Error invoking winupdate on agent $agentHostname - $agentId with error: $($PSItem.ToString())"
    }

    foreach ($update in $agentUpdateResult){
        $updateId       = $update.id 
        $updateKb       = $update.kb 
        $updateAction   = $update.action
        $updateTitle    = $update.title

        if ($updateTitle -like '*Preview*' -And $updateAction -eq "nothing"){
            Write-Host "Setting $updateKb to ignore with title: $updateTitle"

            # Set Ignore KB
            $body = @{
                "action"   = "ignore"
            }
            try {
                $updateIgnoreKb = Invoke-RestMethod -Method 'Put' -Uri "https://$ApiUrlTactical/winupdate/$updateId/" -Body ($body|ConvertTo-Json) -Headers $headers -ContentType "application/json"
                Write-Host "Agent $agentHostname toggling ignore of $updateKB"
            }
            catch {
                Write-Error "Error invoking Ignore KB on agent $agentHostname - $agentId with error: $($PSItem.ToString())"
            }

        }
    }   
} 
