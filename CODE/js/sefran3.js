
$(document).ready(function() {
	// common event handlers
	$(window).unload(function() {
		if (window.opener && SCB.NOREFRESH == 0) {
			if (window.opener.parent.document.getElementById("wmtarget")) {
				window.opener.parent.document.getElementById("wmtarget").contentWindow.location.reload();
			}
		}
	});
	$('#rtclock').css('background','url(/icons/wait.gif) no-repeat center center white');
	$(window).scroll( function(event) {
		$('.voies-dynamiques').css('left', window.pageXOffset);
	});
	// big arrows ?
	if ($('#Larrow').length) {
		$('#Larrow').css('height',$(document).height()+'px');
		$('#Rarrow').css('height',$(document).height()+'px');
		$('#Rarrow').css('left',$(window).width()-$('#Rarrow').width());
	}
	if (typeof MECB  === 'undefined') {
		// event handlers
		$(window).load(function() {		
			init_ref();
			fsx(SCB.SX);
			//$('.submenu').innerWidth($('#refrow').width()-3);
			$('#rtclock').css('background','white');
		});
	} else {
		// event handlers
		$(window).load(function() {
			init_MECB();
			maj_formulaire();
			if (MECB.FORM.secondeEvenement.value!="") {
				sec = MECB.FORM.secondeEvenement.value;
				pos_x = Math.round((sec - 2)*1000*SCB.WIDTH/60000);
				window.scrollBy(pos_x,0);
			}
			shrinkmctags();	
		});
		$(window).keyup(maj_formulaire);
	$(window).change(maj_formulaire);
		// event handlers for crosshair 
		$('.flypointit').mousemove(function(e) { ptr=flypointit(e,false);overlib(ptr,WIDTH,120,OFFSETX,0,FULLHTML); });
		$('.flypointit').click(function(e) { flypointit(e,true) });
	}
});

// ---- show control keys
function showkeys() {
	$('.keys').css('display','block');
}
// ---- hide control keys
function hidekeys() {
	$('.keys').css('display','none');
}

// ---- quit
function quit() {
	SCB.NOREFRESH = 1;
	window.close();
}

// ---- toggle height of mctags 
function shrinkmctags() {
	$('.mctag').each(function () {
		var h = $(this).height() == SCB.LABELTOP ? SCB.HEIGHTIMG : SCB.LABELTOP ;
	    $(this).css('height',h+'px');
	});
}

// ---- toggle visibility of mctags 
function showmctags() {
	$('.mctag').toggle();
	return true;
}

// ---- restore 1:1 signals 
function zoom_1() {
	var ww2 = Math.floor($('body')[0].clientWidth/2);
	var px = window.pageXOffset;
	var w=SCB.WIDTH; // current zoom
	if (w != SCB.WIDTHREF) { 
		var zf = SCB.WIDTHREF/SCB.WIDTH;
		zoom_tag(zf);
		SCB.WIDTH = SCB.WIDTHREF;
		maj_speed();
		if (zf < 1) window.scrollTo((px-(1/zf-1)*(ww2-SCB.WIDTHVOIES))/(1/zf),0);
		if (zf > 1) window.scrollTo(px-zf*(ww2-SCB.WIDTHVOIES),0);
	}
}

// ---- zoom-out signals (width/2)
function zoom_out() {
	var ww2 = Math.floor($('body')[0].clientWidth/2);
	var px = window.pageXOffset;
	zoom_tag(.5);
	SCB.WIDTH /= 2;
	maj_speed();
	window.scrollTo((px-ww2+SCB.WIDTHVOIES)/2,0);
}

// ---- zoom-in signals (width*2)
function zoom_in() {
	var ww2 = Math.floor($('body')[0].clientWidth/2);
	var px = window.pageXOffset;
	zoom_tag(2);
	SCB.WIDTH *= 2;
	maj_speed();
	window.scrollTo(px*2+ww2-SCB.WIDTHVOIES,0);
}

// ---- resize all signal imgs and their map-areas
function maj_speed() {
	$('.png').each( function() {
		$(this).css('width', SCB.WIDTH);
	});
	// ALL maps in page are considered sefran-imgs-maps
	$('map > area').each( function() {
		var c = $(this).attr("coords").split(',');
		c[2] = SCB.WIDTH;
		$(this).attr("coords", c.join(","));
	});
}

