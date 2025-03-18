//submit Task
try {
    var configureTask = System.getModule("api.vspherereplication.operation.replication").postReplications(sourceVrRestHost,vrPairingId,configureReplicationSpec,headers,returnErrorResponses,debug).list[0];
} catch (e) {
    throw e
}

//Wait for Task to finish
var retryCount = 0;
var retryMax = 10;

do {
    retryCount++;
    System.log('Task in progress...');
    System.sleep(3000);

    //Get an update on the task
    var taskId = configureTask.id;
    var configureTask = System.getModule("api.vspherereplication.operation.tasks").getTasksByTaskId(sourceVrRestHost,taskId,headers,returnErrorResponses,debug);

} while(retryCount < retryMax && configureTask.status !== 'RUNNING');
