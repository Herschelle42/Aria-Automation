function Set-AA8MachineCustomProperty
{
<#
.SYNOPSIS
  Update an Aria Automation Machine Custom Property.
.DESCRIPTION
  
.NOTES
   Author:  Clint Fritz

   Single for a single key value pair on one or more machine names
   Multiple for an array of key value pairs on one or more machine names
   File for reading and applying key value pairs to machines.
     will collapse all the key value pairs into a group to apply the machine in
     one action. e.g. if you have 2 custom properties to set on a machine there
     will be 2 entries in the file.

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

    #Name of the machine
    [Parameter(Mandatory,ParameterSetName="Single")]
    [Alias("MachineName")]
    [string[]]$Name,

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
        Write-Verbose "$(Get-Date) ComputerName: $($ComputerName)"
        Write-Verbose "$(Get-Date) Name: $($Name)"
        Write-Verbose "$(Get-Date) Key: $($Key)"
        Write-Verbose "$(Get-Date) Value: $($Value)"

        
    }


    Process {

       #create a new object to populate, if required
        $hash = [ordered]@{}
        if($response.description) { $hash.description = $response.description }
        if($response.tags) { $hash.tags = $response.tags }
        if($response.customProperties) { $hash.customProperties = $response.customProperties }
        if($response.bootConfig) { $hash.bootConfig = $response.bootConfig }



        $body = $machine.payload | ConvertTo-Json -Depth 10
        #Write-Verbose "json payload : $($body | Out-String)" -Verbose

        
        #execute the request
        $method = "PATCH"
        $uri = "https://$($vraServer)/iaas/api/machines/$($machine.id)"


        try
        {
            Write-Verbose "$(Get-Date) Updating machine...." -Verbose
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


    End {
        Write-Verbose "$(Get-Date) End"
    }

}
