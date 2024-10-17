function D = readfmtdata_woform(WO,P,N)
%READFMTDATA_WOFORM subfunction of readfmtdata.m
%
%	From proc P and nodes N, returns data D.
%	See READFMTDATA function for details.
%
%	type: WebObs databank from FORMS
%	data filename: WO.PATH_DATA_DB/P.FORM.FILE_NAME
%	data format: ID|YYYY-MM-DD|HH:MM|NODEID|data1|data2|...|dataN
%	negative ID's (trash) data will be ignored
%	specific treatments apply to several forms:
%	node's CLB: considered if exists AND has the right number of channels
%	(see below)
%
%	form 'EAUX'
%		D.t (datenum)
%		D.d (27 columns)
%
%	form 'GAZ'
%		D.t (datenum)
%		D.d (18 columns)
%
%	form 'EXTENSO'
%		D.t (datenum)
%		D.d (Distance Temp Wind)
%		D.e (Distance Temp Wind)
%
%	form 'RIVERS'
%		D.t (datenum)
%		D.d (18 columns)
%
%	form 'RAINWATER'
%		D.t (datenum)
%		D.d (18 columns)
%
%	form 'SOILSOLUTION'
%		D.t (datenum)
%		D.d (18 columns)
%
%	**WARNING** this file must be iso-8859 (unicode) encoded and NOT utf-8
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2016-07-10, in Yogyakarta (Indonesia)
%	Updated: 2024-10-03

wofun = sprintf('WEBOBS{%s}',mfilename);

GMOL = readcfg(WO,sprintf('%s/etc/gmol.conf',WO.ROOT_CODE));

if ~ismember(P.FORM.SELFREF,{'EAUX','GAZ','EXTENSO','RAINWATER','SOILSOLUTION','RIVERS'})
	error('%s: unknown woform [%s].',wofun,P.FORM.SELFREF);
end

fprintf('%s: importing FORM data [%s] ...\n',wofun,P.FORM.SELFREF);

f = sprintf('%s/%s',WO.PATH_DATA_DB,P.FORM.FILE_NAME);
data = readdatafile(f,[],'HeaderLines',1);

% replaces missing hours by default time, converts to datenum
deftime = field2str(P.FORM,'DEFAULT_SAMPLING_TIME','00:00','notempty');
data(strcmp(data(:,3),''),3) = {deftime};
t = datenum(strcat(data(:,2),{' '},data(:,3),{':00'}));

switch P.FORM.SELFREF

