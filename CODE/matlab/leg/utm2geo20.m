function ll=utm2geo20(en);
%UTM2GEO20 Conversion coordonnées UTM20 (Guadeloupe) en géographiques.
%       LL=UTM2GEO20(EN) retourne une matrice de coordonnées géographiques
%       [LAT LON] avec LAT = latitude (degrés), LON = longitude (degrés), 
%       à partir d'une matrice de coordonnées UTM [E N] avec E = Est (m), 
%       N = Nord (m).

%   Auteurs: F. Beauducel + C. Anténor d'après D. Bellier, OVSG-IPGP
%   Création : 2001-08-23
%   Mise à jour : 2001-08-23

D = 180/pi;
C = 6399593.6257585;
EO = 0.08209443794984;
%C = 6400057.71;
%EO = 8.276528E-02;
IO = 20;
FO = 5.07613E-03;
BO = 4.29451E-05;
GO = 1.696E-07;
AO = -63;

X8 = en(:,1);
Y8 = en(:,2);
Y = Y8/.9996;
P = Y/6366197.724;
S = sin(P);
CO = cos(P);
I1 = EO.*CO;
G1 = C./sqrt(1 + I1.*I1);
X = (X8 - 500000)/.9996;
V = CO;
U = V.*S;
V = V.*V;
J2 = P + U;
J4 = (3*J2 + 2*U.*V)/4;
J6 = (5*J4 + 2*U.*V.*V)/3;
RO = C.*(P - FO.*J2 + BO.*J4 - GO.*J6);
Y = Y - RO;
X2 = X./G1;
N = I1.*X2;
N2 = N.*N;
X2 = X2.*(1 - N2/6);
E1 = (Y./G1).*(1 - N2/2);
P1 = P + E1;
P2 = cos(P1);
P3 = exp(X2);
A = atan(P3.*P3 - 1)./(2*P3.*P2);
G2 = atan(cos(A).*sin(P1)./P2);
V2 = 1 + I1.*I1 - 1.5*EO.*S.*I1.*(G2 - P);
X8 = (A*D) + AO;
Y8 = (P + V2.*(G2 - P))*D;
ll = [Y8,X8];