// ---- apply a zoom factor to mctags and positions of event-start and event-end
function zoom_tag(zoom) {
	$('.mctag').each(function() {
		$(this).css('left', ($(this).position().left - SCB.DX)*zoom + SCB.DX + 'px');
		$(this).css('width', $(this).width() * zoom + 'px');
	});
	$('#eventStart,#eventEnd,#eventSP').each(function() {
		$(this).css('left', ($(this).position().left - SCB.DX)*zoom + SCB.DX + 'px');
	});
}

// ---- load another sefran in its own window for a given hour 
function sefran() {
	window.open(SCB.PROG+'&date=' + formulaire.ad_date.value + formulaire.ad_heure.value);
}

// ---- make the formRef visible if needed 
function init_ref() {
	if (document.form) {
		if (document.form.ref.value == 1) $('#formRef').css('visibility','visible');
	}
}

// ---- handle user switching from realtime to date selection 
function mod_ref() {
	if (document.form.ref.value == 0) {
		$('#formRef').css('visibility','hidden');
		document.form.submit();
	} else {
		$('#formRef').css('visibility','visible');
	}
}

// ---- scroll to right-end of signals (used when page is reloaded with 'previous-date-arrow')
function fsx(sx) { 
	if (sx == 1) window.scrollBy(window.scrollMaxX,0); 
}

