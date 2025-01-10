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
        alarmActionsEnabled: vm.alarmActionsEnabled,
        annotation: vm.annotation,
        biosId: vm.biosId,
        committedStorage: vm.committedStorage,
        configStatus: vm.configStatus,
        connectionState: vm.connectionState,
        cpu: vm.cpu,
        displayName: vm.displayName,
        guestHeartbeatStatus: vm.guestHeartbeatStatus,
        guestMemoryUsage: vm.guestMemoryUsage,
        guestOS: vm.guestOS,
        hostMemoryUsage: vm.hostMemoryUsage,
        hostName: vm.hostName,
        id: vm.id,
        instanceId: vm.instanceId,
        ipAddress: vm.ipAddress,
        isTemplate: vm.isTemplate,
        mem: vm.mem,
        memory: vm.memory,
        memoryOverhead: vm.memoryOverhead,
        name: vm.name,
        overallCpuUsage: vm.overallCpuUsage,
        overallStatus: vm.overallStatus,
        productFullVersion: vm.productFullVersion,
        productName: vm.productName,
        productVendor: vm.productVendor,
        sdkId: vm.sdkId,
        state: vm.state,
        totalStorage: vm.totalStorage,
        type: vm.type,
        unsharedStorage: vm.unsharedStorage,
        vimId: vm.vimId,
        vimType: vm.vimType,
        vmToolsStatus: vm.vmToolsStatus,
        vmToolsVersionStatus: vm.vmToolsVersionStatus,
        vmVersion: vm.vmVersion,
        vmtoolsVersion: vm.config.tools.toolsVersion
    }
    return vmProps
}
