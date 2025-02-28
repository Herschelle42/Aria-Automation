/*
Get VC:VirtualMachine from the Uuid. for instance when using Extensibility subscriptions
*/
var vmUuid = inputProperties['externalIds'][0];
var vmUuid='2a92af15-d7fe-44f3-a867-dc7122a622af';

var vm = getVCVMbyUuid(vmUuid);
System.log('vm name: ' + vm.name);
System.log('vm moref: ' + vm.moref.value);
System.log('vm vimId: ' + vm.vimId);

function getVCVMbyUuid(vmId) {
    var vcList = VcPlugin.allSdkConnections;

    for each(var vc in vcList) {
        System.debug("VC SDK connection: " + vc.id);

        var si = vc.searchIndex;
        var vm = si.findByUuid(null, vmId, true, true);

        System.debug("VM by Instance UUID found: " + vm);
        return vm;

    }
}
