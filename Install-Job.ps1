<#
Install-Job.ps1

.SYNOPSIS
    Creates one or more SQL Server agent jobs which belong to the VMDBA Toolkit
  
.DESCRIPTION
    This script will help the DBA create the jobs that are part of the VM DBA Toolkit.
    

#-----------------------------------------------------------------------------------------------------------------------------#       
.PARAMETER Instance
    The instance that you want to restore. You can pass in a single instance, or a comma-delimited list of instances.
    Default: None

.PARAMETER JobName
    When working with a single job, the name of the job.
    Default: None

.PARAMETER DropIfExists
    Drop the agent job or schedule if it already exists. If this is not specified, the job will NOT be re-created.
    Default: False
    
.PARAMETER JobConfigFile
    The name of the configuration file which contains all jobs and their attributes.
    Default: None

        
#-----------------------------------------------------------------------------------------------------------------------------#

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

    .\Manage-AgentJobs.ps1 -Instance merchsoftdb-t1 -jobConfigVersion pe10 -Verbose -JobName 'DatabaseBackup - SYSTEM_DATABASES - FULL' -CreateJob

    Creates the job 'DatabaseBackup - SYSTEM_DATABASES - FULL' in the instance merchsoftdb-t1, using the job config info in the PE10 config file.



.EXAMPLE

    .\Manage-AgentJobs.ps1 -Instance merchsoftdb-t1 -jobConfigVersion pe11 -Verbose -JobName all -createJob -IncludeVersionOnJobName

    Create jobs on target instance, as defined in the PE11 config file, and include the version name (PE11) as a suffix on the job name


.NOTES  
    File Name    : Install-Job.ps1
    Author       : Johnny London, VMMH
    Date Created : 2018-02-12
    Version 0.10
    
    The -verbose parameter is supported, and will output SQL statements and other additional info.

    This script is one of several scripts which can be used to manage SQL Server agent jobs.

        Install-Job.ps1
        Uninstall-Job.ps1
        Enable-Job.ps1
        Disable-Job.ps1

    
    When you create a job, you specify a job name and a configuration file. The configuration file contains the job description, command and schedule to use.
    The schedule is taken from the schedule configuration file that you specify.

    By Default:
         the job is not enabled.
         Email is not configured
         Event log write is not configured
         

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
    [Parameter( ParameterSetName = 'psCreateJob', Mandatory = $true )]
    [String] $Instance,

    [Parameter( ParameterSetName = 'psCreateJob', Mandatory = $true )]
    [String] $JobName,

    [Parameter (ParameterSetName = 'psCreateJob', Mandatory = $false)] 
    [String] $JobConfigVersion,

    [Parameter (ParameterSetName = 'psCreateJob', Mandatory = $false)]   
    [Switch] $ExecuteCommand,

    [Parameter (ParameterSetName = 'psCreateJob', Mandatory = $false)]
    [Switch] $AddVersionToJobName = $false,
            
    [Parameter (ParameterSetName = 'psCreateJob', Mandatory = $false)]
    [Switch] $DropIfExists,
    
    [Parameter (ParameterSetName = 'psCreateJob', Mandatory = $false)]  
    [Switch] $IncludeVersionOnJobName,

    [Parameter (Mandatory = $false)] [Switch] $ExecuteScript,

    [Parameter (Mandatory = $false)] [String] 
    [ValidateSet("Screen", "File", "Both")]
    $CommandOutput




 )

 
foreach ($Job in .\Get-JobList.ps1 -JobConfigVersion $JobConfigVersion -JobName $JobName) {



    #Build the job output filename
      
    #1. Set the directory of where these instance-specific job output files will go
    $OutputDriveLetter=./Get-LocalDrive.ps1 -Server $Instance

    $OutputFileDir = $OutputDriveLetter + ':' + "\SQLJobLogs\" + $Instance
        
    #2. Set the file placeholder substitution variable
    $ps_OUTPUT_FILE_DIR = $OutputFileDir

    #3. Build the output file name
    # For the file name, replace colons,dashes, and spaces with underscores 
    $OutputFileName = ($Job.Name -replace ': ', '_').trim() ; $OutputFileName = ($OutputFileName -replace ' - ', '_').trim() ; $OutputFileName = ($OutputFileName -replace ' ', '_').trim() 
    
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
        Uninstall-Job -Instance $Instance -JobName $Job.Name
    }
     

    #Tack on the job type and version number to the description
    #Tried, but not very attractive due to inability to put in CR/LF
    #$CurrentJobDescription="'" + "Job Version  : " + $JobConfigVersion.toupper() + "Job Type     : " + $Job.CurrentJobType + "Job Function : " + $Job.CurrentJobDescription + "'"

    #Add single quotes to description
    $JobDescription = "'" + $Job.Description + "'"

                
    #Let's build the Job DDL script file
    
    $CommandComment = "-- Create VMDBA Agent Job $Job.Name"
    
    #$CommandComment | Add-Content $
    

    #Convert objects to strings
    $JobDescription=($Job.Description |out-string).trim()
    $JobName=($Job.Name |out-string).trim()
    $Step1Subsystem=($Job.Step1SubSystem | out-string).trim()
    $Step1Command=($Job.Step1Command | out-string).trim()
    $ScheduleID=($Job.ScheduleID | out-string).trim()

    
    $SQLCmd = "EXEC msdb.dbo.sp_add_job @job_name='${JobName}', @enabled=0,@notify_level_eventlog=0, @notify_level_email=2,@description='${JobDescription}', @category_name=N'VMDBA', @owner_login_name=N'sa', @notify_email_operator_name='' ;"

        Write-Verbose "$SQLCmd"
              
    If ($ExecuteCommand) {

        invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd

    } else {

        write-output $SQLCmd

    }

    
    #Build the job Step
    $SQLCmd = "EXEC msdb.dbo.sp_add_jobstep @job_name='${JobName}', @step_name='${JobName}', @step_id=1, @subsystem='${Step1SubSystem}',@command='${Step1Command}',@output_file_name='${ps_OUTPUT_FILE_NAME}' ;`n"
    
    #Out-Command -command $SQLCmd -CommandComment $CommandComment -CommandOutput $CommandOutput -CommandOUtputFileName "CreateJob_${Instance}.sql"

    
    Write-Verbose $SQLCmd


    if ($ExecuteCommand) {
        
        invoke-sqlcmd2 -ServerInstance $Instance -Database msdb -query $SQLCmd

    } else {

        write-output $SQLCmd
    }


    #Now let's set the schedule
    Write-Verbose "Calling Set-JobSchedule"

    Set-JobSchedule -Instance $Instance -JobName $JobName -JobConfigVersion $JobConfigVersion -ScheduleID $JobScheduleID










