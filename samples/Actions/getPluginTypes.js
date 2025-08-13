/*
.INPUT
  [string]searchString
.RETURN TYPE
  [array]string

TODO: add case insentive matching option
*/

var allPluginTypeList = Server.getAllPluginTypes();

if(searchString == undefined || searchString == null) {
    return allPluginTypeList
} else {
    var matches = [];

    for each(var type in allPluginTypeList) {
        if(type.indexOf(searchString) !== -1) {
            matches.push(type);
        }
    }

    return matches;
}
