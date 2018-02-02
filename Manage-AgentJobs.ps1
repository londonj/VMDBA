<#
Manage-AgentJobs.ps1

.SYNOPSIS
    Manages the DBA Toolkit Agent Jobs and schedules
  
.DESCRIPTION
    This script will help the DBA manage the jobs and schedules that are part of the VM DBA Toolkit.
    With this script, you can 
           1) Add, Modify & Delete Jobs, Job schedules & Procedures, individually or en masse using a configuration file.
           
.PARAMETER Instance
    The instance that you want to restore. You can pass in a single instance, or a comma-delimited list of instances.

.PARAMETER JobName
    When working with a single job, the name of the job.

.PARAMETER DropIfExists
    Drop the agent job or schedule if it already exists. If this is not specified, the job will NOT be re-created.
    
.PARAMETER OutputDriveLetter
    The letter of the drive (C,D,R, etc.) under which the output directory and files will be created.
    
.PARAMETER ScheduleConfigFile
    The name of the configuration file which contains all schedules and their attributes.

.PARAMETER JobConfigFile
    The name of the configuration file which contains all jobs and their attributes.

.PARAMETER DropJob
    Delete specifed job

        
.EXAMPLE
    .\Manage-AgentJobs.ps1 -Instance memorialsql -GetScheduleInfo -JobName 'CommandLog Cleanup' -ShowDetail 
    Shows the current schedule for the job 'CommandLog Cleanup' on the instance 'memorialsql'.

.EXAMPLE

    .\Manage-AgentJobs.ps1 -Instance memorialsql  -GetJobInfo -verbose

    Displays job information for all jobs in the instance memorialsql.


.EXAMPLE

    .\Manage-AgentJobs.ps1 -CreateJob -Instance merchsoftdb-t1 -jobname 'DatabaseBackup - SYSTEM_DATABASES - FULL' -JobConfigVersion pe10 -Verbose -DropIfExists -EnableJob -EmailNotificationOn -EventLogNotificationOn

    Creates a job in the instance 'merchsoftdb-t1'. Uses job information from the file JobConfigPE10.cfg and schedule info from JobSchedulePE10.cfg. 
    If the job already exists, drop it.
    Enable the job upon creation.
    Turn on email notification for job failures (to the DBA group), upon job creation.
    Turn on Windows event log for job failures, upon job creation.

.EXAMPLE

    .\Manage-AgentJobs.ps1 -CreateJob -Instance merchsoftdb-t1 -jobConfigVersion pe10 -Verbose -DropIfExists -JobName All

    Creates/modifies all jobs in the specified config file


.EXAMPLE

    .\Manage-AgentJobs.ps1 -Instance merchsoftdb-t1 -jobConfigVersion pe10 -Verbose -JobName All -RemoveJob

    Removes all jobs listed in the PE10 config file in the instance merchsoftdb-t1


.EXAMPLE

    .\Manage-AgentJobs.ps1 -Instance merchsoftdb-t1 -jobConfigVersion pe10 -Verbose -JobName 'DatabaseBackup - SYSTEM_DATABASES - FULL' -CreateJob

    Creates the job 'DatabaseBackup - SYSTEM_DATABASES - FULL' in the instance merchsoftdb-t1, using the job config info in the PE10 config file.



.EXAMPLE

    .\Manage-AgentJobs.ps1 -Instance merchsoftdb-t1 -jobConfigVersion pe11 -Verbose -JobName all -createJob -IncludeVersionOnJobName

    Create jobs on target instance, as defined in the PE11 config file, and include the version name (PE11) as a suffix on the job name


.EXAMPLE

    \Manage-AgentJobs.ps1 -Instance merchsoftdb-t1 -Verbose -JobName all -removeJob -AllVMDBAJobs
    
    Removes all jobs on target server which belong to the category 'VMDBA'


.NOTES  
    File Name    : Manage-AgentJobs.ps1
    Author       : Johnny London, VMMH
    Date Created : 2018-01-24
    Version 0.80
    
    The -verbose parameter is supported, and will output SQL statements and other additional info.

    Jobs
    The idea here is that you can view, create, delete and modify agent the DBA Toolkit jobs on one or more instances. 
    When you view a job, it will show you the job name, the description, the command and the schedule

    When you create a job, you specify a job name and a configuration file. The configuration file contains the job description, command and schedule to use.
    The schedule is taken from the schedule configuration file that you specify.



    There are several tasks which you can accomplish with this script.
        1. Get a list of current jobs and their version
            Should we put the version number in the description?



    TODO
        1. Should we pass in a filename or a version?
        
        2. Add the ability to update a job's attributes without dropping it first

        

