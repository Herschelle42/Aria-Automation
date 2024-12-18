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

    Write-Verbose "$(Get-Date) Protocol:         $($Protocol)"
    Write-Verbose "$(Get-Date) ComputerName:     $($ComputerName)"
    Write-Verbose "$(Get-Date) Port:             $($Port)"
    Write-Verbose "$(Get-Date) Domain:           $($Domain)"
    Write-Verbose "$(Get-Date) Tenant:           $($tenant)"
    Write-Verbose "$(Get-Date) Skip Cert Check:  $($SkipCertificateCheck)"

    switch ($PSCmdlet.ParameterSetName) {
        "ByCredential" {
            Write-Verbose "$(Get-Date) Using Credential: $($Credential.UserName)"
            [string]$username = $Credential.UserName
            [string]$UnsecurePassword = $Credential.GetNetworkCredential().Password
        }
        "ByUsername" {
            Write-Verbose "$(Get-Date) Using username and password: $($Username)"
            [string]$UnsecurePassword = (New-Object System.Management.Automation.PSCredential('username', $Password)).GetNetworkCredential().Password
        }
        "__AllParameterSets" {}
    }

    Write-Verbose "$(Get-Date) Using Powershell version: $($PSVersionTable.PSVersion.Major)"
    if ($PSVersionTable.PSVersion.Major -le 5 -and $SkipCertificateCheck) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
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
    Write-Verbose "$(Get-Date) method: $($method)"
    Write-Verbose "$(Get-Date) uri:    $($uri)"
    #https://kb.vmware.com/s/article/89129

    Write-Verbose "$(Get-Date) Request an access token"

    #Write-Verbose "$(Get-Date) headers: $($headers | Out-String)"
    #For troubleshooting only, do NOT leave uncommented else your password will be displayed
    #Write-Verbose "$(Get-Date) body: $($body)"

    try
    {
        $response = $null
        if ($PSVersionTable.PSVersion.Major -gt 5) {
            $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body -SkipCertificateCheck:$SkipCertificateCheck
        } else {
            $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body
        }
    } 
    catch [System.Net.Http.HttpRequestException] {
        if($($_.ErrorDetails.Message) -eq "The remote certificate is invalid because of errors in the certificate chain: UntrustedRoot" ) {
            throw "$($_.ErrorDetails.Message). If you trust this server try the -SkipCertificateCheck parameter. PS7+ only."

        } else {
            Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
            Write-Output "Error Message:        $($_.ErrorDetails.Message)"
            Write-Output "Exception:            $($_.Exception)"
            Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
            throw
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

Write-Verbose "$(Get-Date) Refresh Token received:"
Write-Verbose "$(Get-Date) $($response | ConvertTo-Json)"
$newBody = @"
{ 
    refreshToken: "$($response.refresh_token)" 
} 
"@

    $method = "POST"
    $baseUrl = "https://$($ComputerName)"
    $uri = "$($baseUrl)/iaas/api/login"
    Write-Verbose "$(Get-Date) uri: $($uri)"

    Write-Verbose "$(Get-Date) Login"
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
        Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
        Write-Output "Error Message:        $($_.ErrorDetails.Message)"
        Write-Output "Exception:            $($_.Exception)"
        Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
        throw
    }

    Write-Verbose "$(Get-Date) Token received. Add the retrieved Bearer token to the headers"
    Write-Verbose "$(Get-Date) $($response | ConvertTo-json)"
    $bearer_token = $response.token
    $headers.Add("Authorization", "Bearer $($bearer_token)")

    Write-Verbose "$(Get-Date) Copy Bearer token to system Clipboard."
    Set-Clipboard -Value $headers.Authorization

    Write-Verbose "$(Get-Date) Create dynamic global variables"
    $variableName = "bearer_$($ComputerName.Split(".")[0])"
    New-Variable -Name $variableName -Scope Global -Value $headers.Authorization -Force

    $variableName = "headers_$($ComputerName.Split(".")[0])"
    New-Variable -Name $variableName -Scope Global -Value $headers -Force

}

End {
    Write-Verbose "$(Get-Date) End"
}

}
