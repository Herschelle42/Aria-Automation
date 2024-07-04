<#
.SYNOPSIS
  To run the WF 2. discovered and obtain the log from the resource to export 
  and read into a powershell variable for reporting purposes

.NOTES
  Assumes the following variables have been created:
  $vraServer
  $headers
  $outputDirectory

  This example is specifically around the AA8 onBoarding package of workflows 
  and process but the same logic can be applied to other workflows

    #get workflow by name
    #https://vra.corp.local/vco/api/workflows?maxResult=10&startIndex=0&conditions=name^2. captureDiscoveredMachineDatavRA8
    #escaped
    #https://vra.corp.local/vco/api/workflows?maxResult=10&startIndex=0&conditions=name%5E2.%20captureDiscoveredMachineDatavRA8


    #get workflow executions
    #https://vra.corp.local/vco/api/workflows/dc31fd60-86f3-4cb0-b036-d95e79e685fb/executions?maxResult=2147483647&startIndex=0

    #get the log of the workflow execution
    #https://vra.corp.local/vco/api/workflows/dc31fd60-86f3-4cb0-b036-d95e79e685fb/executions/be78d6a6-0f1e-4d0d-bd4d-c80d8c91108b/syslogs?maxResult=2147483647


    {
      "logs": [
           {
              "entry": {
                "origin": "system",
                "short-description": "Resource Element //tmp/machine_data_27-Jun-2024-T014651_discovered.csv Saved to Folder Onboarding",
                "time-stamp": "2024-06-27T01:46:55.891+00:00",
                "time-stamp-val": 1719452815891,
                "severity": "info"
              }
            },

#>
Return


#Get the id of the Workflow by looking it up by name

$wfName = "2. captureDiscoveredMachineDatavRA8"

$uri = "https://$($vraServer)/vco/api/workflows?maxResult=10&startIndex=0&conditions=name^$($wfName)"
$escapedURI = [uri]::EscapeUriString($uri)
$method = "GET"
$response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers

#TODO: test for multiple reponses
$workflowId = $response.link[0].attributes | ? { $_.name -eq "id" } | Select -ExpandProperty value


#run the workflow, there are no parameters for the WF: 2. captureDiscoveredMachineDatavRA8
$uri = "https://$($vraServer)/vco/api/workflows/$($workflowId)/executions"
$method = "POST"
$body = "{}"
$response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $body

$executionId = $response.id

#Monitor status of Workflow and wait for it to complete.
<#
#TODO: Need to updated the request tracking to be the one for vRO not vRA API :)

$requestCounter = 0
$requestLimit = 10

if($response.state = "running") {
    $requestInProgress = $true
} else { 
    $requestInProgress = $false
}

while($requestInProgress -and $requestCounter -lt $requestLimit) {
    $requestCounter++

    Write-Verbose "$(Get-Date) In progress..." -Verbose
    Start-Sleep -Milliseconds 300

    #track the request
    $method = "Get"
    $uri = "https://$($vraServer)/iaas/api/request-tracker/$($executionId)"
    try
    {
        Write-Output "[INFO] $(Get-Date) Checking status"
        $responseRequest = $null
        $responseRequest = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
    }
    catch 
    {
        Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
        Write-Output "Error Message:        $($_.ErrorDetails.Message)"
        Write-Output "Exception:            $($_.Exception)"
        Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
        throw
    }

    if($responseRequest.st -ne "INPROGRESS") {
        $requestInProgress = $false
    }
}

Write-Output "[INFO] $(Get-Date) Final request status: $($responseRequest.status)"
#>


$uri = "https://$($vraServer)/vco/api/workflows/$($workflowId)/executions/$($executionId)/syslogs"
$method = "GET"
$response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers

#get the log entry that relates to the csv file it is saving
$logText = $response.logs.entry | ? { $_.'short-description' -match "machine_data" } | Select -ExpandProperty "short-description"
#Resource Element //tmp/machine_data_27-Jun-2024-T235733_discovered.csv Saved to Folder Onboarding

$logname = $logText.Split("/")[3].split(" ")[0]
#machine_data_27-Jun-2024-T235733_discovered.csv
Write-Output "$(Get-Date) [INFO] Logfile name: $($logname)"


#Get the resource item by name
$selResourceName = @{Name="ResourceName"; Expression={$_.attributes | ? { $_.name -eq "name" } | Select -ExpandProperty Value}}
$selResourceId = @{Name="ResourceId"; Expression={$_.attributes | ? { $_.name -eq "id" } | Select -ExpandProperty Value}}


$method="GET"
$uri = "https://$($vraServer)/vco/api/resources"
#$escapedUri = [uri]::EscapeUriString($uri)
try
{
    $response = $null
    $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
} catch {
    Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
    Write-Output "Error Message:        $($_.ErrorDetails.Message)"
    Write-Output "Exception:            $($_.Exception)"
    Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
    throw
}

#Get the resourceId of the log file
$resourceId = $response.link | Select $selResourceName, $selResourceId | ? { $_.ResourceName -eq $logName } | Select -ExpandProperty ResourceId


$method="GET"
$uri = "https://$($vraServer)/vco/api/resources/$($resourceId)"
#$escapedUri = [uri]::EscapeUriString($uri)
try
{
    $response = $null
    $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
} catch {
    Write-Output "Error Exception Code: $($_.exception.gettype().fullname)"
    Write-Output "Error Message:        $($_.ErrorDetails.Message)"
    Write-Output "Exception:            $($_.Exception)"
    Write-Output "StatusCode:           $($_.Exception.Response.StatusCode.value__)"
    throw
}


#split into individual items if want to do search by line.
#$resourceContent = $response.Split("`n")


#export \ save to a local file
$response | Out-File -FilePath "$($outputDirectory)\$($logname)"  -Encoding ascii
