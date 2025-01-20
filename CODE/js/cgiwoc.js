$(document).ready(function() {
    $.ajaxSetup({
        cache: false
    });

    $("#Qry").focus();
    $("#Qry").on("keypress", function(event) {
        $me = $(this);
        var theKey = event.keyCode || event.which;
        if (theKey == 13) { //enter
            event.preventDefault();
            var cmd = $(this).val();
            var uri = "/cgi-bin/cgiwoc.pl?cmd=" + cmd;
            $("#response").load(encodeURI(uri),
                function(data) {
                    $("<dt>" + cmd + "</dt><dd>" + data + "</dd>").appendTo("#history dl");
                    $("#Qry").val("").focus();
                    $("#response").empty();
                    var h = $('#wmtarget', top.document).contents().height();
                    //$('#wmtarget',top.document).height($('#wmtarget',top.document).contents().height());
                    $('#wmtarget', top.document).height(h);
                    var w = $me.get(0).offsetTop;
                    $('html,body', top.document).animate({
                        scrollTop: w
                    }, 400);
                }
            );
            return false;
        }
        if (theKey == 38) { //up
            $("#Qry").val($("#history dt:last").get(0).innerHTML);
        }
    });
});