// ---- mousemove over hour image(s): build overlib msg, showing position
function flyhour(me,msg) {
	if ( txt = me.href.match(/date=(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/) ) {
		msg += '\n'+txt[1]+'-'+txt[2]+'-'+txt[3]+' '+txt[4]+':'+txt[5]
	}
	overlib(msg,FGCOLOR,'#FFAAAA');
	return;
}

// ---- helper to left-pad value with '0'
function pad2(x) {
	y = x < 10 ? ("0" + x) : x;
	return(y);
}

// ---- MECB initializations on page load
function init_MECB() {
	MECB.FORM = document.formulaire;
	MECB.MFC = $("#mcform")[0];
	MECB.MINUTE = new Date(MECB.FORM.year.value,MECB.FORM.month.value-1,MECB.FORM.day.value,MECB.FORM.hour.value,MECB.FORM.minute.value,0,0);
}

// ---- opens a window for miniseed request
function view_mseed() {
	var dte0 = new Date(MECB.FORM.year.value,MECB.FORM.month.value-1,MECB.FORM.day.value,MECB.FORM.hour.value,MECB.FORM.minute.value,MECB.FORM.secondeEvenement.value);
	dte0.setSeconds(dte0.getSeconds() - 10);
	var ds = (20 + Number(MECB.FORM.dureeEvenement.value));
	var t0 = dte0.getFullYear() + "," + pad2(dte0.getMonth()+1) + "," + pad2(dte0.getDate()) + ","
		 + pad2(dte0.getHours()) + "," + pad2(dte0.getMinutes()) + "," + pad2(dte0.getSeconds());
	for (var i=0; i < MECB.FORM.voiesMSEED.length; i++) {
		if (MECB.FORM.voiesMSEED[i].checked) {
			var all = MECB.FORM.voiesMSEED[i].value;
		}
	}
	window.location.href = MECB.MSEEDREQ + '&t1=' + t0 + '&ds=' + ds + '&all=' + all;
}

// ---- signals mouseover or click handler; bound via jQuery for cross-browser structures
function flypointit(event,click) {
	var dte = new Date(MECB.MINUTE.getTime());      // local dte = date of beginning of window
	deltaT = 60*(event.pageX - SCB.PPI)/SCB.WIDTH;     // local deltaT = mouse seconds from beginning of window 
	duration = deltaT - MECB.FORM.sec.value;           // local duration = mouse seconds from eventStart if it already exists 
	if (!click) {
		// -------------------- process a mouseover -------------
		var ret = '?';
		if (event.shiftKey && MECB.FORM.secondeEvenement.value!="" && duration > 0) {
			ret = "click <b>S</b><br>&nbsp;at +"+duration.toFixed(2)+"s";
		} else {
			if (MECB.FORM.secondeEvenement.value!="" && MECB.FORM.dureeEvenement.value=="" && duration > 0) {
				ret = "click <b>End</b><br>&nbsp;at +"+duration.toFixed(2)+"s";
			} else {
				dte.setSeconds(deltaT);
				var dateEv = pad2(dte.getHours()) + ":" + pad2(dte.getMinutes()) + ":" + pad2((deltaT % 60).toFixed(2));
				ret = "click <b>Start</b><br>&nbsp;at "+dateEv;
			}
		}
		// change mcform horizontal position when crosshair is (or almost) over it if the control-key is pressed
		if (event.ctrlKey && event.clientX >= MECB.MFC.offsetLeft-MECB.PROX && event.clientX <= MECB.MFC.offsetLeft+MECB.MFC.scrollWidth+MECB.PROX) {
			if (MECB.MFC.offsetLeft == SCB.PPI+5) { MECB.MFC.style.left=window.innerWidth-MECB.MFC.scrollWidth-30;}
			else                                  { MECB.MFC.style.left=SCB.PPI+5;}
		}
		// adjust crosshair's legend position (set to left or right of crosshair)
		if (event.clientX >= window.innerWidth - MECB.CHWIDTH) {
			algn = 'right'; ol_hpos = LEFT; 
			ret=ret+'&nbsp;'+MECB.CROSSHAIR;
		} else { 
			algn = 'left'; ol_hpos = RIGHT; 
			ret=MECB.CROSSHAIR+'&nbsp;'+ret;
		}
		return('<div style="width: '+MECB.CHWIDTH+'px;text-align:'+algn+'">'+ret+'</div>');
	} else {
		// ------------------------ process a click -----------------
		if (event.shiftKey && MECB.FORM.secondeEvenement.value!="" && duration > 0) {
			// set S-phase
			MECB.FORM.smoinsp.value = duration.toFixed(2);
		} else {
			if (MECB.FORM.secondeEvenement.value!="" && MECB.FORM.dureeEvenement.value=="" && duration > 0) {
				// set End
				MECB.FORM.dureeEvenement.value = duration.toFixed(2);
				MECB.FORM.uniteEvenement.value = "s";
			} else {
				MECB.FORM.stationEvenement.value = SCB.STREAMS[Math.floor(SCB.CHANNELNB*(event.pageY - SCB.LABELTOP - 5)/(SCB.HEIGHT*SCB.PPI - SCB.LABELTOP - SCB.LABELBOTTOM))];
				dte.setSeconds(dte.getSeconds() + deltaT);
				MECB.FORM.dateEvenement.value = dte.getFullYear() + "-" + pad2(dte.getMonth()+1) + "-" + pad2(dte.getDate()) + " " + pad2(dte.getHours()) + ":" + pad2(dte.getMinutes());
				MECB.FORM.secondeEvenement.value = (deltaT % 60).toFixed(2);
				MECB.FORM.sec.value = deltaT;
				MECB.FORM.dureeEvenement.value = "";
				if ( MECB.NEWPCLEARS == 1 ) MECB.FORM.smoinsp.value = "";
			}
		}
		maj_formulaire();
	}
}

// ---- checks for updates in mcform
function maj_formulaire() {
	var dte0 = new Date(MECB.MINUTE.getTime());
	var duration;
	if (MECB.FORM.secondeEvenement.value!="" && MECB.FORM.secondeEvenement.value >= 0 && MECB.FORM.secondeEvenement.value < 60) {
		date = MECB.FORM.dateEvenement.value;
		sec = parseFloat(MECB.FORM.secondeEvenement.value);
		dte1 = new Date(date.substr(0,4),date.substr(5,2)-1,date.substr(8,2),date.substr(11,2),date.substr(14,2),0);
                MECB.FORM.sec.value = sec + (dte1.getTime() - dte0.getTime()) / 1000 ;
	}
	MECB.FORM.nomOperateur.style.backgroundColor = MECB.COLORS[(MECB.FORM.nomOperateur.value != "")];
	MECB.FORM.nombreEvenement.style.backgroundColor = MECB.COLORS[(MECB.FORM.nombreEvenement.value != "" && ! isNaN(MECB.FORM.nombreEvenement.value) && MECB.FORM.nombreEvenement.value != 0)];
	MECB.FORM.dateEvenement.style.backgroundColor = MECB.COLORS[(MECB.FORM.dateEvenement.value != "")];
	MECB.FORM.secondeEvenement.style.backgroundColor = MECB.COLORS[(MECB.FORM.secondeEvenement.value != "" && MECB.FORM.secondeEvenement.value >= 0 && MECB.FORM.secondeEvenement.value < 60)];
	if (MECB.FORM.secondeEvenement.value!="") {
		pos_x = Math.round((dte1.getTime() + sec*1000 - dte0.getTime())*SCB.WIDTH/60000 + SCB.PPI);                 	
		$('#eventStart').css({ 'left': pos_x, 'visibility': 'visible' });
	} else {
		$('#eventStart').css({ 'visibility': 'hidden' });
		MECB.FORM.sec.value = 0;
	}
	MECB.FORM.dureeEvenement.style.backgroundColor = MECB.COLORS[(MECB.FORM.dureeEvenement.value != "" && ! isNaN(MECB.FORM.dureeEvenement.value) && MECB.FORM.dureeEvenement.value != 0)];
	MECB.FORM.stationEvenement.style.backgroundColor = MECB.COLORS[(MECB.FORM.stationEvenement.value != "")];
	MECB.FORM.amplitudeEvenement.style.backgroundColor = MECB.COLORS[(MECB.FORM.amplitudeEvenement.value != "")];
	MECB.FORM.saturationEvenement.style.backgroundColor = MECB.COLORS[(
		( MECB.FORM.amplitudeEvenement.value != "OVERSCALE"
		&& MECB.FORM.amplitudeEvenement.value != "Sature"
		&& ( MECB.FORM.saturationEvenement.value == 0 || MECB.FORM.saturationEvenement.value == ""))
		||
		( ( MECB.FORM.amplitudeEvenement.value == "OVERSCALE"	|| MECB.FORM.amplitudeEvenement.value == "Sature")
		&& MECB.FORM.saturationEvenement.value > 0 )
	)];
	MECB.FORM.smoinsp.style.backgroundColor = MECB.COLORS[!isNaN(MECB.FORM.smoinsp.value)];
	$("#dist").html((MECB.FORM.smoinsp.value!="" && !isNaN(MECB.FORM.smoinsp.value)) ? " Distance = <b>" + (MECB.FORM.smoinsp.value*8)+" km</b>" : "");
	if (MECB.FORM.dureeEvenement.value!="") {
		switch(MECB.FORM.uniteEvenement.value) {
			case "s" :  duration = MECB.FORM.dureeEvenement.value; break;
			case "mn" : duration = MECB.FORM.dureeEvenement.value*60; break;
			case "h" :  duration = MECB.FORM.dureeEvenement.value*3600; break;
			case "d" :  duration = MECB.FORM.dureeEvenement.value*86400; break;
		}
		if (MECB.FORM.secondeEvenement.value!="") {
			pos_x = Math.round((dte1.getTime() + duration*1000 + sec*1000 - dte0.getTime())*SCB.WIDTH/60000 + SCB.PPI);
			$('#eventEnd').css({ 'left': pos_x, 'visibility': 'visible' });
		} else {
			$('#eventEnd').css({ 'visibility': 'hidden' });
		}
	} else {
		$('#eventEnd').css({ 'visibility': 'hidden' });
	}
	//if (MECB.FORM.smoinsp.value!="" && !isNaN(MECB.FORM.smoinsp.value) && MECB.FORM.dureeEvenement.value!="" && !isNaN(MECB.FORM.dureeEvenement.value)) {
	if (MECB.FORM.smoinsp.value!="" && !isNaN(MECB.FORM.smoinsp.value) ) {
		distance = MECB.FORM.smoinsp.value*8;
		magnitude = 2*Math.log(duration)/Math.log(10)+0.0035*distance-0.87;
		mag = Math.round(10*magnitude)/10;
		pos_x = Math.round((dte1.getTime() + MECB.FORM.smoinsp.value*1000 + sec*1000 - dte0.getTime())*SCB.WIDTH/60000 + SCB.PPI);
		$('#eventSP').css({ 'left': pos_x, 'visibility': 'visible' });
	} else {
		mag = 0;
		$('#eventSP').css({ 'visibility': 'hidden' });
	}
	$("#mag").html((mag>0) ? ", Md = <b>" + mag + "</b>": "");
	MECB.FORM.typeEvenement.style.backgroundColor = MECB.COLORS[(MECB.FORM.typeEvenement.value != "INCONNU" && MECB.FORM.typeEvenement.value != "UNKNOWN" && MECB.FORM.typeEvenement.value != "AUTO")];
	
	// EQDISCRIM
	if (MECB.FORM.secondeEvenement.value!="" && MECB.FORM.dureeEvenement.value!="") {
		$('#eqdiscrim').show("slow");
	} else {
		$('#eqdiscrim').hide("fast");
	}
}

// ---- check box newSC3 if event-type is in SC3ARR
function maj_type() {
	if (jQuery.inArray(MECB.FORM.typeEvenement.value, MECB.SC3ARR) > -1) {
		MECB.FORM.newSC3event.checked = 1;
	} else {
		MECB.FORM.newSC3event.checked = 0;
	}

}

// ---- check for required inputs in mcform
function verif_formulaire() {
	if (MECB.FORM.stationEvenement.value == "") {
        alert(MECB.MSGS['staevt']);
        MECB.FORM.stationEvenement.focus();
        return false;
    }
	if (MECB.FORM.secondeEvenement.value == "" || MECB.FORM.secondeEvenement.value < 0 || MECB.FORM.secondeEvenement.value >= 60) { 
        alert(MECB.MSGS['secevt']);
        MECB.FORM.secondeEvenement.focus(); 
        return false;
    }
	if(MECB.FORM.dureeEvenement.value == "" || isNaN(MECB.FORM.dureeEvenement.value)) {
        alert(MECB.MSGS['durevt']);
        MECB.FORM.dureeEvenement.focus();
        return false;
    }
	if(MECB.FORM.nombreEvenement.value == "" || isNaN(MECB.FORM.nombreEvenement.value)) {
        alert(MECB.MSGS['nbevt']);
        MECB.FORM.nombreEvenement.focus();
        return false;
    }
	if(MECB.FORM.amplitudeEvenement.value == "") {
        alert(MECB.MSGS['ampevt']);
        MECB.FORM.stationEvenement.focus();
        return false; 
    }
	if(MECB.FORM.amplitudeEvenement.value == "Sature" || MECB.FORM.amplitudeEvenement.value == "OVERSCALE") {
		if (MECB.FORM.saturationEvenement.value == "" || MECB.FORM.saturationEvenement.value <= 0) {
        	alert(MECB.MSGS['ovrdur']);
			MECB.FORM.saturationEvenement.focus(); 
			return false;
		}
    } else {
		if (MECB.FORM.saturationEvenement.value > 0) {
        	alert(MECB.MSGS['notovr']);
			MECB.FORM.saturationEvenement.focus(); 
			return false;
		}
	}
	if(MECB.FORM.typeEvenement.value == "INCONNU" || MECB.FORM.typeEvenement.value == "UNKNOWN") {
		if (!confirm(MECB.MSGS['unkevt'])) {
   			MECB.FORM.typeEvenement.focus(); 
   			return false; 
		}
	}
	if(MECB.FORM.typeEvenement.value == "AUTO") {
		alert(MECB.MSGS['notval']);
		MECB.FORM.typeEvenement.focus(); 
		return false; 
	}
}

// ---- hide or delete an MC event
function supprime(level) {
	if (level > 1) {
		if (!confirm(MECB.MSGS['delete'] + MECB.TITLE)) {
			return false; 
		}
	} else {
		if (MECB.FORM.id_evt.value > 0) {
			if (!confirm(MECB.MSGS['hidevt'] + MECB.TITLE)) {
				return false; 
			}
		} else {
			if (!confirm(MECB.MSGS['resevt'] + MECB.TITLE)) {
				return false; 
			}
		}
	}
	MECB.FORM.effaceEvenement.value = level;
	MECB.FORM.submit();
}

// ---- EQDISCRIM: run request
function run_eqdiscrim() {
	var EQD = MECB.FORM.eqdsrv.value;
//	$.getJSON(EQD,
//		'run_predict, 20160831T172927.32, 10'
//	)
//	.done(function(data) {
//		,alert('test !'));
}
