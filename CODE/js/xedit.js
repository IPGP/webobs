
var editor;
var textarea;
var statusbar;
var buttonvim;
var statusfmsg;

$(document).ready(function() {
	textarea = $('#ta')[0];
	statusbar = $('#statusbar')[0];
	buttonvim = $('#bvim')[0];
	statusfmsg = statusbar.innerHTML;
	CodeMirror.commands.save = function(){ postform(); };

	if (XCB.EDITOK || XCB.ADMOK) {
    	editor = CodeMirror.fromTextArea(textarea, {
	        theme: XCB.ETHEME,
			mode: XCB.MODE,
            lineNumbers: true,
			matchBrackets: true,
			showCursorWhenSelecting: true,
			scrollbarStyle: "null"
	   	});
        CodeMirror.on(editor, 'vim-mode-change', function(e) {
		  if (e.mode == 'normal') statusbar.innerHTML = xeditstatus() ;
		  else statusbar.innerHTML = e.mode;
		});
	} else {
    	editor = CodeMirror.fromTextArea(textarea, {
	        theme: XCB.BTHEME,
			mode: XCB.MODE,
		    scrollbarStyle: "simple",
			readOnly: true,
			scrollbarStyle: "null"
	   	});
	}

	editor.setSize('100%', 400);
	if (XCB.VMODE == 'vim') editor.setOption('vimMode',true);
	statusbar.innerHTML = xeditstatus();
	buttonvim.value = editor.getOption('vimMode') ? 'Vim off' : 'Vim on' ;
	editor.focus();
});
function toggleVim() {
	if (editor.getOption('vimMode')) editor.setOption('vimMode',false);
	else editor.setOption('vimMode',true);
	statusbar.innerHTML = xeditstatus();
	buttonvim.value = editor.getOption('vimMode') ? 'Vim off' : 'Vim on' ;
	editor.focus();
}
function xeditstatus() {
	// editbrowse | vimonoff | filemessage
	var xm = "";
	xm += editor.getOption('readOnly') ? 'Browse' : 'Edit' ;
	xm += editor.getOption('vimMode') ? ' | Vim' : '';
	xm += editor.isClean() ? '' : ' | +';
	xm += (statusfmsg != '') ? ' | '+statusfmsg : '';
	return xm;
}

function postform() {
	editor.save();
	$.post(XCB.ME, $('#theform').serialize(), function(data) {
		   if (data != '') alert(data);
		   history.go(-1);
   	});
}

