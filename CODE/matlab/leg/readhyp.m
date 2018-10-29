function D=readhyp(f)
%READHYP Lit le fichier hypocentres
%   D = READHYP(F) lit le fichier d'hypocentres F et retourne une
%   structure D :
%       D.tps = temps origine (format Matlab)
%       D.lat = latitude (degrés décimaux)
%       D.lon = longitude (degrés décimaux)
%       D.dep = profondeur (km)
%       D.mag = magnitude de durée
%	D.gap = gap (°)
%	D.rms = RMS (s)
%       D.erh = erreur horizontale (km)
%       D.erz = erreur verticale (km)
%	D.qml = qualité de la loc (A, B, C ou D)
%       D.msk = intensité (1 = non ressenti)
%       D.typ = type de séisme (voir "codeseisme.m")
%       D.cod = code séisme
%	D.hyp = lignes hypo complètes
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2003-08-19
%   Mise à jour : 2013-02-16

X = readconf;

if nargin < 1
	f = sprintf('%s/%s/%s',X.RACINE_FTP,X.SISMOHYP_PATH_FTP,X.SISMOHYP_HYPO_FILE);
end

if exist(f,'file') == 0
    error(sprintf('Fichier %s inexistant.',f));
else
    % importe les codes séismes
    CS = codeseisme;
    % lit le fichier entier dans le tableau d
    d = textread(f,'%s','delimiter','\n','headerlines',1);
    D.tps = zeros(size(d));
    D.lat = zeros(size(d));
    D.lon = zeros(size(d));
    D.dep = zeros(size(d));
    D.mag = zeros(size(d));
    D.gap = zeros(size(d));
    D.rms = zeros(size(d));
    D.erh = zeros(size(d));
    D.erz = zeros(size(d));
    D.msk = zeros(size(d));
    D.typ = ones(size(d));
    D.cod = cell(size(d));
    D.qml = cell(size(d));
    D.hyp = cell(size(d));
    for i = 1:length(d)
        ds = d{i};
        if ischar(ds) & length(ds) > 80
		yy = str2double(ds(1:4));
		mm = str2double(ds(5:6));
		if isnan(mm), mm = 0; end
		dd = str2double(ds(7:8));
		if isnan(dd), dd = 0; end
		hh = str2double(ds(10:11));
		nn = str2double(ds(12:13));
		ss = str2double(ds(15:19));
		if ds(23) ~= '.'
		    lat = str2double(ds(20:22)) + str2double(ds(24:28))/60;
		else
		    lat = str2double(ds(20:28));
		end
		if ds(33) ~= '.'
		    lon = str2double(ds(29:32)) + str2double(ds(34:38))/60;
		else
		    lon = str2double(ds(29:38));
		end
		dep = str2double(ds(40:45));
		mag = str2double(ds(48:52));
		nbp = str2double(ds(54:55));
		gap = str2double(ds(57:59));
		rms = str2double(ds(66:69));
		erh = str2double(ds(70:74));
		erz = str2double(ds(75:79));
		qml = ds(81);
		if length(ds) > 85
		    cse = ds(84:min([88,length(ds)])); % code séisme
		    if cse(3) == '0'
			msk = 10;
		    else
			msk = str2double(cse(3));
		    end
		    typ = find(strcmp(CS.cde,cse(1:2)));
		    if isempty(typ)
			typ = 1;
		    end
		else
		    msk = 1;
		    typ = 1;
		end
		D.hyp{i} = ds;
		D.tps(i) = datenum(yy,mm,dd,hh,nn,ss);
		D.lat(i) = lat;
		D.lon(i) = -lon;
		D.dep(i) = dep;
		D.mag(i) = mag;
		D.gap(i) = gap;
		D.rms(i) = rms;
		D.erh(i) = erh;
		D.erz(i) = erz;
		D.qml{i} = qml;
		D.msk(i) = msk;
		D.typ(i) = typ;
		D.cod{i} = cse;
	end
    end
    disp(sprintf('File: %s imported.',f))
end

