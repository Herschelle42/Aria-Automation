function Search-vRO8ScriptItem
{
<#
.Synopsis
   Search the Script Item of an Action or Workflow using regex or a simple text search. Powershell 5.
.DESCRIPTION
   Retrieves one or more Aria Automation 8 Actions and or Workflows that meet the search criteria. 
   Will return details of the item including the line number
.PARAMETER Protocol
    The protocol to use to connect to Aria Automation. Valid values are http/https. Default is https.
.PARAMETER ComputerName
   The FQDN, IP address of the Aria Automation server
.PARAMETER Port
    The port to connect to Aria Automation. For example 8281. Default is none.
.PARAMETER Username
    The username in UPN format to connect to Aria Automation. user@corp.local
.PARAMETER Password
    The password to connect to connect to Aria Automation
.PARAMETER Credential
    The powershell Credential object to use to connect to Aria Automation username must be in UPN format.  user@corp.local
.PARAMETER Type
    The Aria Automation object type to search. Valid values are action\workflow\all. Default is all.
.PARAMETER Pattern
    The text string or regex pattern to search for.
.PARAMETER Regex
    Switch indicating whether the Pattern is a regex. Default is false.
    Uses Select-String -Pattern parameter if enabled. Else uses the -SimpleMatch for non-regex string searching.
.PARAMETER Tags
    An array of tags to filter Workflows. Case insensitive.
    The tag array search is an "AND". Meaning the workflow must contain ALL the tags. Each folder in a Workflow path is a tag.
    Filtering by tags can significantly speed up the workflow search.
    Actions do not support Tag filtering. Tags will be ignored during Action searches.
.PARAMETER SkipCertificateCheck
    Skips certificate validation checks that include all validations such as expiration, revocation, trusted root authority, etc.
    WARNING: Using this parameter is not secure and is not recommended. This switch is only intended to be used against known hosts using a self-signed certificate for testing purposes. Use at your own risk.
.EXAMPLE
    $pattern = ".local"
    $credential = Get-Credential -Username "user@corp.local" -Message "Please enter Aria Automation Username and password"
    [array]$result = Search-vROScriptItem -ComputerName "vro.corp.local" -Credential $credential -Type Action -Pattern $pattern
    $result[0]

    Type   : Action
    Name   : createEventDefinition
    Path   : com.vmware.library.vcac/createEventDefinition
    Id     : 7b359d5f-7460-424b-b811-bb9a3c9c6aba
    Script : @{LineNumber=18; Line=// Ugly work around for having an entity created with a CreatedDateTime of type org.joda.time.LocalDateTime (bug 1033984)}

    Returns the straight string match ".local"
.EXAMPLE
    $pattern = ".local"
    $credential = Get-Credential -Username "administrator@vsphere.local" -Message "Please enter Aria Automation Username and password"
    [array]$result = Search-vROScriptItem -ComputerName "vro.corp.local" -Credential $credential -Type Action -Pattern $pattern -Regex
    $result[0]
    
    Type   : Action
    Name   : createAzureConfigurations
    Path   : com.vmware.vra.endpoint.azure.configuration/createAzureConfigurations
    Id     : 0fbf7c8e-573a-4ed2-b90c-c7feb70a7e71
    Script : {@{LineNumber=28; Line=        A_Standard_A0:  "CPU Cores (1), Memory:GiB (0.768), Local HDD:GiB (20), Max data disks(1), Max data disk throughput:IOPS (1x500), Max NICs/Network bandwidth (1/low)",}, @{LineNumber=29; Line=        A_Standard_A1:  "CPU Cores (1), Memory:GiB (1.75), Local HDD:GiB (70), Max data disks(2), Max data disk throughput:IOPS (2x500), Max NICs/Network bandwidth (1/moderate)",}, @{LineNumber=30; Line=        A_Standard_A2:  "CPU Cores (2), Memory:GiB (3.5), Local HDD:GiB (135), Max data disks(4), Max data disk throughput:IOPS (4x500), Max NICs/Network bandwidth (1/moderate)",}, @{LineNumber=31; Line=        A_Standard_A3:  "CPU Cores (4), Memory:GiB (7), Local HDD:GiB (285), Max data disks(8), Max data disk throughput:IOPS (8x500), Max NICs/Network bandwidth (2/high)",}...}

    Same query with the -Regex parameter added, returns line items where the dot (.) is treated as a regex item indicating "any" character.
.EXAMPLE
    $pattern = ".local"
    $credential = Get-Credential -Username "user@corp.local" -Message "Please enter Aria Automation Username and password"
    [array]$result = Search-vROScriptItem -ComputerName "vro.corp.local" -Credential $credential -Pattern $pattern -Type Workflow -Tags "Dev","Automation"

    Return only workflows with the Tags "Dev" AND "Automation" AND the search string ".local"

.INPUTS
   [String]
   [Int]
   [SecureString]
   [Management.Automation.PSCredential]
   [Switch]
.OUTPUTS
   [PSObject]
.NOTES
   Author:  Clint Fritz
   For use with Powershell version 5.

#>



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

        [Parameter(Mandatory,ParameterSetName="ByUsername")]
        [ValidatePattern("^[^@\s]+@[^@\s]+\.[^@\s]+$")]
        [string]$Username,

        [Parameter(Mandatory,ParameterSetName="ByUsername")]
        [SecureString]$Password,

        [Parameter(Mandatory,ParameterSetName="ByCredential")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_.UserName -match "^[^@\s]+@[^@\s]+\.[^@\s]+$"})]
        [Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Workflow","Action","All")]
        [string]$Type="All",

        [Parameter(Mandatory)]
        [String]$Pattern,

        [Parameter(Mandatory=$false)]
        [Switch]$Regex=$false,

        [Parameter(Mandatory=$false)]
        [ValidateScript({ foreach ($tag in $_) { if ($tag -match '\s') { return $false } } return $true })]
        [string[]]$Tags,

        [Parameter(Mandatory=$false)]
        [Switch]$SkipCertificateCheck=$false
        
    )

    Begin
    {

        Write-Verbose "$(Get-Date) ParameterSet: $($PSCmdlet.ParameterSetName)"
        Write-Verbose "$(Get-Date) Protocol: $($Protocol)"
        Write-Verbose "$(Get-Date) ComputerName: $($ComputerName)"
        Write-Verbose "$(Get-Date) Port: $($Port)"
        Write-Verbose "$(Get-Date) SkipCertificateCheck: $($SkipCertificateCheck)"

        #TODO: Change to a switch?
        #TODO: Add check for an existing PowervRA connection. can then skip the authentication steps
        #--- extract username and password from credential
        if ($PSCmdlet.ParameterSetName -eq "ByCredential") {
            Write-Verbose "$(Get-Date) Credential: $($Credential | Out-String)"

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

        Write-Verbose "$(Get-Date) Username: $($Username)"
        Write-Verbose "$(Get-Date) shortUsername: $($shortUsername)"
        Write-Verbose "$(Get-Date) vRADomain: $($vRADomain)"

        Write-Verbose "$(Get-Date) Type: $($Type)"
        Write-Verbose "$(Get-Date) Pattern: $($Pattern)"
        Write-Verbose "$(Get-Date) Regex: $($Regex)"
        
        Write-Verbose "$(Get-Date) Tags: $($Tags)"

        Write-Verbose "Using Powershell version: $($PSVersionTable.PSVersion.Major)"
        if ($PSVersionTable.PSVersion.Major -le 5 -and $SkipCertificateCheck) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        
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
            if ($PSVersionTable.PSVersion.Major -gt 5) {
                $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body -SkipCertificateCheck:$SkipCertificateCheck
            } else {
                $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body

            }
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
            if ($PSVersionTable.PSVersion.Major -gt 5) {
                $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $newBody -SkipCertificateCheck:$SkipCertificateCheck
            } else {
                $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $newBody

            }
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

        Write-Verbose "Headers: $($headers | Out-String)"

        #If a port is defined, updated the server uri.
        $serverUri = $null
        if($Port) {
          $serverUri = "$($protocol)://$($ComputerName):$($Port)"
        } else {
          $serverUri = "$($protocol)://$($ComputerName)"
        }
        $apiUri = "$($serverUri)/vco/api"
        Write-Verbose "Server API Uri: $($apiUri)"
       
        <#
        vRO 7.x requires tls 1.2 to work, otherwise will receive the error:
        Invoke-RestMethod : The underlying connection was closed: An unexpected error occurred on a send.
        when attempting to do Invoke-RestMethod
        #>
        if (-not ("Tls12" -in  (([System.Net.ServicePointManager]::SecurityProtocol).ToString() -split ", ")))
        {
            Write-Verbose "Adding Tls 1.2 to security protocol"
            [System.Net.ServicePointManager]::SecurityProtocol += [System.Net.SecurityProtocolType]::Tls12
        }

        function intGet-ActionScripts
        {
            Write-Verbose "Get Actions"

            $method = "GET"
            $uri = "$($apiUri)/actions"
            $result = $null

            Write-Verbose "uri: $($uri)"
            Write-Verbose "method: $($method)"
            Write-Verbose "skipcert: $($SkipCertificateCheck)"
            Write-Verbose "headers: $($headers | Out-String)"

            try {
                if ($PSVersionTable.PSVersion.Major -gt 5) {
                    $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
                } else {
                    $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers

                }
            } catch {
                    Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
                    Write-Output "Error Message:        $($_.ErrorDetails.Message)"
                    Write-Output "Exception:            $($_.Exception)"
                    Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                    throw
            }


            Write-Verbose "Create a new flat custom object for easier manipulation"
            $item = $null
            $itemList = foreach ($item in $result.link){
    
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

            Write-Verbose "Get each script element"
            $item = $null
            foreach ($item in $itemList)
            {
                Write-Verbose "Action: $($item.name)"
                Write-Verbose "Path: $($item.fqn)"
                try {
                    $result = $null
                    if ($PSVersionTable.PSVersion.Major -gt 5) {
                        $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri "$($item.href)" -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
                    } else {
                        $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri "$($item.href)" -Headers $headers

                    }
                } catch [System.Net.WebException] {
        
                    if ($($_.Exception.Message) -eq "The remote server returned an error: (400) Bad Request." )
                    {
                        Write-Verbose "[ERROR] !!! $($_.Exception.Message)"
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
                        Write-Output "Action: $($item.id) ($($item.name))"
                        throw
                    }

                } catch {
                    Write-Output "Action: $($item.id) ($($item.name))"
                    throw
                }

                #Is this a regex search or a simple text search.
                if ($regex) 
                {
                    Write-Verbose "Regex search"
                    try {
                        if ($linesFound = $result.script.Split("`n") | Select-String -Pattern $pattern | Select-Object LineNumber, Line)
                        {
                            Write-Verbose "Lines found: $($linesFound.count)"
                            $hash=[ordered]@{}
                            $hash.Type="Action"
                            $hash.Name = $item.name
                            $hash.Path = $item.fqn
                            $hash.Id = $item.id
                            $hash.Script = $linesFound
                            $object = New-Object -TypeName PSObject -Property $hash
                            $object
                        }
                    #Catch when the item is empty
                    } catch [System.Management.Automation.RuntimeException] {
                        if ($_.exception.message -match "You cannot call a method on a null-valued expression.") {
                            Write-Verbose "Contains no script."
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

                } else {
                    Write-Verbose "Simple search"

                    try {
                        if ($linesFound = $result.script.Split("`n") | Select-String -SimpleMatch $pattern | Select-Object LineNumber, Line)
                        {
                            Write-Verbose "Lines found: $($linesFound.count)"
                            $hash=[ordered]@{}
                            $hash.Type="Action"
                            $hash.Name = $item.name
                            $hash.Path = $item.fqn
                            $hash.Id = $item.id
                            $hash.Script = $linesFound
                            $object = New-Object -TypeName PSObject -Property $hash
                            $object
                        }
                    #Catch when the item is empty
                    } catch [System.Management.Automation.RuntimeException] {
                        if ($_.exception.message -match "You cannot call a method on a null-valued expression.") {
                            Write-Verbose "Contains no script."
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
                }
            }
        }

        function intGet-WorkflowScripts
        {
            Write-Verbose "Get Workflows"
            $method = "GET"
            
            $uri = "$($apiUri)/workflows?maxResult=2147483647&startIndex=0&queryCount=false"

            if($Tags) {
                Write-Verbose "Adding Tags filter"
                #In the API the array of strings is comma separated.
                $uri = "$($uri)&tags=$($tags -join "%2C")"
            }

            $result = $null
            Write-Verbose "uri: $($uri)"
            Write-Verbose "method: $($method)"
            Write-Verbose "skipcert: $($SkipCertificateCheck)"
            Write-Verbose "headers: $($headers | Out-String)"

            try {
                if ($PSVersionTable.PSVersion.Major -gt 5) {
                    $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
                } else {
                    $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers
                }

            } catch {
                Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
                Write-Output "Error Message:        $($_.ErrorDetails.Message)"
                Write-Output "Exception:            $($_.Exception)"
                Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                throw
            }

            Write-Verbose "Create a new flat custom object for easier manipulation"
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

            Write-Verbose "Get each script element"
            $item = $null
            foreach ($item in $itemList)
            {
                #TODO: Remove this hack when fixed - Avi Deployment WF: Cluster Node Replacement is corrupt
                if($item.id -eq "62307943-f03c-4f5a-80cc-58eb585443e2") { continue }

                Write-Verbose "Workflow: $($item.name)"
                try {
                    $wfContent = $null
                    if ($PSVersionTable.PSVersion.Major -gt 5) {
                        $wfContent = Invoke-RestMethod -Method $method -UseBasicParsing -Uri "$($item.href)content/" -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
                    } else {
                        $wfContent = Invoke-RestMethod -Method $method -UseBasicParsing -Uri "$($item.href)content/" -Headers $headers
                    }
                } catch [System.Net.WebException] {
        
                    if ($($_.Exception.Message) -eq "The remote server returned an error: (400) Bad Request." )
                    {
                        Write-Verbose "[ERROR] !!! $($_.Exception.Message)" -Verbose:$VerbosePreference
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
                        Write-Output "[System.Net.WebException]"
                        Write-Output "Workflow: $($item.id) ($($item.name))"
                        <#
                        $_.Exception.gettype().fullname
                        Write-Output "StatusCode: $($_.Exception.Response.StatusCode.value__)" 
                        $_.Exception
                        $_.ErrorDetails.Message
                        #>
                        throw
                    }

                } catch {
                    Write-Output "Workflow: $($item.id) ($($item.name))"
                    <#
                    $_.Exception.gettype().fullname
                    $_.Exception
                    $_.ErrorDetails.Message
                    Write-Output "StatusCode:" $_.Exception.Response.StatusCode.value__
                    #>
                    throw
                }

                foreach ($contentItem in $wfContent.'workflow-item' | Where-Object { $_.Script } )
                {
                    Write-Verbose "Item Name: $($contentItem.'display-name')"
                    $itemPath = "$($item.globalTags.Replace(' ','\'))\$($item.name)"
                    Write-Verbose "Item Path: $($itemPath)"
        
                    #Is this a regex search or a simple text search.
                    if ($regex) 
                    {
                        Write-Verbose "Regex search"
                        try {
                            if ($linesFound = $contentItem.script.value.Split("`n") | Select-String -Pattern $pattern | Select-Object LineNumber, Line)
                            {
                                Write-Verbose "Lines found: $($linesFound.count)"
                                $hash=[ordered]@{}
                                $hash.Type="Workflow-$($contentItem.type)"
                                $hash.Name = $contentItem.'display-name'
                                $hash.Path = $itemPath.Replace(":__SYSTEM_TAG__","")
                                $hash.Path = $itemPath
                                $hash.Id = $item.Id
                                $hash.Script = $linesFound
                                $object = New-Object -TypeName PSObject -Property $hash
                                $object
                            }
                        #Catch when the item is empty
                        } catch [System.Management.Automation.RuntimeException] {
                            if ($_.exception.message -match "You cannot call a method on a null-valued expression.") {
                                Write-Verbose "Contains no script."
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

                    } else {
                        Write-Verbose "Simple search"
                        try {
                            if ($linesFound = $contentItem.script.value.Split("`n") | Select-String -SimpleMatch $pattern | Select-Object LineNumber, Line)
                            {
                                Write-Verbose "Lines found: $($linesFound.count)"
                                $hash=[ordered]@{}
                                $hash.Type="Workflow-$($contentItem.type)"
                                $hash.Name = $contentItem.'display-name'
                                $hash.Path = $itemPath.Replace(":__SYSTEM_TAG__","")
                                $hash.Id = $item.Id
                                $hash.Script = $linesFound
                                $object = New-Object -TypeName PSObject -Property $hash
                                $object
                            }
                        #Catch when the item is empty
                        } catch [System.Management.Automation.RuntimeException] {
                            if ($_.exception.message -match "You cannot call a method on a null-valued expression.") {
                                Write-Verbose "Contains no script."
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
                    }
                    
                }
		
            }

        }

    }

    Process
    {

        #--- Search Actions ---------------------------------------------------
        if ($Type -eq "action")
        {
            intGet-ActionScripts
        }

        #--- Search Workflows -------------------------------------------------
        if ($Type -eq "workflow")
        {
            intGet-WorkflowScripts
        }

        #--- Search both workflows and actions --------------------------------
        if ($Type -eq "all")
        {
            intGet-ActionScripts
            intGet-WorkflowScripts
        }
        
    }

    End
    {
    }
}
