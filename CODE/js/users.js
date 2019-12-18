$(document).ready(function(){
});

// ATT: the global javascript variable 'Gscriptname' MUST HAVE BEEN defined/set
// at page-build time (it is a self-reference to the script that built the page)

function UidGidExists(id) {
	var q1 = $("div.dusers:contains("+id+")");
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
function openPopupUser(ux) {
	// ux  ==  users' html-table row id OR -1 for a new user
	if (arguments.length <= 0 ) { return; } // noop if no ux
	var form = $('#overlay_form_user')[0];
	if (ux != -1) { // editing an existing user: populate popup from its table row TDs
		// ATT:  $("td",user.ux)[n] = n (0-based) must match users <td> order in def-row  
		form.uid.value = $("td",ux)[2].textContent;
		form.OLDuid.value = $("td",ux)[2].textContent;
		form.uid.style.backgroundColor = "#EEEEEE";
		form.fullname.value = $("td",ux)[3].textContent;
		form.login.value = $("td",ux)[4].textContent;
		form.email.value = $("td",ux)[5].textContent;
		form.valid.value = $("td",ux)[6].textContent;
		var listgids = $("td",ux)[7].textContent.split(',');
		$('#overlay_form_user #gid option').each(function() { 
			$(this).removeProp('selected');
			if (jQuery.inArray( this.value, listgids ) != -1) { $(this).prop('selected',true) }
		});
		$('label[for=gid]').css('display','block');
		$(form.gid).css('display','block');
		form.OLDgid.value = $("td",ux)[7].textContent;
		form.action.value = "update";
	} else { // inserting a new user
		form.uid.value = "";
		form.uid.readOnly = false;
		form.uid.style.backgroundColor = "";
		form.fullname.value = "";
		form.login.value = "";
		form.email.value = "";
		form.valid.value = "Y";
		form.action.value = "insert";
	}
	form.tbl.value = "user";
	$('#overlay_form_user[name=sendbutton]').attr('onclick',"sendPopupUser(); return false");
	$("#overlay_form_user").fadeIn(500);
	positionPopup();
	form.uid.focus();
}
function openPopupGroup(ux) {
	var form = $('#overlay_form_group')[0];
	// ux  ==  groups' html-table row id OR -1 for a new group/user
	if (arguments.length <= 0 ) { return; } // noop if no ux
	if (ux != -1) { // editing a group/user: populate popup from its table row TDs
		// ATT:  $("td",user.ux)[n] = n (0-based) must match users <td> order in def-row  
		form.gid.value = $("td",ux)[2].textContent;
		var listuids = $("td",ux)[3].textContent.split(',');
		$('#overlay_form_group #uid option').each(function() { 
			$(this).removeProp('selected');
			if (jQuery.inArray( this.value, listuids ) != -1) { $(this).prop('selected',true) }
		});
		$('label[for=uid]').css('display','block');
		$(form.uid).css('display','block');
		form.OLDgid.value = $("td",ux)[2].textContent;
		form.OLDuid.value = $("td",ux)[3].textContent;
		form.action.value = "updgrp";

	} else { // inserting a new group
		form.uid.value = "!";
		$('label[for=uid]').css('display','none');
		$(form.uid).css('display','none');
		form.gid.value = "";
		form.action.value = "insert";
	}
	form.tbl.value = "group";
	$('#overlay_form_group[name=sendbutton]').attr('onclick',"sendPopupGroup(); return false");
	$("#overlay_form_group").fadeIn(500);
	positionPopup();
	form.gid.focus();
}

function openPopupNotf(ux) {
	var form = $('#overlay_form_notf')[0];
	// ux  ==  notifications' html-table row id OR -1 for a new notif.
	if (arguments.length <= 0 ) { return; } // noop if no ux
	if (ux != -1) { 
		// ATT:  $("td",notf.ux)[n] = n (0-based) must match notifications <td> order in def-row  
		form.event.value = $("td",ux)[2].textContent;
		form.OLDevent.value = $("td",ux)[2].textContent;
		form.event.style.backgroundColor = "#EEEEEE";
		form.valid.value = $("td",ux)[3].textContent;
		form.uid.value = $("td",ux)[4].textContent;
		form.OLDuid.value = $("td",ux)[4].textContent;
		form.uid.style.backgroundColor = "#EEEEEE";
		form.mailsub.value = $("td",ux)[5].textContent;
		form.mailatt.value = $("td",ux)[6].textContent;
		form.act.value = $("td",ux)[7].textContent;
		form.OLDact.value = $("td",ux)[7].textContent;
		form.act.style.backgroundColor = "#EEEEEE";
		form.action.value = "update";
	} else { // inserting a new user
		form.event.value = "";
		form.event.style.backgroundColor = "";
		form.valid.value = "Y";
		form.uid.value = "";
		form.uid.style.backgroundColor = "";
		form.mailsub.value = "";
		form.mailatt.value = "";
		form.act.value = "";
		form.act.style.backgroundColor = "";
		form.action.value = "insert";
	}
	form.tbl.value = "notification";
	$('#overlay_form_notf[name=sendbutton]').attr('onclick',"sendPopupNotf(); return false");
	$("#overlay_form_notf").fadeIn(500);
	positionPopup();
	form.event.focus();
}

function openPopupAuth(tb,ux) {
	form = $('#overlay_form_auth')[0];
	if (arguments.length <= 0 ) { return; } // noop if no ux
	if (ux != -1) { 
		form.uid.value = $("td",ux)[2].textContent;
		form.OLDuid.value = $("td",ux)[2].textContent;
		form.uid.style.backgroundColor = "#EEEEEE";
		form.res.value = $("td",ux)[3].textContent;
		form.OLDres.value = $("td",ux)[3].textContent;
		form.res.style.backgroundColor = "#EEEEEE";
		form.auth.value = $("td",ux)[4].textContent;
		form.action.value = "update";
	} else { 
		form.uid.value = "";
		form.uid.style.backgroundColor = "";
		form.res.value = "";
		form.res.style.backgroundColor = "";
		form.auth.value = "";
		form.action.value = "insert";
	}
	form.tbl.value = tb;
	$('#overlay_form_auth[name=sendbutton]').attr('onclick',"sendPopupAuth(); return false");
	$("#overlay_form_auth").fadeIn(500);
	positionPopup();
	form.uid.focus();
}

function sendPopupUser() {
	var form = $('#overlay_form_user')[0];
	if ( form.uid.value == "" ) {
		alert ("uid can't be empty");
		return false;
	}
	if ( form.fullname.value == "" ) {
		alert ("fullname can't be empty");
		return false;
	}
	if ( form.login.value == "" ) {
		alert ("login can't be empty");
		return false;
	}
	$("#overlay_form_user").fadeOut(500);
	$("#ovly").fadeOut(500);
	if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
	location.href = Gscriptname+"?"+$("#overlay_form_user").serialize()+"\#IDENT";
}

function sendPopupGroup() {
	var form = $('#overlay_form_group')[0];
	if ( form.gid.value ==  "" ) {
		alert ("gid can't be empty");
		return false;
	}
	if ( !form.gid.value.match(/^\+/) ) {
		alert ("gid invalid syntax");
		return false;
	}
	var usels=''; 
	for (i=0;i<form.uid.length;i++) { 
		if (form.uid[i].selected) usels += form.uid[i].value+','; 
	}
	usels=usels.slice(0,-1);
	if ( usels.length == 0 ) {
		alert ("uid can't be empty");
		return false;
	}
	var answer = confirm("confirm that group "+form.gid.value+" will contain "+usels+" ?");
	if (answer) {
		$("#overlay_form_group").fadeOut(500);
		$("#ovly").fadeOut(500);
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?"+$("#overlay_form_group").serialize()+"\#IDENT";
	} else { return false; }
}

function sendPopupNotf() {
	var form = $('#overlay_form_notf')[0];
	if ( form.event.value  == "" ) {
		alert ("event can't be empty");
		return false;
	}
	if ( form.uid.value == "" ) {
		alert ("uid can't be empty");
		return false;
	}
	if ( form.act.value == "" ) {
		alert ("action can't be empty");
		return false;
	}
	if ( UidGidExists(form.uid.value) ) {
		$("#overlay_form_notf").fadeOut(500);
		$("#ovly").fadeOut(500);
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?"+$("#overlay_form_notf").serialize()+"\#POSTBOARD";
	} else {
		alert (form.uid.value+" is not a uid/gid ");
	}
}

function sendPopupAuth() {
	var form = $('#overlay_form_auth')[0];
	if ( form.uid.value == "" ) {
		alert ("uid can't be empty");
		return false;
	}
	if ( UidGidExists(form.uid.value) ) {
		if ( form.res.value == "" ) {
			alert ("resource can't be empty");
			return false;
		}
		if ( form.auth.value == "" ) {
			alert ("authorization can't be empty");
			return false;
		}
		if ( ['1','2','4'].indexOf(form.auth.value) == -1 ) {  
			alert ("authorization must be one of 1,2,4");
			return false;
		}
		$("#overlay_form_auth").fadeOut(500);
		$("#ovly").fadeOut(500);
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?"+$("#overlay_form_auth").serialize()+"\#AUTH";
	} else {
		alert (form.uid.value+" is not a uid/gid ");
	}
}

function postDeleteUser(ux) {
	var uid =  $("td",ux)[2].textContent;
	var answer = confirm("do you really want to delete userid " + uid + " ? If so, you might first delete the corresponding line in htpasswd.")
	if (answer) {
		uid = uid.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=delete&tbl=user&uid="+uid+"\#IDENT"
	}
}

function postDeleteGroup(ux) {
	var gid =  $("td",ux)[2].textContent;
	var uid =  $("td",ux)[3].textContent;
	var answer = confirm("do you really want to delete "+gid+" / "+uid+" ?")
	if (answer) {
		gid =  gid.replace(/\+/g,'%2B');
		uid =  uid.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=delete&tbl=group&gid="+gid+"&uid="+uid+"\#IDENT"
	}
}

function postDeleteUGroup(ux) {
	var gid =  $("td",ux)[2].textContent;
	var answer = confirm("do you really want to delete group "+gid+" ?")
	if (answer) {
		gid = gid.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=deleteU&tbl=group&gid="+gid+"\#IDENT"
	}
}

function postDeleteNotf(ux) {
	var evt = $("td",ux)[2].textContent;
	var uid = $("td",ux)[4].textContent;
	var act = $("td",ux)[7].textContent;
	var answer = confirm("do you really want to delete event "+evt+"/"+uid+"/"+act+" ?")
	if (answer) {
		uid =  uid.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=delete&tbl=notification&event="+evt+"&uid="+uid+"&act="+act+"\#POSTBOARD"
	}
}

function postDeleteUNotf(ux) {
	var evt  =  $("td",ux)[1].textContent;
	var answer = confirm("do you really want to delete event "+evt+" ?")
	if (answer) {
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=deleteU&tbl=notification&event="+evt+"\#POSTBOARD"
	}
}

function postDeleteAuth(tb,ux) {
	var uid =  $("td",ux)[2].textContent;
	var res =  $("td",ux)[3].textContent;
	var answer = confirm("do you really want to delete auth "+uid+"/"+res+" ?")
	if (answer) {
		uid = uid.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=delete&tbl="+tb+"&uid="+uid+"&res="+res+"\#AUTH"
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
