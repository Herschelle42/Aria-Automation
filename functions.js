/*
Random functions
*/
function getISODate(){
    var date = new Date();
    var dateTimeString = date.getFullYear() + '-' +
    ('0' + (date.getMonth()+1) 	).slice(-2) + '-' + 
    ('0' + 	date.getDate()		).slice(-2)
    return dateTimeString;
}


function getISODateTime(){
    var date = new Date();
    var dateTimeString = date.getFullYear() + '-' +
    ('0' + (date.getMonth()+1) 	).slice(-2) + '-' + 
    ('0' + 	date.getDate()		).slice(-2) + '-' + 
    ('0' + 	date.getHours()		).slice(-2) + '-' + 
    ('0' + 	date.getMinutes()	).slice(-2) + '-' + 
    ('0' + 	date.getSeconds()	).slice(-2) 
    return dateTimeString;
}

function convertVcVmToProperties(vm){
    var vmProps = {
        vimType: vm.vimType,
        overallCpuUsage: vm.overallCpuUsage,
        memory: vm.memory,
        vimId: vm.vimId,
        instanceId: vm.instanceId,
        hostMemoryUsage: vm.hostMemoryUsage,
        guestMemoryUsage: vm.guestMemoryUsage,
        vmToolsVersionStatus: vm.vmToolsVersionStatus,
        biosId: vm.biosId,
        productVendor: vm.productVendor,
        isTemplate: vm.isTemplate,
        vmToolsStatus: vm.vmToolsStatus,
        name: vm.name,
        displayName: vm.displayName,
        unsharedStorage: vm.unsharedStorage,
        id: vm.id,
        cpu: vm.cpu,
        connectionState: vm.connectionState,
        committedStorage: vm.committedStorage,
        hostName: vm.hostName,
        type: vm.type,
        sdkId: vm.sdkId,
        guestHeartbeatStatus: vm.guestHeartbeatStatus,
        overallStatus: vm.overallStatus,
        totalStorage: vm.totalStorage,
        guestOS: vm.guestOS,
        productFullVersion: vm.productFullVersion,
        configStatus: vm.configStatus,
        ipAddress: vm.ipAddress,
        annotation: vm.annotation,
        productName: vm.productName,
        state: vm.state,
        mem: vm.mem,
        memoryOverhead: vm.memoryOverhead,
        alarmActionsEnabled: vm.alarmActionsEnabled,
        vmVersion: vm.vmVersion
    }
    return vmProps
}
