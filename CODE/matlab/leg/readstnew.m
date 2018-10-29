function S = readst(grids,op,tlim,clb);
%READST Read nodes info from WEBOBS database
%       READST imports all stations info and returns a structure S with fields:" 
%           - S.cod = station ID code (7 char)
%           - S.ali = station alias code
%           - S.dat = station data code
%           - S.nom = station full name
%           - S.geo = vector of geographics coordinates WGS84 [Lat Lon Elv]
%                     in decimal degrees and meters for elevation
%           - S.wgs = vector of coordinates UTM WGS84 [East Nord Up] in meters
%           - S.utm = vector of coordinates in local Transverse Mercator [East Nord up] in meters
%           - S.dte = date of positionning (in DATENUM format)
%           - S.pos = type of positionning (0 = unknown, 1 = Map, 2 = GPS)
%           - S.ope = station validity/activity (0 = unvalid, 1 = valid and active, -1 = valid and inactive)
%           - S.ins = date of start / installation (string)
%           - S.fin = date of end / stop (string)
%           - S.clb = sub-structure for sensor calibration:
%                  .nx = number of channels
%                  .dt = vector of validity (format DATENUM): 
%                  .nv = vector for channel numbers (1 to nx);
%                  .nm = vector for channel names;
%                  .un = vector for channel units;
%                  .ns = vector for serial numbers;
%                  .cd = vector for sensor codes/names;
%                  .of = vector for offsets;
%                  .et = vector for calibration factors;
%                  .ga = vector for gains;
%                  .vn = vector for minimum values (raw data);
%                  .vm = vector for maximum values (raw data);
%                  .az = vector for sensor azimuth orientation (°N);
%                  .la = vector for sensor latitude coordinate (°N);
%                  .lo = vector for sensor longitude coordinate (°E);
%                  .al = vector for sensor elevation (m);
%           Example: for the station i, S.clb(i).nx is the number of channels, S.clb(i).ga
%           is a vector of gains corresponding to channels numbers S.clb(i).nv and dates of
%           validity S.clb(i).dt
%
%       READST(R) where R = {R1,R2,..} is a list of network codes, selects the corresponding
%           stations. Examples: 
%           READST({'GSZ ','GSL'}) returns all thestations from networks GSZ and GSL (short-period and broad-band in Guadeloupe);
%           READST('GDD') returns stations from network GDD (EDM in Guadeloupe).
%
%       READST(R,OBS) specifies the operator/observatory OBS (default is all). To select all the stations,
%       use READST('','',...).
%
%       READST(R,OBS,0) returns also the unvalid stations.
%
%       READST(R,OBS,OP,TLIM)
%
%       READST(R,OBS,OP,TLIM,0) do not read the calibration files (save time).
%       

%   Author: F. Beauducel, OVSG-IPGP
%   Created : 2001-08-17
%   Updated : 2010-06-11
%   Convrtd : 2013-04-11

%DL-was: X = readconf;
%DL-new: start WO check: must have WO loaded
global WO;
readcfg;
%DL-new: end WO check

%DL-was: start traitement des arguments d'entrée
%  if nargin < 1
%  	cd = {''};        % défaut = toutes les stations
%  else
%  	cd = cellstr(cd);
%  end
%  if nargin < 2
%  	ob = {''};        % défaut = tous les observatoires
%  %end
%  %if length(ob) == 0
%  %	OBS = readgr('OBSERVATOIRE');
%  %	ob = OBS.cod;        % default = tous les observatoires
%  else
%  	ob = cellstr(ob);
%  end	
%  if nargin < 3
%  	op = 1;         % default = valid station only
%  end
%  if nargin < 4
%  	tlim = [now;now];
%  else
%  	tlim = datenum(tlim);
%  end
%  if nargin < 5
%  	clb = 1;
%  end
%DL-was: end traitement des arguments d'entrée

if nargin < 1
	%FB-was: grids = {''};
	G = dir(sprintf('%s/*',WO.PATH_VIEWS));
	grids = strcat('VIEW.',{G(~ismember({G.name},{'.','..'})).name});
else
	if ~iscell(grids)
		grids = cellstr(grids);
	end
end

if nargin < 2 
	op = 1;
end 

if nargin < 3 
	tlim = [now;now];
else
	tlim = datenum(tlim);
end

if nargin < 4
	clb = 1;
end 


NODES = readcfg(WO.CONF_NODES);
cod = [];  ali = [];  lat = [];  lon = [];  alt = [];  pos = [];  dte = [];  ope = [];  dat = [];  fin = [];  nom = [];  ins = [];  typ = [];  tra = [];  lst = []; C = [];