#>


[cmdletbinding(SupportsShouldProcess)] #For -WhatIf support

param(

    #The parameter $Instance is mandatory, and belongs to several different parameter sets
    [Parameter( ParameterSetName = 'psGetJobInfo', Mandatory = $true )]
    [Parameter( ParameterSetName = 'psGetScheduleInfo', Mandatory = $true )]
    [Parameter( ParameterSetName = 'psCreateJob', Mandatory = $true )]
    [Parameter( ParameterSetName = 'psRemoveJob', Mandatory = $true )]
    [String] $Instance,

    [Parameter (ParameterSetName = 'psGetJobInfo', Mandatory = $false)] 
    [Parameter (ParameterSetName = 'psGetScheduleInfo', Mandatory = $false)] 
    [Switch] $ShowDetail,

    [Parameter (ParameterSetName = 'psGetJobInfo', Mandatory = $false)]
    [Parameter (ParameterSetName = 'psGetScheduleInfo', Mandatory = $false)]
    [Parameter (ParameterSetName = 'psGetJobConfig', Mandatory = $false)]
    [Parameter( ParameterSetName = 'psCreateJob', Mandatory = $true )]
    [Parameter( ParameterSetName = 'psRemoveJob', Mandatory = $true )]
    [ValidateSet("All", "DatabaseBackup - SYSTEM_DATABASES - FULL", "DatabaseBackup - USER_DATABASES - DIFF", "DatabaseBackup - USER_DATABASES - FULL", "DatabaseBackup - USER_DATABASES - LOG", "DatabaseIntegrityCheck - SYSTEM_DATABASES", "DatabaseIntegrityCheck - USER_DATABASES", "IndexOptimize - USER_DATABASES", "Output File Cleanup", "CommandLog Cleanup", "sp_delete_backuphistory", "sp_purge_jobhistory", "VMDBA: Alert Database Files Near MAXSIZE", "VMDBA: Cycle Error Logs", "VMDBA: Database Data and Log File Space Usage", "VMDBA: Database Table Size Usage", "VMDBA: spWhoIsActive Logging", "VMDBA: UpdateStats")]
    [String] $JobName,


    [Parameter (ParameterSetName = 'psGetJobInfo', Mandatory = $false)] 
    [Parameter (ParameterSetName = 'psCreateJob', Mandatory = $false)] 
    [Parameter (ParameterSetName = 'psRemoveJob', Mandatory = $false)] 
    [String] $JobConfigVersion,


    
    [Parameter (Mandatory = $false)]
    [Switch] $DropIfExists,

    [Parameter (Mandatory = $false)]
    [String] $OutputDriveLetter = "R",


    [Parameter (Mandatory = $false)]
    [Switch] $ViewCommand,

    [Parameter (Mandatory = $false)]
    [Switch] $EnableJob = $false,

    [Parameter (Mandatory = $false)]
    [Switch] $EmailNotificationOn = $false,

    [Parameter (Mandatory = $false)]
    [Switch] $EventLogNotificationOn = $false,

    [Parameter (Mandatory = $false)]
    [String] $ScheduleConfigFile,

    [Parameter (ParameterSetName = 'psGetJobInfo', Mandatory = $true)] [Switch] $GetJobInfo,

    [Parameter (ParameterSetName = 'psGetScheduleInfo', Mandatory = $true)] [Switch] $GetScheduleInfo,

    [Parameter (ParameterSetName = 'psGetJobConfig', Mandatory = $true)] [Switch] $GetJobConfig,

    [Parameter (ParameterSetName = 'psCreateJob', Mandatory = $true)]    [Switch] $CreateJob,
    [Parameter (ParameterSetName = 'psCreateJob', Mandatory = $false)]   [Switch] $ExecuteCommand,


    [Parameter (ParameterSetName = 'psCreateJob', Mandatory = $false)]  
    [Parameter (ParameterSetName = 'psRemoveJob', Mandatory = $false)]  
    [Switch] $IncludeVersionOnJobName,

    [Parameter (ParameterSetName = 'psRemoveJob', Mandatory = $true)] 
    [Alias ('DeleteJob', 'DropJob')]
    [Switch] $RemoveJob,

    [Parameter (ParameterSetName = 'psRemoveJob', Mandatory = $false)] [Switch] $AllVMDBAJobs,

    [Parameter (Mandatory = $false)] [String] $SwitchPath ,

    [Parameter (Mandatory = $false)] [Switch] $GenerateScript,

    [Parameter (Mandatory = $false)] [Switch] $ExecuteScript,

    [Parameter (Mandatory = $false)] [String] 
    [ValidateSet("Screen", "File", "Both")]
    $CommandOutput


    

)



