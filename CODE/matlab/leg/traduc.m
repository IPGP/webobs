function j = traduc(d)
%TRADUC Traduit les noms de jour et de mois

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-10-10
%   Mise à jour : 2001-10-10


% Jours de la semaine
F = {'lundi','mardi','mercredi','jeudi','vendredi','samedi','dimanche'};
A = {'Mon','Tue','Wed','Thu','Fri','Sat','Sun'};

% Mois de l'année
F = [F,{'janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'}];
A = [A,{'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'}];

k = find(strcmp(A,d));
if ~isempty(k)
    j = F{k};
else
    j = '?';
end