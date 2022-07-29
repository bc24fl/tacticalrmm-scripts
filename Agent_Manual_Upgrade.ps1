# Added to prevent TLS/SSL error when interacting on https:// 

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

try {
    $versionResult = Invoke-RestMethod -Method 'Get' -Uri "https://api.github.com/repos/amidaware/rmmagent/releases/latest" -Headers $headers -ContentType "application/json"
}
catch {
    throw "Error getting latest version from Github with error: $($PSItem.ToString())"
}

$tag = $versionResult.tag_name

#https://github.com/amidaware/rmmagent/releases/download/v2.1.1/tacticalagent-v2.1.1-windows-amd64.exe

$downloadUrl = "https://github.com/amidaware/rmmagent/releases/download/$tag/tacticalagent-$tag-windows-amd64.exe"

Write-Host "Downloading WinAgent from " + $downloadUrl + " Please wait..." 
$tmpDir = [System.IO.Path]::GetTempPath()

    
$outpath = $tmpDir + "winagent-$tag.exe"
        
Write-Host "Saving file to " + $outpath
        
Invoke-WebRequest -Uri $downloadUrl -OutFile $outpath

Write-Host "Running Tactical Agent Setup... Please wait a few minutes for the upgrade to complete." 
$appArgs = @("/VERYSILENT /LOG=agentupdate.txt")
Start-Process -Filepath $outpath -ArgumentList $appArgs