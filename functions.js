/*
Random functions
*/
function getISODate(){
    var date = new Date();
    var dateTimeString = date.getFullYear() + '-' +
    ('0' + (date.getMonth()+1) 	).slice(-2) + '-' + 
    ('0' + 	date.getDate()		).slice(-2)
    return dateTimeString;
}


function getISODateTime(){
    var date = new Date();
    var dateTimeString = date.getFullYear() + '-' +
    ('0' + (date.getMonth()+1) 	).slice(-2) + '-' + 
    ('0' + 	date.getDate()		).slice(-2) + '-' + 
    ('0' + 	date.getHours()		).slice(-2) + '-' + 
    ('0' + 	date.getMinutes()	).slice(-2) + '-' + 
    ('0' + 	date.getSeconds()	).slice(-2) 
    return dateTimeString;
}
