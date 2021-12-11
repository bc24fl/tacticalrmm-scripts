<#
    .SYNOPSIS
    Restarts stuck printer jobs.

    .DESCRIPTION 
    Cycles through each printer and restarts any jobs that are stuck with error status.

    .NOTES
    Change Log
    ----------------------------------------------------------------------------------
	V1.0 Initial Release by https://github.com/bc24fl/tacticalrmm-scripts/

#>

$AllPrinters = Get-Printer
foreach ($Printer in $AllPrinters) {
    $PrintJobs = Get-PrintJob -PrinterName $($Printer.Name)
    if ($PrintJobs) {
        foreach ($Job in $PrintJobs) {
            if ($Job.JobStatus -match 'Error') {
		$stuckPrinterName = $Job.PrinterName
		$stuckPrinterJob = $Job.Id
		Write-Host "Restarting Job Id $stuckPrinterJob on printer $stuckPrinterName"
                Restart-PrintJob -InputObject $Job
            }
        }
    }
}
