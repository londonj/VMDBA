[cmdletbinding(SupportsShouldProcess)] #For -WhatIf support

param (
    [Parameter (Mandatory = $true)] [String]$Server
)


#The job does not appear in the config file
if (!(sls $Server LocalDrive.cfg)) {
    Write-Host "The server $Server was not found in LocalDrive.cfg"
    exit
}

$LocalDrive=(import-csv -delimiter '|' LocalDrive.cfg | ? Server -eq $Server | select-object DriveLetter | ft -HideTableHeaders |out-string).trim()    

$LocalDrive
