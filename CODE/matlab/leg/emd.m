function [md,en] = emd(t,d);
%EMD    Energie et magnitude de durée des séismes
%   [MD,EN] = EMD(T,D) renvoie la magnitude de durée MD et l'énergie associée EN (en MJ)
%   à partir de la durée du signal T (en s) et la distance D (en km).
%
%   Auteur: F. Beauducel, OVSG-IPGP.
%   Créé: 2005-06-28
%   Modifié: 2005-06-29
%   Références: formule MD = [Lee and Lahr, 1975]
%               formule énergie = [OVSG ?]

md = 2*log10(t) + 0.0035*d - .87;
en = 1e-6*10.^(2.9 + 1.92*md - .024*md.*md);
if isnan(en)
    en = 0;
end