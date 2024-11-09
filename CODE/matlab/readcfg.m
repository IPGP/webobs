function X=readcfg(varargin);
%READCFG Read WEBOBS configuration files
%   WO=READCFG returns a structure variable WO containing every field key and
%   corresponding value from default "/etc/webobs.d/WEBOBS.rc". It applies
%   variable substitutions:
%   	${KEY} for internal conf variable KEY
%   	$WEBOBS{KEY} for WEBOBS.rc variable KEY
%
%   X=READCFG(CONFIG) or READCFG(WO,CONFIG) reads the config file CONFIG. It
%   returns different structure format depending on config file header:
%
%   	no header or =key|value
%   		X.KEY1 = value1
%   		X.KEY2 = value2
%   		...
%
%   	=key|field1|field2|...|fieldN
%   		X.KEY1.field1 = value11
%   		X.KEY1.field2 = value12
%   		...
%   		X.KEY2.field1 = value21
%   		...
%
%   	NOTE: because Matlab does not accept field names starting with a number,
%   	the function adds a prefix 'KEY' to any numerical key.
%
%   X=READCFG(...,'keyarray') uses the key as a numerical index in a
%   structure array where each line corresponds to an element of the structure:
%
%   	no header or =key|value
%   		X(1).value = value1
%   		X(2).value = value2
%   		...
%
%   	=key|field1|field2|...|fieldN
%   		X(1).field1 = value11
%   		X(1).field2 = value12
%   		...
%   		X(2).field1 = value21
%   		...
%   	NOTE: the key field must be positive integers.
%
%
%   Authors: François Beauducel, Didier Lafon, WEBOBS/IPGP
%   Created: 2013-02-22 in Paris (France)
%   Updated: 2022-11-26

if nargin > 0 && isstruct(varargin{1})
	WO = varargin{1};
	conf = varargin{2};
else
	% reads default WEBOBS.rc
	fprintf('WEBOBS{%s}: ',mfilename);
	WO = rfile;
	if nargin > 0
		conf = varargin{1};
	end
end


% --- no input argument: reads and returns WO from WEBOBS.rc
if nargin < 1
	 X = WO;
else
	fprintf('WEBOBS{%s}: ',mfilename);
	if ~isempty(regexp(conf,'/'))
		f = conf;
	else
		f = sprintf('/etc/webobs.d/%s',conf);
	end
	% allows WO variable substitution in f (using ${VAR} syntax)
	f = varsub(f,WO);

	if ~exist(f,'file')
		error('config file %s does not exist.',f);
	end

	% --- 'keyarray' option: reads specific file and returns a key array
	if nargin > 1 && any(strcmp(varargin,'keyarray'))
		Y = rfile(WO,f,1);
		for n = fieldnames(Y)'
			x = round(str2double(regexprep(n,'KEY','')));
			if ~isnan(x) & x > 0
				X(x) = Y.(n{:});
			end
		end
	% --- returns a key|value structure from file f
	else
		if nargin > 1 && any(strcmp(varargin,'novsub'))
			X = rfile(WO,f,0,'nobsub');
		else
			X = rfile(WO,f,0);
		end
	end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function X = rfile(WO,f,mode,novsub)
%RF actually read the configuration file f
%  mode = 0 : key|value conf file (default)
%  mode = 1 : key array
%    novsub : no internal variable substitution

if nargin < 2
	f = '/etc/webobs.d/WEBOBS.rc';
end
if nargin < 3
	mode = 0;
end
if nargin < 4
	novsub = false;
else
	novsub = true;
end


fprintf('%s ... ',f);

% reads all the file content in a single string
sraw = fileread(f);
if ~isoctave
	% clears escaped new lines
	sraw = regexprep(sraw,'\\(\r\n|\n)\s*','');
end

s = textscan(sraw,'%s','CommentStyle','#','Delimiter','\n');

df = [];

