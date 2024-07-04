<#
.SYNOPSIS
  Update the icons on Deployments.

/deployment/api/deployments/5afd4f5f-51b2-4be1-813a-6f2f958cc32c/requests?apiVersion=2020-08-25
POST
{"actionId":"Deployment.EditDeployment","inputs":{"Name":"scom-DevMS2","Icon":"020b90f7-af7a-31b5-a01c-350661a72136"}}

.NOTES
  Not Production ready.

#>

Return

#region --- Input Variables ---------------------------------------------------

$initialDirectory = "$($env:USERPROFILE)\Documents\Manage Discovered VMs"

$vraServer = "vra.corp.local"
$authDomain = "corp.local"

#create header and bearer tokens
New-vRABearerToken -ComputerName $vraServer -Credential $vraCredential -Domain $authDomain
$headers = $headers_vra

#endregion --------------------------------------------------------------------


Add-Type -AssemblyName System.Windows.Forms

#get the file of machines that were migrated (getting only 'yes' items)
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = $initialDirectory
    Filter = 'CSV (*machine_data*.csv)|*machine_data*.csv|All Files (*.*)|*'
}
Write-Output "Please chose a machine_data file with the machines to be imported"
$null = $FileBrowser.ShowDialog()
if($FileBrowser.FileNames.Count -eq 1) {
    Write-output "Import machine file:          $($FileBrowser.FileName)"
    $importMachineList = Import-Csv -Path $FileBrowser.FileName
} else {
    Write-Warning "No file selected or multiple selected."
    Return
}

#strip out just the machines from the import file that are being imported.
[array]$machineList = $importMachineList | ? { $_.import -eq "yes" }

# $VerbosePreference = "Continue"

