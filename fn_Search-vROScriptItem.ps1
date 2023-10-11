function Search-vROScriptItem
{
<#
.Synopsis
   Search the Script Item of an Action or Workflow using regex or a simple text search
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
    An array of tag names to filter Workflows. Actions do not support Tag filtering.
.PARAMETER SkipCertificateCheck
    Skips certificate validation checks that include all validations such as expiration, revocation, trusted root authority, etc.
    WARNING: Using this parameter is not secure and is not recommended. This switch is only intended to be used against known hosts using a self-signed certificate for testing purposes. Use at your own risk.
.EXAMPLE
    $pattern = ".local"
    $credential = Get-Credential -Username "user@corp.local" -Message "Please enter Aria Automation Username and password"
    [array]$result = Search-vROScriptItem -ComputerName "vro.corp.local" -Credential $credential -Type action -Pattern $pattern
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
    [array]$result = Search-vROScriptItem -ComputerName "vro.corp.local" -Credential $credential -Type action -Pattern $pattern -Regex
    $result[0]
    
    Type   : Action
    Name   : createAzureConfigurations
    Path   : com.vmware.vra.endpoint.azure.configuration/createAzureConfigurations
    Id     : 0fbf7c8e-573a-4ed2-b90c-c7feb70a7e71
    Script : {@{LineNumber=28; Line=        A_Standard_A0:  "CPU Cores (1), Memory:GiB (0.768), Local HDD:GiB (20), Max data disks(1), Max data disk throughput:IOPS (1x500), Max NICs/Network bandwidth (1/low)",}, @{LineNumber=29; Line=        A_Standard_A1:  "CPU Cores (1), Memory:GiB (1.75), Local HDD:GiB (70), Max data disks(2), Max data disk throughput:IOPS (2x500), Max NICs/Network bandwidth (1/moderate)",}, @{LineNumber=30; Line=        A_Standard_A2:  "CPU Cores (2), Memory:GiB (3.5), Local HDD:GiB (135), Max data disks(4), Max data disk throughput:IOPS (4x500), Max NICs/Network bandwidth (1/moderate)",}, @{LineNumber=31; Line=        A_Standard_A3:  "CPU Cores (4), Memory:GiB (7), Local HDD:GiB (285), Max data disks(8), Max data disk throughput:IOPS (8x500), Max NICs/Network bandwidth (2/high)",}...}

    Same query with the -Regex parameter added, returns line items where the dot (.) is treated as a regex item indicating "any" character.

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
   Enhancments ideas: 
   - Add Case sensitivity searching
   - Add paging for Workflows
   - Add paging for Actions - not possible atm, as no parameters in API for actions
   - Add foreach parallel to the search (if using Powershell 7.x +)
   - Add a count property to each output. For each item in which the string if found add the count of instances. we do have the lines but having a count might be useful too. maybe...

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

        [Parameter(Mandatory)]
        [String]$Pattern,

        [Parameter(Mandatory=$false)]
        [Switch]$Regex=$false,

        [Parameter(Mandatory=$false)]
        [ValidateScript({ foreach ($tag in $_) { if ($tag -match '\s') { return $false } } return $true }, ErrorMessage="Tags cannot contain spaces")]
        [string[]]$Tags,

        [Parameter(Mandatory=$false)]
        [Switch]$SkipCertificateCheck=$false
        
    )

    Begin
    {

        Write-Verbose "ParameterSet: $($PSCmdlet.ParameterSetName)"
        Write-Verbose "Protocol: $($Protocol)"
        Write-Verbose "ComputerName: $($ComputerName)"
        Write-Verbose "Port: $($Port)"
        Write-Verbose "SkipCertificateCheck: $($SkipCertificateCheck)"

        #TODO: Change to a switch?
        #TODO: Add check for an existing PowervRA connection. can then skip the authentication steps
        #--- extract username and password from credential
        if ($PSCmdlet.ParameterSetName -eq "ByCredential") {
            Write-Verbose "Credential: $($Credential | Out-String)"

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

        Write-Verbose "Username: $($Username)"
        Write-Verbose "shortUsername: $($shortUsername)"
        Write-Verbose "vRADomain: $($vRADomain)"

        Write-Verbose "Type: $($Type)"
        Write-Verbose "Pattern: $($Pattern)"
        Write-Verbose "Regex: $($Regex)"
        
        Write-Verbose "Tags: $($Tags)"

        
        Write-Verbose "vRA8 Header Creation"
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
        try
        {
            $response = $null
            $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body -SkipCertificateCheck
        }
        catch 
        {
            Write-Output "$(Get-Date) StatusCode:" $_.Exception.Response.StatusCode.value__
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
            Write-Output "$(Get-Date) StatusCode:" $_.Exception.Response.StatusCode.value__
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
                $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
            } catch {
                    $_.Exception.gettype().fullname
                    $_.Exception
                    $_.ErrorDetails.Message
                    Write-Output "StatusCode:" $_.Exception.Response.StatusCode.value__
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
                    $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri "$($item.href)" -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
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
                        throw
                    }

                } catch {
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
                            throw
                        }
                    } catch {
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
                            throw
                        }
                    } catch {
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
                $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
            } catch {
                    $_.Exception.gettype().fullname
                    $_.Exception
                    $_.ErrorDetails.Message
                    Write-Output "StatusCode:" $_.Exception.Response.StatusCode.value__
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
                Write-Verbose "Workflow: $($item.name)"
                try {
                    $wfContent = $null
                    $wfContent = Invoke-RestMethod -Method $method -UseBasicParsing -Uri "$($item.href)content/" -Headers $headers -SkipCertificateCheck:$SkipCertificateCheck
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
                        throw
                    }

                } catch {
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
                                throw
                            }
                        } catch {
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
                                throw
                            }
                        } catch {
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
