
var plot;
var fontsize = 11;
var options;
var yticks;
var data=new Array();
var TZoffset = -(new Date()).getTimezoneOffset()*60*1000;
$(document).ready(function(){
	options = {
		grid: {
			//backgroundColor: { colors: ["#999", "#fff"] },
			backgroundColor: "#DDD" ,
			borderWidth: 0,
			borderColor: null
		},
		series: { 
			lines: { show: true, color: "##E8C699", lineWidth: 8 },
			hoverable: true,
			shadowSize: 0
		},
		xaxis: {
			mode: "time",
			timezone: "browser",
			timeformat: "%y/%m/%d<br>%H:%M",
			minTickSize: [1, "hour"]
		},
		yaxis: {
			ticks: [],
			font: {
				size: 10, lineHeight: 12
			},
			min: 0
		}
	};
	setData();
	plotit();
});

function plotit() {
	plot = $.plot($("#placeholder"), data, options);
	setsizes();
	plot = $.plot($("#placeholder"), data, options);
}

function setsizes() {
	options.yaxis.max = yticks+1;
	options.yaxis.font.size = fontsize;
	options.yaxis.font.lineHeight = fontsize+10;
	options.series.lines.lineWidth = fontsize-4;
	$('.timeline-container').height((yticks+1)*options.yaxis.font.lineHeight);
}

function positionPopup(){
	//if(!$("#overlay_form").is(':visible')) { return; }
	$("#ovly").css('display','block');
	$("#overlay_form").css({
		left: ($(window).width() - $('#overlay_form').width()) / 2,
		top: ($(window).height() - $('#overlay_form').height()) / 2,
		position:'absolute'
	});
}
function openPopup(jix) {
	// jix is always required; jix  ==  jobsdefs' html-table row id OR -1 for a new job
	if (arguments.length <= 0 ) { return; } // noop if no jix
	//if (!$("#overlay_form").is(':visible')) { return; } 
	if (jix != -1) { // editing an existing job: populate popup from its table row TDs
		// ATT:  $("td",job.jix)[n] = n (0-based) must match jobsdefs <td> order in def-row  
		$('[name=validity]').val( $("td",jix)[3].textContent);
		$('[name=res]').val( $("td",jix)[4].textContent);
		$('[name=xeq1]').val( $("td",jix)[5].textContent);
		$('[name=xeq2]').val( $("td",jix)[6].textContent);
		$('[name=xeq3]').val( $("td",jix)[7].textContent);
		$('[name=runinterval]').val( $("td",jix)[8].textContent);
		$('[name=maxinstances]').val( $("td",jix)[9].textContent);
		$('[name=maxsysload]').val( $("td",jix)[10].textContent);
		$('[name=logpath]').val( $("td",jix)[11].textContent);
		var jid = $("td",jix)[2].textContent;
		$('[name=jid]').val(jid);
		$('[name=action]').val("update");
		$('[name=sendbutton]').attr('onclick',"sendPopup(); return false");

	} else { // inserting a new job
		// DON'T rely on default values for popup defined at html-page creation time
		$('[name=validity]').val("Y");
		$('[name=res]').val("");
		$('[name=xeq1]').val("");
		$('[name=xeq2]').val("");
		$('[name=xeq3]').val("");
		$('[name=runinterval]').val("");
		$('[name=maxinstances]').val("1");
		$('[name=maxsysload]').val("0.8");
		$('[name=logpath]').val("");
		$('[name=jid]').val("-1");
		$('[name=action]').val("insert");
		$('[name=sendbutton]').attr('onclick',"sendPopup(); return false");
	}
	$("#overlay_form").fadeIn(500);
	positionPopup();
}
function closePopup() {
	$("#overlay_form").fadeOut(500);
	$("#ovly").fadeOut(500);
}
function sendPopup() {
	if ( !($('[name=validity]').val()).match(/^Y|N/g) ) {
		alert ("validity must be Y or N");
		return false;
	}	
	if ( !($('[name=runinterval]').val()).match(/^[0-9]+$/) ) {
		alert ("runInterval must be numeric");
		return false;
	}	
	if ( !($('[name=maxinstances]').val()).match(/^[0-1]$/) ) {
		alert ("maxinstances must be 0 or 1");
		return false;
	}
	if ( !($('[name=maxsysload]').val()).match(/^[0-9.]+$/) ) {
		alert ("maxsysload must be a float");
		return false;
	}
	if ( $('[name=logpath]').val() == "" ) {
		alert ("logpath can't be empty");
		return false;
	}
	if ( $('[name=xeq1]').val() == "" && $('[name=xeq2]').val() == "" && $('[name=xeq3]').val() == "" ) {
		alert ("invalid: nothing to be executed!");
		return false;
	}
	postInsUpd();
}
function postInsUpd() {
	$("#overlay_form").fadeOut(500);
	$("#ovly").fadeOut(500);
	location.href = "/cgi-bin/schedulerMgr.pl?"+$("#overlay_form").serialize();
}
function postDelete(jix) {
	var jid =  $("td",jix)[2].textContent;
	var answer = confirm("do you really want to delete delete jid "+jid+ " ?")
	if (answer) {
		location.href = "/cgi-bin/schedulerMgr.pl?action=delete&jid="+jid
	}
}

//---   $("form").serialize() 
//$("td",job.jid).each(function() { 
//	console.log(this.textContent) ;
//});
