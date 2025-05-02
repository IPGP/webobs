function D = readfmtdata_genform(WO,P,N,F)
%READFMTDATA_GENFORM subfunction of readfmtdata.m
%
%	From proc P, node N and option F, returns data D.
%	See READFMTDATA function for details.
%
%	type: WebObs genform from FORMS
%	DB filename: WO.SQL_FORMS
%	DB table: lowercase(F.raw{1})
%	data content format: from structure FORM.formname
%	node's CLB: will create autoclb for calling PROC (if not exists)
%
%	will return for selected node N:
%		D.t (time or 2-column [T,Tstart] if STARTING_DATE true, datenum format)
%		D.d (columns defined in FORM.PROC_DATA_LIST)
%		D.e (columns defined in FORM.PROC_ERROR_LIST)
%		D.c (operator,comment + columns defined in FORM.PROC_CELL_LIST)
%
%	note: input type list values are converted to numbers in D.d if in PROC_DATA_LIST
%
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2024-07-03, in Surabaya (Indonesia)
%	Updated: 2025-04-28

wofun = sprintf('WEBOBS{%s}',mfilename);

fn = upper(F.raw{1});
tn = lower(fn);
FORM = readcfg(WO,sprintf('%s/%s/%s.conf',WO.PATH_FORMS,fn,fn),'quiet');
tz = field2num(FORM,'TZ',0);
startdate = isok(FORM,'STARTING_DATE');

% test database table and get the number of fields (must exists!)
[s,w] = wosystem(sprintf('sqlite3 %s "pragma table_info(%s)"|wc -l',WO.SQL_FORMS,tn));
if ~s && ~isempty(w)
	nf = str2double(w);
else
	error('%s: table "%s" does not exist in %s...',tn,WO.SQL_FORMS);
end

% datelim is finite dates limits of PROC (or NODE) expressed in the FORM's TZ (same for all nodes)
datelim = [max([P.DATELIM(1),N.INSTALL_DATE,P.BANG]), min([P.DATELIM(2),N.END_DATE,P.NOW])] - P.TZ/24 + tz/24;
d1 = datestr(datelim(1),'yyyy-mm-dd HH:MM:SS');
d2 = datestr(datelim(2),'yyyy-mm-dd HH:MM:SS');

% filter the node n within the requested date interval and not in trash
filter = sprintf('node = ''%s'' AND trash = 0 AND ((sdate BETWEEN ''%s'' AND ''%s'') OR (edate BETWEEN ''%s'' AND ''%s''))',N.ID,d1,d2,d1,d2);

% requests for data associated (all inputs) and converts strings to ISO
[s,w] = wosystem(sprintf('sqlite3 %s "select * from %s where %s"|iconv -f UTF-8 -t ISO_8859-1',WO.SQL_FORMS,tn,filter));
if ~s && ~isempty(w)
    lines = textscan(w, '%s', 'delimiter','\n');
    data = regexp(lines{1}, '\|', 'split');
    data = cat(1,data{:}); 
else
    data = cell(0,nf);
end
fprintf(' %d samples.\n',size(data,1));
% data: id, trash, quality, site, edate0, edate1, sdate0, sdate1, opers, rem, ts0, user, input01, ...

% --- time
% fix potential issue in datetime format (must be yyyy-mm-dd HH:MM)
dte = regexprep(data(:,5:8),'(....).(..).(..)(.*)','$1-$2-$3$4');
dte = regexprep(dte,'(.{10} ..).(..)','$1:$2');
t = datenum(regexprep(dte(:,1),'(.{10} ..).(..)','$1:$2'));
[t,k] = sort(t); % sort the matrix
data = data(k,:);
if startdate
    if any(cellfun(@isempty,dte(:,3)))
        ts = nan(size(t));
    else
        ts = datenum(regexprep(dte(:,3),'(.{10} ..).(..)','$1:$2'));
    end
    t = [t,ts(k)];
end

fn = fieldnames(FORM);

% --- data
inp = str2double(data(:,13:end)); % inputXX fields (numerical only)

% computes all outputs of formula type and store results in intermediate structure
k = find(~cellfun(@isempty,regexp(fn,'^OUTPUT[0-9]{2,3}_TYPE')));
out = nan(size(data,1),length(k)); % initiating output matrix
for i = 1:length(k)
    v = FORM.(fn{k(i)});
    if ~isempty(regexp(v,'^formula'))
        fml = regexprep(v,'^formula.*:',''); % removes 'formula:' tag
        % replaces variables and functions
        fml = regexprep(fml,'PI','pi'); % π
        fml = regexprep(fml,'median\(([^)]*)','rmedian([$1],2'); % median (ignore NaN)
        fml = regexprep(fml,'mean\(([^)]*)','rmean([$1],2'); % mean (ignore NaN)
        fml = regexprep(fml,'std\(([^)]*)','rstd([$1],2'); % std (ignore NaN)
        if startdate
            fml = regexprep(fml,'DURATION','diff(t,2)'); % DURATION (in days)
        end
        % replaces input/output name in string
        fml = regexprep(fml,'INPUT([0-9]{2,3})','inp(:,$1)');
        fml = regexprep(fml,'OUTPUT([0-9]{2,3})','out(:,$1)');
        % specific Matlab syntax
        fml = regexprep(fml,'(\*\*)','.^'); % replaces ** with ^
        fml = regexprep(fml,'(\*|/)','.$1'); % adds point before * and /
        eval(sprintf('out(:,i)=%s;',fml)); % computes the formula
    end
end

% export data, errors, names and units
pdn = split(field2str(FORM,'PROC_DATA_LIST',''),','); % list of numerical INPUT/OUTPUT to export
pen = split(field2str(FORM,'PROC_ERROR_LIST',''),','); % list of corresponding errors
pcn = split(field2str(FORM,'PROC_CELL_LIST',''),','); % list of text INPUT/OUTPUT to export
nx = length(pdn);
d = nan(size(data,1),nx);
e = d; % error have same size as data
nm = cell(1,nx);
un = cell(1,nx);
for i = 1:nx
    dd = pdn{i};
    dd = regexprep(dd,'INPUT([0-9]{2,3})','inp(:,$1)');
    dd = regexprep(dd,'OUTPUT([0-9]{2,3})','out(:,$1)');
    if ~isempty(dd)
        eval(['d(:,i)=',dd,';']);
    end
    if length(pen) >= i
        dd = pen{i};
        dd = regexprep(dd,'INPUT([0-9]{2,3})','inp(:,$1)');
        dd = regexprep(dd,'OUTPUT([0-9]{2,3})','out(:,$1)');
        if ~isempty(dd)
            eval(['e(:,i)=',dd,';']);
        end
    end
    nm{i} = field2str(FORM,[pdn{i} '_NAME']);
    un{i} = field2str(FORM,[pdn{i} '_UNIT']);
end

D.t = t - N.UTC_DATA;
D.d = d;
D.e = e;
D.c = data(:,9:10);

% set default names and units to inexistant/unappropriate calibration files of node
if N.CLB.nx ~= nx
    N.CLB = mkautoclb(N,nm,un);
end
% note: calibration files are defined in node's TZ
[D.d,D.CLB] = calib(D.t,D.d,N.CLB);
D.t = D.t + P.TZ/24;

