/*
	Javascript functions for pages using the CodeMirror javascript editor.
	Configuration should be passed using the CODEMIRROR_CONF table.

	Example configuration:

	var CODEMIRROR_CONF = {
		// The CodeMirror theme used when editing a file content / text in
		// read-write mode.
		READWRITE_THEME: 'default',

		// The CodeMirror theme used when editing a file content / text in
		// read-only mode.
		READONLY_THEME: 'default',

		// The CodeMirror language mode to use.
		LANGUAGE_MODE: 'cmwocfg',

		// If 'true' or 'yes' (case-insentive), enter the vim mode as soon on
		// editor setup.
		AUTO_VIM_MODE: 'false',

		// This javascript value should be true if the user has the permission to
		// modify the text content.
		EDIT_PERM: 1,

		// JQuery selector for the form used to write the edited text.
		FORM: '#theform',

		// The URL the form should be submitted to.
		POST_URL: '$SCRIPT_NAME'
	};

	Also note:
	- the textarea to apply the editor to must be #textarea-editor
	- the status bar of the textarea must be #statusbar
	- the checkbox toggling the vim mode should be #toggle-vim-mode
	  (only used to check it on on startup if auto vim mode is enabled)

*/
var editor;
var textarea;
var statusbar;
var statusfmsg;

$(document).ready(function() {
	textarea = $("#textarea-editor")[0];
	statusbar = $("#statusbar")[0];
	statusfmsg = statusbar.innerHTML;
	CodeMirror.commands.save = function(){ alert('submitting'); postform(); };

	if (CODEMIRROR_CONF.EDIT_PERM) {
		editor = CodeMirror.fromTextArea(textarea, {
			theme: CODEMIRROR_CONF.READWRITE_THEME,
			mode: CODEMIRROR_CONF.LANGUAGE_MODE,
			lineNumbers: true,
			matchBrackets: true,
			showCursorWhenSelecting: true,
			//scrollbarStyle: "null"
		});
		CodeMirror.on(editor, 'vim-mode-change', function(e) {
			if (e.mode == 'normal') {
				statusbar.innerHTML = editorStatus();
			} else {
				statusbar.innerHTML = e.mode;
			}
		});
	} else {
		editor = CodeMirror.fromTextArea(textarea, {
			theme: CODEMIRROR_CONF.READONLY_THEME,
			mode: CODEMIRROR_CONF.LANGUAGE_MODE,
			readOnly: true,
			//scrollbarStyle: "null"
		});
	}

	// Set the widht and height of the textarea.
	// Must also be set in codemirror-wo.css.
	editor.setSize('650px', '450px');

	// Automatically enter vim mode if CODEMIRROR_CONF.AUTO_VIM_MODE is 'yes' or 'true'
	// (also 'vim' for backward-compatibility reason with WebObs <= 2.1.4c)
	var auto_vim_mode = CODEMIRROR_CONF.AUTO_VIM_MODE.toLowerCase();
	if (auto_vim_mode == 'yes' || auto_vim_mode == 'true' || auto_vim_mode == 'vim') {
		editor.setOption('vimMode',true);
		// Check the checkbox to show vim mode is on
		$("#toggle-vim-mode").attr('checked', true);
	}
	statusbar.innerHTML = editorStatus();
	editor.focus();
});

function toggleVim() {
	// Toggle vim mode in the editor
	editor.setOption('vimMode', !editor.getOption('vimMode'));
	statusbar.innerHTML = editorStatus();
	editor.focus();
}

function editorStatus() {
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
	$.post(CODEMIRROR_CONF.POST_URL, $(CODEMIRROR_CONF.FORM).serialize(), function(data) {
		if (data != '') alert(data);
		history.go(-1);
	});
}

