function Import-vRAResourceAction {
    <#
.SYNOPSIS
  Import exported VMware Automation Resource Actions
.PARAMETER Path
  The path to the json file with the Resource Actions to import. This function
  expects an array of resource actions.
.NOTES
  This function assumes that the Workflows used by the Resource Actions are in 
  an embedded vRO instance.

  Requires a vRAConnection variable exists. Created by New-vRAConnection.

  The Workflows that the Resource Actions use must be imported into the 
  embedded VRO prior to importing. Wait for a collection cycle for Assembler
  to be able to see the Workflows.
#>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory)]
        [ValidateScript({ if (Test-Path -Path $_) { $true } else { throw "Invalid path $_" } })]
        [string]$Path
    )

    Begin {
        if (-not $vRAConnection) {
            throw "vRA Connection variable does not exist. Please run New-vRAConnection and try again."
        }

        Write-Verbose "$(Get-Date) Read file"
        $fileContent = Get-Content -Path $Path -Raw

        try {
            $jsonObject = $fileContent | ConvertFrom-Json
        }
        catch {
            throw("invalid JSON. Please check the file and try again.")
        }

        #If there is a content value, use the data from inside
        if ($jsonObject.content -ne $null) {
            Write-Verbose "$(Get-Date) Content value found in source json"
            $jsonObject = $jsonObject.content
        }

        Write-Verbose "$(Get-Date) Check object is an array"
        if (-not $jsonObject.gettype().IsArray) {
            throw('Expecting an array of resource actions. If embedded in ')
        }

        Write-Verbose "$(Get-Date) Get the id of the embedded vRO server"
        try {
            $integrationsResponse = invoke-restMethod -Uri "$($vRAConnection.Server)/iaas/api/integrations?apiVersion=2021-07-15&`$filter=integrationType eq vro&`$filter=name eq embedded-VRO"  -Method GET -Headers $vRAConnection.Headers
        }
        catch {
            throw
        }
        #There can only be 1 embedded VRO
        if ($integrationsResponse.numberOfElements -eq 1) {
            $vroId = $integrationsResponse.content[0].id
        }
        else {
            throw('No embedded VRO found.')
        }

    }

    Process {

        $counter = 1
        foreach ($item in $jsonObject) {
            Write-Verbose "Processing $($counter) of $($jsonObject.Count) - $($item.displayName)"
            $counter++

            #confirm has some mandatory fields
            if (-not ($item.id -and $item.name -and $item.id.Trim() -ne "" -and $item.name.Trim() -ne "" -and $item.formDefinition.name -and $item.formDefinition.id.trim() -ne "" -and $item.runnableItem -and $item.runnableItem.endpointLink)) {
                throw 'One or more mandatory items are missing'
            }

            #remove formDefinition.id as it must not be present for NEW items. The id CAN be present if it is already exists and you are updating it.
            if ($item.formDefinition.id) { 
                $item.formDefinition.PSObject.Properties.Remove('id')
            }
            if ($item.orgId) { 
                $item.PSObject.Properties.Remove('orgId')
            }
            if ($item.formDefinition.tenant) { 
                $item.formDefinition.PSObject.Properties.Remove('tenant')
            }

            $item.runnableItem.endpointLink = "/resources/endpoints/$($vroId)"

            $body = $item | ConvertTo-Json -Depth 5
            Write-Verbose "$(Get-Date) Body: `n$($body)"

            $method = "POST"
            $uri = "$($vRAConnection.Server)/form-service/api/custom/resource-actions"

            try {
                $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $vRAConnection.Headers -Body $body -SkipCertificateCheck:$vRAConnection.SkipCertificateCheck
                Write-Verbose "$(Get-Date) Response: $($response)"
            }
            catch [Microsoft.PowerShell.Commands.HttpResponseException] {
                #runnableItem.Id is the id of the Workflow and is required to be present before importing a Resource Action

                if ($_.ErrorDetails.Message -match "Error message: 404 NOT_FOUND \\u0022Cannot find workflow with id") {
                    throw("Workflow id: $($item.runnableItem.id) is missing from Orchestrator. Please import the workflow and try again.")
                }
                else {
                    Write-Verbose "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                    Write-Verbose "Error Exception Code: $($_.exception.gettype().fullname)"
                    Write-Verbose "Error Message:        $($_.ErrorDetails.Message)"
                    Write-Verbose "Exception:            $($_.Exception)"
                    throw
                }

            }
            catch {
                Write-Verbose "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                Write-Verbose "Error Exception Code: $($_.exception.gettype().fullname)"
                Write-Verbose "Error Message:        $($_.ErrorDetails.Message)"
                Write-Verbose "Exception:            $($_.Exception)"
                throw
            }

            $counter = 0
            $limit = 10
            while ($response.status -and $response.status -ne "FINISHED" -and $counter -lt $limit) {
                $counter++
                Write-Verbose "$(Get-Date) in progress"
                Start-Sleep -Seconds 3
                #Check the progress of the request
                $uriRequest = "$($vRAConnection.Server)$($response.selflink)"
                $methodRequest = "GET"
                $response = Invoke-RestMethod -Method $methodRequest -Uri $uriRequest -Headers $vRAConnection.Headers -SkipCertificateCheck:$vRAConnection.SkipCertificateCheck
            }
        }
    }

    End {
        Write-Verbose "$(Get-Date) End"
    }

}

