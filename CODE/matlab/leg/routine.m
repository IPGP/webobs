function routine(mat)
%ROUTINE  Routines des réseaux OVSG

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2003-07-02
%   Mise à jour : 2004-02-06

if nargin < 1
    mat = 1;
end

tnow = datevec(now);
X = readconf;

eval('acqui','disperr(''acqui'')');
eval('mkroutine','disperr(''mkroutine'')');
%if mat
%    eval('webstat(1)','disperr(''webstat'')');
%end

% statistiques accès web : attention très lent (+5min)!!
%if tnow(5) < 5
%    eval('webstat','disperr(''webstat'')');
%end
    
% Affiche des informations sur l'erreur
function disperr(s)
disp(sprintf('* Matlab Error: Problème avec la fonction %s',upper(s)));
disp(lasterr);
