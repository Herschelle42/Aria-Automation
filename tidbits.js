//Get an objects class and type
System.log('Class: ' + System.getObjectClassName(thisObject));
System.log('Type:  ' + System.getObjectType(thisObject));

//--- split a block of text, for example a list of items like server names, into an array to be processed.
//var textArray = keylist.split('\n');
var textList = textBlock.split('\n');
//now removing any empty lines
myArray = textList.filter(function(item) {
    if(item != undefined && item != null && item.length > 0)
    {
        return item;
    }
});


//--- Create a resource element
var resourcePath = 'zDev/example'

//create a resource name with date and time
//e.g. log 2024-05-14-19-55-38
var date = new Date();
var dateTimeString = date.getFullYear() + '-' +
('0' + (date.getMonth()+1) 	).slice(-2) + '-' + 
('0' + 	date.getDate()		).slice(-2) + '-' + 
('0' + 	date.getHours()		).slice(-2) + '-' + 
('0' + 	date.getMinutes()	).slice(-2) + '-' + 
('0' + 	date.getSeconds()	).slice(-2) 
var resourceName = 'log ' + dateTimeString;

var myProps = new Properties();
myProps['level1'] = {};
myProps['level1'] ['thiskey'] = 'thisValue';

/*
takes a path or resourceCategory as the first input. If the path does not exist it will be created.
If the resourceName already exists it will result in a terminating error.
*/
var resourceElement = Server.createResourceElement(resourcePath, resourceName, null);

var mimeAttachment = new MimeAttachment();
//mimeAttachment.content = Server.toStringRepresentation(prop).stringValue;
//mimeAttachment.content = inputString;
mimeAttachment.content = JSON.stringify(myProps);
mimeAttachment.mimeType = "text/plain";
mimeAttachment.name = resourceElement.name;
resourceElement.setContentFromMimeAttachment(mimeAttachment);

//EBS report event topic and type when the workflow is running
System.warn('eventTopicId: ' + System.getContext().getParameter("__metadata_eventTopicId"));
System.warn('targetType:   ' + System.getContext().getParameter("__metadata_targetType"));


/*WF Dump Properties*/
//Displays the eventTopic this WF is running at
System.warn('eventTopidId: ' + System.getContext().getParameter("__metadata_eventTopicId"));
System.warn('targetType:   ' + System.getContext().getParameter("__metadata_targetType"));

System.log("inputProperties:");
System.log(JSON.stringify(inputProperties, null, 2));

System.log("Parameters:");
var parameterNames = System.getContext().parameterNames();
for each ( var parameter in parameterNames) {
    System.log("   " + parameter + " : " + System.getContext().getParameter(parameter));
}

//The default vRA Host in vRO (restHost?)
VraHostManager.defaultHostData

//Convert a VRA:project Object to a Properties object
var project = {
  name: vraProject.name,
  id: vraProject.id,
  updatedAt: vraProject.updatedAt,
  owner: vraProject.owner,
  orgId: vraProject.orgId,
  createdAt: vraProject.createdAt,
  operationTimeout: vraProject.operationTimeout,
  placementPolicy: vraProject.placementPolicy,
  description: vraProject.description,
  internalIdString: vraProject.internalIdString,
  sharedResources: vraProject.sharedResources,
  machineNamingTemplate: vraProject.machineNamingTemplate,

  customPropertiesExtension: JSON.parse(vraProject.customPropertiesExtension),
  administratorsExtension: JSON.parse(vraProject.administratorsExtension),
  viewersExtension: JSON.parse(vraProject.viewersExtension),
  memberExtension: JSON.parse(vraProject.memberExtension),
  zonesExtension: JSON.parse(vraProject.zonesExtension),
  constraintsExtension: JSON.parse(vraProject.constraintsExtension),
  linksExtension: JSON.parse(vraProject.linksExtension)
}

//Search for a workflow by name and report it's id.
var workflowList = Server.query("Workflow", "name='My workflow'"); 

for each (var wf in workflowList) {
  System.log(wf.id);
}

//iterate a Properties object
for each(var key in customProperties.keys) {
    System.log(key + ' : ' + customProperties[key]);
}

//add or update an item in a Properties object
body.customProperties.test4 = 'value4';

//dynamically update a properties object key
body.customProperties[key] = customProperties[key];

//remove an item by setting the value to null
body.customProperties.test2 = null;
