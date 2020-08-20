
var plot;
var fontsize = 11;
var options;
var yticks;
var data=new Array();
var TZoffset = -(new Date()).getTimezoneOffset()*60*1000;
$(document).ready(function(){
	var placeholder = $("#placeholder");
	options = {
		grid: {
			//backgroundColor: { colors: ["#999", "#fff"] },
			backgroundColor: "white" ,
			borderWidth: 1,
			borderColor: "#DDD"
		},
		series: { 
			lines: { show: true, color: "#A59A8D", lineWidth: 8 },
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
			color: "#6B6055",
			min: 0
		},
		selection: {
			mode: "x",
			color: "#D1B999"
		},
		canvas: true
	};
	setData();
	placeholder.bind("plotselected", function (event, ranges) {
		plot = $.plot(placeholder, data, $.extend(true, {}, options, {
			xaxis: {
				 min: ranges.xaxis.from,
				 max: ranges.xaxis.to
			 },
			 canvas: true
		}));
		cop();
	});

	setsizes();
	plot = $.plot(placeholder, data, options);
	cop();
});

function plotall() {
	plot.setSelection({ xaxis: { from: options.xaxis.min, to: options.xaxis.max } },true);
	setsizes();
	plot = $.plot(placeholder, data, options);
	cop();
}

function cop(color) {
	var bgcolor = (typeof color == "undefined") ? "#fff" : color ;
	var link = $("#tlsavelink");
	link.hidden;
	try {
		var canvas = plot.getCanvas();
		var context=canvas.getContext("2d");
		context.globalCompositeOperation = "destination-over";
		context.fillStyle = "#fff";
		context.fillRect(0,0,canvas.width,canvas.height);
		var canvasimg = canvas.toDataURL();
		link.attr('href',canvasimg);
		link.attr('download','WebObsSchedTimeLine.png');
		link.show;
	} catch(e) {
		console.log("canvas op failed: "+e);
	}
}

function setsizes() {
	options.yaxis.max = yticks+1;
	options.yaxis.font.size = fontsize;
	options.yaxis.font.lineHeight = fontsize+10;
	options.series.lines.lineWidth = fontsize-4;
	options.xaxis.minTickSize = [1, "hour"];
	if (options.xaxis.max-options.xaxis.max <= 4*86400) {options.xaxis.minTickSize = [10,"minute"]; }
	$('.timeline-container').height((yticks+1)*options.yaxis.font.lineHeight);
}

function positionPopup(){
	$("#ovly").css('display','block');
	$("#overlay_form").css({
		//left: ($(window).width() - $('#overlay_form').width()) / 2,
		//top: ($(window).height() - $('#overlay_form').height()) / 2,
		//position:'absolute'
		left: (($(window).width() - $('#overlay_form').outerWidth()) / 2)+$(window).scrollLeft() + "px",
		position:'fixed'
	});
}
function openPopup(jix) {
	// jix is always required; jix  ==  jobsdefs' html-table row id OR -1 for a new job
	if (arguments.length <= 0 ) { return; } // noop if no jix
	//if (!$("#overlay_form").is(':visible')) { return; } 
	if (jix != -1) { // editing an existing job: populate popup from its table row TDs
		// ATT:  $("td",job.jix)[n] = n (0-based) must match jobsdefs <td> order in def-row  
		$('[name=validity]').prop("checked", $("td", jix)[4].textContent.match(/^Y/g) ? "checked" : "");
		$('[name=res]').val( $("td",jix)[5].textContent);
		$('[name=xeq1]').val( $("td",jix)[6].textContent);
		$('[name=xeq2]').val( $("td",jix)[7].textContent);
		$('[name=xeq3]').val( $("td",jix)[8].textContent);
		$('[name=runinterval]').val( $("td",jix)[9].textContent);
		$('[name=maxsysload]').val( $("td",jix)[10].textContent);
		$('[name=logpath]').val( $("td",jix)[11].textContent);
		$('[name=newjid]').val( $("td",jix)[3].textContent);
		$('[name=jid]').val( $("td",jix)[3].textContent );
		$('[name=action]').val("update");
		$('[name=sendbutton]').attr('onclick',"sendPopup(); return false");

	} else { // inserting a new job
		// DON'T rely on default values for popup defined at html-page creation time
		$('[name=validity]').prop("checked", "");
		$('[name=res]').val("");
		$('[name=xeq1]').val("$WEBOBS{JOB_MCC} genplot");
		$('[name=xeq2]').val("");
		$('[name=xeq3]').val("");
		$('[name=runinterval]').val("3600");
		$('[name=maxsysload]').val("0.8");
		$('[name=logpath]').val("");
		$('[name=jid]').val("-1");
		$('[name=newjid]').val("");
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
	if ( !($('[name=newjid]').val()).match(/^[a-zA-Z0-9\-_]+$/) ) {
		alert ("required jid, [a-zA-Z0-9\-_] only)");
		return false;
	}
	if ( !($('[name=runinterval]').val()).match(/^[0-9]+$/) ) {
		alert ("runInterval must be numeric");
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
	if ( $('[name=jid]').val() == "-1"  ) {
		$('[name=jid]').val($('[name=newjid]').val());
	}
	postInsUpd();
}
function postInsUpd() {
	$("#overlay_form").fadeOut(500);
	$("#ovly").fadeOut(500);
	location.href = "/cgi-bin/schedulerMgr.pl?"+$("#overlay_form").serialize();
}
function postDelete(jix) {
	var jid =  $("td",jix)[3].textContent;
	var answer = confirm("do you really want to delete jid "+jid+ " ?")
	if (answer) {
		location.href = "/cgi-bin/schedulerMgr.pl?action=delete&jid="+jid
	}
}
function postSubmit(jix) {
	var jid =  $("td",jix)[3].textContent;
	var answer = confirm("do you really want to submit jid "+jid+ " ?")
	if (answer) {
		location.href = "/cgi-bin/schedulerMgr.pl?action=submit&jid="+jid
	}
}
function postKill(jix) {
	var answer = confirm("do you really want to kill job process kid "+jix+" ?")
	if (answer) {
		location.href = "/cgi-bin/schedulerRuns.pl?action=killjob&kid="+jix
	}
}

//---   $("form").serialize() 
//$("td",job.jid).each(function() { 
//	console.log(this.textContent) ;
//});
