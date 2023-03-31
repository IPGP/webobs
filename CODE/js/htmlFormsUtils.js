
$.fn.extend({ formChanges: function() {
	$(":input",this).change(function() {
		$(this.form).data("changed", true);
	});
}
,
	hasChanged: function() { 
		return this.data("changed"); 
	}
});
					
function scrolldivHeight() {
	var sh = parent.innerHeight - $('#wm',window.parent.document).height() - parseInt($('body').css('marginTop'), 10);
	$('#scrolldiv').height(sh);
}

function SelectMoveRows(SS1,SS2) 
{
    var SelID='';
    var SelText='';
    // Move rows from SS1 to SS2 from bottom to top
    for (i=SS1.options.length - 1; i>=0; i--) {
        if (SS1.options[i].selected == true) {
            SelID=SS1.options[i].value;
            SelText=SS1.options[i].text;
            var newRow = new Option(SelText,SelID);
            SS2.options[SS2.length]=newRow;
            SS1.options[i]=null;
        }
    }
    SelectSort(SS2);
}

function SelectSort(SelList)
{
    var ID='';
    var Text='';
    for (x=0; x < SelList.length - 1; x++) {
        for (y=x + 1; y < SelList.length; y++) {
            if (SelList[x].text > SelList[y].text) {
                // Swap rows
                ID=SelList[x].value;
                Text=SelList[x].text;
                SelList[x].value=SelList[y].value;
                SelList[x].text=SelList[y].text;
                SelList[y].value=ID;
                SelList[y].text=Text;
            }
        }
    }
}

function SelectRows(fromSelectTDs, toTextArea)
{
	var s = "";
	$("input."+fromSelectTDs+":checked").each(function(ix){
			var v = ($(this))[0].nextSibling.search.replace(/.*\?grid=/, '');
			s += "+" + v 
		});
	toTextArea.value = s;
}

function SelectAllRows(fromSelectTDs, tag, toTextArea)
{
	if (toTextArea.value == tag) {
		toTextArea.value = "";
		$("input."+fromSelectTDs).attr('checked', false);
	} else {
		toTextArea.value = tag;
		$("input."+fromSelectTDs).attr('checked', true);
	}
}

function CLBshowhide() 
{
	$('.CLBshowhide').toggle();
}

function geditopenPopup() {
	$("#geditoverlay_form").fadeIn(500);
	geditpositionPopup();
}

function geditpositionPopup(){
	$("#geditovly").css('display','block');
	$("#geditoverlay_form").css({
		left: (($(window).width() - $('#geditoverlay_form').outerWidth()) / 2)+$(window).scrollLeft() + "px",
		position:'fixed'
	});
}

function geditsendPopup() {
	if ( $('#geditoverlay_form')[0].geditN.value == "" ) {
		alert('Please specify a grid name') ;
		return false;
	}
	var gtype = $('#geditoverlay_form')[0].geditT.value;
	var gname = $('#geditoverlay_form')[0].geditN.value;
	if ( gname.match(/^[A-Za-z]/) && !gname.match(/[^A-Za-z_0-9]/g) ) {
		var tt = gtype.split(".");
		$("#geditoverlay_form").fadeOut(500);
		$("#geditovly").fadeOut(500);
		location.href = "/cgi-bin/formGRID.pl?grid=" + tt[0] + "." + gname.toUpperCase() + "&type=" + gtype;
	} else {
		alert('Grid name is alphanumerical and underscore characters only, case insensitive, and the first character must be a letter.');
		return false;
	}
	//FBwas: if ( gname.match(/PROC\./i) || gname.match(/VIEW\./i) ) {
	//FBwas:	$("#geditoverlay_form").fadeOut(500);
	//FBwas:	$("#geditovly").fadeOut(500);
	//FBwas:	location.href = "/cgi-bin/formGRID.pl?grid="+gname;
	//FBwas: } else {
	//FBwas:	alert('Grid name must be VIEW.name or PROC.name');
	//FBwas:	return false;
	//FBwas: }
}

function geditclosePopup() {
	$("#geditoverlay_form").fadeOut(500);
	$("#geditovly").fadeOut(500);
}

