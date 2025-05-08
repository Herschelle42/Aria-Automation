function Export-vRASubscription {
    <#
  .SYNOPSIS
    Export Assembler Extensibility Subscriptions
  .PARAMETER Path
    Directory location to save the exported json files. Default is the current directory.
  .PARAMETER Name
    NOT IMPLEMENTED YET - The Name of the Subscription to export. Example: 'SRM - Remove Replication'
  .PARAMETER Id
    NOT IMPLEMENTED YET - The Id of the Subscription to export. Example:  sub_1733701955727
  .NOTES
    Requires the vRAConnection variable exists. Created by New-vRAConnection.

  #>
  
    [CmdletBinding(DefaultParameterSetName = "Default")]
    Param
    (
        [Parameter(Position = 0)]
        [ValidateScript({ if (Test-Path -Path $_) { $true } else { throw "Invalid path $_" } })]
        [string]$Path = "./"
  
        <#
      [Parameter(Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName,ParameterSetName="ById")]
      [string[]]$Id,

      [Parameter(Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName,ParameterSetName="ByName")]
      [string[]]$Name
      #>
    )
  
    Begin {
        if (-not $vRAConnection) {
            throw "vRA Connection variable does not exist. Please run New-vRAConnection and try again."
        }
  
    }
  
    Process {
  
        switch ($PSCmdlet.ParameterSetName) {
            "Default" {
                Write-Verbose "$(Get-Date) Exporting all items"
              
                $method = "GET"
                #TODO: Add paging
                $uri = "$($vRAConnection.Server)/event-broker/api/subscriptions?page=0&size=1000&`$filter=type eq 'RUNNABLE'"
                try {
                    $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $vRAConnection.Headers -SkipCertificateCheck:$vRAConnection.SkipCertificateCheck
                    Write-Verbose "$(Get-Date) Response: $($response)"
                }
                catch {
                    Write-Verbose "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                    Write-Verbose "Error Exception Code: $($_.exception.gettype().fullname)"
                    Write-Verbose "Error Message:        $($_.ErrorDetails.Message)"
                    Write-Verbose "Exception:            $($_.Exception)"
                    throw
                }
          
                if ($response.content) {
                    Write-Verbose "$(Get-Date) Save response to file"
                    $response.content | ConvertTo-Json -Depth 50 -Compress:$Compress | Out-File -FilePath "$($Path)\subscriptions.json" -Encoding ascii 
                }
            }
            "ById" {
                #TODO: not finished or tested.
                $counter = 1
                foreach ($SubscriptionId in $id) {
                    Write-Verbose "$(Get-Date) Processing $($counter) of $($id.Count) - $($SubscriptionId)"
                    $counter++
            
                    $method = "GET"
                    #$uri = "$($vRAConnection.Server)/event-broker/api/subscriptions?page=0&size=200&`$filter=id eq '$($SubscriptionId)'"
                    $uri = "$($vRAConnection.Server)/event-broker/api/subscriptions/$($SubscriptionId)"
            
                    try {
                        $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $vRAConnection.Headers -SkipCertificateCheck:$vRAConnection.SkipCertificateCheck
                        Write-Verbose "$(Get-Date) Response: $($response)"
                    }
                    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            
                        if ($_.ErrorDetails.Message -match "404 NOT_FOUND") {
                            throw("Resource Action not found: [$($id)] Please check the Id and try again.")
                        }
                        else {
                            Write-Verbose "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
                            Write-Verbose "Error Exception Code: $($_.exception.gettype().fullname)"
                            Write-Verbose "Error Message:        $($_.ErrorDetails.Message)"
                            Write-Verbose "Error Message Type:   $($_.ErrorDetails.Message.gettype())"
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
            
                    Write-Verbose "$(Get-Date) Save response to file"
                    $response | ConvertTo-Json -Depth 50 -Compress:$Compress | Out-File -FilePath "$($Path)\$($SubscriptionId).json" -Encoding ascii 
            
                }
            } 
            "ByName" {
                #TODO:
                #$uri = "$($vRAConnection.Server)/event-broker/api/subscriptions?page=0&size=200&`$filter=name eq 'SRM - Remove Replication'"
            }
        }

      
    }
  
    End {
        Write-Verbose "$(Get-Date) End"
    }
  
}
