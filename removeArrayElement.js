//rmeove a single element from an array
function removeArrayElement(array, element) {
    return array.filter(function (item) {
        return item != element;
    });
}