case 'EAUX'
	FT = readcfg(WO,sprintf('%s/%s',P.FORM.ROOT,P.FORM.FILE_TYPE));
	tcod = fieldnames(FT);
	% replaces site type of sampling by a number
	for i = 1:length(tcod)
		data(strcmp(data(:,5),tcod(i)),5) = {num2str(i)};
	end
	% converts all fields to number (after replacing french decimal points)
	d = str2double(regexprep(data(:,5:26),',','.'));
	% converts concentrations to mmol/l
	elm = {'Li','Na','K','Mg','Ca','F','Cl','Br','NO3','SO4','HCO3','I'};
	for i = 1:length(elm)
		d(:,i+7) = d(:,i+7)/str2double(GMOL.(elm{i}));
	end
	% adds 5 new columns with chemical ratios an NICB
	d(:,23) = d(:,14)./d(:,17);
	d(:,24) = d(:,18)./d(:,17);
	d(:,25) = d(:,11)./d(:,14);
	d(:,26) = d(:,6)./(1+.02*(d(:,3)-25));
	% computes NICB (Mg++, Ca++ and SO4-- are double counted)
	cations = rsum(d(:,[8,9,10,11,11,12,12])');
	anions = rsum(d(:,[13,14,15,16,17,17,18])');
	d(:,27) = 100*((cations - anions)./(cations + anions))';

	e = zeros(size(d));
	nm = {'type','TA','TS','pH','Flux','Cond','Level','Li+','Na+','K+','Mg++','Ca++','F-','Cl-','Br-','NO3-','SO4--','HCO3-','I-', ...
		'\delta^{13}C','\delta^{18}O','{\delta}D','Cl-/SO4-- ','HCO3-/SO4--','Mg++/Cl-','Cond_{25}','NICB'};
	un = {    '','°C','°C',  '','l/mn',  'µS',    'm','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l', ...
		    '',    '',  '',          '',           '',        '',    'µS',   '%'};

	D = share2nodes(t,d,e,data(:,4),P,N,nm,un);

case 'GAZ'
	FT = readcfg(WO,sprintf('%s/%s',P.FORM.ROOT,P.FORM.FILE_TYPE));
	tcod = fieldnames(FT);
	% replaces site type of sampling by a number
	for i = 1:length(tcod)
		data(strcmp(data(:,9),tcod(i)),9) = {num2str(i)};
	end
	% converts all fields to number (after replacing french decimal points)
	d = str2double(regexprep(data(:,5:22),',','.'));
	d(isnan(d(:,5)),5) = 1;	% type NaN is forced to 1 (none)

	% adds 1 new column with S/C ratio
	d(:,18) = (d(:,11)+d(:,14))./d(:,13);

	e = zeros(size(d));
	nm = {'Temperature','pH','Flux',  'Rn','type','H_2','He','CO','CH_4','N_2','H_2S','Ar','CO_2','SO_2','O_2','\delta^{13}C','\delta^{18}O','S/C'};
	un = {  '°C',  '',   '-','#/mn',    '', '%', '%', '%',  '%', '%',  '%', '%',  '%',  '%', '%',    '',    '',   ''};

	D = share2nodes(t,d,e,data(:,4),P,N,nm,un);

case 'EXTENSO'
	d1 = str2double(data(:,10:3:34)); % windows (fentre)
	d2 = str2double(data(:,11:3:35)); % faces (cadran)
	d2(isnan(d2)) = 0;	% forces void faces to 0
	d3 = str2double(data(:,12:3:36)); % wind speed
	d = [sum(str2double(data(:,8:9)),2) + rmean(d1+d2,2), ...	% sum of offset + ribbon + (windows + faces) average
		str2double(data(:,6)), ...	% temperature
		rmean(d3,2), ...	% wind speed average
	];

	e = [2*rstd(d1+d2,2),ones(size(d1,1),1),2*rstd(d3,2)];	% errors = 2*standard deviation
	e(e==0) = 1;	% forces error = 1

	nm = {'Distance','TempAir','Wind'};
	un = {      'mm',     '°C',   '-'};

	D = share2nodes(t,d,e,data(:,4),P,N,nm,un);

case 'FISSURO'
	d1 = str2double(data(:,10:3:34)); % perpendicular (opening)
	d2 = str2double(data(:,11:3:35)); % parallel (senestral)
	d3 = str2double(data(:,12:3:36)); % vertical
	d = [rmean(d1,2),rmean(d2,2),rmean(d3,2); ...	% 3-component fissurometer averages
		str2double(data(:,6)), ...	% temperature
	];

	e = [2*rstd(d1,2),2*rstd(d2,2),2*rstd(d3,2)];	% errors = 2*standard deviation
	e(e==0) = 1;	% forces error = 1

	nm = {'Perp.','Para.','Vert.','TempAir'};
	un = {   'mm',   'mm',   'mm',  '°C'};

	D = share2nodes(t,d,e,data(:,4),P,N,nm,un);

case 'RAINWATER'
	data(strcmp(data(:,6),''),3) = {deftime};
	t2 = datenum(strcat(data(:,5),{' '},data(:,6),{':00'}));
	% converts all fields to number (after replacing french decimal points)
	dd = str2double(regexprep(data(:,7:19),',','.'));
	dr = 10*dd(:,1)./(pi*(dd(:,2)/2).^2)./(t-t2); % daily rain (mm/day)
	d = [dr,dd(:,3:end)];
	% converts concentrations to mmol/l
	elm = {'Na','K','Mg','Ca','HCO3','Cl','SO4'};
	for i = 1:length(elm)
		d(:,i+3) = d(:,i+3)/str2double(GMOL.(elm{i}));
	end
	% adds 4 new columns with chemical ratios an NICB
	% [FB:Todo] use ratios.conf file to build selected ratios only
	d(:,13) = d(:,9)./d(:,4); % Cl/Na
	d(:,14) = d(:,10)./d(:,4); % SO4/Na
	d(:,15) = d(:,6)./d(:,4); % Mg/Na
	% computes NICB (Mg++, Ca++ and SO4-- are double counted)
	cations = rsum(d(:,[4,5,6,6,7,7])');
	anions = rsum(d(:,[8,9,10,10])');
	d(:,16) = 100*((cations - anions)./(cations + anions))';

	e = zeros(size(d));
	nm = {'Rainmeter','pH','Cond','Na+','K+','Mg++','Ca++','HCO3-','Cl-','SO4--', ...
		'{\delta}D','\delta^{18}O','Cl-/Na+ ','SO4--/Na+','Mg++/Na+','NICB'};
	un = {    'mm/day',  '',  'µS', 'mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l', ...
		    '%{\fontsize{5}o}',    '%{\fontsize{5}o}',    '',      '',      '',  '%'};

	D = share2nodes(t,d,e,data(:,4),P,N,nm,un);

case 'SOILSOLUTION'
	data(strcmp(data(:,6),''),3) = {deftime};
	duration = t - datenum(strcat(data(:,5),{' '},data(:,6),{':00'}));
	% adds duration from t2 and onverts all fields to number (after replacing french decimal points)
	d = [duration,str2double(regexprep(data(:,7:20),',','.'))];
	% converts concentrations to mmol/l
	elm = {'Na','K','Mg','Ca','HCO3','Cl','NO3','SO4'};
	for i = 1:length(elm)
		d(:,i+5) = d(:,i+5)/str2double(GMOL.(elm{i}));
	end
	% adds 4 new columns with chemical ratios an NICB
	% [FB:Todo] use ratios.conf file to build selected ratios only
	d(:,16) = d(:,11)./d(:,6); % Cl/Na
	d(:,17) = d(:,13)./d(:,6); % SO4/Na
	d(:,18) = d(:,8)./d(:,6); % Mg/Na
	% computes NICB (Mg++, Ca++ and SO4-- are double counted)
	cations = rsum(d(:,[6,7,8,8,9,9])');
	anions = rsum(d(:,[10,11,12,13,13])');
	d(:,19) = 100*((cations - anions)./(cations + anions))';

	e = zeros(size(d));
	nm = {'Duration','Depth','Level','pH','Cond','Na+',  'K+',    'Mg++',  'Ca++',  'HCO3-', 'Cl-',   'NO3-',  'SO4--', ...
		'SiO2','DOC','Cl-/Na+ ','SO4--/Na+','Mg++/Na+','NICB'};
	un = {    'day', 'cm'   , ''    ,'',  'µS', 'mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l', ...
		'ppm', 'ppm','',        '',         '',        '%'};

	D = share2nodes(t,d,e,data(:,4),P,N,nm,un);

case 'RIVERS'
	% type of sampling
	FT = readcfg(WO,sprintf('%s/%s',P.FORM.ROOT,P.FORM.FILE_TYPE));
	tcod = fieldnames(FT);
	% replaces type of sampling by a number
	for i = 1:length(tcod)
		data(strcmp(data(:,6),tcod(i)),6) = {num2str(i)};
	end
	% type of flacon (bottle)
	FB = readcfg(WO,sprintf('%s/%s',P.FORM.ROOT,P.FORM.FILE_FLACONS));
	tcod = fieldnames(FB);
	% replaces type of bottle by a number
	for i = 1:length(tcod)
		data(strcmp(data(:,7),tcod(i)),7) = {num2str(i)};
	end
	% converts all fields to numbers (after replacing french decimal points)
	d = str2double(regexprep(data(:,5:end),',','.'));
	% converts concentrations to mmol/l
	elm = {'Na','K','Mg','Ca','HCO3','Cl','SO4'};
	for i = 1:length(elm)
		d(:,i+7) = d(:,i+7)/str2double(GMOL.(elm{i}));
	end
	% adds 5 new columns with chemical ratios an NICB
	d(:,19) = d(:,14)./d(:,8); % SO4/Na
	d(:,20) = d(:,13)./d(:,8); % Cl/Na
	d(:,21) = d(:,11)./d(:,8); % Ca/Na
	d(:,22) = d(:,10)./d(:,8); % Mg/Na
	% computes NICB (Mg++, Ca++ and SO4-- are double counted)
	cations = rsum(d(:,[8,9,10,10,11,11])');
	anions = rsum(d(:,[12,13,14,14])');
	d(:,23) = 100*((cations - anions)./(cations + anions))';

	e = zeros(size(d));
	nm = {'level','type','flacon','TR','Sload','pH','Cond25','Cond','Na+','K+','Mg++','Ca++','HCO3-','Cl-','SO4--','SiO2','DOC','POC', ...
		'SO4/Na','Cl/Na','Ca/Na','Mg/Na','NICB'};
	un = { 'm','','','°C','mg/L',  '','µS',  'µS','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','mmol/l','ppm','ppm','ppm', ...
		    '',    '',  '',      '',   '%'};

	D = share2nodes(t,d,e,data(:,4),P,N,nm,un);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function D=share2nodes(t,d,e,si,P,N,nm,un)
% shares raw data into nodes

% sort data by chronological order
[t,k] = sort(t);
d = d(k,:);
e = e(k,:);
si = si(k);

for n = 1:length(N)
	k = find(strcmp(si,N(n).ID));	% selects data from site (node's ID)
	D(n).t = t(k) - N(n).UTC_DATA;
	D(n).d = d(k,:);
	D(n).e = e(k,:);
	% set default names and units to inexistant/unappropriate calibration files of node
	if N(n).CLB.nx ~= length(nm)
		D(n).CLB.nx = length(nm);
		D(n).CLB.nv = 1:length(nm);
		D(n).CLB.nm = nm;
		D(n).CLB.un = un;
	else
		% note: calibration files are defined in node's TZ
		[D(n).d,D(n).CLB] = calib(D(n).t,D(n).d,N(n).CLB);
	end
	D(n).t = D(n).t + P.TZ/24;
end
