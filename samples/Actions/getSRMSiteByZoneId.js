/*
Returns the association SRM Site of the vCenter the vRA Zone Id is assocaited with

Return type:   SRM:Site

Inputs:
[string]zoneId

*/
if(zoneId == undefined || zoneId == null ) {
    return null;
}

var cloudAccountId =  Server.findAllForType('VRA:Zone').filter(function process(zone) { return zone.id == zoneId })[0].cloudAccountId;
System.debug('cloudAccountId: ' + cloudAccountId);

var customProps = JSON.parse(Server.findAllForType('VRA:CloudAccount').filter(function process(account) { return account.id == cloudAccountId})[0].customPropertiesExtension);
var vcUuid = customProps.vcUuid;
var vcHostname = customProps.hostName;
System.debug('vcUuid: ' + vcUuid);
System.debug('vcHostname: ' + vcHostname);

var dunesId = vcUuid + '_com.vmware.vcDr';

return Server.findForType("SRM:Site", dunesId);
