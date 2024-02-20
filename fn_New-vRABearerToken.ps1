function New-vRABearerToken {
<#
.SYNOPSIS
  Create a vRA Bearer Token for use in REST calls or Swagger
.DESCRIPTION
  Creates a vRA Bearer Token, copies it to the system clipboard and dynamically
  creates a variable $bearer_<hostname>
.NOTES
  Author: Clint Fritz

  Bearer <token>
  VAA API - IaaS
  
  <token>
  VAA API - Catalog
#>

[CmdletBinding(DefaultParameterSetName="ByCredential")]
Param(
    #Protocol. https is the default.
    [Parameter(Mandatory=$false)]
    [ValidateSet("https","http")]
    [string]$Protocol="https",

    #Computer name
    [Parameter(Mandatory)]
    [Alias("Server","IPAddress","FQDN")]
    [string]$ComputerName,

    #Port
    [Parameter(Mandatory=$false)]
    [ValidatePattern("^[1-9][0-9]{0,4}$")]
    [int]$Port,

    #vRA Tenant
    [Parameter(Mandatory=$false)]
    [string]$tenant = "vsphere.local",

    #vRA Domain to log into?
    [Parameter(Mandatory)]
    [string]$Domain,

    #Credential
    [Parameter(Mandatory,ParameterSetName="ByCredential")]
    [ValidateNotNullOrEmpty()]
    [Management.Automation.PSCredential]$Credential,
        
    #Username
    [Parameter(Mandatory,ParameterSetName="ByUsername")]
    [string]$Username,

    #Password
    [Parameter(Mandatory,ParameterSetName="ByUsername")]
    [SecureString]$Password,

    [Parameter(Mandatory=$false)]
    [Switch]$SkipCertificateCheck=$false
)

Begin {
    switch ($PSCmdlet.ParameterSetName) {
        "ByCredential" {
            Write-Verbose "[INFO] Using Credential: $($Credential.UserName)"
            [string]$username = $Credential.UserName
            [string]$UnsecurePassword = $Credential.GetNetworkCredential().Password
        }
        "ByUsername" {
            Write-Verbose "[INFO] Using username and password: $($Username)"
            [string]$UnsecurePassword = (New-Object System.Management.Automation.PSCredential('username', $Password)).GetNetworkCredential().Password
        }
        "__AllParameterSets" {}
    }
}

Process {

    $body = @{
        username = $username
        password = $UnsecurePassword
        tenant = $tenant
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
        $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body -SkipCertificateCheck:$SkipCertificateCheck
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
        $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $newBody -SkipCertificateCheck:$SkipCertificateCheck
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

    Write-Verbose "Copy Bearer token to system Clipboard."
    Set-Clipboard -Value $headers.Authorization

    Write-Verbose "Create dynamic global variables"
    $variableName = "bearer_$($ComputerName.Split(".")[0])"
    New-Variable -Name $variableName -Scope Global -Value $headers.Authorization -Force

    $variableName = "headers_$($ComputerName.Split(".")[0])"
    New-Variable -Name $variableName -Scope Global -Value $headers -Force

}

End {
    Write-Verbose "End"
}

}
