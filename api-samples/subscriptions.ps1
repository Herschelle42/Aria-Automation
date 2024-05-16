

#Get all the current subscriptions configured.
$method = "GET"
$uri = "https://$($vraServer)/event-broker/api/subscriptions?page=0&size=20&%24filter=type%20eq%20%27RUNNABLE%27"
$response = Invoke-WebRequest -Method $method -Uri $uri -Headers $vRAheaders
($response.content | ConvertFrom-Json).Content | Select eventTopicId, name,priority, blocking | sort Name

