/*
Returns vSphere Replication site associated with the vCenter that the Zone Id is a member of.

Return type:  VR:Site
Inputs
[strong]input (Zone Id)

*/

if(input == undefined || input == null ) {
    return null;
}

/*
var dunesId = 'YyV_ul4FSHW4Z2dkll4r2A,Zone:' + input;
return Server.findForType('VRA:Zone', dunesId);
*/

/* for seome reason I get 2 objects back, but they have different dunesId prefixes. 
At the end of the day it doesn't matter just need the CloudAccountId*/
var cloudAccountId =  Server.findAllForType('VRA:Zone').filter(function process(zone) { return zone.id == input })[0].cloudAccountId;
System.debug('cloudAccountId: ' + cloudAccountId);

//again get 2 objects returned.
var customProps = JSON.parse(Server.findAllForType('VRA:CloudAccount').filter(function process(account) { return account.id == cloudAccountId})[0].customPropertiesExtension);
var vcUuid = customProps.vcUuid;
var vcHostname = customProps.hostName;
System.debug('vcUuid: ' + vcUuid);
System.debug('vcHostname: ' + vcHostname);

return Server.findForType("VR:Site", vcHostname);
