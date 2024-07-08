function Set-AA8MachineCustomProperty
{
<#
.SYNOPSIS
  Update an Aria Automation Machine Custom Property.
.DESCRIPTION
  
.NOTES
   Author:  Clint Fritz

   ParameterSet ideas

   Single for a single key value pair on one or more machine names

   Multiple for an array of key value pairs on one or more machine names

   File for reading and applying key value pairs to machines.
     will collapse all the key value pairs into a group to apply the machine in
     one action. e.g. if you have 2 custom properties to set on a machine there
     will be 2 entries in the file.


  Add update by id?

#>

[CmdletBinding(DefaultParameterSetName='Single')]
Param(
    #fqdn\ipaddress of the server
    [Parameter(Mandatory=$false)]
    [Alias("Server","IPAddress","FQDN","vraServer")]
    [string]$ComputerName=$vraServer,

    #Credential
    [Parameter(Mandatory=$false)]
    $Credential=$vraCredential,

    #The authentication domain to validate the user against
    [string]$AuthDomain=$AuthDomain,

    #Name of the machine
    [Parameter(Mandatory,ParameterSetName="Single")]
    [Alias("Name")]
    [string[]]$MachineName,

    #Custom property name
    [Parameter(Mandatory,ParameterSetName="Single")]
    [string]$Key,

    #Custom Property value to set. $null is allowed and used to Remove a custom property.
    [Parameter(Mandatory,ParameterSetName="Single")]
    [AllowEmptyString()]
    [string]$Value,

    #Path to the file to use as input parameters for the name, key and value.
    [Parameter(Mandatory,ParameterSetName="File")]
    [Alias("Path")]
    [string]$FilePath



)


Begin {
    Write-Verbose "$(Get-Date) Begin"
    Write-Verbose "$(Get-Date) ParameterSet: $($PSCmdlet.ParameterSetName)"
    Write-Verbose "$(Get-Date) ComputerName: $($ComputerName)"
    Write-Verbose "$(Get-Date) Credential:   $($Credential)"
    Write-Verbose "$(Get-Date) Auth Domain:  $($AuthDomain)"
    Write-Verbose "$(Get-Date) Machine Name: $($MachineName)"
    Write-Verbose "$(Get-Date) Key:          $($Key)"
    Write-Verbose "$(Get-Date) Value:        $($Value)"
    Write-Verbose "$(Get-Date) FilePath:     $($FilePath)"


    if($PSCmdlet.ParameterSetName -eq "Single") {
        
    } else {
        Write-Warning "ParameterSet $($PSCmdlet.ParameterSetName) is not currently supported."
        throw
    }
    

    #TODO: Create the headers

    [string]$username = $Credential.UserName
    [string]$UnsecurePassword = $Credential.GetNetworkCredential().Password

    $body = @{
        username = $username
        password = $UnsecurePassword
        tenant = "vsphere.local"
        domain = $Domain
    } | ConvertTo-Json
    
    #this fails on systems where Powershell is locked down. preventing even .net things from working :(
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    } catch {
        Write-Warning "Your organisation has broken stuff!"
        Write-Output "[ERROR] $(Get-Date) Exception: $($_.Exception)"
        throw
    }
    $headers.Add("Accept", 'application/json')
    $headers.Add("Content-Type", 'application/json')

    $method = "POST"
    $baseUrl = "https://$($ComputerName)"
    #$uri = "$($baseUrl)/identity/api/tokens"
    $uri = "$($baseUrl)/csp/gateway/am/api/login?access_token"
    Write-Verbose "$(Get-Date) uri: $($uri)"
    #https://kb.vmware.com/s/article/89129

    Write-Verbose "$(Get-Date) Request a token from vRA"

    Write-Verbose "$(Get-Date) method: $($method)"
    Write-Verbose "$(Get-Date) headers: $($headers)"
    #For troubleshooting only, do NOT leave uncommented else your password will be displayed
    #Write-Verbose "$(Get-Date) body: $($body)"


    try
    {
        $response = $null
        $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body
    }
    catch 
    {
        Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
        Write-Output "Error Message:        $($_.ErrorDetails.Message)"
        Write-Output "Exception:            $($_.Exception)"
        Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
        throw
    }

Write-Verbose "$(Get-Date) Refresh Token received."
$newBody = @"
{ 
    refreshToken: "$($response.refresh_token)" 
} 
"@

    $method = "POST"
    $baseUrl = "https://$($ComputerName)"
    $uri = "$($baseUrl)/iaas/api/login"
    Write-Verbose "$(Get-Date) uri: $($uri)"

    Write-Verbose "$(Get-Date) Request a token from vRA"
    try
    {
        $response = $null
        $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $newBody
    }
    catch 
    {
        Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
        Write-Output "Error Message:        $($_.ErrorDetails.Message)"
        Write-Output "Exception:            $($_.Exception)"
        Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
        throw
    }

    Write-Verbose "$(Get-Date) Token received. Add the retrieved Bearer token to the headers"
    $bearer_token = $response.token
    $headers.Add("Authorization", "Bearer $($bearer_token)")



}


