/* couple of example doing the same tihing */

function sortVMsByLabel(vmList) {
    return vmList.sort(function(a, b) {
        return a.label.toLowerCase().localeCompare(b.label.toLowerCase());
    });
}


function sortVMsByLabel(vmList) {
    return vmList.sort(function(a, b) {
        var labelA = a.label.toLowerCase();
        var labelB = b.label.toLowerCase();
        if (labelA < labelB) return -1;
        if (labelA > labelB) return 1;
        return 0;
    });
}
