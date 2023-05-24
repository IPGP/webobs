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
	// ux  ==  domain' html-table row id OR -1 for a new domain
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
	} else { // inserting a new domain
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

function openPopupProducer(ux) {
	// ux  ==  domain' html-table row id OR -1 for a new domain
	if (arguments.length <= 0 ) { return; } // noop if no ux
	var form = $('#overlay_form_producer')[0];
	if (ux != -1) { // editing an existing domain: populate popup from its table row TDs
		// ATT:  $("td",domain.ux)[n] = n (0-based) must match domains <td> order in def-row  
		console.log($("td",ux));
		form.id.value = $("td",ux)[2].textContent;
		form.OLDcode.value = $("td",ux)[2].textContent;
		form.id.style.backgroundColor = "#EEEEEE";
		form.title.value = $("td",ux)[3].textContent;
		form.prodName.value = $("td",ux)[4].textContent;
		form.desc.value = $("td",ux)[5].textContent;
		form.objective.value = $("td",ux)[6].textContent;
		form.measVar.value = $("td",ux)[7].textContent;
		form.email.value = $("td",ux)[8].textContent;
		form.contacts.value = $("td",ux)[9].textContent;
		form.funders.value = $("td",ux)[10].textContent;
		form.onlineRes.value = $("td",ux)[11].textContent;
		var listgrids = $("td",ux)[12].textContent.split(', ');
		$('#overlay_form_producer #grid option').each(function() { 
			$(this).removeProp('selected');
			if (jQuery.inArray( this.value, listgrids ) != -1) { $(this).prop('selected',true) }
		});
		$('label[for=gid]').css('display','block');
		$(form.gid).css('display','block');
		form.OLDgrid.value = $("td",ux)[6].textContent;
		form.action.value = "update";
	} else { // inserting a new domain
		form.id.value = "";
		form.id.readOnly = false;
		form.id.style.backgroundColor = "";
		form.prodName.value = "";
		form.title.value = "";
		form.desc.value = "";
		form.objective.value = "";
		form.measVar.value = "";
		form.email.value = "";
		form.contacts.value = "";
		form.funders.value = "";
		form.onlineRes.value = "";
		form.action.value = "insert";
	}
	form.tbl.value = "producer";
	$('#overlay_form_producer[name=sendbutton]').attr('onclick',"sendPopupUser(); return false");
	$("#overlay_form_producer").fadeIn(500);
	positionPopup();
	form.id.focus();
}

function sendPopupProducer() {
	var form = $('#overlay_form_producer')[0];
	
	// checking if mandatory fields are not empty
	if ( form.id.value == "" ) {
		alert ("id can't be empty");
		return false;
	}
	if ( form.prodName.value == "" ) {
		alert ("name can't be empty");
		return false;
	}
	if ( form.title.value == "" ) {
		alert ("title can't be empty");
		return false;
	}
	if ( form.desc.value == "" ) {
		alert ("desc can't be empty");
		return false;
	}
	if ( form.email.value == "" ) {
		alert ("email can't be empty");
		return false;
	}
	
	// preparing data for the integration in the database
	if (form.count_mgr.value == 0) {
		form.contacts.value = 'projectLeader:'+form.contacts.value+'|'+form.contacts.value;
	} else if (form.count_mgr.value > 0) {
		var contacts = ['projectLeader:'+form.contacts.value];
		var emails = [form.contacts.value];
		for (let i = 1; i <= form.count_mgr.value; i++) {
			var id = 'dataMgr'+i;
			contacts.push('dataManager:'+form.elements[id].value)
			emails.push(form.elements[id].value);
		} form.contacts.value = contacts.join('_,'); form.contacts.value = form.contacts.value + '|' + emails.join(','); 
	} 
	
	// preparing data for the integration in the database
	if (form.count_fnd.value == 1) {
		form.funders.value = form.typeFunders.value+form.scanR.value+'|'+form.nameFunders.value+'|'+form.scanR.value;
	} else if (form.count_fnd.value > 1) {
		var funders = [];
		var names = [];
		var scanR = [];
		for (let i = 0; i <= form.count_fnd.value-1; i++) {
			funders.push(form.typeFunders[i].value+form.scanR[i].value);
			names.push(form.nameFunders[i].value);
			scanR.push(form.scanR[i].value);
		} form.funders.value = funders.join('_,'); form.funders.value = form.funders.value +'|'+names.join(',')+'|'+scanR.join(',');
	} 
	
	if ( form.contacts.value == "" ) {
		alert ("contacts can't be empty");
		return false;
	} 
	if ( form.funders.value == "" ) {
		alert ("funders can't be empty");
		return false;
	}
	if ( form.grid.value == "" ) {
		alert ("grid can't be empty");
		return false;
	}
	
	// preparing data for the integration in the database
	if (form.count_res.value == 1) {
		if (form.nameRes.value == '') {form.onlineRes.value = ''}
		else {form.onlineRes.value = form.typeRes.value+form.nameRes.value}
	} else if (form.count_res.value > 1) {
	    var onlineRes = [];
	    var names = [];
	    var types = [];
	    for (let i = 0; i <= form.count_res.value-1; i++) {
		    onlineRes.push(form.typeRes[i].value+form.nameRes[i].value);
		    names.push(form.nameRes[i].value);
		    types.push(form.typeRes[i].value);
	    } form.onlineRes.value = onlineRes.join('_,');
	} 
	
	// return false;
	$("#overlay_form_producer").fadeOut(500);
	$("#ovly").fadeOut(500);
	if (Gscriptname == "") { Gscriptname = "/cgi-bin/gridsMgr.pl"; }
	location.href = Gscriptname+"?"+$("#overlay_form_producer").serialize()+"\#IDENT";
}


function postDeleteProducer(ux) {
	//console.log($("td", ux));
	//return false;
	var did =  $("td",ux)[2].textContent;
	var name =  $("td",ux)[3].textContent;
	var answer = confirm("do you really want to delete producer " + did + " (" + name + ") ? All associated grids will remain but hidden from grid tables.")
	if (answer) {
		did = did.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/gridsMgr.pl"; }
		location.href = Gscriptname+"?action=delete&tbl=producer&id="+did+"\#IDENT"
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

