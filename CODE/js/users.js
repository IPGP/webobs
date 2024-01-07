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

function openPopupUser(user_row) {
	// user_row is the jquery selector for the user row in the table.
	// If user_row is undefined, edit a new user
	var form = $('#overlay_form_user')[0];
	var listgids;

	if (user_row !== undefined) {
		// editing an existing user: populate popup from its table row TDs
		form.uid.value = $(user_row + ' .user-uid').text();
		if (form.isWO.value == 0) form.uid.readOnly = true;
		form.OLDuid.value = $(user_row + ' .user-uid').text();
		form.uid.style.backgroundColor = "#EEEEEE";
		form.fullname.value = $(user_row + ' .user-fullname').text();
		form.login.value = $(user_row + ' .user-login').text();
		form.email.value = $(user_row + ' .user-email').text();
		listgids = $(user_row + ' .user-groups').text().split(' ');
		$('#overlay_form_user #gid option').each(function() {
			$(this).removeProp('selected');
			if (jQuery.inArray( this.value, listgids ) != -1) {
				$(this).prop('selected',true)
			}
		});
		$('label[for=gid]').css('display','block');
		$(form.gid).css('display','block');
		form.OLDgid.value = $(user_row + ' .user-groups').text();
		$(form.valid).prop("checked",
		    ($(user_row + ' .user-validity').text() == 'Y' ? "checked" : ""));
		form.enddate.value = $(user_row + ' .user-enddate').text();
		form.comment.value = $(user_row + ' .user-comment').text();
		form.action.value = "update";
	} else {
		// populate a blank form to edit a new user
		form.uid.value = "";
		form.uid.readOnly = false;
		form.uid.style.backgroundColor = "";
		form.fullname.value = "";
		form.login.value = "";
		form.email.value = "";
		$('#overlay_form_user #gid option').each(function() {
			// clear any option selected in an earlier edition
			$(this).removeProp('selected');
		});
		$(form.valid).prop("checked", "checked");
		form.enddate.value = "";
		form.comment.value = "";
		form.action.value = "insert";
	}
	form.tbl.value = "user";
	$('#overlay_form_user[name=sendbutton]').attr('onclick',"sendPopupUser(); return false");
	$("#overlay_form_user").fadeIn(500);
	positionPopup();
	form.uid.focus();
}

