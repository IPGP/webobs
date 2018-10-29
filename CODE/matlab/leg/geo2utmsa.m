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
A1 = 6378137;            % WGS84 demi grand axe
F1 = 1/298.257223563;    % WGS84 aplatissement
A2 = 6378388;            % HAYFORD 1909 demi grand axe
F2 = 1/297;              % HAYFORD 1909 aplatissement
K0 = 0.9996;             % UTM20 facteur d'échelle au point origine
F0 = 20;                 % UTM20 n° du fuseau
P0 = 0/D0;               % UTM20 latitude origine (rad)
X0 = 500000;             % UTM20 Coordonnée Est en projection du point origine (m)
Y0 = 0;                  % UTM20 Coordonnée Nord en projection du point origine (m)

TX = -472.29;               % HAYFORD 1909 => WGS84 : Translation X (m)
TY = -5.63;                 % HAYFORD 1909 => WGS84 : Translation Y (m)
TZ = -304.12;               % HAYFORD 1909 => WGS84 : Translation Z (m)
D = 1.8984*1e-6;            % HAYFORD 1909 => WGS84 : Facteur d'échelle (ppm)
RX = 0.4362*pi/(180*3600);  % HAYFORD 1909 => WGS84 : Rotation X (")
RY = -0.8374*pi/(180*3600); % HAYFORD 1909 => WGS84 : Rotation Y (")
RZ = 0.2563*pi/(180*3600);  % HAYFORD 1909 => WGS84 : Rotation Z (")

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
L0 = (6*F0 - 183)/D0;    % UTM20 longitude origine (rad)

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
[l2,p2,h2] = ign0012(x2,y2,z2,A2,E2);

if vb
    disp(sprintf(' HAYFORD 1909 géographiques : Phi = %g rad, Lam = %g rad, H = %1.3f m',p2,l2,h2))
end

% Transformation Géographiques => UTM20 (HAYFORD 1909)

[LC,N,XS,YS] = ign0052(A2,E2,K0,L0,P0,X0,Y0);
[e2,n2] = ign0030(LC,N,XS,YS,E2,l2,p2);

if vb
    disp(sprintf(' HAYFORD 1909 UTM20 Ste-Anne : Est = %1.3f m, Nord = %1.3f m',e2,n2))
end

% Conversion altimétrique WGS84 => IGN1988 par méthode de grille

[lam,phi,ngd,xgd] = textread(fgrd,'%n%n%n%n','headerlines',4);
k = find(~isnan(l1) & ~isnan(p1));
u2 = h1;
he = interp2(reshape(lam,[31,32]),reshape(phi,[31,32]),reshape(ngd,[31,32]),l1(k)*D0,p1(k)*D0);
u2(k) = h1(k) - he;

if vb
    disp(sprintf(' UTM20 Ste-Anne : altitude = %1.3f m',u2))
end

enu = [e2,n2,u2];
