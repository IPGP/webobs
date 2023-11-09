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
	// ux  ==  producer' html-table row id OR -1 for a new producer
	if (arguments.length <= 0 ) { return; } // noop if no ux
	var form = $('#overlay_form_producer')[0];
	if (ux != -1) { // editing an existing producer: populate popup from its table row TDs
		// ATT:  $("td",producer.ux)[n] = n (0-based) must match producers <td> order in def-row  
		form.id.value = $("td",ux)[2].textContent;
		form.OLDid.value = $("td",ux)[2].textContent;
		form.id.style.backgroundColor = "#EEEEEE";
		form.title.value = $("td",ux)[3].textContent;
		form.prodName.value = $("td",ux)[4].textContent;
		form.desc.value = $("td",ux)[5].textContent;
		form.objective.value = $("td",ux)[6].textContent;
		form.measVar.value = $("td",ux)[7].textContent;
		form.email.value = $("td",ux)[8].textContent;
		var count_contacts = $("td",ux)[9].textContent.split(',').length;
		if (count_contacts>1) {
			var emails = $("td",ux)[9].textContent.split(',');
			form.firstName.value = emails[0].split(' ')[2];
			form.lastName.value  = emails[0].split(' ')[3].slice(0, -1);
			form.emails.value    = emails[0].split(': ')[1];
			form.roles.value     = emails[0].split(' ').slice(0, 2).join(' ').slice(1, -1);
			for (var i = 0; i<count_contacts-1; i++) {
				addMgr();
				form.firstName[i+1].value = emails[i+1].split(' ')[3];
				form.lastName[i+1].value  = emails[i+1].split(' ')[4].slice(0, -1);
				form.emails[i+1].value    = emails[i+1].split(': ')[1];
				form.roles[i+1].value     = emails[i+1].split(' ').slice(1, 3).join(' ').slice(1, -1);
			}
		} else {
			form.firstName.value = $("td",ux)[9].textContent.split(' ')[2];
			form.lastName.value  = $("td",ux)[9].textContent.split(' ')[3].slice(0, -1);
			form.emails.value    = $("td",ux)[9].textContent.split(': ')[1];
			form.roles.value     = $("td",ux)[9].textContent.split(' ').slice(0, 2).join(' ').slice(1, -1);
		}
		var count_funders = $("td",ux)[10].textContent.split(',').length;
		if (count_funders>1) {
			var funders = $("td",ux)[10].textContent.split(', ');
			form.typeFunders.value = funders[0].split(':')[0];
			form.nameFunders.value = funders[0].split(': ')[1].split('(')[0];
			form.acronyms.value    = funders[0].split('(')[1].split(')')[0];
			form.scanR.value       = funders[0].split('/ ')[1];
			for (var i = 0; i<count_funders-1; i++) {
				addFnd();
				form.typeFunders[i+1].value = funders[i+1].split(':')[0];
				form.nameFunders[i+1].value = funders[i+1].split(': ')[1].split('(')[0];
				form.acronyms[i+1].value    = funders[i+1].split('(')[1].split(')')[0];
				form.scanR[i+1].value       = funders[i+1].split('/ ')[1];
			}
		} else {
			form.typeFunders.value = $("td",ux)[10].textContent.split(' ')[2];
			form.nameFunders.value = $("td",ux)[10].textContent.split(' ')[3].slice(0, -1);
			form.acronyms.value    = $("td",ux)[10].textContent.split(': ')[1];
			form.scanR.value       = $("td",ux)[10].textContent.split(' ').slice(0, 2).join(' ').slice(1, -1);
		}
		var count_res = $("td",ux)[11].textContent.split('_,').length;
		if (count_res>1) {
			var res = $("td",ux)[11].textContent.split('_,');
			form.typeRes.value = res[0].split('@')[0]+'@';
			form.nameRes.value = res[0].split('@')[1];
			for (var i = 0; i<count_res-1; i++) {
				addRes();
				form.typeRes[i+1].value = res[i+1].split('@')[0]+'@';
				form.nameRes[i+1].value = res[i+1].split('@')[1];

			}
		} else {
			form.typeRes.value = $("td",ux)[11].textContent.split('@')[0]+'@';
			form.nameRes.value = $("td",ux)[11].textContent.split('@')[1];
		}
		var listgrids = $("td",ux)[12].textContent.split(',');
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
	
	// concatening the contacts and funders data into one variable
	var contacts = [];
	if (form.count_mgr.value > 1) {
		for (let i = 0; i <= form.count_mgr.value-1; i++){
			contacts.push('('+form.roles[i].value+') '+form.firstName[i].value+' '+form.lastName[i].value+': '+form.emails[i].value);
		} form.contacts.value = contacts;
	} else { form.contacts.value = '('+form.roles.value+') '+form.firstName.value+' '+form.lastName.value+': '+form.emails.value }
	
	var funders = [];
	if (form.count_fnd.value > 1) {
		var types = [];
		var scanR = [];
		var names = [];
		var acronyms = [];
		for (let i = 0; i <= form.count_fnd.value-1; i++){
			types.push(form.typeFunders[i].value);
			scanR.push(form.scanR[i].value);
			names.push(form.nameFunders[i].value);
			acronyms.push(form.acronyms[i].value);
		} form.funders.value = types.join('_,') + '|' + scanR.join('_,') + '|' + names.join('_,') + '|' + acronyms.join('_,'); 
	} else { form.funders.value = form.typeFunders.value + '|' + form.scanR.value + '|' + form.nameFunders.value + '|' + form.acronyms.value; }
	if (form.count_fnd.value > 1) {
		for (let i = 0; i <= form.count_fnd.value-1; i++){
			funders.push(form.typeFunders[i].value+': '+form.nameFunders[i].value+' ('+form.acronyms[i].value+') / '+form.scanR[i].value);
		} form.funders.value = funders;
	} else { form.funders.value = form.typeFunders.value+': '+form.nameFunders.value+' ('+form.acronyms.value+') / '+form.scanR.value }
	console.log(form.funders);
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


