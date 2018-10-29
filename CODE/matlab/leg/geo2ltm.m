function enu=geo2utmsa(llh,v);
%GEO2UTMSA Conversion coordonnées géographiques WGS84 à UTM Ste-Anne
%       ENU=GEO2UTMSA(LLH) retourne une matrice de coordonnées UTM [E N U]
%       avec E = Est (m), N = Nord (m), U = Altitude (m), à partir d'une matrice 
%       de coordonnées géographiques [LAT LON ELE] avec LAT = latitude (degrés), 
%       LON = longitude (degrés) et ELE = hauteur ellipsoidale (km).

%   Bibliographie:
%       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
%       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
%       I.G.N., Transformation entre systèmes géodésiques, Service de Géodésie et Nivellement, http://www.ign.fr, 1999/2002.
%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2003-01-10
%   Mise à jour : 2004-04-27

X = readconf;

% Définition des constantes
D0 = 180/pi;
A1 = str2double(X.ELLIPSOID_WGS84_SEMIMAJOR_AXIS);              % WGS84 demi grand axe
F1 = 1/str2double(X.ELLIPSOID_WGS84_INVERSE_FLATTENING);        % WGS84 aplatissement
K0 = str2double(X.UTM_LOCAL_SCALE_FACTOR);                      % TM local facteur d'échelle au point origine
L0 = str2double(X.UTM_LOCAL_MERIDIAN_ORIGIN)/D0;    % UTM20 longitude origine (rad)
P0 = 0/D0;               % UTM20 latitude origine (rad)
X0 = str2double(X.UTM_LOCAL_FALSE_EASTING);			% TM local coordonnée Est en projection du point origine (m)
Y0 = 0;                  % UTM20 Coordonnée Nord en projection du point origine (m)

A2 = str2double(X.ELLIPSOID_LOCAL_SEMIMAJOR_AXIS);		% HAYFORD 1909 demi grand axe
F2 = 1/str2double(X.ELLIPSOID_LOCAL_INVERSE_FLATTENING);	% HAYFORD 1909 aplatissement
TX = str2double(X.GEODETIC_LOCAL2WGS84_TRANSLATION_X);		% HAYFORD 1909 => WGS84 : Translation X (m)
TY = str2double(X.GEODETIC_LOCAL2WGS84_TRANSLATION_Y);		% HAYFORD 1909 => WGS84 : Translation Y (m)
TZ = str2double(X.GEODETIC_LOCAL2WGS84_TRANSLATION_Z);		% HAYFORD 1909 => WGS84 : Translation Z (m)
D = str2double(X.GEODETIC_LOCAL2WGS84_SCALE_FACTOR);
RX = str2double(X.GEODETIC_LOCAL2WGS84_ROTATION_X)/(D0*3600);	% HAYFORD 1909 => WGS84 : Rotation X (")
RY = str2double(X.GEODETIC_LOCAL2WGS84_ROTATION_Y)/(D0*3600);	% HAYFORD 1909 => WGS84 : Rotation Y (")
RZ = str2double(X.GEODETIC_LOCAL2WGS84_ROTATION_Z)/(D0*3600);	% HAYFORD 1909 => WGS84 : Rotation Z (")

fgrd = sprintf('%s/%s',X.RACINE_DATA_MATLAB,X.DATA_GRILLE_GEOIDE); % fichier grille géoide Guadeloupe

if nargin > 1
    vb = 1;
else
    vb = 0;
end
if vb
    disp('*** Transformation de coordonnées géographiques WGS84 => UTM Ste-Anne')
    disp(sprintf(' WGS84 géographiques: Lat = %1.6f °, Lon = %1.6f °, H = %1.0f m',llh'))
end

% Conversion des données
B1 = A1*(1 - F1);
E1 = sqrt((A1*A1 - B1*B1)/(A1*A1));
B2 = A2*(1 - F2);
E2 = sqrt((A2*A2 - B2*B2)/(A2*A2));

k = find(llh==-1);
llh(k) = NaN;
p1 = llh(:,1)/D0;        % Phi = Latitude (rad)
l1 = llh(:,2)/D0;        % Lambda = Longitude (rad)
h1 = llh(:,3);           % H = Hauteur (m)

if vb
    disp(sprintf(' WGS84 géographiques: Phi = %g rad, Lam = %g rad, H = %1.3f m',p1,l1,h1))
end

% Transformation Géographiques => Cartésiennes WGS84

[x1,y1,z1] = ign0009(l1,p1,h1,A1,E1);

if vb
    disp(sprintf(' WGS84 cartésiennes : X = %1.3f m, Y = %1.3f m, Z = %1.3f m',x1,y1,z1))
end

% Transformation par similitude 3D à 7 paramètres WGS84 => HAYFORD 1909
[x2,y2,z2] = ign0013b(TX,TY,TZ,D,RX,RY,RZ,[x1,y1,z1]);

if vb
    disp(sprintf(' HAYFORD 1909 cartésiennes : X = %1.3f m, Y = %1.3f m, Z = %1.3f m',x2,y2,z2))
end

% Transformation Cartésiennes => Géographiques (HAYFORD 1909)
if all(~isnan(x2))
	[l2,p2,h2] = ign0012(x2,y2,z2,A2,E2);
else
	l2 = NaN*x2;
	p2 = NaN*x2;
	h2 = NaN*x2;
end

if vb
    disp(sprintf(' HAYFORD 1909 géographiques : Phi = %g rad, Lam = %g rad, H = %1.3f m',p2,l2,h2))
end

% Transformation Géographiques => UTM20 (HAYFORD 1909)

[LC,N,XS,YS] = ign0052(A2,E2,K0,L0,P0,X0,Y0);
[e2,n2] = ign0030(LC,N,XS,YS,E2,l2,p2);

if vb
    disp(sprintf(' HAYFORD 1909 TM Ste-Anne : Est = %1.3f m, Nord = %1.3f m',e2,n2))
end

% Conversion altimétrique WGS84 => IGN1988 par méthode de grille

[lam,phi,ngd,xgd] = textread(fgrd,'%n%n%n%n','headerlines',4);
k = find(~isnan(l1) & ~isnan(p1));
u2 = h1;
he = interp2(reshape(lam,[31,32]),reshape(phi,[31,32]),reshape(ngd,[31,32]),l1(k)*D0,p1(k)*D0);
u2(k) = h1(k) - he;

if vb
    disp(sprintf(' TM local: altitude = %1.3f m',u2))
end

enu = [e2,n2,u2];