function srchopenPopup(g) {
	if (arguments.length <= 0 ) { return; } // noop if no argument
	$('#srchoverlay_form')[0].grid.value = g;
	$("#srchoverlay_form").fadeIn(500);
	srchpositionPopup();
}

function srchpositionPopup(){
	$("#srchovly").css('display','block');
	$("#srchoverlay_form").css({
		left: (($(window).width() - $('#srchoverlay_form').outerWidth()) / 2)+$(window).scrollLeft() + "px",
		position:'fixed'
	});
	gl = $("#srchoverlay_form")[0].grid.value.length;
	$("#srchoverlay_form input#grid").attr('size',Math.min(15,gl));
	if (gl > 15) {
		$("#srchoverlay_form input#grid")[0].nextSibling.textContent='...} for:'
	}
}

function srchsendPopup() {
	if ( $('#srchoverlay_form')[0].searchW.value == "" ) {
		alert('Enter string/expression to be searched for');
		return false;
	}
	$("#srchoverlay_form").fadeOut(500);
	$("#srchovly").fadeOut(500);
	//alert($("#srchoverlay_form").serialize());
	location.href = "/cgi-bin/nsearch.pl?"+$("#srchoverlay_form").serialize();
}

function srchclosePopup() {
	$("#srchoverlay_form").fadeOut(500);
	$("#srchovly").fadeOut(500);
}

function toggledrawer(d) { 
	$(d).toggle(); 
}

function delEvent(vedit,obj,evt) {
	if (confirm('confirm delete '+evt+' ?')) {
		$.get(vedit+'?'+jQuery.param({ object:obj, event:evt, action:'del' }), function(data) {
			alert($("<div/>").html(data).text());
			location.reload();
		});
	}
}

// Data producer form

function addMgr () {
	let form_producer = document.getElementById("overlay_form_producer");
	var new_div = document.createElement('div');
    form_producer.elements['mgr'].value = parseInt(form_producer.elements['mgr'].value)+1;
    var div_mgr = document.getElementById('div_mgr');
    new_div.innerHTML = "<label>Contact:<span class='small'>Data manager</span></label><input type='text' name='dataManager' value=''/><br/><br/>";
    new_div.id = 'dataMgr';
    div_mgr.append(new_div);
}

function removeMgr() {
	let form_producer = document.getElementById("overlay_form_producer");
	if (document.getElementById('dataMgr') === null) {
		return false;
	}
	if (form_producer.elements['mgr'].value > 0) {
		document.getElementById('dataMgr').remove();
		form_producer.elements['mgr'].value -= 1;
	}
}

function addFnd () {
	let form_producer = document.getElementById("overlay_form_producer");
    form_producer.elements['count_fnd'].value = parseInt(form_producer.elements['count_fnd'].value)+1;
    var div_fnd = document.getElementById('div_fnd');
    var div_fnd_2 = document.getElementById('div_fnd_2');
    var new_div = document.createElement('div');
    new_div.id = 'new_fnd';
    new_div.innerHTML = div_fnd.innerHTML;
    div_fnd_2.append(new_div);
}

function removeFnd() {
	let form_producer = document.getElementById("overlay_form_producer");
	if (document.getElementById('new_fnd') === null) {
		return false;
	}
	if (form_producer.elements['count_fnd'].value > 1) {
		document.getElementById('new_fnd').remove();
		form_producer.elements['count_fnd'].value -= 1;
	}
}

function addRes () {
	let form_producer = document.getElementById("overlay_form_producer");
    form_producer.elements['res'].value = parseInt(form_producer.elements['res'].value)+1;
    var div_res = document.getElementById('div_res');
    var div_res_2 = document.getElementById('div_res_2');
    var new_div = document.createElement('div');
    new_div.id = 'new_res';
    new_div.innerHTML = div_res.innerHTML;
    div_res_2.append(new_div);
}

function removeRes() {
	let form_producer = document.getElementById("overlay_form_producer");
	if (document.getElementById('new_res') === null) {
		return false;
	}
	if (form_producer.elements['res'].value > 1) {
		document.getElementById('new_res').remove();
		form_producer.elements['res'].value -= 1;
	}
}
