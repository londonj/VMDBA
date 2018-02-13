    
param (
    [Parameter (Mandatory = $true)] [String]$JobName,
    [Parameter (Mandatory = $true)] [String]$Instance,
    [Parameter (Mandatory = $true)] [String]$JobConfigVersion,
    [Parameter (Mandatory = $true)] [String]$ScheduleID,
    [Parameter (Mandatory = $false)] [Switch]$ExecuteCommand

)
    

#We need to find the appropriate schedule for this job
#First, get the filename
$JobScheduleConfigFile = "JobSchedules_" + $JobConfigVersion + ".cfg"

#Now get the Schedule name and definition
$ScheduleName =       (import-csv -Path $JobScheduleConfigFile -Delimiter '|' | ? ScheduleID -eq $ScheduleID | select-object ScheduleName | ft -HideTableHeaders |out-string).trim()
$ScheduleDefinition = (import-csv -Path $JobScheduleConfigFile -Delimiter '|' | ? ScheduleID -eq $ScheduleID | select-object ScheduleDefinition | ft -HideTableHeaders | out-string).replace(" ","")

            
if (!($ScheduleName )) {
Write-Host "No schedule found for $Jobname"

    exit
}

        
#Now see if the schedule exists on the target instance
$SQLCmd = "select count(*) as cnt from msdb.dbo.sysschedules where name =" + "'" + $ScheduleName + "'"
Write-Verbose "Invoke-DbaSqlCmd -SqlInstance $Instance -Query $SQLCmd"

$Results = Invoke-SqlCmd2 -SqlInstance $Instance -Query $SQLCmd

        
#Check to see
#Schedule does not exist
if ($Results.cnt -eq 0) {
    
    
    $SQLCmd = "EXEC msdb.dbo.sp_add_schedule " + $ScheduleDefinition.trim() + " ;"
    Write-Verbose $SQLCmd

    if ($ExecuteCommand) {
        Invoke-sqlcmd2 -SqlInstance $Instance -Query $SQLCmd
    } else {

        Write-Output $SQLCmd
    }
    
}
else {
    #Schedule exists
    
    Write-Verbose "Schedule $ScheduleName exists."
}
        

    
    
#Build the schedule step
$SQLCmd = "EXEC msdb.dbo.sp_attach_schedule @job_name= " + "'" + $JobName + "'" + ",@schedule_name = " + "'" + $ScheduleName + "' ;" 
write-Verbose $SQLCmd
    
if ($ExecuteCommand) {
    invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd
} else {

    write-output $SQLCmd

}

     
$SQLCmd = "EXEC msdb.dbo.sp_add_jobserver @job_name = " + "'" + $JobName + "'" + ", @server_name = N'(local)' ;"
Write-Verbose $SQLCmd
    
if ($ExecuteCommand) {
    invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd
} else {

    Write-Output $SQLCmd
}


    