%DL-was: liste des stations
%  for i = 1:length(ob)
%  	for ii = 1:length(cd)
%  		ST = dir(sprintf('%s/%s%s*',X.RACINE_DATA_STATIONS,ob{i},cd{ii}));
%  		for iii = 1:length(ST)
%  			% lecture du fichier .conf
%  			f = sprintf('%s/%s/%s.conf',X.RACINE_DATA_STATIONS,ST(iii).name,ST(iii).name);
%  			if exist(f,'file')
%  				% disp(sprintf('Lecture de la config de la station %s',ST(iii).name));
%DL-was: end loop thru stations				
for i = 1:length(grids)
	k = 0;
	g = grids{i};
	%FB-was: D = dir(sprintf('%s/PROC.%s.*',WO.PATH_GRIDS2NODES,g));
	D = dir(sprintf('%s/%s.*',WO.PATH_GRIDS2NODES,g));
	for iii = 1:length(D)
		n = split(D(iii).name,'.');
		X = readnode(sprintf('%s/%s/%s.cnf',NODES.PATH_NODES,n{3},n{3}));
		cod = [cod;{n{3}}];
		if isfield(X,'NAME')  nom = [nom;{X.NAME}];  else nom = [nom;{''}]; end
		if isfield(X,'ALIAS') ali = [ali;{X.ALIAS}]; else ali = [ali;{''}]; end
		if isfield(X,'FID')   dat = [dat;{X.FID}];   else dat = [dat;{''}]; end
		if isfield(X,'VALID') ope = [ope;X.VALID]; else ope = [ope;0]; end
		if isfield(X,'INSTALL_DATE') ins = [ins;X.INSTALL_DATE]; else ins = [ins;0]; end
		if isfield(X,'END_DATE')     fin = [fin;X.END_DATE];  else fin = [fin;0]; end
		if isfield(X,'LAT_WGS84')    lat = [lat;X.LAT_WGS84]; else lat = [lat;0]; end
		if isfield(X,'LON_WGS84')    lon = [lon;X.LON_WGS84]; else lon = [lon;0]; end
		if isfield(X,'ALTITUDE')     alt = [alt;X.ALTITUDE];  else alt = [alt;0]; end
		if isfield(X,'POS_DATE')     dte = [dte;X.POS_DATE];  else dte = [dte;0]; end
		if isfield(X,'POS_TYPE')     pos = [pos;X.POS_TYPE];  else pos = [pos;0]; end
		if isfield(X,'TRANSMISSION') tra = [tra;{X.TRANSMISSION}]; else tra = [tra;{''}]; end
		if isfield(X,'LAST_DELAY')   lst = [lst;X.LAST_DELAY]; else lst = [lst;0]; end
		% Attribue ope = -1 pour les stations inactives
		%DL-was: date0 = isodatenum(ins{end}); 
		%DL-was: date1 = isodatenum(fin{end}); 
		if (~isnan(fin(end)) & fin(end) < tlim(1)) || (~isnan(ins(end)) & ins(end) > tlim(2))
			ope(end) = -1;
		end

		% lecture du fichier type.txt
		%DL-was: f = sprintf('%s/%s/type.txt',X.RACINE_DATA_STATIONS,ST(iii).name);
		f = sprintf('%s/%s/type.txt',NODES.PATH_NODES,n{3});
		if exist(f,'file')
			xt = textread(f,'%s','delimiter','');
			if isempty(xt)
				xt = {''};
			end
		else
			xt = {''};
		end
		typ = [typ;xt];

		if clb
			% lecture du fichier .clb
			f = sprintf('%s/%s/%s.clb',NODES.PATH_NODES,n{3},n{3});
			CC = struct('nx',0,'dt',0,'nv',0,'nm','','un','','ns','','cd','','of',0,'et',0,'ga',0,'vn',0,'vm',0,'az',0,'la',0,'lo',0,'al',0);
			if exist(f,'file')
				[y,m,d,h,n,nv,nm,un,ns,cc,of,et,ga,vn,vm,az,la,lo,al] = textread(f,'%d-%d-%d%d:%d%s%s%s%s%s%s%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|','commentstyle','shell');
				nn = 1;
				for j = 1:length(y)
					k = findstr(nv{j},'-');
					if isempty(k)
						j1 = str2double(nv{j});
						j2 = j1;
					else
						j1 = str2double(nv{j}(1:(k-1)));
						j2 = str2double(nv{j}((k+1):end));
					end
					for jj = j1:j2
						CC.dt(nn) = datenum(y(j),m(j),d(j),h(j),n(j),0);
						CC.nv(nn) = jj;
						CC.nm{nn} = nm{j};
						CC.un{nn} = un{j};
						CC.ns{nn} = ns{j};
						CC.cd{nn} = cc{j};
						CC.of(nn) = str2double(of(j));
						CC.et(nn) = str2double(et(j));
						CC.ga(nn) = str2double(ga(j));
						CC.vn(nn) = str2double(vn(j));
						CC.vm(nn) = str2double(vm(j));
						CC.az(nn) = str2double(az(j));
						CC.la(nn) = str2double(la(j));
						CC.lo(nn) = str2double(lo(j));
						CC.al(nn) = str2double(al(j));
						nn = nn + 1;
					end
					CC.nx = length(unique(CC.nv));
				end
			end
			C = [C;CC];
		end  %end clb
	end %end iii
end %end i grids

% Sélection des stations valides (opérationnelles)
k = find((ope | op == 0));

if ~isempty(k)
	S.geo = [lat(k) lon(k) alt(k)];
  	S.wgs = geo2utmwgs(S.geo);
%  	S.utm = geo2ltm(S.geo);
  	S.dte = dte(k);
else
	S.geo = [0,0,0]*NaN;
  	S.wgs = S.geo*NaN;
%  	S.utm = S.geo*NaN;
  	S.dte = 0;
end

S.cod = cod(k);
S.ali = ali(k);
S.dat = dat(k);
S.nom = nom(k);
S.pos = pos(k);
S.ope = ope(k);
S.ins = ins(k);
S.fin = fin(k);
S.typ = typ(k);
S.tra = tra(k);
S.lst = lst(k);
if clb
	S.clb = C(k);
end

disp(sprintf('WEBOBS: %d nodes imported',length(cod)));

