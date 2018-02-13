

param (
    [Parameter (Mandatory = $true)]  [String]$Instance,
    [Parameter (Mandatory = $true)]  [String]$JobName,
    [Parameter (Mandatory = $false)] [Switch]$ExecuteCommand
)

#We need either a single job name or the keyword ALL

If ($JobName -eq "All") {

    $SQLCmd = "declare @JobName varchar(100);select name into #t1 from msdb.dbo.sysjobs where category_id = (select category_id from msdb.dbo.syscategories where name = 'VMDBA'  and category_class = 1); while exists (select * from #t1) begin select top 1 @JobName = name from #t1; exec msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule=1; delete from #t1 where name = @JobName; end"
    Write-Verbose $SQLCmd

    if ($ExecuteCommand) {
        invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd
    } else {
        write-output $SQLCmd

    }


} else {

    $SQLCmd = "IF EXISTS (SELECT job_id from msdb.dbo.sysjobs WHERE name = '$JobName') EXEC msdb.dbo.sp_delete_job @Job_name = '$JobName'" + "," + "@delete_unused_schedule=1;"

    if ($ExecuteCommand) {
        invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd
    } else {
        Write-Output $SQLCmd
    }

}