#-----------------------------------------------------
function Set-JobSchedule {

    
    param (
        [Parameter (Mandatory = $true)] [String]$Instance,
        [Parameter (Mandatory = $true)] [String]$JobName,
        [Parameter (Mandatory = $true)] [String]$JobConfigVersion,
        [Parameter (Mandatory = $true)] [String]$ScheduleID
    )
    

    #We need to find the appropriate schedule for this job

    #First, get the filename
    $JobScheduleConfigFile = Set-ScheduleConfigFile -JobConfigVersion $JobConfigVersion


    #Now get the Schedule ID from the config file
    $ScheduleName = (import-csv -Path $JobScheduleConfigFile -Delimiter '|' | ? ScheduleID -eq $ScheduleID | select-object ScheduleName | ft -HideTableHeaders |out-string).trim()
    $ScheduleDefinition = (import-csv -Path $JobScheduleConfigFile -Delimiter '|' | ? ScheduleID -eq $ScheduleID | select-object ScheduleDefinition | ft -HideTableHeaders | out-string).trim()

    
        
    if (!($ScheduleName )) {

        Write-Host "No schedule found for $Jobname"

        exit
    }

    
    #Now see if the schedule exists on the target instance
    $SQLCmd = "select count(*) as cnt from msdb.dbo.sysschedules where name =" + "'" + $ScheduleName + "'"
    Write-Verbose $SQLCmd

    $Results = Invoke-DbaSqlCmd -SqlInstance $Instance -Query $SQLCmd

    
    #Check to see
    #Schedule does not exist
    if ($Results.cnt -eq 0) {
    
        $SQLCmd = "exec msdb.dbo.sp_add_schedule " + $ScheduleDefinition
        Write-Verbose $SQLCmd

        #Create the schedule
        Invoke-DbaSqlCmd -SqlInstance $Instance -Query $SQLCmd
    
    }
    else {
        #Schedule exists
    
        Write-Verbose "Schedule $ScheduleName exists."
    }
        

            
    #Build the schedule step
    $SQLCmd = "EXEC msdb.dbo.sp_attach_schedule @job_name= " + "'" + $JobName + "'" + ",@schedule_name = " + "'" + $ScheduleName + "'" 
    write-Verbose $SQLCmd
    
    invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd

     
    $SQLCmd = "EXEC msdb.dbo.sp_add_jobserver @job_name = " + "'" + $JobName + "'" + ", @server_name = N'(local)'"
    Write-Verbose $SQLCmd
    
    invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd


}         #Function Set-JobSchedule


#-----------------------------------------------------
function Set-ScheduleConfigFile {

    param (
        [Parameter (Mandatory = $false)] [String]$JobConfigVersion
    )

    $JobScheduleConfigFile = "JobSchedules_" + $JobConfigVersion + ".cfg"
   

    Write-Output $JobScheduleConfigFile #$JobScheduleConfigFile

}  #Function Set-JobScheduleConfigFile


#-----------------------------------------------------
function Set-JobConfigFile {

    param (
        [Parameter (Mandatory = $false)] [String]$JobConfigVersion
    )

    $JobConfigFile = "JobConfig_" + $JobConfigVersion.toupper() + ".cfg"
        
    Write-Verbose "JobConfigFile = $JobConfigFile"

    Write-Output $JobConfigFile #$JobScheduleConfigFile

}       #Function Set-JobConfigFile

#test
#This is a test


