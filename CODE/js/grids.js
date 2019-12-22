$(document).ready(function(){
});

// ATT: the global javascript variable 'Gscriptname' MUST HAVE BEEN defined/set
// at page-build time (it is a self-reference to the script that built the page)

function UidGidExists(id) {
	var q1 = $("div.ddomains:contains("+id+")");
	var q2 = $("div.dugrps:contains("+id+")");
	if (q1.length > 0 || q2.length > 0) { return true }
	return false;
}

function positionPopup(){
	$("#ovly").css('display','block');
	$(".overlay_form").css({
		left: (($(window).width() - $('.overlay_form').outerWidth()) / 2)+$(window).scrollLeft() + "px",
	});
}
function openPopupDomain(ux) {
	// ux  ==  domain' html-table row id OR -1 for a new user
	if (arguments.length <= 0 ) { return; } // noop if no ux
	var form = $('#overlay_form_domain')[0];
	if (ux != -1) { // editing an existing domain: populate popup from its table row TDs
		// ATT:  $("td",domain.ux)[n] = n (0-based) must match domains <td> order in def-row  
		form.code.value = $("td",ux)[2].textContent;
		form.OLDcode.value = $("td",ux)[2].textContent;
		form.code.style.backgroundColor = "#EEEEEE";
		form.ooa.value = $("td",ux)[3].textContent;
		form.name.value = $("td",ux)[4].textContent;
		form.marker.value = $("td",ux)[5].textContent;
		var listgrids = $("td",ux)[6].textContent.split(', ');
		$('#overlay_form_domain #grid option').each(function() { 
			$(this).removeProp('selected');
			if (jQuery.inArray( this.value, listgrids ) != -1) { $(this).prop('selected',true) }
		});
		$('label[for=gid]').css('display','block');
		$(form.gid).css('display','block');
		form.OLDgrid.value = $("td",ux)[6].textContent;
		form.action.value = "update";
	} else { // inserting a new user
		form.code.value = "";
		form.code.readOnly = false;
		form.code.style.backgroundColor = "";
		form.ooa.value = "";
		form.name.value = "";
		form.marker.value = "";
		form.action.value = "insert";
	}
	form.tbl.value = "domain";
	$('#overlay_form_domain[name=sendbutton]').attr('onclick',"sendPopupUser(); return false");
	$("#overlay_form_domain").fadeIn(500);
	positionPopup();
	form.code.focus();
}

function sendPopupDomain() {
	var form = $('#overlay_form_domain')[0];
	if ( form.code.value == "" ) {
		alert ("code can't be empty");
		return false;
	}
	if ( form.name.value == "" ) {
		alert ("name can't be empty");
		return false;
	}
	if ( form.ooa.value == "" ) {
		alert ("rank can't be empty");
		return false;
	}
	$("#overlay_form_domain").fadeOut(500);
	$("#ovly").fadeOut(500);
	if (Gscriptname == "") { Gscriptname = "/cgi-bin/gridsMgr.pl"; }
	location.href = Gscriptname+"?"+$("#overlay_form_domain").serialize()+"\#IDENT";
}


function postDeleteDomain(ux) {
	var did =  $("td",ux)[2].textContent;
	var name =  $("td",ux)[4].textContent;
	var answer = confirm("do you really want to delete domain " + did + " (" + name + ") ? All associated grids will remain but hidden from grid tables.")
	if (answer) {
		did = did.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/gridsMgr.pl"; }
		location.href = Gscriptname+"?action=delete&tbl=domain&code="+did+"\#IDENT"
	}
}


function closePopup() {
	$(".overlay_form").fadeOut(500);
	$("#ovly").fadeOut(500);
}

//---   $("form").serialize() 
//$("td",job.jid).each(function() { 
//	console.log(this.textContent) ;
//});
