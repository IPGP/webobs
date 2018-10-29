function en=geo2utm20(ll);
%GEO2UTM20 Conversion coordonnées géographiques à UTM20 (Guadeloupe)
%       EN=GEO2UTM20(LL) retourne une matrice de coordonnées UTM [E N]
%       avec E = Est (m), N = Nord (m), à partir d'une matrice de coordonnées 
%       géographiques [LAT LON] avec LAT = latitude (degrés), LON = longitude
%       (degrés).

%   Auteurs: F. Beauducel + C. Anténor d'après D. Bellier, OVSG-IPGP
%   Création : 2001-08-23
%   Mise à jour : 2001-08-23

if size(ll,2) > 2
    en = [ll(:,1:2) ll(:,3)*1000];
end
D = 180/pi;
FO = 5.07613E-03;
BO = 4.29451E-05;
GO = 1.696E-07;
C = 6399593.6257585;
EO = 0.08209443794984;
%C = 6400057.7;
%EO = 8.276528E-02;
IO = 20;
AO = -63/D;

A = ll(:,2)/D;
L = ll(:,1)/D;

A1 = A - AO;
CO = cos(L);
U = sin(L);
X2 = CO.*sin(A1);
X2 = .5*log((1 + X2)./(1 - X2));
E1 = atan(U./(CO.*cos(A1))) - L;
G1 = C./sqrt(1 + (EO.*CO.*EO.*CO));
E2 = EO.*CO.*X2.*EO.*CO.*X2;
X8 = G1.*X2.*(1 + E2/6);
Y8 = G1.*E1.*( 1 +E2/2);
U = CO.*U;
V = CO.*CO;
J2 = L + U;
J4 = (3*J2 + 2*U.*V)/4;
J6 = (5*J4 + 2*U.*V.*V)/3;
RO = C.*(L - FO.*J2 + BO.*J4 - GO.*J6);

e = 500000 + .9996*X8;
n = .9996*(Y8 + RO);
en(:,1:2) = [e,n];