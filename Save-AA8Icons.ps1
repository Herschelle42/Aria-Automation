$dirIcons = "$($env:USERPROFILE)\Documents\icons"

$iconIdList = $allDeploymentList | ? { $_.iconId } | Select -ExpandProperty iconId | Sort -Unique

foreach($iconId in $iconIdList) {
    $uri = "https://$($vraServer)/icon/api/icons/$($iconId)"
    $outFile = "$($dirIcons)\$($iconId).image"
    #want to get extra information that is not returned if using Invoke-RestMethod
    $responseIcon = Invoke-WebRequest -Method Get -Uri $uri -Headers $headers -OutFile $outFile -PassThru
    $extension = $responseIcon.Headers."Content-Type".Split("/")[1]
    #rename file using the extension information
    Rename-Item -Path $outFile -NewName "$($outFile.replace("image",$extension))" 
}