for i = 1:size(s{:},1)
	ss = s{1}{i};
	if isempty(ss), continue, end

	%FB-was: if strncmp(ss,'=',1)
	if strncmp(ss,'=key',4)
		df = textscan(ss,'%s','Delimiter','|');
		continue
	end
	if length(df{1}) <= 2 && mode==0
		% in case of 2-column format, value is all after the first | and end-line comment is allowed
		wrk = textscan(ss,'%s%[^\n]','Delimiter','|','CollectOutput',1);
	else
		wrk = { regexp(ss, '(?<!\\)\|', 'split') };
		wrk = wrk';
	end
	key = '';
	if length(wrk{1}) > 0
		key = strtrim(wrk{1}{1});
	end
	if ~isempty(key)
		% in case of numeric key, adds a prefix 'KEY' to key name !
		if ~isletter(key(1))
			key = strcat('KEY',key);
		end
		if length(df{1}) <= 2 && mode==0
			val = '';
			if length(wrk{1}) > 1
				val = strtrim(stresc(wrk{1}{2}));
				if ~isoctave
					% deletes end-line comment (if # not escaped as \#)
					val = regexprep(val,'[^\\]#.*$','');
				end
			end
			% if key contains dots, produces sub-structures
			skey = split(key,'.');
			switch length(skey)
			case 2
				X.(skey{1}).(skey{2}) = val;
			case 3
				X.(skey{1}).(skey{2}).(skey{3}) = val;
			otherwise
				X.(skey{1}) = val;
			end
		else
			for j = 2:length(df{1})
				key2 = '';
				val = '';
				if length(df{1}{j}) > 0
					key2 = strtrim(df{1}{j});
				end
				if ~isempty(key2) && isletter(key2(1))
					if length(wrk{1}) >= j
						val = strtrim(stresc(wrk{1}{j}));
					end
					X.(key).(key2) = val;
				end
			end
		end
	end
end

if length(df{1}) <= 2 && mode==0

	if ~novsub
		% makes internal KEY variable substitution
		X = vsub(X,'[\$][\{](.*?)[\}]');
	end

	% makes WEBOBS variable substitution
	if exist('WO','var')
		X = vsub(X,'[\$]WEBOBS[\{](.*?)[\}]',WO);
	end
end

fprintf('read.\n');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function s = stresc(x)
%STRESC Replaces escape characters in string X.

if ~isempty(x)
	s = strrep(x,'\#','#');
	s = strrep(s,'\|','|');
else
	s = '';
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function X = vsub(X,pat,W)
%VSUB Variable substitution in structure X, pattern PAT
%	If W provided, uses it to substitute $WEBOBS{} variables

keys = fieldnames(X);
for i = 1:length(keys)
	if ~isempty(X.(keys{i})) && ~isstruct(X.(keys{i}))
		s = regexp(X.(keys{i}),pat,'tokens');
		if ~isempty(s)
			for j = 1:length(s)
				if nargin < 3
					if isfield(X,s{j}{:})
						X.(keys{i}) = regexprep(X.(keys{i}),['\${' s{j}{:} '}'],regexprep(X.(s{j}{:}),'\${','\\${'));
					end
				else
					if isfield(W,s{j}{:})
						X.(keys{i}) = regexprep(X.(keys{i}),['\$WEBOBS{' s{j}{:} '}'],regexprep(W.(s{j}{:}),'\${','\\${'));
					end
				end
			end
			if ~isempty(strfind(X.(keys{i}),'${'))
				fprintf(' ** WARNING ** key %s contains undefined variable "%s", replaces with empty value! ',keys{i},X.(keys{i}));
				X.(keys{i}) = '';
			end
		end
	end
	% for NODE's config, associated PROC's parameters are in substructures like N.PROC.name.key
	if strcmp(keys{i},'PROC') && isstruct(X.PROC)
		proc = fieldnames(X.PROC);
		for p = 1:length(proc)
			keyp = fieldnames(X.PROC.(proc{p}));
			for k = 1:length(keyp)
				if ~isempty(X.PROC.(proc{p}).(keyp{k}))
					s = regexp(X.PROC.(proc{p}).(keyp{k}),pat,'tokens');
					if ~isempty(s)
						for j = 1:length(s)
							if nargin < 3
								if isfield(X,s{j}{:})
									X.PROC.(proc{p}).(keyp{k}) = regexprep(X.PROC.(proc{p}).(keyp{k}),['\${' s{j}{:} '}'],regexprep(X.(s{j}{:}),'\${','\\${'));
								end
							else
								if isfield(W,s{j}{:})
									X.PROC.(proc{p}).(keyp{k}) = regexprep(X.PROC.(proc{p}).(keyp{k}),['\$WEBOBS{' s{j}{:} '}'],regexprep(W.(s{j}{:}),'\${','\\${'));
								end
							end
						end
					end
				end
			end
		end
	end
end
