function Export-vRAResourceAction {
  <#
.SYNOPSIS
  Export Assembler Resource Actions (Day 2)
.PARAMETER Path
  Directory location to save the exported json. If an Id is specified the file 
  will be named the id. 
.PARAMETER Id
  The Id of the Resource Action to export. Example:  Cloud.vSphere.Machine.custom.myaction
  If left blank ALL Resource Actions will be exported to a single json file.
.NOTES
  Requires the vRAConnection variable exists. Created by New-vRAConnection.

#>

  [CmdletBinding()]
  Param
  (
    [Parameter(Position = 0, Mandatory)]
    [ValidateScript({ if (Test-Path -Path $_) { $true } else { throw "Invalid path $_" } })]
    [string]$Path,

    [Parameter(Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$Id

  )

  Begin {
    if (-not $vRAConnection) {
      throw "vRA Connection variable does not exist. Please run New-vRAConnection and try again."
    }

  }

  Process {

    if ($id.count -gt 0) {

      $counter = 1
      foreach ($item in $id) {
        Write-Verbose "$(Get-Date) Processing $($counter) of $($id.Count) - $($item)"
        $counter++

        $method = "GET"
        $uri = "$($vRAConnection.Server)/form-service/api/custom/resource-actions/$($item)"

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
        $response | ConvertTo-Json -Depth 50 -Compress:$Compress | Out-File -FilePath "$($Path)\$($id).json" -Encoding ascii 

      }
    }
    else {
      Write-Verbose "$(Get-Date) No Id provided. Exporting all resource actions."

      $method = "GET"
      #Yes this is lazy and really needs to use paging
      $uri = "$($vRAConnection.Server)/form-service/api/custom/resource-actions?page=0&size=1000"
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
        $response.content | ConvertTo-Json -Depth 50 -Compress:$Compress | Out-File -FilePath "$($Path)\resource-actions.json" -Encoding ascii 
      }
    }
  }

  End {
    Write-Verbose "$(Get-Date) End"
  }

}
