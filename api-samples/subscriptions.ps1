

#Get all the current subscriptions configured.
$method = "GET"
$uri = "https://$($vraServer)/event-broker/api/subscriptions?page=0&size=20&%24filter=type%20eq%20%27RUNNABLE%27"
$response = Invoke-WebRequest -Method $method -Uri $uri -Headers $vRAheaders
($response.content | ConvertFrom-Json).Content | Select eventTopicId, name,priority, blocking | sort Name

<# 
Exported as csv
"eventTopicId","name","priority","blocking"
"compute.reservation.pre","01 ComputeReservationPre - kvs_deployment_creation1 - BLOCKING","10","True"
"compute.allocation.pre","02 ComputeAllocationPre - Set Resource Custom Name - BLOCKING","10","True"
"compute.allocation.pre","03 ComputeAllocationPre - Save Resource Names - BLOCKING","20","True"
"network.configure","04 NetworkConfigure - Insert IP Addresses - BLOCKING","10","True"
"compute.provision.post","05 ComputePostProvision - Apply NSX Security Tags - BLOCKING","10","True"
"compute.provision.post","06 ComputePostProvision - Linux - Base Post Build Steps - BLOCKING","20","True"
"compute.provision.post","06 ComputePostProvision - Windows - Base Post Build Steps - BLOCKING","20","True"
"compute.removal.post","50 ComputePostRemoval - Linux IaaS Compute Disposing - BLOCKING","10","True"
"compute.removal.post","50 ComputePostRemoval - Windows IaaS Compute Disposing - BLOCKING","10","True"
"network.removal.post","50 NetworkPostRemoval - Cleanup Resource Names","10","False"
"compute.removal.post","51 ComputePostRemoval - Release IP Addresses","10","False"
"compute.removal.post","52 ComputeRemovalPost - Delete Computer AD Object","10","False"
"compute.provision.post","ComputePostProvision - Dump - BLOCKING","10","True"
"deployment.request.pre","DeploymentRequested - Dump","10","False"
#>
