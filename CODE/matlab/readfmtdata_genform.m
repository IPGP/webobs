function D = readfmtdata_genform(WO,P,N)
%READFMTDATA_GENFORM subfunction of readfmtdata.m
%
%	From proc P and nodes N, returns data D.
%	See READFMTDATA function for details.
%
%	type: WebObs genform from FORMS
%	DB filename: WO.SQL_FORMS
%	DB table: lowercase(P.FORM.SELFREF)
%	data content format: from structure P.FORM
%	node's CLB: will create autoclb
%
%	will return for selected node N:
%		D.t (datenum)
%		D.d (columns defined in P.FORM.PROC_DATA_LIST)
%		D.e (columns defined in P.FORM.PROC_ERROR_LIST)
%		D.c (comment)
%
%	note: input type list values are converted to numbers in D.d
%
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2024-07-03, in Surabaya (Indonesia)
%	Updated: 2025-01-08

wofun = sprintf('WEBOBS{%s}',mfilename);

F = P.FORM;

tn = lower(F.SELFREF);

fprintf('%s: importing GENFORM data [%s] ...\n',wofun,F.SELFREF);

% test database table and get the number of fields (must exists!)
[s,w] = wosystem(sprintf('sqlite3 %s "pragma table_info(%s)"|wc -l',WO.SQL_FORMS,tn));
if ~s && ~isempty(w)
	nf = str2double(w);
else
	error('%s: table "%s" does not exist in %s...',tn,WO.SQL_FORMS);
end

for n = 1:length(N)
	% datelim is finite dates limits of PROC (or NODE) expressed in the FORM's TZ (same for all nodes)
	datelim = [max([P.DATELIM(1),N(n).INSTALL_DATE,P.BANG]), min([P.DATELIM(2),N(n).END_DATE,P.NOW])] - P.TZ/24 + F.TZ/24;
	d1 = datestr(datelim(1),'yyyy-mm-dd HH:MM:SS');
	d2 = datestr(datelim(2),'yyyy-mm-dd HH:MM:SS');

	% filter the node n within the requested date interval and not in trash
	filter = sprintf('node = ''%s'' AND trash = 0 AND ((sdate BETWEEN ''%s'' AND ''%s'') OR (edate BETWEEN ''%s'' AND ''%s''))',N(n).ID,d1,d2,d1,d2);

	% requests for data associated
	[s,w] = wosystem(sprintf('sqlite3 %s "select * from %s where %s"|iconv -f UTF-8 -t ISO_8859-1',WO.SQL_FORMS,tn,filter));
	if ~s && ~isempty(w)
		lines = textscan(w, '%s', 'delimiter','\n');
		data = regexp(lines{1}, '\|', 'split');
		data = cat(1,data{:}); 
	else
		data = cell(0,nf);
	end
	% data: id, trash, quality, site, edate0, edate1, sdate0, sdate1, opers, rem, ts0, user, input01, ...

	inp = str2double(data(:,13:end)); % inputXX fields (numerical only)

	% computes all outputs of formula type and store results in intermediate structure
	fn = fieldnames(F);
	k = find(~cellfun(@isempty,regexp(fn,'^OUTPUT.._TYPE')));
	out = nan(size(data,1),length(k)); % initiating output matrix
	for i = 1:length(k)
		v = F.(fn{k(i)});
		if ~isempty(regexp(v,'^formula'))
			fml = regexprep(v,'^formula.*:','');
			fml = regexprep(fml,'INPUT(..)','inp(:,$1)'); % replaces input name in string
			fml = regexprep(fml,'OUTPUT(..)','out(:,$1)'); % replaces input name in string
			fml = regexprep(fml,'(\*\*)','.^'); % replaces ** with ^
			fml = regexprep(fml,'(\*|/)','.$1'); % adds point before * and /
			eval(sprintf('out(:,i)=%s;',fml)); % computes the formula
		end
	end

	% export data, errors, names and units
	pdn = strsplit(F.PROC_DATA_LIST,',','CollapseDelimiters',false);
	pen = strsplit(F.PROC_ERROR_LIST,',','CollapseDelimiters',false);
	nx = length(pdn);
	d = nan(size(data,1),nx);
	e = d; % error have same size as data
	nm = cell(1,nx);
	un = cell(1,nx);
	for i = 1:nx
		dd = pdn{i};
		dd = regexprep(dd,'INPUT(..)','inp(:,$1)');
		dd = regexprep(dd,'OUTPUT(..)','out(:,$1)');
		if ~isempty(dd)
			eval(['d(:,i)=',dd,';']);
		end
		dd = pen{i};
		dd = regexprep(dd,'INPUT(..)','inp(:,$1)');
		dd = regexprep(dd,'OUTPUT(..)','out(:,$1)');
		if ~isempty(dd)
			eval(['e(:,i)=',dd,';']);
		end
		nm{i} = F.([pdn{i} '_NAME']);
		nm{i} = F.([pdn{i} '_UNIT']);
	end

	t = datenum(data(:,4));

	D(n).t = t - N(n).UTC_DATA;
	D(n).d = d;
	D(n).e = e;
	D(n).c = data(:,8:11);
	
	% set default names and units to inexistant/unappropriate calibration files of node
	if N(n).CLB.nx ~= nx
		N(n).CLB = mkautoclb(N(n),nm,un);
	else
		% note: calibration files are defined in node's TZ
		[D(n).d,D(n).CLB] = calib(D(n).t,D(n).d,N(n).CLB);
	end
	D(n).t = D(n).t + P.TZ/24;

end
