
function lz(n) { return (n<10) ? "0"+n : n; }

function set_wodp(days, months, holidays, min, max) {
    $('input#gdate').wodp({
        icon: true,
        range: {from: min, to: max},
        days: days,
        months: months,
        holidays: holidays,
        onpicked: function(i) { if ($('input#gdate').data('wodpdesc') != "ranging") submitform($('input#gdate').data('wodpdesc')); },
    });
    $('select#gview').on('change', function() {
        submitform($('input#gdate').data('wodpdesc'));
    });
    $('select#gcategory').on('change', function() {
        submitform($('input#gdate').data('wodpdesc'));
    });
    $('input#gfilter').on('change', function() {
        submitform($('input#gdate').data('wodpdesc'));
    });
    $('input#gdate').on('change', function() {
        if ($('input#gdate').data('wodpdesc') != "ranging" && $('input#gdate').data('wodp').inrange()) {
            submitform($('input#gdate').data('wodpdesc'));
        }
    });
}

function showtip(event,title,text,color) {
    $("#gzt-tip" ).remove();
    var box = '<div class="gzt-tip" id="gzt-tip"><div class="gzt-tiptitle" style="background:'+color+'">'+title+'</div><div class="gzt-tiptext">'+text+'</div></div>';
    $(box).appendTo($('body'));
    var vH = window.parent.innerHeight-$('#wm',window.parent.document).outerHeight();
    var vW = window.parent.innerWidth;
    var tipH = $('#gzt-tip').outerHeight();
    var tipW = $('#gzt-tip').outerWidth();
    $("#gzt-tip").css({'top': event.pageY+10, 'left': event.pageX+10});
    if (event.pageY+tipH+10>vH) $("#gzt-tip").css({'top': event.pageY-tipH-10});
    if (event.pageX+tipW+10>vW) $("#gzt-tip").css({'left': event.pageX-tipW-10});
}

function showobject(objname) {
    if (typeof objname === 'undefined') return false;
    var objel = objname.split(".");
    if (typeof objel[2] === 'undefined') {
        location.href="/cgi-bin/showGRID.pl?grid="+objname+'#EVENTS';
    } else {
        location.href="/cgi-bin/showNODE.pl?node="+objname+'#EVENTS';
    }
}

function hidetip() {
    $("#gzt-tip" ).remove();
}

function submitform(dtype) {
    $('form#gztform').append('<input type=\"text\" name=\"wodpdesc\" hidden value=\"'+dtype+'\" />');
    $('form#gztform').submit();
}

function shortcuts(shortcut, inputel) {
    // inputel must be a dom input tag with a wodp attached
    if ( typeof $(inputel).data('wodp') === 'undefined') return false;
    var d0 = new Date(); // today
    var d1 = 0;
    switch (shortcut) {
        case "today" :
            break;
        case "tomorrow" :
            d0.setDate(d0.getDate()+1);
            break;
        case "yesterday" :
            d0.setDate(d0.getDate()-1);
            break;
        case "allyear" :
            d0 = new Date(d0.getFullYear(),0,1);
            d1 = new Date(d0.getFullYear(),11,31);
            break;
        case "all" :
            d0 = $(inputel).data('wodp').from;
            d1 = $(inputel).data('wodp').to;
            break;
        case "toEnd" :
            d1 = $(inputel).data('wodp').to;
            break;
        case "fromStart" :
            d1 = d0;
            d0 = $(inputel).data('wodp').from;
            break;
        case "currWeek" :
            d0 = new Date(d0.toDateString()); //same at 00:00:00
            d0.setDate(d0.getDate() - (d0.getDay() + 6) % 7);
            d1 = new Date(); d1.setDate(d0.getDate() + 6 - (d0.getDay() + 6) % 7);
            break;
        default:
    }
    var ds = d0.getFullYear()+'-'+lz((d0.getMonth()+1))+'-'+lz(d0.getDate());
    if (d1 != 0) {ds += ','+d1.getFullYear()+'-'+lz((d1.getMonth()+1))+'-'+lz(d1.getDate()) }
    $(inputel).val(ds).trigger('change');
    return true;
}