#-----------------------------------------------------
Function Get-JobConfig {

    #Display the contents of the specified job config file

    param (
        [parameter (Mandatory = $false)] [String] $JobName ,
        [parameter (Mandatory = $true)] [String] $JobConfigVersion
    )


    $JobConfigFile = "JobConfig" + $JobConfigVersion + ".cfg"
    $JobScheduleConfigFile = "JobSchedules" + $JobConfigVersion + ".cfg"


    if ($JobName) {

        $Jobs = Import-CSV $JobConfigFile -Delimiter '|' | ? JobName -like $JobName
    
        $Schedule = Import-CSV $JobScheduleConfigFile -Delimiter '|' | Where-Object ScheduleID -eq $Jobs.Scheduleid
    
    }
    else {

        Get-Content $JobConfigFile

    }


}           #Function Get-JobConfig


#-----------------------------------------------------
Function Get-JobInfo {

    param (
        [parameter (Mandatory = $true) ] [String] $Instance,
        [parameter (Mandatory = $false)] [String] $JobName ,
        [parameter (Mandatory = $false)] [Bool] $ShowDetail
    )

    Write-Verbose "In Function Get-JobInfo"

    $WhereClause = $null

    if ($JobName) {
        $WhereClause = "AND jobs.name = '" + $JobName + "'"
    }

    $QryFile = "QryJobInfo.sql"
    $QryFileTmp = "QryJobInfo_tmp.sql"


    #Let's invoke an external SQL script, but first update the ps_WHERE_CLAUSE in the SQL

    #Write-Verbose "Get-Content $QryFile | ForEach-Object {$_ -replace "ps_WHERE_CLAUSE", $WhereClause} | Set-Content $QryFileTmp"

    Get-Content $QryFile | ForEach-Object {$_ -replace "ps_WHERE_CLAUSE", $WhereClause} | Set-Content $QryFileTmp


    if ($ShowDetail) {
    
        Invoke-DbaSqlCmd -SqlInstance $Instance -File $QryFileTmp     

    }
    else {
        
        Write-Verbose "Invoke-DbaSqlCmd -SqlInstance $Instance -File $QryFileTmp | select-object JobName,Enabled,ScheduleName,EventLogWrite,EmailNotify,EmailOperator | format-table"

        Invoke-DbaSqlCmd -SqlInstance $Instance -File $QryFileTmp | select-object JobName, Enabled, ScheduleName, EventLogWrite, EmailNotify, EmailOperator | format-table

    } #If




}             #Function Get-JobInfo


#-----------------------------------------------------
Function Get-ScheduleInfo {

    param (
        [parameter (Mandatory = $true)] [String] $Instance,
        [parameter (Mandatory = $false)]  [String] $JobName,
        [parameter (Mandatory = $false)] [Bool] $ShowDetail
    )


    $WhereClause = $null

    if ($JobName) {
        $WhereClause = "AND name = '" + $JobName + "'"
    }

    $QryFile = "QryScheduleInfo.sql"
    $QryFileTmp = "QryScheduleInfo_tmp.sql"


    #Let's invoke an external SQL script, but first update the ps_WHERE_CLAUSE in the SQL

    Get-Content $QryFile | ForEach-Object {$_ -replace "ps_WHERE_CLAUSE", $WhereClause} | Set-Content $QryFileTmp

    if ($ShowDetail) {
    
        Invoke-DbaSqlCmd -SqlInstance $Instance -File $QryFileTmp   | format-table  

    }
    else {

        Invoke-DbaSqlCmd -SqlInstance $Instance -File $QryFileTmp | select-object ScheduleName, Occurs, Detail, Frequency | format-table

    } #If



}        #Function Get-ScheduleInfo


