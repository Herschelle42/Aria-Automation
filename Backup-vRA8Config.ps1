<#
.SYNOPSIS
  Backup vRA configuration without resorting to db dumps or full snapshots.
.DESCRIPTION
  Exports vRA8 configurations as json files using API calls.

.NOTES
  This is a work in progress, not Production ready and may not actually just work out of the box.

#>

#The location of the credential file containing vRA login credentials
$CredentialPath = "$($env:USERPROFILE)\cred-vra.xml"

$vraServer = "vra01.corp.local"
$vraDomain = "corp.local"
$tenant = "vsphere.local"

<#
Where to save all the files.
will create sub directory structure  ..\<vra server>\<iso date>\
example:
"C:\Work\Backup\vra01.corp.local\2024-02-22\"
#>
$BackupRoot = "C:\Work\Backup"

<# This is for a Scheduled task if set up.

[CmdletBinding()]
Param(
        [Parameter(Mandatory)]
        [String]$vRAServer,
        [string]$Tenant="vsphere.local",
        #Path to the Credential file to be used. The credential username should be in UPN format.
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [System.IO.FileInfo]$CredentialPath,
        #Path the Backup directory
        [ValidateScript({Test-Path $_})]
        [System.IO.FileInfo]$BackupRoot="\\fileserver.corp.local\Backup\vRA7"
)

Write-Verbose "$(Get-Date) vRAServer:      $($vRAServer)"
Write-Verbose "$(Get-Date) Tenant:         $($Tenant)"
Write-Verbose "$(Get-Date) CredentialPath: $($CredentialPath)"
Write-Verbose "$(Get-Date) BackupRoot:     $($BackupRoot)"

#>

#region --- Setup -------------------------------------------------------------


#Capture current location so we can return to it at the end of the script.
$thisLocation = $pwd

# Import credential file
$import = Import-Clixml -Path $CredentialPath

# Test for valid import
if ( !$import.UserName -or !$import.EncryptedPassword ) {
    throw "Input is not a valid ExportedPSCredential object, exiting."
}
$Username = $import.Username
 
# Decrypt the password and store as a SecureString object for safekeeping
$SecurePass = $import.EncryptedPassword | ConvertTo-SecureString
 
# Build the new credential object
$vraCredential = New-Object System.Management.Automation.PSCredential $Username, $SecurePass

if (-not $vraCredential)
{
    $vraCredential = Get-Credential -Message "vRA Credentials for: $($vraServer)"
}

#set location as writing to relative paths - or are we?
Set-Location $backupRoot
$isoDate = Get-Date -UFormat "%Y-%m-%d"

Write-Verbose "$(Get-Date) Remove oldest directories"
#if (Test-Path -Path "$($backupRoot)\$($vraServer)\$($tenant)\") {
#    $dirList = Get-ChildItem -Path "$($backupRoot)\$($vraServer)\$($tenant)\"  | Where-Object { $_.PSIsContainer -and $_.CreationTime -lt (Get-Date).AddDays(-50) } | Sort-Object Name
if (Test-Path -Path "$($backupRoot)\$($vraServer)\") {
    $dirList = Get-ChildItem -Path "$($backupRoot)\$($vraServer)\"  | Where-Object { $_.PSIsContainer -and $_.CreationTime -lt (Get-Date).AddDays(-50) } | Sort-Object Name
    Write-Verbose "$(Get-Date) $($dirList | Select-Object Name | out-string)"
    $dirList | Remove-Item -Recurse -Force
}

Write-Verbose "$(Get-Date) Create backup folders"
#$backupDirectory = "$($backupRoot)\$($vraServer)\$($tenant)\$($isoDate)"
$backupDirectory = "$($backupRoot)\$($vraServer)\$($isoDate)"
if(-not (Test-Path -Path $backupDirectory)) {
    Write-Output "[INFO] $(Get-Date) Creating directory"
    New-Item -ItemType Directory -Path $backupDirectory -Force
} else {
    Write-Verbose "$(Get-Date) Directory already exists"
}

