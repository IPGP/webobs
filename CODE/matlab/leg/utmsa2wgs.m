function [e_wgs,n_wgs]=utmsa2wgs(e_sa,n_sa)
%UTMSA2WGS Translation UTM Ste-Anne vers WGS84
%       [E_WGS,N_WGS] = UTMSA2WGS(E_SA,N_SA) translate les coordonnées UTM20
%       Sainte-Anne Est,Nord (en m) en coordonnées WGS84 par la formule
%       approximative:
%           E_WGS = E_SA - 422.58 (Est)
%           N_WGS = N_SA - 303.51 (Nord)
%
%       Cette translation est exacte pour le sommet de la Soufrière et a une
%       altération linéaire de 147.6 mm/km.
%
%       F. Beauducel, OVSG-IPGP, 2004

e_wgs = e_sa - 422.58;
n_wgs = n_sa - 303.51;
