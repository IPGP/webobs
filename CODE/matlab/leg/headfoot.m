function h=headfoot(ht,ft,f2)
%HEADFOOT Ajoute un en-tête et un pied de page aux graphes Matlab
%       HEADFOOT(HT,FT) ajoute un en-tête avec le texte HT (en haut à gauche), et
%	un pied de page avec le texte FT complété par la date, l'heure, l'utilisateur et
%	la machine (en bas à droite), ainsi qu'un cartouche avec le logo IPGP ("data/logo.jpg").
%
%	HEADFOOT(HT,FT,L2) ajoute un second logo F2 (format JPG, hauteur max = 50 pixels).
%
%       H = MATPAD renvoie les handles des axes créés.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2005-10-11 (sur base de GTITLE, ETAT100 et MATPAD)
%   Mise à jour : 2005-10-11

X = readconf;

if nargin < 3
    f2 = [];
end

% Définition des variables et chargement des logos
if ~isempty(f2)
    f2 = sprintf('%s/%s',X.RACINE_DATA_MATLAB,f2);
end
flogo = sprintf('%s/logo.jpg',X.RACINE_DATA_MATLAB);
A = imread(flogo);
isz = size(A);
pps = get(gcf,'PaperPosition');

% Affichage de l'en-tête


% Affichage du logo
pos = [0 0 isz(2)/(100*pps(3)) isz(1)/(100*pps(4))];
h1 = axes('Position',pos,'Visible','off');
image(A), axis off
if ~isempty(f2)
    A = imread(f2);
    isz = size(A);
    pos = [sum(pos([1,3])) pos(2) isz(2)/(100*pps(3)) isz(1)/(100*pps(4))];
    h2 = axes('Position',pos,'Visible','off');
    image(A), axis off
end
posr = sum(pos([1,3]));

% texte du cartouche
[s1,m1] = unix('whoami');
[s2,m2] = unix('hostname');
h2 = axes('Position',[posr,0,1 - posr,1]);
axis([0 1 0 1]), axis off
if p == 0
    h = text(.5,0,sprintf('(c) %s - %s - %s - by %s on %s',t,datestr(now),f,deblank(m1),deblank(m2)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7,'Color','b','Interpreter','none');
else
    h = text(0.05,0.01,{sprintf('%s %s  %s',f,t,datestr(now))}, ...
        'VerticalAlignment','bottom','FontSize',7,'Color','b','Interpreter','none');
end
if nargout
    h = [h1;h2];
end