#-----------------------------------------------------
Function Remove-Job {

    param (
        [Parameter (Mandatory = $true)]  [String]$Instance,
        [Parameter (Mandatory = $true)]  [String]$JobName,
        [Parameter (Mandatory = $true)]  [Switch]$AllVMDBAJobs
    )


    If ($AllVMDBAJobs) {
        
        #$SQLCmd="declare @JobName varchar(100);`nselect name into #t1 from msdb.dbo.sysjobs where category_id = (select category_id from msdb.dbo.syscategories where name = 'VMDBA'  and category_class = 1); while exists (select * from #t1) begin select top 1 @JobName = name from #t1; exec msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule=1; delete from #t1 where name = @JobName; end"

        $SQLCmd = "declare @JobName varchar(100);select name into #t1 from msdb.dbo.sysjobs where category_id = (select category_id from msdb.dbo.syscategories where name = 'VMDBA'  and category_class = 1); while exists (select * from #t1) begin select top 1 @JobName = name from #t1; exec msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule=1; delete from #t1 where name = @JobName; end"

        Write-Verbose $SQLCmd
        
        $ScriptName = "c:\temp\RemoveJob_${Instance}.ps1"

        if ($GenerateScript) {
        
            Write-output "invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query ""$SQLCmd""" > $ScriptName
            write-host "`nGenerated script is $Scriptname."

        }


        if ($ExecuteCommand) {

            #invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd

            invoke-sqlcmd -ServerInstance $Instance -Database msdb -InputFile $ScriptName

        }

        

    }
    else {

        
        $SQLCmd = "IF EXISTS (SELECT job_id from msdb.dbo.sysjobs WHERE name = '$JobName') EXEC msdb.dbo.sp_delete_job @Job_name = '$JobName'" + "," + "@delete_unused_schedule=1;"

        Write-Verbose $SQLCmd

        invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd

    }

    
}              #Function Remove-Job


Function Out-Command {

    param (

        [Parameter(Mandatory = $true)] $Command,
        [Parameter(Mandatory = $true)] $CommandOutput,
        [Parameter(Mandatory = $true)] $CommandComment,
        [Parameter(Mandatory = $false)] $CommandOUtputFileName
    )


    Switch ($CommandOutput) {

        "Screen" {write-host $Command }

        "File" {
            write-host "File"
            $Command | set-content "c:\temp\$CommandOutputFilename"

        }


        "Both" {write-host "both"}

    }


} #Function Out-Command


#-----------------------------------------------------
Function New-Job {

    param (
        [Parameter(Mandatory = $true )] [String]$Instance,
        [Parameter(Mandatory = $true )] [String]$JobName,
        [Parameter(Mandatory = $true )] [String]$JobConfigFile,
        [Parameter(Mandatory = $true )] [String]$JobConfigVersion,
        [Parameter(Mandatory = $true )] [String]$OutputDriveLetter,
        [Parameter(Mandatory = $false )] [String]$ps_Enabled,
        [Parameter(Mandatory = $false )] [String]$ps_NOTIFY_LEVEL_EVENTLOG,
        [Parameter(Mandatory = $false )] [String]$ps_NOTIFY_EMAIL_OPERATOR_NAME,
        [Parameter(Mandatory = $false )] [String]$AddVersionToJobName
    )


    Write-Verbose "Inside function: New-Job"

    Write-Verbose "JobName=$Jobname"
    Write-Verbose "JobConfigFile=$JobConfigFile"
    Write-Verbose "JobConfigVersion=$JobConfigVersion"
    
    
    #Build the job output filename
      
    #1. Set the directory of where these instance-specific job output files will go
    $OutputFileDir = $OutputDriveLetter + ':' + "\SQLJobLogs\" + $Instance
        
    #2. Set the file placeholder substitution variable
    $ps_OUTPUT_FILE_DIR = $OutputFileDir

    #3. Build the output file name
    # For the file name, replace colons,dashes, and spaces with underscores 
    $OutputFileName = ($CurrentJobName -replace ': ', '_').trim() ; $OutputFileName = ($OutputFileName -replace ' - ', '_').trim() ; $OutputFileName = ($OutputFileName -replace ' ', '_').trim() 
    
    #4. Add a timestamp
    $Timestamp = [DateTime]::Now.ToString("yyyyMMdd-HHmm") -replace '-', '_'
    $OutputFileName = $OutputFileName + '__' + $Timestamp

    #5. Add a suffix
    $OutputFileName = $OutputFileName + '.txt'
    
    #6. Set the replacement variable
    $ps_OUTPUT_FILE_NAME = $OutputFileName
    
    #7. Now add the directory
    $ps_OUTPUT_FILE_NAME = $OutputFileDir + '\' + $OutputFileName

    Write-Verbose "ps_OUTPUT_FILE_NAME = $ps_OUTPUT_FILE_NAME"
    
    
        
    #Drop the job on the target instance if it already exists
    if ($DropIfExists) {
        Remove-Job -Instance $Instance -JobName $CurrentJobName
    }
     

    #Tack on the job type and version number to the description
    #Tried, but not very attractive due to inability to put in CR/LF
    #$CurrentJobDescription="'" + "Job Version  : " + $JobConfigVersion.toupper() + "Job Type     : " + $CurrentJobType + "Job Function : " + $CurrentJobDescription + "'"

    #Add single quotes to description
    $CurrentJobDescription = "'" + $CurrentJobDescription + "'"

    
            
    #Let's build the Job DDL
    $SQLCmd = "EXEC msdb.dbo.sp_add_job @job_name=N'${CurrentJobName}', @enabled=$ps_Enabled,@notify_level_eventlog=$ps_NOTIFY_LEVEL_EVENTLOG, @notify_level_email=2,@description=${CurrentJobDescription},@category_name=N'VMDBA', @owner_login_name=N'sa', @notify_email_operator_name='${ps_NOTIFY_EMAIL_OPERATOR_NAME}'"
    write-Verbose $SQLCmd


    $CommandComment = "Comment!"

    # Send the command to screen, file or both
    Out-Command -command $SQLCmd -CommandComment $CommandComment -CommandOutput $CommandOutput -CommandOUtputFileName "CreateJob_${Instance}.sql"

    exit

        
    If ($ExecuteCommand) {
        invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd
    }


    #Build the job Step
    $JobStepDDL = "EXEC msdb.dbo.sp_add_jobstep @job_name='${CurrentJobName}', @step_name='${CurrentJobName}', @step_id=1, @subsystem='${CurrentJobStep1SubSystem}',@command='${CurrentJobStep1Command}',@output_file_name='${ps_OUTPUT_FILE_NAME}'"
    write-Verbose $JobStepDDL

    if ($ExecuteCommand) {
        invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $JobStepDDL
    }


    #Now let's set the schedule
    Write-Verbose "Calling Set-JobSchedule"

    Set-JobSchedule -Instance $Instance -JobName $CurrentJobName -JobConfigVersion $JobConfigVersion -ScheduleID $Job.ScheduleID



} #Function New-Job