$counter=1
foreach($machine in $machineList) {

    $machineId = $machine.machineId
    $machineName = $machine.machineName

    $deploymentId = $machine.deploymentId
    $deploymentName = $machine.deploymentName


    Write-Output "$(Get-Date) [INFO] Processing $($counter) of $($machineList.Count) - $($machineName) (Dep: $($deploymentName)) [Proj: $($machine.businessGroup)]"
    $counter++
   
    #first you must get the machine as you must have the tags if you do not they will be removed.
    #get the tags, customProperties and bootConfig (if they exist)
    $method="GET"
    $uri = "https://$($vraServer)/deployment/api/deployments/$($deploymentId)"
    #$escapedUri = [uri]::EscapeUriString($uri).Replace('&','%26')

    try
    {
        $response = $null
        $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
    } catch [System.Net.WebException] {
        
        #capture not found nicely so script can continue.
        if ($($_.Exception.Message) -eq "The remote server returned an error: (404) Not Found." )
        {
            Write-Verbose "[ERROR] !!! $($_.Exception.Message)"
            Write-Verbose "Deployment NOT Found with id: $($deploymentId)"
            Write-Verbose "Looking up by Deployment name."

            $method="GET"
            $uri = "https://$($vraServer)/deployment/api/deployments?`$filter=name eq '$($deploymentName)'"
            $escapedUri = [uri]::EscapeUriString($uri)
            try
            {
                $response = $null
                $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
            } catch [System.Net.WebException] {
        
                if ($($_.Exception.Message) -eq "The remote server returned an error: (404) Not Found." )
                {
                    Write-Verbose "[ERROR] !!! $($_.Exception.Message)"
                    Write-Verbose "Deployment NOT Found with name: $($deploymentName)"
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
                Write-Verbose "Found by Name"
                $response = $response.content | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                #get the id
                $deploymentId = $response.id
            } elseif ($response.totalElements -gt 1) {
                Write-Warning "More than 1 deployment found of the same name."

                #is 1 of them managed vs discovered.
                #TODO: make better if more than 1 managed machine found.
                foreach ($item in $response.content) {
                    if ($item.deploymentId) {
                        
                        $response = $item | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                        $deploymentId = $item.id
                    } else {
                        Continue
                    }
                }
            } else {
                Write-Warning "No Deployment found by name: $($deploymentName). Skipping"
                Continue
            }


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


    $deployment = $response

    #get available icons
    $actionId = "Deployment.EditDeployment"
    $uri = "https://$($vraServer)/deployment/api/deployments/$($deploymentId)/actions/$($actionId)/data/catalog-icons?expandProjects=true&sort=name%2Casc&page=0&size=10&apiVersion=2020-08-25"

    try {
        $responseIcons = $null
        $responseIcons = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers

    } catch {
        Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
        Write-Output "Error Message:        $($_.ErrorDetails.Message)"
        Write-Output "Exception:            $($_.Exception)"
        Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
        Write-Warning "No icons found, skipping."
        Continue
        #throw
    }

    #match the icon with the template name
    $iconId = $null
    $iconId = $responseIcons.content | ? { $_.catalogName -eq $machine.cloudTemplateName } | Select -ExpandProperty id
    
    if(-not $iconId) { 
        Write-Warning "No icon matches the name: $($machine.cloudTemplateName)"
        Continue
    }

    #Does the deployment already have the correct icon?
    if($deployment.iconId -eq $iconId) {
        Write-Verbose "Icon already matches, no action required." -Verbose
    } else {

#create json body as here string. do _not_ indent
$body = @"
    {
        "actionId": "$($actionId)",
        "inputs": {
            "Name": "$($deploymentName)",
            "Icon": "$($iconId)"
        }
    }
"@
        
        #execute the request
        $method = "POST"
        $uri = "https://$($vraServer)/deployment/api/deployments/$($deploymentId)/requests?apiVersion=2020-08-25"
        try
        {
            Write-Output "[INFO] $(Get-Date) Updating icon: $($machine.cloudTemplateName)"
            $responseUpdate = $null
            $responseUpdate = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body
            #add a small wait to not DDOS AA8
            Start-Sleep -Milliseconds 300
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

}

$VerbosePreference = "SilentlyContinue"

Return

#region --- Update icons

<#
  Update other deployments using the $allDeploymentList
#>

$actionId = "Deployment.EditDeployment"
$noIconDeployments = $allDeploymentList | ? { -not $_.iconId}
$noIconDeployments.Count

$counter = 1
foreach($deployment in $noIconDeployments) {
    Write-Output "$(Get-Date) [INFO] Processing $($counter) of $($noIconDeployments.Count) - $($deployment.name)"
    $counter++
    
    $vm = $null
    $iconId = $null
    $machineName = $null

    $machineName = $deployment.resources | ? { $_.type -eq "Cloud.vSphere.Machine" } | Select -ExpandProperty name
    $vm = $vmlist | ? { $_.name -eq $machineName }
    
    if($vm.guest_OS) {
        $iconId = switch($vm.guest_OS) {
            {$_ -match "Windows.*Server"} {
                Write-Verbose "$($vm.guest_OS) - Windows Server" -Verbose
                "020b90f7-af7a-31b5-a01c-350661a72136"
                break;
            }
            {$_ -match "Ubuntu"} {
                "e6edb3e1-e787-3b0a-9af0-76b03cf247e2"
                break;
            }
            {$_ -match "Debian"} {
                "d8b6e576-a524-317e-84a9-3ea623ab4873"
                break;
            }
            {$_ -match "SLES"} {
                "c40460d7-e025-3a92-b38c-acc2d0b1788b"
                break;
            }
            {$_ -match "RHEL"} {
                "0af9bf3f-3e7e-388f-9b11-bcb2129089e7"
                break;
            }
            {$_ -match "Photon"} {
                "925f2de8-bb47-3bc1-b6a8-09dd67b26b41"
                break;
            }
            {$_ -match "CentOS"} {
                "94611f39-3606-3826-afe9-68ad77706917"
                break;
            }
            {$_ -match "FreeBSD"} {
                "6d9e4e48-4257-3369-bba9-0e9fd936903b"
                break;
            }
            {$_ -match "Solaris"} {
                "b75774ca-ee2c-3caf-bc30-e7a70cd718ab"
                break;
            }
            {$_ -match "Other.*Linux"} {
                "f36ac768-65b1-3bbe-895e-12a86e9e42bc"
                break;
            }
            {$_ -match "Windows"} {
                #if does not equal windows server, then use the colorful desktop icon
                Write-Verbose "$($vm.guest_OS) - Windows Desktop" -Verbose
                "1ee4fc87-454a-36c8-9630-2093e72820ad"
                break;
            }
            default {
                $null
            }
        }

        if($iconId) {

    #create json body as here string. do _not_ indent
$body = @"
    {
        "actionId": "$($actionId)",
        "inputs": {
            "Name": "$($deployment.name)",
            "Icon": "$($iconId)"
        }
    }
"@
        
            #execute the request
            $method = "POST"
            $uri = "https://$($vraServer)/deployment/api/deployments/$($deployment.id)/requests?apiVersion=2020-08-25"
            try
            {
                Write-Output "[INFO] $(Get-Date) Updating icon: $($vm.guest_OS)"
                $responseUpdate = $null
                $responseUpdate = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body
                #add a small wait to not DDOS AA8
                Start-Sleep -Milliseconds 100
            }
            catch 
            {
                Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
                Write-Output "Error Message:        $($_.ErrorDetails.Message)"
                Write-Output "Exception:            $($_.Exception)"
                Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                throw
            }

        } else {
            Write-Warning "No icon Id was able to be determined for $($vm.guest_OS)"
        }
    } else {
        Write-Warning "No OS detected!"
    }
}

#endregion --------------------------------------------------------------------

Return

#region --- update icon from one to another -----------------------------------

#FreeBSD
$oldIconId = "9a717f08-cf30-372c-9a0d-ede650536c4c"
$iconId = "6d9e4e48-4257-3369-bba9-0e9fd936903b"

#Solaris
$oldIconId = "b75774ca-ee2c-3caf-bc30-e7a70cd718ab"
$iconId = "dd047a8f-729a-3880-9cb8-91b427dbca3b"


#which deployments to target?
$theseDeployments = $allDeploymentList | ? { $_.iconId -eq $oldIconId }

$actionId = "Deployment.EditDeployment"

$counter=1
foreach($deployment in $theseDeployments) {
    Write-Output "$(Get-Date) [INFO] Processing $($counter) of $($theseDeployments.Count) - $($deployment.name)"
    $counter++

    #create json body as here string. do _not_ indent
$body = @"
    {
        "actionId": "$($actionId)",
        "inputs": {
            "Name": "$($deployment.name)",
            "Icon": "$($iconId)"
        }
    }
"@
        
        #execute the request
        $method = "POST"
        $uri = "https://$($vraServer)/deployment/api/deployments/$($deployment.id)/requests?apiVersion=2020-08-25"
        try
        {
            Write-Output "[INFO] $(Get-Date) Updating icon"
            $responseUpdate = $null
            $responseUpdate = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body
            #add a small wait to not DDOS AA8
            Start-Sleep -Milliseconds 100
         } catch [System.Net.WebException] {
        
            if ($($_.ErrorDetails.Message) -match "No change in the name, description or icon values. Please provide a new name or description or icon!" )
            {
                Write-Verbose "$(Get-Date) Icon already changed. No action required." -Verbose
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

#endregion --------------------------------------------------------------------
