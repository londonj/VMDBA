<#
Get-JobList.ps1

.SYNOPSIS
    Returns a list of jobs in a specified version file
  
.DESCRIPTION
    Based upon a config file version, this script returns properties for the specified job, or all jobs
    

#-----------------------------------------------------------------------------------------------------------------------------#       

.PARAMETER JobName
    When working with a single job, the name of the job.
    Default: None

.PARAMETER JobConfigVersion
    Drop the agent job or schedule if it already exists. If this is not specified, the job will NOT be re-created.
    Default: False
    

        
#-----------------------------------------------------------------------------------------------------------------------------#

.EXAMPLE


.NOTES  
    File Name    : all-Job.ps1
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


                       

#>




  [CmdletBinding()]

    param (
    [Parameter (Mandatory=$true)] $JobName,
    [Parameter (Mandatory=$true)] $JobConfigVersion
    )


    $JobConfigFile=.\Set-JobConfigFile.ps1 -JobConfigVersion $JobConfigVersion

     If ($JobName -ne "All") {

        $Jobs = Import-CSV $JobConfigFile -Delimiter '|' | ? JobName -like $JobName
    }

    

    If ($JobName -eq "All") {

        $Jobs = Import-CSV $JobConfigFile -Delimiter '|' 
    }


    $JobCollection = New-Object System.Collections.ArrayList

    Foreach ($Job in $Jobs) {
        
        $JobObj=new-object system.object
        
        $JobObj | Add-Member -MemberType NoteProperty -Name "Name"               -Value $Job.JobName
        $JobObj | Add-Member -MemberType NoteProperty -Name "Description"           -Value $Job.Description
        $JobObj | Add-Member -MemberType NoteProperty -Name "Step1Subsystem"        -Value $Job.Step1Subsystem
        $JobObj | Add-Member -MemberType NoteProperty -Name "Step1Command"          -Value $Job.Step1Command
        $JobObj | Add-Member -MemberType NoteProperty -Name "ScheduleID"            -Value $Job.ScheduleID

        $JobCollection.Add($JobObj) | out-Null

    } #End Foreach


    write-output $JobCollection

    
    
        



<#
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

  
  #>
  
    