Function Set-Category-VMDBA {

    param (
        [Parameter(Mandatory = $true )] [String]$Instance
    )


    #Does category already exist?
    $Result = Invoke-DbaSqlCmd -SqlInstance $Instance -query "select count(*) as cnt from msdb.dbo.syscategories where name = 'VMDBA' and category_class=1"

    if ($Result.cnt -gt 0) {
        
        Write-Verbose "The category VMDBA already exists in $Instance ."
        
    }
    else {

        $SQLCmd = "exec msdb.dbo.sp_add_category @class = 'JOB', @type = 'LOCAL', @name = 'VMDBA' "

        Invoke-DbaSqlCmd -SqlInstance $Instance -Query $SQLCmd
    
    }

    

}      #Function Set-Category-VMDBA





#-------------------------------------------------------- MAIN -------------------------------------------------------------#


# Change to the working directory
$RootDir = "D:\SQLScripts\Installation\DBA_Tools_Setup\Jobs"
cd $RootDir


if (!($env:PSModulePath | select-string "vmmc" )) {

    . D:\vmmc\bin\PowerShell\mssql_scripts\Shared\ProfileGlobal.ps1
    import-module dbatools

}

#Set switch variables according to parameters passed in

switch ($EmailNotificationOn) {
    $true {$ps_NOTIFY_EMAIL_OPERATOR_NAME = "DBA-Alert"}
    $false {$ps_NOTIFY_EMAIL_OPERATOR_NAME = ""}
}


switch ($EventLogNotificationOn) {
    $true {$ps_NOTIFY_LEVEL_EVENTLOG = "2"}
    $false {$ps_NOTIFY_LEVEL_EVENTLOG = "0"}
}


switch ($EnableJob) {
    $true {$ps_Enabled = "1"}
    $false {$ps_Enabled = "0"}
}


## First, see if any of the read-only functions are being called

#Get information about existing job 
If ($GetJobInfo) {
    Write-Verbose "-GetJobInfo"
    Get-JobInfo -Instance $Instance -JobName $JobName -ShowDetail $ShowDetail
    exit
}


#Get schedule info for existing job
If ($GetScheduleInfo) {
    Get-ScheduleInfo $Instance $JobName $ShowDetail
    exit
}


