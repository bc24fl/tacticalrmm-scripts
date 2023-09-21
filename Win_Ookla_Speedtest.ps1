<#
.SYNOPSIS
    Performs a speedtest using Ookla CLI Speed Test Tool https://www.speedtest.net/apps/cli

.NOTES
    V1.0 Initial Release by https://github.com/bc24fl/tacticalrmm-scripts/
#>

param(
    $MinUp,
    $MinDown
)

if ([string]::IsNullOrEmpty($MinUp)) {throw "MinUp must be defined. Use -MinUp <value> to pass it."}
Try {
    $Null = [convert]::ToInt32($MinUp)
} Catch {throw "MinUp must be a number."}

if ([string]::IsNullOrEmpty($MinDown)) {throw "MinDown must be defined. Use -MinDown <value> to pass it."}
Try {
    $Null = [convert]::ToInt32($MinDown)
} Catch {throw "MinDown must be a number."}

$scrapedLinks = (Invoke-WebRequest -Uri 'https://www.speedtest.net/apps/cli').Links.Href  | Get-Unique 
# Note: Possible Hack.  Assumes there is just one link with win64.zip
#       There is likely a better way of doing this with regex but DONE IS BETTER THAN PERFECT ;)
foreach ($url in $scrapedLinks){
    if ($url.contains('win64.zip')){
        $downloadUrl = $url
        $archiveName = Split-Path -Path $url -Leaf
        break
    }
}

$executableName = "speedtest.exe"

try{

    Write-Host "Downloading SpeedTest from " + $downloadUrl + " Please wait..." 
    $tmpDir = [System.IO.Path]::GetTempPath()
    
    $downloadLocation = $tmpDir + $archiveName
    $executable = $tmpDir + $archiveName.replace('.zip','') + "\" + $executableName
    
    Write-Host "Saving file to " + $downloadLocation 
    Write-Output "File executable located " + $executable
        
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadLocation
    
    Expand-Archive -Path $downloadLocation -Force
    
    Write-Host "Running Ookla Speedtest.  Please wait for results..." 

    $stResults = & $executable --format=json --accept-license --accept-gdpr
    
    Remove-Item -Path $downloadLocation -Force
    Remove-Item -Path $downloadLocation.replace('.zip','') -Recurse -Force
    
    $stResults = $stResults | ConvertFrom-Json
    
    [PSCustomObject]$stObject = [ordered]@{
        downloadSpeed = [math]::Round($stResults.download.bandwidth / 1000000 * 8, 2)
        uploadSpeed   = [math]::Round($stResults.upload.bandwidth / 1000000 * 8, 2)
        packetLoss    = [math]::Round($stResults.packetLoss)
        isp           = $stResults.isp
        externalIP    = $stResults.interface.externalIp
        internalIP    = $stResults.interface.internalIp
        host          = $stResults.server.host
        url           = $stResults.result.url
        jitter        = [math]::Round($stResults.ping.jitter)
        latency       = [math]::Round($stResults.ping.latency)
    }

    Write-Output $stObject
    
    if ( ([Double]$stObject.downloadSpeed -lt [Double]$MinDown) -or ([Double]$stObject.uploadSpeed -lt [Double]$MinUp) ){
        Write-Output "`nDownload or upload is BAD..."
        exit 1
    }else{
        Write-Output "`nDownload or upload is GOOD"
    }
    
}
catch{
    throw "Ookla Speedtest Installation failed with error message: $($PSItem.ToString())"
}
