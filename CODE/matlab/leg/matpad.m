function h=matpad(t,p,f2,f)
%MATPAD Ajoute une signature aux graphes Matlab
%       MATPAD(T) ajoute un cartouche avec une image "data/logo.jpg", le texte T, la date et l'heure 
%	    en bas à gauche de la figure courante.
%
%       MATPAD(T,P) précise la position gauche P (entre 0 et 1) de l'axe contenant le texte.
%
%       MATPAD(T,P,F2) ajoute un second logo F2 (format JPG, hauteur max = 50 pixels).
%
%       H = MATPAD renvoie le handle de l'axe.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   CrÃation : 2001-05-01
%   Mise à jour : 2008-06-17

X = readconf;

if nargin < 2
    p = 0;
end
if nargin < 3
    f2 = [];
end
if nargin < 4
    f = '';
end

if ~isempty(f2)
    f2 = sprintf('%s/%s',X.RACINE_DATA_MATLAB,f2);
end

flogo = sprintf('%s/logo_ipgp.jpg',X.RACINE_DATA_MATLAB);
A = imread(flogo);
isz = size(A);
pps = get(gcf,'PaperPosition');

% Affichage du logo
if p == 0
    pos = [0 0 isz(2)/(100*pps(3)) isz(1)/(100*pps(4))];
else
    pos = [p 0 isz(2)/(120*pps(3)) isz(1)/(120*pps(4))];
end
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
%S = dbstack;
%if size(S,1) > 1
%    f = S(2).name;
%else
%    f = sprintf('Matlab %s',version);
%end
h2 = axes('Position',[posr,0,1 - posr,1]);
axis([0 1 0 1]), axis off
if p == 0
    %[s1,m1] = unix('whoami');
    %[s2,m2] = unix('hostname');
    %h = text(.5,0,sprintf('(c) %s - %s - %s - by %s on %s',t,datestr(now),f,deblank(m1),deblank(m2)), ...
    %    'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7,'Color','b','Interpreter','none');
    h = text(.5,0,sprintf('(c) %s - %s - %s - by Matlab',t,datestr(now),f), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7,'Color','b','Interpreter','none');
else
    h = text(0.05,0.01,{sprintf('%s %s  %s',f,t,datestr(now))}, ...
        'VerticalAlignment','bottom','FontSize',7,'Color','b','Interpreter','none');
end
if nargout
    h = [h1;h2];
end