#Show the contents of a job config file
If ($GetJobConfig) {
    Get-JobConfig $JobName $JobConfigVersion 
    exit
}


#Remove all jobs which belong to the category 'VMDBA'
if ($RemoveJob -and $AllVMDBAJobs) {
    if ($AllVMDBAJobs) { $AllVMDBAJobs = $true } else {$AllVMDBAJobs = $false}
    Remove-Job -Instance $Instance -JobName All -AllVMDBAJobs
    exit
}



#Get the name of the config file, based upon the version
$JobConfigFile = Set-JobConfigFile -JobConfigVersion $JobConfigVersion


#Let's first see if the job config file exists
if (!(Test-Path $JobConfigFile)) {

    Write-Host "`nThe job config file $JobConfigFile does not exist."
    exit

}


#Do we have any action to take

if (!($CreateJob) -and (!($RemoveJob))) {
    
    Write-Host "No action specified"
    exit
}


#Let's be optimistic
$Process = $true

#Now let's loop through each job specified


#The job does not appear in the config file
if (!(sls $JobName $JobConfigFile)) {$Process = $false}


#We want to create all jobs listed in the config file
If ($JobName -eq "All") {$Process = $true}


If (!($Process)) {
    write-output "Job $JobName not found in $JobConfigFile"
    exit
}


# Get the list of jobs
If ($JobName -ne "All") {

    $Jobs = Import-CSV $JobConfigFile -Delimiter '|' | ? JobName -like $JobName
}

    

If ($JobName -eq "All") {

    $Jobs = Import-CSV $JobConfigFile -Delimiter '|' 
}

    
    

Foreach ($Job in $Jobs) {

    #JobName,JobType,Description,Step1Subsystem,Step1Command,ScheduleID

    # Process each job as listed in manifest
    $CurrentJobName = ($Job.JobName | out-string -Stream).trim()
    $CurrentJobType = ($Job.JobType | out-string -Stream).trim()
    $CurrentJobDescription = ($Job.Description | out-string -Stream).trim()
    $CurrentJobStep1Subsystem = ($Job.Step1Subsystem | out-string -Stream).trim()
    $CurrentJobStep1Command = ($Job.Step1Command | out-string -Stream).trim()
    $CurrentJobSchedule = ($Job.ScheduleID | out-string -Stream).trim()

    Write-Verbose "Current Job Name = $CurrentJobName"
    Write-Verbose "Current Job Type = $CurrentJobType"

    Write-Verbose "Current Job Description = $CurrentJobDescription"
    Write-Verbose "Current Job Step 1 Subsystem = $CurrentJobStep1Subsystem"
    Write-Verbose "Current Job Step 1 Command = $CurrentJobStep1Command"
    Write-Verbose "Current Job Schedule = $CurrentJobSchedule"

    
    
    if (($JobName) -and ($Jobname -ne "All")) {
        #Was a job name specified? If so, skip all other jobs.

        if ($CurrentJobName -ne $JobName) {
            Write-Output "Current Job `"$CurrentJobName`" does not match specified job name `"$JobName`""
            Continue 
        }
    }
    

    #Let's add a suffix to the job name
    If ($IncludeVersionOnJobName) {
        $CurrentJobName = $CurrentJobName + " - Version:" + $JobConfigVersion.toupper()
    }

    #Create a new job
    if ($CreateJob) {

        Write-Verbose "-CreateJob"
        Set-Category-VMDBA $Instance
        New-Job -Instance $Instance -JobName $CurrentJobName -JobConfigFile $JobConfigFile -JobConfigVersion $JobConfigVersion -OutputDriveLetter $OutputDriveLetter -ps_NOTIFY_LEVEL_EVENTLOG $ps_NOTIFY_LEVEL_EVENTLOG -ps_Enabled $ps_Enabled -ps_NOTIFY_EMAIL_OPERATOR_NAME $ps_NOTIFY_EMAIL_OPERATOR_NAME
    }


    if ($RemoveJob) {
        Write-Verbose "-RemoveJob"
        
        Remove-Job -Instance $Instance -JobName $CurrentJobName -AllVMDBAJobs
        
    }



}# End Foreach



<#
    if ($ViewCommand) {
    cmd.exe /c start /max notepad.exe $InstanceSpecificFilename
    }

    #>