Process {

    if($PSCmdlet.ParameterSetName -eq "Single") {
    
        #A Single update refers to the custom property not the machines. 
        #you may wish to update multiple machines with the same property.
        $counter=1
        foreach($name in $machineName) {
            Write-Verbose "Processing $($counter) of $($MachineName.Count) - $($name)"
            $counter++

            #find the machine by name
            $method="GET"
            $uri = "https://$($vraServer)/iaas/api/machines?`$filter=name eq '$($name)'"
            #$escapedUri = [uri]::EscapeUriString($uri)
            try
            {
                $response = $null
                $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
            } catch [System.Net.WebException] {
        
                if ($($_.Exception.Message) -eq "The remote server returned an error: (404) Not Found." )
                {
                    Write-Verbose "[ERROR] !!! $($_.Exception.Message)"
                    Write-Verbose "Machine NOT Found with name: $($machineName)"
                } else {
                    Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
                    Write-Output "Error Message:        $($_.ErrorDetails.Message)"
                    Write-Output "Exception:            $($_.Exception)"
                    Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                    throw
                }
            } catch {
                Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
                Write-Output "Error Message:        $($_.ErrorDetails.Message)"
                Write-Output "Exception:            $($_.Exception)"
                Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                throw
            }

            #Convert the response to the same object type as returned by id lookup.
            if($response.totalElements -eq 1) {
                Write-Verbose "SUCCESS: Machine found by Name"
                $machine = $response.content | ConvertTo-Json -Depth 10 | ConvertFrom-Json

            } elseif ($response.totalElements -gt 1) {
                Write-Warning "More than 1 machine found of the same name."

                #is 1 of them managed vs discovered.
                #TODO: make better if more than 1 managed machine found.
                foreach ($item in $response.content) {
                    if ($item.deploymentId) {
                        
                        $machine = $item | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                    } else {
                        Continue
                    }
                }
            } else {
                Write-Warning "No machine found by name: $name. Skipping machine"
                Continue
            }


            #create a new object to populate, if required. These items must be resubmitted
            #else they will be deleted from the machine if left blank. At least that is how
            #I read the API doco.
            $hash = [ordered]@{}
            if($machine.description) { $hash.description = $machine.description }
            if($machine.tags) { $hash.tags = $machine.tags }
            if($machine.customProperties) { $hash.customProperties = $machine.customProperties }
            if($machine.bootConfig) { $hash.bootConfig = $machine.bootConfig }

            #Check if the custom property is already on this machine and skip if it is
            if([bool]($hash.customProperties.PSObject.Properties.Name -eq $($Key))) {
                Write-Verbose "Custom Property: $($Key) already exists"
                if($machine.customProperties.$($Key) -eq $Value -and $Value.Length -gt 0) {
                    Write-Warning "Custom Property value is already: $($machine.customProperties.$($Key))"
                    Write-Warning "No change required. Skipping update"
                    Continue

                #have to test for empty string as this will be treated as $null
                } elseif ($Value.Length -eq 0) {
                    Write-Verbose "Removing Custom Property: $Key"
                    $hash.customProperties.$($Key) = $null
                } else {
                    Write-Verbose "Custom Property: $($Key) will be updated from: $($machine.customProperties.$($Key)) to: $($Value)"
                    $hash.customProperties.$($Key) = $Value
                }
            } else {
                if ($Value.Length -eq 0) {
                    Write-Verbose "Value is empty. Not action will be taken."
                    Continue
                } else {
                    Write-Verbose "New custom property to be added: $($Key):$($Value)"
                    $hash.customProperties | Add-Member -MemberType NoteProperty -Name $Key -Value $Value
                }
            }

            $body = $hash | ConvertTo-Json -Depth 10
            Write-Verbose "json payload : $($body | Out-String)"
        
            #execute the request
            $method = "PATCH"
            $uri = "https://$($vraServer)/iaas/api/machines/$($machine.id)"

            try
            {
                Write-Verbose "$(Get-Date) Updating machine...."
                $response = $null
                $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body
            }
            catch 
            {
                Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
                Write-Output "Error Message:        $($_.ErrorDetails.Message)"
                Write-Output "Exception:            $($_.Exception)"
                Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                throw
            }
        }
    } else {
        Write-Warning "TODO: add logic for other parameter sets"
    }
}


End {
    Write-Verbose "$(Get-Date) End"
}

}
