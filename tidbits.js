
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

