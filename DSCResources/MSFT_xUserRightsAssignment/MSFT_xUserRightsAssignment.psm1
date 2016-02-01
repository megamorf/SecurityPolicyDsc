function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Create_a_token_object","Access_this_computer_from_the_network","Change_the_system_time","Deny_log_on_as_a_batch_job","Deny_log_on_through_Remote_Desktop_Services","Create_global_object","Remove_computer_from_docking_station","Deny_access_to_this_computer_form_the_network","Act_as_part_of_the_operating_system","Modify_firmware_environment_values","Deny_log_on_locally","Access_Credential_Manager_as_a_trusted_caller","Restore_files_and_directories","Change_the_time_zone","Replace_a_process_level_token","Manage_auditing_and_security_log","Create_symbolic_links","Modify_an_object_label","Enable_computer_and_user_accounts_to_be_trusted_for_delegation","Generate_security_audits","Increase_a_process_working_set","Take_ownership_of_files_or_other_objects","Bypass_traverse_checking","Log_on_as_a_service","Shut_down_the_system","Lock_pages_in_memory","Impersonate_a_client_after_authentication","Profile_system_performance","Debug_programs","Profile_single_process","Allow_log_on_through_Remote_Desktop_Services","Allow_log_on_locally","Increase_scheduling_priority","Synchronize_directory_service_data","Add_workstations_to_domain","Adjust_memory_quotas_for_a_process","Perform_volume_maintenance_tasks","Load_and_unload_device_drivers","Force_shutdown_from_a_remote_system","Back_up_files_and_directories","Create_a_pagefile","Deny_log_on_as_a_service","Log_on_as_a_batch_job","Create_permanent_shared_objects")]
		[System.String]
		$Policy,

		[parameter(Mandatory = $true)]
        [AllowNull()]
		[System.String[]]
		$Identity,

		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    
    $usrResult = Get-USRPolicy -Policy $Policy -Areas USER_RIGHTS

    $testResult = Test-TargetResource -Identity $Identity -Policy $Policy -Ensure $Ensure -Verbose:0
    
    If($testResult)
    {
        $ensureResult = 'Present'
    }
    Else
    {
        $ensureResult = 'Absent'
    }

    $returnValue = @{

		Policy = $usrResult.PolicyFriendlyName
		Identity = $Identity
        Ensure = $ensureResult
        ActualIdentity = $usrResult.Identity
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Create_a_token_object","Access_this_computer_from_the_network","Change_the_system_time","Deny_log_on_as_a_batch_job","Deny_log_on_through_Remote_Desktop_Services","Create_global_object","Remove_computer_from_docking_station","Deny_access_to_this_computer_form_the_network","Act_as_part_of_the_operating_system","Modify_firmware_environment_values","Deny_log_on_locally","Access_Credential_Manager_as_a_trusted_caller","Restore_files_and_directories","Change_the_time_zone","Replace_a_process_level_token","Manage_auditing_and_security_log","Create_symbolic_links","Modify_an_object_label","Enable_computer_and_user_accounts_to_be_trusted_for_delegation","Generate_security_audits","Increase_a_process_working_set","Take_ownership_of_files_or_other_objects","Bypass_traverse_checking","Log_on_as_a_service","Shut_down_the_system","Lock_pages_in_memory","Impersonate_a_client_after_authentication","Profile_system_performance","Debug_programs","Profile_single_process","Allow_log_on_through_Remote_Desktop_Services","Allow_log_on_locally","Increase_scheduling_priority","Synchronize_directory_service_data","Add_workstations_to_domain","Adjust_memory_quotas_for_a_process","Perform_volume_maintenance_tasks","Load_and_unload_device_drivers","Force_shutdown_from_a_remote_system","Back_up_files_and_directories","Create_a_pagefile","Deny_log_on_as_a_service","Log_on_as_a_batch_job","Create_permanent_shared_objects")]
		[System.String]
		$Policy,

		[parameter(Mandatory = $true)]
        [AllowNull()]
		[System.String[]]
		$Identity,

		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

        [Switch]$PassThru
	)
    
    $policyList = Get-AssignmentFriendlyNames
    $policyName = $policyList[$Policy]
    $script:seceditOutput = "$env:TEMP\Secedit-OutPut.txt"

    #secedit.exe overwrites the current identities that have rights. So we need to store the current identities in an array then remove and add as needed
    
    $getResults = Get-TargetResource -Policy $Policy -Identity $Identity -Ensure $Ensure -Verbose:0    
    $IdList = New-Object System.Collections.ArrayList

    #Convert all strings to lower case because the Remove() method is case sensitive
    If($getResults.ActualIdentity)
    {
        [System.Collections.ArrayList]$idList += $getResults.ActualIdentity | % {$_.ToLower()}
    }

    If($Identity -ne 'NULL' -and $Identity)
    {
        $Identity = $Identity | % {$_.ToLower()}

        Foreach($desiredId in $Identity)
        {
            If($Ensure -eq 'Present')
            {
                If($idList -notcontains $desiredId)
                {
                    [void]$idList.Add($desiredId)
                }
            }
            Else
            {
                If($idList -contains $desiredId)
                {
                    [void]$idList.Remove($desiredId)
                }
            }
        }    
    }
    Else
    {
        Write-Verbose "Identity is NULL. Removing all Identities from $Policy"
        $idList = $null
    }    

    #Create INF to configure desired permissions
    $userRightsToAddInf = ([system.IO.Path]::GetTempFileName()).Replace('tmp','inf')    
    $idsToAdd = $idList -join ","
    Out-UserRightsInf -InfPolicy $policyName -UserList $idsToAdd -FilePath $userRightsToAddInf
    Write-Debug "Temp inf $userRightsToAddInf"

    If($Identity -ne 'NULL')
    {
        If($Ensure -eq 'Present')
        {
            Write-Verbose "Granting rights to $idsToAdd on $Policy"
        }
        Else
        {
            Write-Verbose "Removing rights from $identity on $Policy"
        }
    }
    Else
    {
        Write-Verbose "Remvoing all rights granted on $Policy"
    }

    Invoke-Secedit -UserRightsToAddInf $userRightsToAddInf -SecEditOutput $seceditOutput

    #Verify secedit command was successful
    $testSuccuess = Test-TargetResource -Identity $Identity -Policy $Policy -Ensure $Ensure -Verbose:0

    If($testSuccuess -eq $true)
    {
        Write-Verbose "The task has completed successfully"
    }
    Else
    {
        $seceditResult = Get-Content $script:seceditOutput
        Write-Verbose "The task did not complete successfully."
        Write-Verbose "$($seceditResult[-1])"
    }

    If($PassThru)
    {
        [pscustomobject]@{
            Policy = $Policy
            Identity = $idsToAdd
        }
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Create_a_token_object","Access_this_computer_from_the_network","Change_the_system_time","Deny_log_on_as_a_batch_job","Deny_log_on_through_Remote_Desktop_Services","Create_global_object","Remove_computer_from_docking_station","Deny_access_to_this_computer_form_the_network","Act_as_part_of_the_operating_system","Modify_firmware_environment_values","Deny_log_on_locally","Access_Credential_Manager_as_a_trusted_caller","Restore_files_and_directories","Change_the_time_zone","Replace_a_process_level_token","Manage_auditing_and_security_log","Create_symbolic_links","Modify_an_object_label","Enable_computer_and_user_accounts_to_be_trusted_for_delegation","Generate_security_audits","Increase_a_process_working_set","Take_ownership_of_files_or_other_objects","Bypass_traverse_checking","Log_on_as_a_service","Shut_down_the_system","Lock_pages_in_memory","Impersonate_a_client_after_authentication","Profile_system_performance","Debug_programs","Profile_single_process","Allow_log_on_through_Remote_Desktop_Services","Allow_log_on_locally","Increase_scheduling_priority","Synchronize_directory_service_data","Add_workstations_to_domain","Adjust_memory_quotas_for_a_process","Perform_volume_maintenance_tasks","Load_and_unload_device_drivers","Force_shutdown_from_a_remote_system","Back_up_files_and_directories","Create_a_pagefile","Deny_log_on_as_a_service","Log_on_as_a_batch_job","Create_permanent_shared_objects")]
		[System.String]
		$Policy,

		[parameter(Mandatory = $true)]
        [AllowNull()]
		[System.String[]]
		$Identity,

		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    
    $attendance = @{}
    
    $userRights = Get-USRPolicy -Policy $Policy -Areas USER_Rights

    #Create a hashtable to reference if an identity is Absent or Present
    If($Identity -ne 'NULL')
    {
        Write-Verbose "Testing $($Identity -join",") is $Ensure on policy $Policy"
        Foreach($id in $Identity)
        {
            If($userRights.Identity -contains $id)
            {
                $attendance.Add($id,'Present')
            }
            Else
            {
               $attendance.Add($id,'Absent')         
            }       
        }

        Foreach($name in $attendance.keys)
        {
            If($attendance[$name] -ne $Ensure)
            {
                return $false
            }
        }
    }
    Else
    {
        Write-Verbose "Testing policy $Policy for NULL Identity"
        If($userRights.Identity)
        {
            Write-Verbose "$Policy has $($userRights.Identity.count) identities assigned. Expected NULL"
            return $false
        }
    }
    #If the code made it this far all identities have the desired user rights

    return $true
}


Export-ModuleMember -Function *-TargetResource