function openPopup(el,id) {
    var form = $('#overlay_form_article')[0];
    $('input[type!="button"],select',form).each(function() { $(this).css('background-color','transparent')});
    $("#overlay_form_article #delbutton").remove();
    // id  ==  article's ID or -1 for creating a new article
    if (arguments.length < 2 ) { return; } // noop if no (el,id)
    // initialize the users' dropdown list with 'valid' users
    $("#overlay_form_article #UID").empty();
    $.each(gazette_usrV, function(val,text) {$('#overlay_form_article #UID').append( $('<option></option>').val(val).html(text) ) });
    if (id != -1) { // editing an existing article 'id': populate form fields first
        $.get("/cgi-bin/Gazette.pl", { "getid": id }, function(d) {
            form.setid.value = d.ID;
            form.STARTDATE.value = d.STARTDATE;
            form.STARTTIME.value = d.STARTTIME;
            form.ENDDATE.value = d.ENDDATE;
            form.ENDTIME.value = d.ENDTIME;
            form.OTHERS.innerHTML =  d.OTHERS; form.OTHERS.value = form.OTHERS.innerHTML;
            form.PLACE.innerHTML = d.PLACE; form.PLACE.value = form.PLACE.innerHTML;
            form.SUBJECT.innerHTML = d.SUBJECT; form.SUBJECT.value = form.SUBJECT.innerHTML;
            $("option",form.CATEGORY).prop("selected", false);
            $('option[value='+d.CATEGORY+']',form.CATEGORY).prop("selected",true);
            $.each(gazette_usrI, function(val,text) {$('#overlay_form_article #UID').append( $('<option></option>').val(val).html("<i>"+text+"</i>") ) });
            $("option",form.UID).prop("selected", false);
            //d.UID.split('+').forEach(function(item) { $('option[value='+item+']',form.UID).prop("selected",true)});
            d.UID.split('+').forEach(function(item) { $('option[value="'+item+'"]',form.UID).prop("selected",true)});
            $('#overlay_form_article #UID option:selected').prependTo('#overlay_form_article #UID'); //move all selected to top of list
        });
        $('#overlay_form_article #sendbutton').before('<input type="button" id="delbutton" style="margin-right: 40px;" value="'+gazette_remove_text+'" onclick="delPopup('+id+'); return false;">');
    } else { // creating a new article
        $('input[type!="button"],select',form).each(function() { $(this).val(""); });
        var today = new Date();
        form.STARTDATE.value = today.getFullYear()+'-'+lz(today.getMonth()+1)+'-'+lz(today.getDate());
        form.ENDDATE.value = form.STARTDATE.value;
        form.setid.value = '-1';
        $("#formTitle").html(gazette_create_text);
    }
    $('#overlay_form_article input#STARTDATE').wodp({
        icon: true ,
        onpicked: function() {
            wodpin = $('#overlay_form_article input#STARTDATE').val();
            d=wodpin.split(',');
            $('#overlay_form_article input#STARTDATE').val(d[0]);
            // when wodp range and enddate not defined yet, make enddate = end of wodp range
            if ($('#overlay_form_article input#ENDDATE').val() == '' && typeof d[1] !== 'undefined' ) {
                $('#overlay_form_article input#ENDDATE').val(d[1]);
            }
        },
    });
    $('#overlay_form_article input#ENDDATE').wodp({
        icon: true ,
        onpicked: function() {
            wodpin = $('#overlay_form_article input#ENDDATE').val();
            d=wodpin.split(',');
            $('#overlay_form_article input#ENDDATE').val(d[0]);
        },
    });
    $('#overlay_form_article[name=sendbutton]').attr('onclick',"sendPopup(); return false");
    $("#overlay_form_article").fadeIn(500);
    positionPopup(el);
    form.STARTDATE.focus();
}

function sendPopup() {
    if (!validPopup()) return false;
    var form = $('#overlay_form_article')[0];
    closePopup();
    // form.UID is a select multiple, appearing as multiple UID=value in serialized form
    // make it appear as a single UID=value+value+...
    var f0 = $( "#overlay_form_article" ).serialize().split("&"); var f1 = [];
    var uids = "";
    for (var i=0;i<f0.length;i++) {
        if (f0[i].match(/^UID=/i)) { uids += "%2B"+(f0[i].replace(/UID=/,"")); }
        else { f1.push(f0[i]); }
    };
    uids = uids.replace(/^%2B/,"");
    // rebuilt location.search, omitting non-display key=val  and using modified uid=
    // todo: use location.search OR current display as requested via submitform ?
    var l0 = location.search.split("&"); var l1 = [] ;
    for (var i=0;i<l0.length;i++) { if (l0[i].match(/gview|gdate|gcategory|gfilter|wodpdesc/)) l1.push(l0[i]); }
    location.href = "/cgi-bin/Gazette.pl?"+(f1.join("&"))+"&UID="+uids+"&"+(l1.join("&"));
}

function delPopup(id) {
    if (!confirm("Do you really want to remove this article ?")) return false;
    closePopup();
    // rebuilt location.search, omitting non-display key=val
    // todo: use location.search OR current display as requested via submitform ?
    var l0 = location.search.split("&"); var l1 = [] ;
    for (var i=0;i<l0.length;i++) { if (l0[i].match(/gview|gdate|gcategory|gfilter|wodpdesc/)) l1.push(l0[i]); }
    location.href = "/cgi-bin/Gazette.pl?delid="+id+"&"+(l1.join("&"));
}

function validPopup() {
    var form = $('#overlay_form_article')[0];
    var bad = false;
    $('input[type!="button"],select',form).each(function() { $(this).css('background-color','transparent')});
    if (!form.STARTDATE.value.match(/^\d{4}-[0-1]\d-[0-3]\d$/)) {bad=true; form.STARTDATE.style.background='red';}
    if (form.ENDDATE.value != "") {
        if (!form.ENDDATE.value.match(/^\d{4}-[0-1]\d-[0-3]\d$/)) {bad=true; form.ENDDATE.style.background='red';}
        if (form.ENDDATE.value < form.STARTDATE.value) {bad=true; form.ENDDATE.style.background='red';}
    }
    if (form.UID.value == "") {bad=true; form.UID.style.background='red';}
    if (form.CATEGORY.value == "") {bad=true; form.CATEGORY.style.background='red';}
    if (bad) return false;
    return true;
}

function closePopup() {
    $(".overlay_form").fadeOut(500);
    $("#ovly").fadeOut(500);
}

function positionPopup(el){
    $("#ovly").css('display','block');
    $(".overlay_form").css({
        position: 'absolute',
        left: "50%",
        top: 0,
        transform: "translate(-50%)"
    });
}
