

    param (
        [Parameter (Mandatory = $false)] [String]$JobConfigVersion
    )

    $JobConfigFile = "JobConfig_" + $JobConfigVersion.toupper() + ".cfg"
        
    if (!(Test-Path $JobConfigFile)) {
        Write-Host "File $JobConfigFile does NOT exist."
        return $false
    }
    
    Write-Verbose "JobConfigFile = $JobConfigFile"

    Write-Output $JobConfigFile 




