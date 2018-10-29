// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: http://codemirror.net/LICENSE

// WebObs configuration files syntax
// To be used with a theme having distinct colors for comment,keyword,operator,qualifier
// such as ambiance.css

(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
    mod(require("/js/codemirror/lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["/js/codemirror/lib/codemirror"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
  "use strict";

  function errorIfNotEmpty(stream) {
    var nonWS = stream.match(/^\s*\S/);
    stream.skipToEnd();
    return nonWS ? "error" : null;
  }

  CodeMirror.defineMode("cmwocfg", function() {
    return {

	token: function(stream, state) {
		var m;
		if (stream.match(/\s*#.*$/)) return "comment";
		if (stream.sol() && (m = stream.match(/^\=.*\|.*$/))) {
			state.type = "keys";
			return "qualifier";
		}
		if (state.type == "keys") {
			if (stream.sol()) {
			 	if (stream.match(/.+?(?=[\|#])/)) return "keyword";
			}
			if (stream.next() == '|') return "operator"; 
			if (stream.match(/.+?(?=[\|#])/)) return null;
			if (stream.match(/.+?\s$/)) return null;
		} else {
			if (stream.sol()) {
				if (stream.peek() == '*') state.admin = 1;
				else state.admin = null;
			}
			if (stream.match(/<a[^>]*>/)) {
				state.href = 1;
				return state.admin ? "keyword" : "operator";
			}
			if (stream.match(/<\/a>/)) {
				state.href = null;
				return state.admin ? "keyword" : "operator";
			} else {
				if (state.href) {
					stream.next();
					return state.admin ? "atom" : "qualifier";
				}
			}
			stream.next();
			return state.admin ? "special" : null;
		}
		stream.skipToEnd();
		return null;
	},

	startState: function() {
		return { state: "top", type: null, href: null, admin: null }
	}

    }
  });

});
