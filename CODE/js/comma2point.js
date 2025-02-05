$(document).ready(function() {
    $('input.inputNum').change(comma2point).keyup(comma2point);
});

function comma2point() {
    $(this).val($(this).val().replace(",", "."));
}