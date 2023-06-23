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
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2016-07-10, in Yogyakarta (Indonesia)
%	Updated: 2017-08-02

wofun = sprintf('WEBOBS{%s}',mfilename);


f = sprintf('%s/%s',WO.PATH_DATA_DB,P.FORM.FILE_NAME);
if ~exist(f,'file')
	error('%s: %s not found [%s].',wofun,f,P.FORM.SELFREF);
end

fprintf('%s: importing FORM data [%s] ...\n',wofun,P.FORM.SELFREF);

data = readdatafile(f,[],'HeaderLines',1);

% replaces missing hours by '00:00', converts to datenum
data(strcmp(data(:,3),''),3) = {'00:00'};
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
	GMOL = readcfg(WO,sprintf('%s/etc/gmol.conf',WO.ROOT_CODE));
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

	d1 = str2double(data(:,10:3:34)); % windows (fenêtre)
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
	D(n).d = d(k,:);
	D(n).e = e(k,:);
	D(n).t = t(k) - N(n).UTC_DATA;
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

