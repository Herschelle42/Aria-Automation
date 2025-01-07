var resourcePath = "Custom";
var resourceName = 'deployments_' + getISODate() + '.json';

var resourceData = new MimeAttachment();
resourceData.content = JSON.stringify(actionResult, null, 2);
resourceData.mimeType = 'text/json';

var resourceElementCategory = Server.getResourceElementCategoryWithPath(resourcePath);

//--- option 1 ---------------------------------

//is this a new element
var isNew = true;
if(resourceElementCategory.allResourceElements.length > 0) {
    resourceElementCategory.allResourceElements.forEach(function process(element){
        System.log(element.name);
        if(element.name == resourceName) {
            System.debug('Updating exsiting element named: ' + resourceName);
            //if element already exists update it
            element.setContentFromMimeAttachment()
            isNew = false;
        }
    })
}

//if this is a new element then create it.
if(isNew) {
    System.debug('Creating new element named: ' + resourceName);
    Server.createResourceElement(resourcePath,resourceName,resourceData);
}

//--- option 2 -------------------------    alternatively could do this

//Test to see if the resource element of the same name already exists
resourceElement = resourceElementCategory.allResourceElements.filter(function(item){
    return item.name == resourceName;
})

//update existing element or create a new one
if(resourceElement.length == 1) {
    System.log('Updating exsiting element named: ' + resourceName);
    resourceElement[0].setContentFromMimeAttachment(resourceData);
} else {
    System.log('Creating new element named: ' + resourceName);
    Server.createResourceElement(resourcePath,resourceName,resourceData);
}

// --- functions --------------------------------
function getISODate(){
    var date = new Date();
    var dateTimeString = date.getFullYear() + '-' +
    ('0' + (date.getMonth()+1) 	).slice(-2) + '-' + 
    ('0' + 	date.getDate()		).slice(-2)
    return dateTimeString;
}
      
