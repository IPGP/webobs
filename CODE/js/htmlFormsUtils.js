
$.fn.extend({ formChanges: function() {
	$(":input",this).change(function() {
		$(this.form).data("changed", true);
	});
}
,
	hasChanged: function() { 
		return this.data("changed"); 
	}
});
					
function scrolldivHeight() {
	var sh = parent.innerHeight - $('#wm',window.parent.document).height() - parseInt($('body').css('marginTop'), 10);
	$('#scrolldiv').height(sh);
}

function SelectMoveRows(SS1,SS2) 
{
    var SelID='';
    var SelText='';
    // Move rows from SS1 to SS2 from bottom to top
    for (i=SS1.options.length - 1; i>=0; i--) {
        if (SS1.options[i].selected == true) {
            SelID=SS1.options[i].value;
            SelText=SS1.options[i].text;
            var newRow = new Option(SelText,SelID);
            SS2.options[SS2.length]=newRow;
            SS1.options[i]=null;
        }
    }
    SelectSort(SS2);
}

function SelectSort(SelList)
{
    var ID='';
    var Text='';
    for (x=0; x < SelList.length - 1; x++) {
        for (y=x + 1; y < SelList.length; y++) {
            if (SelList[x].text > SelList[y].text) {
                // Swap rows
                ID=SelList[x].value;
                Text=SelList[x].text;
                SelList[x].value=SelList[y].value;
                SelList[x].text=SelList[y].text;
                SelList[y].value=ID;
                SelList[y].text=Text;
            }
        }
    }
}

function SelectRows(fromSelectTDs, toTextArea)
{
	var s = "";
	$("input."+fromSelectTDs+":checked").each(function(ix){
			var v = ($(this))[0].nextSibling.search.replace(/.*\?grid=/, '');
			s += "+" + v 
		});
	toTextArea.value = s;
}

function SelectAllRows(fromSelectTDs, tag, toTextArea)
{
	if (toTextArea.value == tag) {
		toTextArea.value = "";
		$("input."+fromSelectTDs).attr('checked', false);
	} else {
		toTextArea.value = tag;
		$("input."+fromSelectTDs).attr('checked', true);
	}
}

function CLBshowhide() 
{
	$('.CLBshowhide').toggle();
}

function geditopenPopup() {
	$("#geditoverlay_form").fadeIn(500);
	geditpositionPopup();
}

function geditpositionPopup(){
	$("#geditovly").css('display','block');
	$("#geditoverlay_form").css({
		left: (($(window).width() - $('#geditoverlay_form').outerWidth()) / 2)+$(window).scrollLeft() + "px",
		position:'fixed'
	});
}

function geditsendPopup() {
	if ( $('#geditoverlay_form')[0].geditN.value == "" ) {
		alert('Please specify a grid name') ;
		return false;
	}
	var gtype = $('#geditoverlay_form')[0].geditT.value;
	var gname = $('#geditoverlay_form')[0].geditN.value;
	if ( !gname.match(/[^A-Z_]/g) ) {
		var tt = gtype.split(".");
		$("#geditoverlay_form").fadeOut(500);
		$("#geditovly").fadeOut(500);
		location.href = "/cgi-bin/formGRID.pl?grid=" + tt[0] + "." + gname.toUpperCase() + "&type=" + gtype;
	} else {
		alert('Grid name have to be uppercase letters only, no other character except underscore allowed');
		return false;
	}
	//FBwas: if ( gname.match(/PROC\./i) || gname.match(/VIEW\./i) ) {
	//FBwas:	$("#geditoverlay_form").fadeOut(500);
	//FBwas:	$("#geditovly").fadeOut(500);
	//FBwas:	location.href = "/cgi-bin/formGRID.pl?grid="+gname;
	//FBwas: } else {
	//FBwas:	alert('Grid name must be VIEW.name or PROC.name');
	//FBwas:	return false;
	//FBwas: }
}

function geditclosePopup() {
	$("#geditoverlay_form").fadeOut(500);
	$("#geditovly").fadeOut(500);
}

function srchopenPopup(g) {
	if (arguments.length <= 0 ) { return; } // noop if no argument
	$('#srchoverlay_form')[0].grid.value = g;
	$("#srchoverlay_form").fadeIn(500);
	srchpositionPopup();
}

function srchpositionPopup(){
	$("#srchovly").css('display','block');
	$("#srchoverlay_form").css({
		left: (($(window).width() - $('#srchoverlay_form').outerWidth()) / 2)+$(window).scrollLeft() + "px",
		position:'fixed'
	});
	gl = $("#srchoverlay_form")[0].grid.value.length;
	$("#srchoverlay_form input#grid").attr('size',Math.min(15,gl));
	if (gl > 15) {
		$("#srchoverlay_form input#grid")[0].nextSibling.textContent='...} for:'
	}
}

function srchsendPopup() {
	if ( $('#srchoverlay_form')[0].searchW.value == "" ) {
		alert('Enter string/expression to be searched for');
		return false;
	}
	$("#srchoverlay_form").fadeOut(500);
	$("#srchovly").fadeOut(500);
	//alert($("#srchoverlay_form").serialize());
	location.href = "/cgi-bin/nsearch.pl?"+$("#srchoverlay_form").serialize();
}

function srchclosePopup() {
	$("#srchoverlay_form").fadeOut(500);
	$("#srchovly").fadeOut(500);
}

function toggledrawer(d) { 
	$(d).toggle(); 
}

function delEvent(vedit,obj,evt) {
	if (confirm('confirm delete '+evt+' ?')) {
		$.get(vedit+'?'+jQuery.param({ object:obj, event:evt, action:'del' }), function(data) {
			alert($("<div/>").html(data).text());
			location.reload();
		});
	}
}