#Create vRA API Bearer token 
if ($vraCredential) {
    Write-Verbose "$(Get-Date) Credentials passed"

    $Username = $vraCredential.username
    $Password = $vraCredential.getnetworkcredential().Password

    $body = @{
        username = $Username
        password = $Password
        tenant = $tenant
        domain = $vraDomain
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
    $baseUrl = "https://$($vraServer)"
    #$uri = "$($baseUrl)/identity/api/tokens"
    $uri = "$($baseUrl)/csp/gateway/am/api/login?access_token"
    #https://kb.vmware.com/s/article/89129

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
    $baseUrl = "https://$($vraServer)"
    $uri = "$($baseUrl)/iaas/api/login"

    Write-Verbose "$(Get-Date) Request a token from vRA"
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

    Write-Verbose "$(Get-Date) Token received. Add the retrieved Bearer token to the headers"
    $bearer_token = $response.token
    $headers.Add("Authorization", "Bearer $($bearer_token)")

} else {
    Write-Error "$(Get-Date) No credentials provided. Terminating."
    Return
}

#endregion ---



#region --- Functions ---------------------------------------------------------

function Invoke-vRAAPIBackup
{
[CmdletBinding()]
Param(
    #Full uri API call. (Unescaped)
    [Parameter(Mandatory)]
    [string]$Uri,
    #REST Method
    [Parameter(Mandatory)]
    [ValidateSet("GET","PUT","POST","DELETE","PATCH")]
    [string]$Method,
    #Body of api call (Optional)
    [string]$Body,
    #Name (Type) of object being backed up. Used in the file name. If no name specified object is returned to the pipeline instead.
    [Parameter()]
    [string]$Name,
    #Compress the json output. Default is false.
    [switch]$Compress,
    #Number of entries per page to return. Default is 20. Provides the ability to override for some of the APIs do not provide totalElements metadata. Or worse only return the default page size as the total elements.
    [int]$PageSize = 20,
    #Directory path to save the file to. Default is $backupDirectory
    [string]$Path=$backupDirectory
)

Begin {
    
    $pageCount = 0
    $totalPages = 9999

    Write-Verbose "$(Get-Date) URI     : $($Uri)"
    Write-Verbose "$(Get-Date) Method  : $($Method)"
    Write-Verbose "$(Get-Date) Body    : $($Body | Out-String)"
    Write-Verbose "$(Get-Date) Name    : $($Name)"
    Write-Verbose "$(Get-Date) Compress: $($Compress)"
    Write-Verbose "$(Get-Date) PageSize: $($PageSize)"

}

Process {

    $allResults = while ($pageCount -le $totalPages) {
        Write-Verbose "$(Get-Date) Processing Page: $($pageCount) of $($totalPages)"

        Write-Verbose "$(Get-Date) uri : $($uri)"
        Write-Verbose "$(Get-Date) uri : [uri]::EscapeUriString($($uri)"
        Write-Verbose "$(Get-Date) IndexOf ? : $($uri.IndexOf("?"))"
        if ($uri.IndexOf("?") -gt 0)
        {
            $escapedURI = [uri]::EscapeUriString($uri + "&page=$($pageCount)&limit=$($pageSize)&orderby=name")
        } else {
            $escapedURI = [uri]::EscapeUriString($uri + "?page=$($pageCount)&limit=$($pageSize)&orderby=name")
        }

        #hack for deployments. uses top instead of limit. and has no orderby and skip instead of page
        Write-Verbose "$(Get-Date) IndexOf deployments : $($uri.IndexOf("deployments"))"
        if ($uri.IndexOf("deployments") -gt 0 -and $uri.IndexOf("?") -gt 0)
        {
            $escapedURI = [uri]::EscapeUriString($uri + "&`$skip=$($pageCount*$PageSize)&`$top=$($pageSize)")
        } else {
            $escapedURI = [uri]::EscapeUriString($uri + "?`$skip=$($pageCount*$PageSize)&`$top=$($pageSize)")
        }

        Write-Verbose "$(Get-Date) Escaped URI: $($escapedURI)"
        <#
        if($uri.IndexOf("@") -gt 0) {
            $escapedURI = $escapedURI.Replace("@","%40")
            Write-Verbose "$(Get-Date) Escaped URI: $($escapedURI)"
        }
        #>
        if($uri.IndexOf('$') -gt 0) {
            $escapedURI = $escapedURI.Replace('$',"%24")
            Write-Verbose "$(Get-Date) Escaped URI: $($escapedURI)"
        }
        try{
            #TODO: Remove -SkipCertificateCheck when in Production
            if($Body) {
                $result = Invoke-WebRequest -Uri $escapedURI -Headers $headers -Method $Method -Body $Body -UseBasicParsing -Verbose:$VerbosePreference -SkipCertificateCheck
            } else {
                $result = Invoke-WebRequest -Uri $escapedURI -Headers $headers -Method $Method -UseBasicParsing -Verbose:$VerbosePreference -SkipCertificateCheck
            }
        } catch {
            throw $_
        }
        #Have to convert to powershell object to be able to easily use the results
        $object = $result.Content | ConvertFrom-Json
        $object

        #increment
        $pageCount++
        if($object.metadata)
        {
            Write-Verbose "$(Get-Date) Metadata:  $($object.metadata | Out-String)"
            #hack for /api/tenants/{tenantId}/groups which does not return the correct totalPages or totalElements metadata
            if ($object.metadata.totalElements/$pageSize -gt $object.metadata.totalPages)
            {
                Write-Verbose "$(Get-Date) totalPages: $($object.metadata.totalPages)"
                Write-Verbose "$(Get-Date) totalElements: $($object.metadata.totalElements)"
                $totalPages = [Math]::Ceiling($object.metadata.totalElements/$pageSize)

            } else {
                $totalPages = $object.metadata.totalPages
            }

        #hack for /api/iaas/deployments where not found in metadata.
        } elseif ($object.totalElements -and $object.numberOfElements) {

            Write-Verbose "$(Get-Date) totalElements:  $($object.totalElements)"
            Write-Verbose "$(Get-Date) numberOfElements:  $($object.numberOfElements)"
            $totalPages = [Math]::Ceiling($object.totalElements/$pageSize)  
                  
        } else {
            $pageCount = $totalPages+1
        }
        Write-Verbose "$(Get-Date) pageCount: $($pageCount)"
        Write-Verbose "$(Get-Date) totalPages: $($totalPages)"
    }

    #TODO: remove -Verbose from the "Count Of" after successfully validated all correct data returned
    if ($Name)
    {
        #$FileName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars())
        #[System.IO.Path]::GetInvalidFileNameChars() | % {$text = $text.replace($_,'.')}
        #$Path.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        #"$($Path)\$($Name.Replace('[','_').replace(']','_')).json"


        Write-Verbose "$(Get-Date) Saving to file"
        #Note: Some objects have a content key that contains a string and other items
        #TODO: Validate the output is what is expected
        if ($allResults.content -and $item.content.gettype().IsArray)
        {
            Write-Verbose "$(Get-Date) Count of $($Name) : $($allResults.content.count)" -Verbose
            $allResults.content | ConvertTo-Json -Depth 50 -Compress:$Compress | Out-File -FilePath "$($Path)\$($Name).json" -Encoding ascii 
        } else {
            Write-Verbose "$(Get-Date) no .content"
            Write-Verbose "$(Get-Date) Count of $($Name) : $($allResults.count)" -Verbose
            $allResults | ConvertTo-Json -Depth 50 -Compress:$Compress | Out-File -FilePath "$($Path)\$($Name).json" -Encoding ascii 
        }

    }

    Write-Verbose "$(Get-Date) Returning Powershell Object"
    Return $allResults
}

End {
    Write-Verbose "$(Get-Date) End Invoke-vRAAPIBackup"
}

}


#endregion ---



#region --- Export configurations ---------------------------------------------

Invoke-vRAAPIBackup -uri "$($baseUrl)/project-service/api/projects" -method GET -Name "projectservice-projects"

$cloudAccounts = Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/cloud-accounts" -method GET -Name "cloud-accounts" | Select-Object -ExpandProperty Content
#cannot remember why I am capturing the cloudAccounts like this
#$cloudAccounts.name

#no paging options
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/compute-gateways" -method GET -Name "compute-gateways"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/compute-nats" -method GET -Name "compute-nats"
#Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/data-collectors" -method GET -Name "data-collectors"

Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/fabric-azure-storage-accounts" -method GET -Name "fabric-azure-storage-accounts"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/fabric-computes" -method GET -Name "fabric-computes"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/fabric-flavors" -method GET -Name "fabric-flavors"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/fabric-images" -method GET -Name "fabric-images"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/fabric-networks" -method GET -Name "fabric-networks"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/fabric-vsphere-datastores" -method GET -Name "fabric-vsphere-datastores"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/fabric-vsphere-storage-policies" -method GET -Name "fabric-vsphere-storage-policies"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/flavor-profiles" -method GET -Name "flavor-profiles"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/flavors" -method GET -Name "flavors"
#Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/folders" -method GET -Name "folders"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/image-profiles" -method GET -Name "image-profiles"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/images" -method GET -Name "images"
## requires API version
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/integrations?apiVersion=2021-07-15" -method GET -Name "integrations"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/zones" -method GET -Name "zones"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/regions" -method GET -Name "regions"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/network-domains" -method GET -Name "network-domains"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/networks" -method GET -Name "networks"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/external-ip-blocks" -method GET -Name "external-ip-blocks"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/network-ip-ranges" -method GET -Name "network-ip-ranges"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/external-network-ip-ranges" -method GET -Name "external-network-ip-ranges"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/network-profiles" -method GET -Name "network-profiles"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/projects" -method GET -Name "iaas-projects"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/configuration-properties?apiVersion=2021-07-15" -method GET -Name "configuration-properties"

Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/security-groups" -method GET -Name "security-groups"
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/storage-profiles" -method GET -Name "storage-profiles"

<# !no total elements returned. when use count=true I get an error 
$count cannot be used togerther with $top in swagger
#>
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/tags?`$top=100" -method GET -Name "tags" -Verbose


#Workload calls, deployments, machines etc
Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/load-balancers" -method GET -Name "load-balancers"

#Ths is just an active tracker not a configuration to collect
#Invoke-vRAAPIBackup -uri "$($baseUrl)/iaas/api/request-tracker" -method GET -Name "request-tracker"

Invoke-vRAAPIBackup -uri "$($baseUrl)/properties/api/property-groups" -method GET -Name "property-groups"


Invoke-vRAAPIBackup -uri "$($baseUrl)/form-service/api/custom/resource-types" -method GET -Name "resource-types"
$resourceActions = Invoke-vRAAPIBackup -uri "$($baseUrl)/form-service/api/custom/resource-actions" -method GET -Name "resource-actions" | Select-Object -ExpandProperty Content
#Save each of the resource action forms in a subdirectory vs creating a custom complete json file
$thisDirectory = "$($backupDirectory)\resource-actions"
if(-not (Test-Path -Path $thisDirectory)) {
    Write-Output "[INFO] $(Get-Date) Creating directory"
    New-Item -ItemType Directory -Path $thisDirectory -Force
} else {
    Write-Verbose "$(Get-Date) Directory already exists"
}

foreach($action in $resourceActions) {
    Invoke-vRAAPIBackup -uri "$($baseUrl)/form-service/api/custom/resource-actions/$($action.id)/form" -method GET -Name "$($action.id)" -Path $thisDirectory
}

$blueprintList = Invoke-vRAAPIBackup -uri "$($baseUrl)/blueprint/api/blueprints" -method GET -Name "blueprints" | Select-Object -ExpandProperty Content
#Create a directory to save each of the items
$thisDirectory = "$($backupDirectory)\blueprints"
if(-not (Test-Path -Path $thisDirectory)) {
    Write-Output "[INFO] $(Get-Date) Creating directory"
    New-Item -ItemType Directory -Path $thisDirectory -Force
} else {
    Write-Verbose "$(Get-Date) Directory already exists"
}

$blueprintDetails = foreach($item in $blueprintList) {
    #Gets the current draft content
    Invoke-vRAAPIBackup -uri "$($baseUrl)$($item.selfLink)" -method GET -Name "$($item.id)" -Path $thisDirectory

    #if there are version avaiable backup the different versions into their own subdirectory
    if($item.totalVersions -gt 0) {
        $versionList = Invoke-vRAAPIBackup -uri "$($baseUrl)$($item.selfLink)/versions" -method GET | Select-Object -ExpandProperty Content
        foreach($version in $versionList){
            #gets the versioned item content
            $versionDirectory = "$($thisDirectory)\$($item.id)"
            if(-not (Test-Path -Path $versionDirectory)) {
                Write-Output "[INFO] $(Get-Date) Creating directory"
                New-Item -ItemType Directory -Path $versionDirectory -Force
            } else {
                Write-Verbose "$(Get-Date) Directory already exists"
            }

            Invoke-vRAAPIBackup -uri "$($baseUrl)$($item.selfLink)/versions/$($version.id)" -method GET -Name "$($version.id)" -Path $versionDirectory
        }
    }
}



#endregion ---

Write-Output "[INFO] $(Get-Date) End"
Set-Location -Path $thisLocation
