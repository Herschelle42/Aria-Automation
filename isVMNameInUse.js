/*
Checks to see if a vCenter Virtual Machine name is already in use. Returns true if name already in use.

Inputs:
[string]input

Output:
[boolean]
*/

//return false if nothing is passed in to prevent form errors.
if(input == undefined || input == null) {
    return false;
}

//Get all the vCenter VMs
var allvCenterVMs = VcPlugin.getAllVirtualMachines();

//Filter the VMs and return only vms with the same name
var found = allvCenterVMs.filter(function process(vm){
    //System.debug('vm name: ' + vm.name);
    return vm.name.toLowerCase() == input.toLowerCase();
});

//if 1 or more VMs found with the same name return true
if(found.length > 0) {
    //System.warn('VM name found');
    return true;
} else {
    return false;
}