function openPopupGroup(group_row) {
	// group_row is the jquery selector for the group row in the table.
	// If group_row is undef, edit a new group
	var form = $('#overlay_form_group')[0];
	var listuids;

	if (group_row !== undefined) {
		// group members edition: populate popup from its table row elements
		form.gid.value = $(group_row + ' .group-gid').text();

		listuids = $(group_row + ' .group-uids').text().split(' ');
		$('#overlay_form_group #uid option').each(function() {
			$(this).removeProp('selected');
			if (jQuery.inArray( this.value, listuids ) != -1) {
				$(this).prop('selected',true);
			}
		});
		$('label[for=uid]').css('display','block');
		$(form.uid).css('display','block');
		form.OLDgid.value = $(group_row + ' .group-gid').text();
		form.OLDuid.value = $(group_row + ' .group-uids').text();
		form.action.value = "updgrp";

	} else {
		// populate a blank form to edit a new group
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

function openPopupNotf(notif_row) {
	// notif_row is the jquery selector for the notification row in the table.
	// If notif_row is undef, edit a new notification
	var form = $('#overlay_form_notf')[0];
	if (notif_row !== undefined) {
		form.event.value = $(notif_row + " .notif-event").text();
		form.OLDevent.value = $(notif_row + " .notif-event").text();
		form.event.style.backgroundColor = "#EEEEEE";
		$(form.valid).prop("checked",
		  ($(notif_row + " .notif-validity").text() == 'Y' ? "checked" : ""));
		form.uid.value = $(notif_row + " .notif-emailuid").text();
		form.OLDuid.value = $(notif_row + " .notif-emailuid").text();
		form.uid.style.backgroundColor = "#EEEEEE";
		form.mailsub.value = $(notif_row + " .notif-emailsubj").text();
		form.mailatt.value = $(notif_row + " .notif-emailattach").text();
		form.act.value = $(notif_row + " .notif-action").text();
		form.OLDact.value = $(notif_row + " .notif-action").text();
		form.act.style.backgroundColor = "#EEEEEE";
		form.action.value = "update";
	} else {
		// populate a blank form to edit a new notification
		form.event.value = "";
		form.event.style.backgroundColor = "";
		$(form.valid).prop("checked", "checked");
		form.uid.value = "";
		form.uid.style.backgroundColor = "";
		form.mailsub.value = "";
		form.mailatt.value = "";
		form.act.value = "-";
		form.act.style.backgroundColor = "";
		form.action.value = "insert";
	}
	form.tbl.value = "notification";
	$('#overlay_form_notf[name=sendbutton]').attr('onclick',"sendPopupNotf(); return false");
	$("#overlay_form_notf").fadeIn(500);
	positionPopup();
	form.event.focus();
}

function openPopupAuth(auth_table, auth_row) {
	// auth_row is the jquery selector for the authorization row in the table auth_table.
	// If auth_row is undef, edit a new authorization in the table.
	form = $('#overlay_form_auth')[0];
	if (auth_row !== undefined) {
		form.uid.value = $(auth_row + " .auth-uid").text();
		form.OLDuid.value = $(auth_row + " .auth-uid").text();
		form.uid.style.backgroundColor = "#EEEEEE";
		form.res.value = $(auth_row + " .auth-res").text();
		form.OLDres.value = $(auth_row + " .auth-res").text();
		form.res.style.backgroundColor = "#EEEEEE";
		form.auth.value = $(auth_row + " .auth-auth").text();
		form.action.value = "update";
	} else {
		// populate a blank form to edit a new authorization
		form.uid.value = "";
		form.uid.style.backgroundColor = "";
		form.res.value = "";
		form.res.style.backgroundColor = "";
		form.auth.value = "";
		form.action.value = "insert";
	}
	form.tbl.value = auth_table;
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
		alert ("gid must start with '+'");
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
		alert ("uid can't be empty (set to '-' disable email)");
		return false;
	}
	if ( form.act.value == "" ) {
		alert ("action can't be empty (set to '-' to disable)");
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

function postDeleteUser(user) {
	var uid = $(user + ' .user-uid').text();
	var answer = confirm("do you really want to delete userid " + uid + " ? If so, you might first delete the corresponding line in htpasswd.")
	if (answer) {
		uid = uid.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=delete&tbl=user&uid="+uid+"\#IDENT"
	}
}

function postDeleteUGroup(group) {
	var gid = $(group + ' .group-gid').text();
	var answer = confirm("do you really want to delete group "+gid+" ?")
	if (answer) {
		gid = gid.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=deleteU&tbl=group&gid="+gid+"\#IDENT"
	}
}

function postDeleteNotf(notif) {
	var evt = $(notif + ' .notif-event').text();
	var uid = $(notif + ' .notif-emailuid').text();
	var act = $(notif + ' .notif-action').text();
	var answer = confirm("do you really want to delete event "+evt+"/"+uid+"/"+act+" ?")
	if (answer) {
		uid =  uid.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=delete&tbl=notification&event="+evt+"&uid="+uid+"&act="+act+"\#POSTBOARD"
	}
}

function postDeleteUNotf(unotif) {
	var evt = $(unotif + ' .unotif-event').text();
	var answer = confirm("do you really want to delete event "+evt+" ?")
	if (answer) {
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=deleteU&tbl=notification&event="+evt+"\#POSTBOARD"
	}
}

function postDeleteAuth(auth_table, auth) {
	var uid =  $(auth + ' .auth-uid').text();
	var res =  $(auth + ' .auth-res').text();
	var answer = confirm("do you really want to delete auth "+uid+"/"+res+" ?")
	if (answer) {
		uid = uid.replace(/\+/g,'%2B');
		if (Gscriptname == "") { Gscriptname = "/cgi-bin/usersMgr.pl"; }
		location.href = Gscriptname+"?action=delete&tbl="+auth_table+"&uid="+uid+"&res="+res+"\#AUTH"
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
