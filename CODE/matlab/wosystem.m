function varargout = wosystem(cmd,varargin)
%WOSYSTEM Execute system command and return result.
%	[status,result] = WOSYSTEM('command') works exactly like SYSTEM() 
%	function excepted it displays the result string in case of command
%	error, i.e., non-null exit status (return code).
%
%	WOSYSTEM('command') without output argument, or 
%	[status,result] = WOSYSTEM('command','error') both will produce a 
%	Matlab error if the command is unsuccessful.
%
%	WOSYSTEM('command','warning') without output argument forces the
%	warning mode (no Matlab error in case of non-null exist status).
%
%	Additional optional arguments are:
%
%	     'error' : forces the error mode.
%	   'warning' : forces the error mode.
%	     'print' : returns result string as first output argument.
%	     'chomp' : removes last '\n' from result string.
%	     'debug' : displays more log information.
%
%	WOSYSTEM('command',P,options) passes the structure P (e.g. from a
%	PROC's configuration).
%
%
%	Author: F. Beauducel, WEBOBS
%	Created: 2017-02-02 in Yogyakarta, Indonesia
%	Updated: 2017-09-11

if nargin < 1
	error('Not enough input argument.');
end

ST = dbstack;
if length(ST) < 2
	wofun = '';
else
	wofun = sprintf('\nWEBOBS{%s}: ',ST(2).name);
end

cmd = strcat('export LD_LIBRARY_PATH=;', cmd);
msg = sprintf('\n%s%s\n',wofun,cmd);

[s,w] = system(cmd);

if s || any(strcmpi(varargin,'debug')) || (nargin > 1 && (isok(varargin{1},'DEBUG')))
	display(regexprep(msg,'\','\\'));
end

% if unsuccessful, displays the result
if s
	% ERROR mode: will stop with error if command unsuccessful 
	if (nargout == 0 || any(strcmpi(varargin,'error'))) && ~any(strcmpi(varargin,'warning'))
		error('%s command unsuccessful [rc = %d]: %s',wofun,s,w);
	else
		fprintf('%s** WARNING ** command unsuccessful [exit status = %d]:\n%s',wofun,s,w);
	end
end

% 'chomp' option: removes any \n from result string
if any(strcmpi(varargin,'chomp'))
	w = regexprep(w,'\n*$','');
end

% 'print' option: returns result as first argument
if any(strcmpi(varargin,'print'))
	varargout{1} = w;
elseif nargout > 0
	varargout{1} = s;
end

if nargout > 1
	varargout{2} = w;
end
