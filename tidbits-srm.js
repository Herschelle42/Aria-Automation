//create array of srm site properties.
var srmSites = new Array();
Server.findAllForType("SRM:Site", "").forEach(function(site) {
    var props = {
        name: site.name,
        deploymentId: site.deploymentId
    }
    srmSites.push(props);
});

