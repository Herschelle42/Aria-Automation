/*
When running a catalog item get the execution context variables
*/
var ec = System.getContext();
var ecProps = new Properties();
for each (var paramName in ec.parameterNames().sort()) {
    ecProps.put(paramName, ec.getParameter(paramName));
}
System.log('ec props: ' + JSON.stringify(ecProps, null, 2));
