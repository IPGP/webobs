
$(document).ready(function() {

	var wmHurl = ""; var wmHy = 0;

	$.ajaxSetup ({          
    	cache: false        
	});                     
    
	$('#wmtarget')[0].style.marginTop = $('#wm')[0].offsetHeight+'px';
	splash();

	//all links will load to wmtarget iframe (except for index.pl AND http[s]:)
	$("a").on("click", function(event) { 
		if ( $(this).attr("href").match(/^http.*:/gi)
		     || $(this).hasClass("externe") )
		{
			$(this).attr('target', '_blank');
			return true;
		}
		if ( ! $(this).attr("href").match(/index.pl/gi) ) {
			splash();
			$("#wmtarget").attr("src", $(this).attr("href"));
			return false;
		}
		location.reload(true);  //reload page from server (refresh)
	});

	$('#wmtarget').load(function () { // when iframe wmtarget is loaded:
		var cw = this.contentWindow;

		// 1) adapt wmtarget height to loaded page
		this.style.height = cw.document.body.offsetHeight + 20 + 'px';

		// 2) vertical scroll to specified hash, or saved position, or top otherwise
		if (cw.location.hash != "" ) {
			var anc=$('[name="' + cw.location.hash.substr(1) + '"]',cw.document).position();
			$('html, body').scrollTop(anc.top-this.offsetTop);
		} else {
			if (wmHurl == $('#wmtarget')[0].contentDocument.URL) { window.scrollTo(0,wmHy); }
			else { window.scrollTo(0, 0) };
		}

		// 3) setup to intercept clicks on <a>'s
		$('a', frames['wmtarget'].document).click(function(){
			if (this.attributes['href'].value.indexOf('#') == 0) {
				//hack FF: smooth scroll to anchor, without document reload, when href='#anchor' that exists
				var tgt = "a[name='"+this.hash.replace(/#/,'')+"']";
				if ($(tgt, frames['wmtarget'].document).length > 0) {
					var w = $(tgt, frames['wmtarget'].document).get(0).offsetTop;
					$('html,body').animate({ scrollTop: w }, 400);
					return false;
				}
			} else {
				//save current iframe contents url and its Y scroll
				wmHurl = $('#wmtarget')[0].contentDocument.URL;
				wmHy = $('body').scrollTop();
				//splash on links from within wmtarget, 
				//except when targetting can be a browser popup (not an .html* or .pl), 
				//except when targetting another window/tab,
				//except in markItUp or lighbox2 contexts ...
				var theaddr = /[^?]*/.exec(this.attributes['href'].value)[0]; //href up to a '?'
				if (theaddr.match(/\.htm[l]*$|\.pl$/gi)) {
					if (!this.attributes['target'] || this.attributes['target'] == '_self') {
						if ($(this).parents('.markItUp').length == 0) {
							if ( this.attributes["data-lightbox"] === undefined ) {
								splash(); 
								return true;
							}
						}
					}
				}
			}
		});

	});

	$(window).resize(function(){
		var w = $('#wmtarget')[0];
		w.style.height = w.contentWindow.document.body.offsetHeight + 20 + 'px';
	});

	// 'loading' screen (css is here for first page-load)
	function splash() {
		var splashdiv = '<div style="position: fixed;background: url(/icons/ipgp/wait_WebObs.gif) no-repeat center 30px #d1d1cc; border-radius: 5px; opacity: 0.7; top:0; left:0; width:100%; height: 100%; color: red;font-weight: bold; text-align: center;">loading...</div>';
		$("#wmtarget").contents().find("body").append(splashdiv); 
	}

	// dropdown navigation menu stuff
    $("ul.dropdown li").hover(function(){
        $(this).addClass("hover");
        $('ul:first',this).css('visibility', 'visible');
    }, function(){
        $(this).removeClass("hover");
		$(this).css('width', 'auto');
        $('ul:first',this).css('visibility', 'hidden');
    });
    
	$("ul.dropdown li ul").addClass("sub_menu").css("visibility","hidden");
	$("ul.dropdown li ul ul").css("visibility","hidden");
	$("ul.dropdown li ul li:has(ul)").find("a:first").append(" &raquo; ");

});

// pseudo-logout for session-less webobs 
function logout(user,lo) {
	if ( confirm("You are about to log out current user '"+user+"'.\nClick OK then Cancel at the next login prompt and close the window/tab.") )  {
		open(lo, '_top').close();
	} else {
		location.href = document.referrer;
	}
}

