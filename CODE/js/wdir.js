$(document).ready(function(){
	$("#newfile").keyup(function(event){
		if(event.keyCode == 13){
			$("#clicknewfile").click();
		}
	});
	$("#newsdir").keyup(function(event){
		if(event.keyCode == 13){
			$("#clicknewsdir").click();
		}
	});
});

function newFile(dir) {
	var fn = $('#newfile').val();
	if (fn.match(/^--|^\s*$|\//)) {
		alert ('invalid filename "'+fn+'"');
		exit;
	}
	location.href = "/cgi-bin/wedit.pl?file="+dir+fn
}

function selFile(dir) { // onClick for newfile input
	var nf = $('#newfile');
	var fn = nf.val();
	if (fn.match(/^--/)) {
		nf[0].setSelectionRange(0, fn.length);
	}
}

function newSdir(dir) {
	var fn = $('#newsdir').val();
	if (fn.match(/^--|^\s*$|\//)) {
		alert ('invalid folder name "'+fn+'"');
		exit;
	}
	location.href = "/cgi-bin/wdir.pl?dir="+dir+"&sdir="+fn
}

function selSdir(dir) { // onClick for new sdir
	var nf = $('#newsdir');
	var fn = nf.val();
	if (fn.match(/^--/)) {
		nf[0].setSelectionRange(0, fn.length);
	}
}

function delFile(dir,file) {
	if (!confirm("Do you really want to delete "+dir+file+" ?")) return false;
	location.href = "/cgi-bin/wdir.pl?dir="+dir+"&del="+file ;
}

