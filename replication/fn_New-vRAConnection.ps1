function New-vRAConnection {
    <#
.SYNOPSIS
  Create a global variable $vRAConnection
.DESCRIPTION
  This variable will contain the generated token and headers for use with API calls.
.PARAMETER Protocol
  The protocol to use to connect to Aria Automation. Valid values are http/https. Default is https.
.PARAMETER ComputerName
  The FQDN, IP address of the Aria Automation server
.PARAMETER Port
  The port to connect to Aria Automation. Default is none.
.PARAMETER SkipCertificateCheck
  Skips certificate validation checks that include all validations such as 
  expiration, revocation, trusted root authority, etc.
  WARNING: Using this parameter is not secure and is not recommended. This 
  switch is only intended to be used against known hosts using a self-signed 
  certificate for testing purposes. Use at your own risk.
.PARAMETER Credential
  The powershell Credential object to use to connect to Aria Automation username MUST be in UPN format.  user@corp.local
.PARAMETER Username
  The username in UPN format to connect to Aria Automation. user@corp.local
.PARAMETER Password
  The password to connect to connect to Aria Automation
.EXAMPLE
  New-vRAConnection -ComputerName vra.corp.local -Credential $credential
#>

    #Powershell 7+
    #Requires -Version 7.0

    [CmdletBinding(DefaultParameterSetName = "ByCredential")]
    Param
    (
        [Parameter(Mandatory = $false)]
        [ValidateSet("https", "http")]
        [string]$Protocol = "https",

        [Parameter(Mandatory)]
        [Alias("Server", "IPAddress", "FQDN")]
        [string]$ComputerName,

        [Parameter(Mandatory = $false)]
        [ValidatePattern("^[1-9][0-9]{0,4}$")]
        [int]$Port,

        [Parameter(Mandatory = $false)]
        [Switch]$SkipCertificateCheck = $false,

        [Parameter(Mandatory, ParameterSetName = "ByCredential")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.UserName -match "^[^@\s]+@[^@\s]+\.[^@\s]+$" }, ErrorMessage = "Username is not in UPN format. user@corp.local")]
        [Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory, ParameterSetName = "ByUsername")]
        [ValidatePattern("^[^@\s]+@[^@\s]+\.[^@\s]+$", ErrorMessage = "Username is not in UPN format. user@corp.local")]
        [string]$Username,

        [Parameter(Mandatory, ParameterSetName = "ByUsername")]
        [SecureString]$Password

    )

    Process {
        Write-Verbose "$(Get-Date) ParameterSet:         $($PSCmdlet.ParameterSetName)"
        Write-Verbose "$(Get-Date) Protocol:             $($Protocol)"
        Write-Verbose "$(Get-Date) ComputerName:         $($ComputerName)"
        Write-Verbose "$(Get-Date) Port:                 $($Port)"
        Write-Verbose "$(Get-Date) SkipCertificateCheck: $($SkipCertificateCheck)"

        #--- extract username and password from credential
        if ($PSCmdlet.ParameterSetName -eq "ByCredential") {
            Write-Verbose "$(Get-Date) Credential:           $($Credential | Out-String)"

            $shortUsername = $Credential.UserName.Split("@")[0]
            $UnsecurePassword = $Credential.GetNetworkCredential().Password
            $vRADomain = $Credential.UserName.Split("@")[1]

        }
        elseif ($PSCmdlet.ParameterSetName -eq "ByUsername") {
            $shortUsername = $Username.Split("@")[0]
            $vRADomain = $Username.Split("@")[1]
            $UnsecurePassword = (New-Object System.Management.Automation.PSCredential('username', $Password)).GetNetworkCredential().Password
        }
        else {
            throw "Unable to determine parameter set."
        }

        Write-Verbose "$(Get-Date) Username:             $($Username)"
        Write-Verbose "$(Get-Date) shortUsername:        $($shortUsername)"
        Write-Verbose "$(Get-Date) vRADomain:            $($vRADomain)"

        Write-Verbose "$(Get-Date) vRA8 Header Creation"
        $body = @{
            username = $shortUsername
            password = $UnsecurePassword
            tenant   = $tenant
            domain   = $vRADomain
        } | ConvertTo-Json

        #this fails on systems where Powershell is locked down. preventing even .net things from working :(
        try {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        }
        catch {
            Write-Warning "Your organisation has broken stuff!"
            Write-Output "[ERROR] $(Get-Date) Exception: $($_.Exception)"
            throw
        }
        $headers.Add("Accept", 'application/json')
        $headers.Add("Content-Type", 'application/json')

        $method = "POST"
        $baseUrl = "$($Protocol)://$($ComputerName)"
        $uri = "$($baseUrl)/csp/gateway/am/api/login?access_token"

        Write-Verbose "$(Get-Date) Request a token from vRA"
        try {
            $response = $null
            $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body -SkipCertificateCheck:$SkipCertificateCheck
        }
        catch {
            Write-Output "$(Get-Date) StatusCode:" $_.Exception.Response.StatusCode.value__
            throw
        }

        $Token = $response.refresh_token
        Write-Verbose "$(Get-Date) Refresh Token received."
        $newBody = @"
{ 
    refreshToken: "$($Token)" 
} 
"@

        $method = "POST"
        $baseUrl = "$($Protocol)://$($ComputerName)"
        $uri = "$($baseUrl)/iaas/api/login"

        Write-Verbose "$(Get-Date) Request a token from vRA"
        try {
            $response = $null
            $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $newBody -SkipCertificateCheck:$SkipCertificateCheck
        }
        catch {
            Write-Output "$(Get-Date) StatusCode:" $_.Exception.Response.StatusCode.value__
            throw
        }

        Write-Verbose "$(Get-Date) Token received. Add the retrieved Bearer token to the headers"
        $bearer_token = $response.token
        $headers.Add("Authorization", "Bearer $($bearer_token)")

        Write-Verbose "$(Get-Date) Headers: $($headers | Out-String)"

        # --- Create Output Object
        $vRAConnection = [PSCustomObject] @{

            Server               = $baseUrl
            Token                = $Token
            RefreshToken         = $bearer_token
            Headers              = $headers
            SkipCertificateCheck = $SkipCertificateCheck
        }
        New-Variable -Name 'vRAConnection' -Scope Global -Value $vRAConnection -Force

    }

}
