
$(document).ready(function(){
	// Set a click handler for thumbnail img and image area
	$('img[wolbsrc],area[wolbsrc]').click( function() {
		openPopup($(this));
	});
	// Set a click handler for icons opening an album designated by wolbtarget
	$('img[wolbtarget]').click( function() {
		openPopup($("[wolbset="+$(this).attr('wolbtarget')+"]").first());
	});
	wolbHtml="<div id='wolbOvly' class='wolbOvly' onClick='closePopup()'></div>"+
	  "<div id='wolbBox' class='wolbBox'>"+
		"<div class='wolbNav'>"+
			"<div class='wolbPrev'>_&nbsp;</div>"+
			"<div class='wolbId'></div>"+
			"<div class='wolbNext'>&nbsp;_</div>"+
		"</div>"+
	  	"<img src='' />"+
	  "</div>";
	$(wolbHtml).appendTo($('body'));
});

function getImage(i){
	$("#wolbBox img")
		.attr('src','')
		.one('load', function() {
			fitVisible($(this));
		})
		.attr('src', i)
		.each(function() { if(this.complete) $(this).trigger('load'); });
}

function fitVisible(that) {
	var margins = 8;
	var img = that[0];
	var iw = img.naturalWidth; var ih = img.naturalHeight;
	var box = $("#wolbBox");
	var winY = window.parent.pageYOffset;
	var viewH = window.parent.innerHeight-$('#wm',window.parent.document).outerHeight();
	var winH = Math.min($("#wolbOvly").innerHeight(),viewH);
	var winW = $("#wolbOvly").innerWidth();
	box.show();var decoH = box.outerHeight()-box.innerHeight()+(2*margins)+$('.wolbNav').height();box.hide();
	var decoW = box.outerWidth()-box.innerWidth();
	if (iw >= winW-decoW || ih >= winH-decoH ) {
		var ratioH = (winH-decoH) / ih;
		var ratioW = (winW-decoW) / iw;
		if (ratioH < ratioW) {
			img.height = winH-decoH;
			img.width  = iw*ratioH;
		} else {
			img.width = winW-decoW;
			img.height = ih*ratioW;
		}
	} else {
		img.width = iw;
		img.height = ih; 
	}
	box.css({
		left: ((winW - box.outerWidth()) / 2) + "px",
		top:  winY + ((winH - margins - box.outerHeight()) / 2) + "px",
	});
	box.fadeIn(10);
}

function dokey(event) {
	if (event.keyCode == 27) closePopup();
	if (event.keyCode == 37 && event.data.prev != '') openPopup(event.data.prev) ;
	if (event.keyCode == 39 && event.data.next != '') openPopup(event.data.next) ;
}

function openPopup(i) {
	$(".wolbPrev, .wolbNext").css('visibility','hidden');
	$(".wolbPrev, .wolbNext").off('click');
	$(document).off('.wolb');
	$("#wolbOvly").css('display','block');
	getImage(i.attr('wolbsrc'));
	var id = ""; var prev = ""; var next = "";
	if (typeof i.attr('wolbset') != 'undefined') {
		var album = i.attr('wolbset');
		var s = "";
		s = i.prev("[wolbset="+album+"]");
		if (s.length > 0) {
			prev = $(s);
			$(".wolbPrev").css('visibility','visible')
			              .on('click', function() { openPopup(prev); });
		}
		s = "";
		s = i.next("[wolbset="+album+"]"); 
		if (s.length > 0) {
			next = $(s);
			$(".wolbNext").css('visibility','visible')
			              .on('click', function() { openPopup(next); });
		}
	}
	$(document).on('keyup.wolb', { next: next, prev: prev }, dokey);
	id += i.attr('wolbsrc').split(/(\\|\/)/g).pop();
	$(".wolbId").text(id);
	$(".wolbNav").css('display','block');
}

function closePopup() {
	$(".wolbPrev, .wolbNext").off('click');
	$("#wolbBox").fadeOut(100);
	$(".wolbNav").css('display','none');
	$("#wolbOvly").fadeOut(500);
	$(document).off('.wolb');
}

