function Search-vROChanges
{
<#
.SYNOPSIS
  To create a list of the workflows and actions that have been changed in a given timeframe
.DESCRIPTION
  Collect a list of workflow, actions (and maybe config and resource elements) that
  have been changed in a given time period. Primarily when doing development to capture
  all the changes we have made and put them say into a package to update another vRA 
  instance.
.PARAMETER Protocol
    The protocol to use to connect to Aria Automation. Valid values are http/https. Default is https.
.PARAMETER ComputerName
   The FQDN, IP address of the Aria Automation server
.PARAMETER Port
    The port to connect to Aria Automation. For example 8281. Default is none.
.PARAMETER SkipCertificateCheck
    Skips certificate validation checks that include all validations such as expiration, revocation, trusted root authority, etc.
    WARNING: Using this parameter is not secure and is not recommended. This switch is only intended to be used against known hosts using a self-signed certificate for testing purposes. Use at your own risk.
.PARAMETER Username
    The username in UPN format to connect to Aria Automation. user@corp.local
.PARAMETER Password
    The password to connect to connect to Aria Automation
.PARAMETER Credential
    The powershell Credential object to use to connect to Aria Automation username must be in UPN format.  user@corp.local
.PARAMETER Type
    The Aria Automation object type to search. Valid values are action\workflow\all. Default is all.
.PARAMETER Tags
    An array of tags to filter Workflows. Case insensitive.
    The tag array search is an "AND". Meaning the workflow must contain ALL the tags. Each folder in a Workflow path is a tag.
    Filtering by tags can significantly speed up the workflow search.
    Actions do not support Tag filtering. Tags will be ignored during Action searches.
.PARAMETER DateFrom
  Date after which we are looking for updates. Default is 30 days
.PARAMETER DateTo
  Date before which we are looking for updates. Default is now.
.PARAMETER Throttle
  Advanced setting to speed up retrieval of Action audit data. Default is 10. Be careful setting
  this too high as this will impact Aria Automation with concurrent API calls.
.EXAMPLE
  Get changes in the last 7 days

  $after = "(Get-Date).AddDays(-7)"
  $credential = Get-Credential -Username "user@corp.local" -Message "Please enter Aria Automation Username and password"
  [array]$result = search-vROScriptItem -ComputerName "vra.corp.local" -Credential $vroCredential -DateFrom "2024-07-29" -Type Workflow -SkipCertificateCheck
  $result[0]

  id          : 452cae92-a61b-41af-8747-b846ef284076
  name        : findVcVmByVcAndVmUuid
  description : Find vCenter VM by vCenter instance ID and VM UUID.
              Throws error when:
              - No vCenter host configuration is found with the given ID
              - No VM is found with the given ID
  fqn         : com.vmware.vra.xaas/findVcVmByVcAndVmUuid
  version     : 1.0.0
  href        : https://vra8-fielddemo.cmbu.local:443/vco/api/actions/452cae92-a61b-41af-8747-b846ef284076/
  rel         : action
  updatedAt   : 1722175370715

.INPUTS
   [String]
   [Int]
   [SecureString]
   [Management.Automation.PSCredential]
   [Switch]
   [DateTime]
.OUTPUTS
   [PSObject]
.NOTES
  Author:  Clint Fritz
  Enhancments ideas: 
  - Add paging for Workflows
  - Add paging for Actions - not possible, currently no parameters in API for actions
  - Add foreach parallel to the search of audit-logs for Actions (if using Powershell 7.x +) as they have to go through every Action to get the audit-logs
    example:   $itemlist | Foreach-Object -Parallel { <peform operations here> }  -ThrottleLimit 10
  - Add Package changed?
  - Add Policies?
  - Add Resource Elements - has updatedAt
  - Add Configuration elements?
  - Add Templates?
  - Add Custom Forms?

#>

#Powershell 7+
#Requires -Version 7.0

[CmdletBinding(DefaultParameterSetName="ByCredential")]
    Param
    (
        [Parameter(Mandatory=$false)]
        [ValidateSet("https","http")]
        [string]$Protocol="https",

        [Parameter(Mandatory)]
        [Alias("Server","IPAddress","FQDN")]
        [string]$ComputerName,

        [Parameter(Mandatory=$false)]
        [ValidatePattern("^[1-9][0-9]{0,4}$")]
        [int]$Port,

        [Parameter(Mandatory=$false)]
        [Switch]$SkipCertificateCheck=$false,

        [Parameter(Mandatory,ParameterSetName="ByUsername")]
        [ValidatePattern("^[^@\s]+@[^@\s]+\.[^@\s]+$", ErrorMessage="Username is not in UPN format. user@corp.local")]
        [string]$Username,

        [Parameter(Mandatory,ParameterSetName="ByUsername")]
        [SecureString]$Password,

        [Parameter(Mandatory,ParameterSetName="ByCredential")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_.UserName -match "^[^@\s]+@[^@\s]+\.[^@\s]+$"}, ErrorMessage="Username is not in UPN format. user@corp.local")]
        [Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Workflow","Action","All")]
        [string]$Type="All",

        [Parameter(Mandatory=$false)]
        [ValidateScript({ foreach ($tag in $_) { if ($tag -match '\s') { return $false } } return $true }, ErrorMessage="Tags cannot contain spaces")]
        [string[]]$Tags,

        [Parameter(Mandatory=$false)]
        [DateTime]$DateFrom = (Get-Date).AddDays(-30),   #Saturday, 29 June 2024 10:02:28 AM

        [Parameter(Mandatory=$false)]
        [DateTime]$DateTo = (Get-Date),                   #Monday, 29 July 2024 10:02:14 AM

        [Parameter(Mandatory=$false)]
        [int]$Throttle=10
        
    )

    Begin
    {

        Write-Verbose "$(Get-Date) ParameterSet:         $($PSCmdlet.ParameterSetName)"
        Write-Verbose "$(Get-Date) Protocol:             $($Protocol)"
        Write-Verbose "$(Get-Date) ComputerName:         $($ComputerName)"
        Write-Verbose "$(Get-Date) Port:                 $($Port)"
        Write-Verbose "$(Get-Date) SkipCertificateCheck: $($SkipCertificateCheck)"
        Write-Verbose "$(Get-Date) Type:                 $($Type)"
        Write-Verbose "$(Get-Date) Tags:                 $($Tags)"
        Write-Verbose "$(Get-Date) Throttle:             $($Throttle)"

        #TODO: Change to a switch?
        #TODO: Add check for an existing PowervRA connection. can then skip the authentication steps
        #--- extract username and password from credential
        if ($PSCmdlet.ParameterSetName -eq "ByCredential") {
            Write-Verbose "$(Get-Date) Credential:           $($Credential | Out-String)"

            $shortUsername = $Credential.UserName.Split("@")[0]
            $UnsecurePassword = $Credential.GetNetworkCredential().Password
            $vRADomain = $Credential.UserName.Split("@")[1]

        } elseif ($PSCmdlet.ParameterSetName -eq "ByUsername") {
            $shortUsername = $Username.Split("@")[0]
            $vRADomain = $Username.Split("@")[1]
            $UnsecurePassword = (New-Object System.Management.Automation.PSCredential('username', $Password)).GetNetworkCredential().Password
        } else {
            throw "Unable to determine parameter set."
        }

        Write-Verbose "$(Get-Date) Username:             $($Username)"
        Write-Verbose "$(Get-Date) shortUsername:        $($shortUsername)"
        Write-Verbose "$(Get-Date) vRADomain:            $($vRADomain)"

        #Convert Dates to unix time for comparison.
        $DateFromUNIX = [int64](Get-Date -Date $DateFrom -UFormat %s) * 1000
        $DateToUNIX = [int64](Get-Date -Date $DateTo -UFormat %s) * 1000

        Write-Verbose "$(Get-Date) vRA8 Header Creation"
        $body = @{
            username = $shortUsername
            password = $UnsecurePassword
            tenant = $tenant
            domain = $vRADomain
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
        $uri = "$($baseUrl)/csp/gateway/am/api/login?access_token"

        Write-Verbose "$(Get-Date) Request a token from vRA"
        Write-Verbose "$(Get-Date) uri: $($uri)"
        try
        {
            $response = $null
            $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body -SkipCertificateCheck
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

        Write-Verbose "$(Get-Date) Request a bearer token from vRA"
        try
        {
            $response = $null
            $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $newBody -SkipCertificateCheck
        }
        catch 
        {
            $_.Exception.gettype().fullname
            $_.Exception
            $_.ErrorDetails.Message
            Write-Output "StatusCode:" $_.Exception.Response.StatusCode.value__
            throw
        }

        Write-Verbose "$(Get-Date) Bearer Token received. Add the retrieved Bearer token to the headers"
        $bearer_token = $response.token
        $headers.Add("Authorization", "Bearer $($bearer_token)")

        Write-Verbose "$(Get-Date) Headers: $($headers | Out-String)"

        #If a port is defined, updated the server uri.
        $serverUri = $null
        if($Port) {
          $serverUri = "$($protocol)://$($ComputerName):$($Port)"
        } else {
          $serverUri = "$($protocol)://$($ComputerName)"
        }
        $apiUri = "$($serverUri)/vco/api"
        Write-Verbose "$(Get-Date) Server API Uri: $($apiUri)"
       
        <#
        vRO 7.x requires tls 1.2 to work, otherwise will receive the error:
        Invoke-RestMethod : The underlying connection was closed: An unexpected error occurred on a send.
        when attempting to do Invoke-RestMethod
        #>
        if (-not ("Tls12" -in  (([System.Net.ServicePointManager]::SecurityProtocol).ToString() -split ", ")))
        {
            Write-Verbose "$(Get-Date) Adding Tls 1.2 to security protocol"
            [System.Net.ServicePointManager]::SecurityProtocol += [System.Net.SecurityProtocolType]::Tls12
        }

        function intGet-ActionScripts
        {
            Write-Verbose "$(Get-Date) Get Actions"

            $method = "GET"
            $uri = "$($apiUri)/actions"
            $result = $null

            Write-Verbose "$(Get-Date) uri: $($uri)"
            Write-Verbose "$(Get-Date) method: $($method)"

            try {
                $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
            } catch {
                Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
                Write-Output "Error Message:        $($_.ErrorDetails.Message)"
                Write-Output "Exception:            $($_.Exception)"
                Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                throw
            }


            Write-Verbose "$(Get-Date) Create a new flat custom object for easier manipulation"
            $item = $null
            $itemList = foreach ($item in $result.link){    
                $hash = [ordered]@{}
                foreach ($attrib in $item.attributes)
                {
                    $hash.$($attrib.name) = $($attrib.value)
                }#end foreach attrib
                $hash.href = $item.href
                $hash.rel = $item.rel
                $hash.updatedAt = $null
                $object = new-object PSObject -property $hash 
                $object
  
            }
            Write-Verbose "$(Get-Date) Total Actions returned: $($itemList.Count)"

            Write-Verbose "$(Get-Date) Get Audit logs"
            $itemlist | Foreach-Object -Parallel { 
                $item = $_
                
                $actionId = $item.id
                Write-Verbose "$(Get-Date) Name: $($item.name)"
                Write-Verbose "$(Get-Date) Id  : $($item.id)"
                #Write-Verbose "$(Get-Date) Path: $($item.fqn)"
                
                try {
                    $result = $null
                    $method = "Get"
                    $uri = "$($using:apiUri)/audit-logs?fetchLimit=100&severity=info&fromDate=$($using:DateFromUNIX)&toDate=$($using:DateToUNIX)&objectId=$($actionId)"
                    $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $using:headers -SkipCertificateCheck:$using:SkipCertificateCheck
                } catch [System.Net.WebException] {
        
                    if ($($_.Exception.Message) -eq "The remote server returned an error: (400) Bad Request." )
                    {
                        Write-Error "$(Get-Date) [ERROR] !!! $($_.Exception.Message)"
                        <# Undecided how we surface this up.
                        $hash=[ordered]@{}
                        $hash.Name = $item.name
                        $hash.Path = $item.globalTags.Replace(" ","\")
                        $hash.ItemName = "ERROR: $($_.Exception.Message)"
                        $hash.Script = $null
                        $object = New-Object -TypeName PSObject -Property $hash
                        $object
                        #>
                    } else {
                        Write-Error "Action: $($item.id) ($($item.name))"
                        throw
                    }

                } catch {
                    Write-Error "Action: $($item.id) ($($item.name))"
                    throw
                }

                if($result.events.Count -gt 0) {
                    [array]$logList = $result.events | Select-Object -ExpandProperty audit-log | Where-Object { $_.'time-stamp-val' -gt $using:DateFromUNIX -and $_.'time-stamp-val' -lt $using:DateToUNIX -and $_.'short-description' -match "Action content saved|Action saved|Action created" } | Sort-Object -Property 'time-stamp-val' -Descending 
                    if($logList.Count -gt 0) {
                        #Add the most recent updated time to our custom object.
                        $item.updatedAt = $logList[0].'time-stamp-val'
                    }
                }

            }  -ThrottleLimit $Throttle

            Write-Verbose "$(Get-Date) Return changed Actions"
            $itemList | Where-Object { $_.updatedAt -gt $DateFromUNIX -and $_.updatedAt -lt $DateToUNIX }
        }

        function intGet-WorkflowScripts
        {
            Write-Verbose "$(Get-Date) Get Workflows"
            $method = "GET"
            
            #TODO: Add paging
            $uri = "$($apiUri)/workflows?maxResult=2147483647&startIndex=0&queryCount=false"

            if($Tags) {
                Write-Verbose "$(Get-Date) Adding Tags filter"
                #In the API the array of strings is comma separated.
                $uri = "$($uri)&tags=$($tags -join "%2C")"
            }

            $result = $null
            Write-Verbose "$(Get-Date) uri: $($uri)"
            Write-Verbose "$(Get-Date) method: $($method)"
            Write-Verbose "$(Get-Date) skipcert: $($SkipCertificateCheck)"
            Write-Verbose "$(Get-Date) headers: $($headers | Out-String)"

            try {
                $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
            } catch {
                Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
                Write-Output "Error Message:        $($_.ErrorDetails.Message)"
                Write-Output "Exception:            $($_.Exception)"
                Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                throw
            }

            Write-Verbose "$(Get-Date) Create a new flat custom object for easier manipulation"
            $item = $null
            $itemList = foreach ($item in $result.link){

                #TODO: Remove this hack when WF is fixed
                #Avi Deployment WF: Cluster Node Replacement is corrupt
                if($item.id -eq "62307943-f03c-4f5a-80cc-58eb585443e2") { continue }

                $hash = [ordered]@{}
                foreach ($attrib in $item.attributes)
                {
                    $hash.$($attrib.name) = $($attrib.value)
                }#end foreach attrib
                $hash.href = $item.href
                $hash.rel = $item.rel
                $hash.Script = $null
                $object = new-object PSObject -property $hash 
                $object
  
            }
            Write-Verbose "$(Get-Date) Total Workflows returned: $($itemList.Count)"

            #TODO: Is there an API filter that can be applied instead of doing it this way?
            Write-Verbose "$(Get-Date) Returned changed Workflows"
            $itemList | Where-Object { $_.updatedAt -gt $DateFromUNIX -and $_.updatedAt -lt $DateToUNIX }

        }

    }

    Process
    {

        #--- Search Actions ---------------------------------------------------
        if ($Type -eq "Action")
        {
            intGet-ActionScripts
        }

        #--- Search Workflows -------------------------------------------------
        if ($Type -eq "Workflow")
        {
            intGet-WorkflowScripts
        }

        #--- Search both workflows and actions --------------------------------
        if ($Type -eq "All")
        {
            intGet-ActionScripts
            intGet-WorkflowScripts
        }
        
    }

    End
    {
        Write-Verbose "$(Get-Date) End"
    }
}
