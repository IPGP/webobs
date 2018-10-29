function etat100(p,a,s,r)
%ETAT100 Cartouche d'état de station
%       ETAT100(P,A,S) affiche à droite de l'axe courant 2 icones de pourcentage 
%       sur fond de couleur P % pour état et A % pour l'acquisition et une lettre
%       S donnant le type de station. Les couleurs sont :
%           - P ou A >= 90 : fond vert
%           - P ou A >=10 & P ou A < 90 : fond jaune
%           - P ou A < 10 : fond rouge
%           - P == -1 : affiche "Veille" sur fond gris.

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-07-02
%   Mise à jour : 2003-03-04

if nargin < 2
    a = 100;
    s = 'T';
    r = 0;
end

samp = echant(r);
x = .95;  rx = .05;
y = .8;  ry = .1;

axis off

[c,t] = colortext(round(p),s);
rectangle('position',[x-rx,y-ry,2*rx,2*ry],'Facecolor',c,'Curvature',[0 0]);
text(x,y,t,'FontSize',10,'FontWeight','bold','HorizontalAlignment','center')
text(x,y+ry,'ÉTAT','FontSize',6,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','bottom')

[c,t] = colortext(round(a),s);
rectangle('position',[x-rx,y-ry-4*ry,2*rx,2*ry],'Facecolor',c,'Curvature',[0 0]);
text(x,y-4*ry,t,'FontSize',10,'FontWeight','bold','HorizontalAlignment','center')
text(x,y-3*ry,'ACQUISITION','FontSize',6,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','bottom')

text(x-rx,y-7*ry,s,'FontSize',16,'FontWeight','bold','HorizontalAlignment','left')
text(x+rx,y-7*ry,samp,'FontSize',8,'FontWeight','bold','HorizontalAlignment','right')

%==================================================================================
function [c,t] = colortext(x,s);

if x >= 90
    c = 'g';
else if x < 10
        if strcmp(s(1),'M') | strcmp(s(1),'A')
            c = [1 .5 0];
        else
            c = 'r';
        end
    else
        c = 'y';
    end
end

if x == -1
    c = .7*[1 1 1];
    t = 'Veille';
else
    t = sprintf('%d %%',x);
end


%==================================================================================
function s = echant(x);

xx = x*1440;
s = sprintf('%1.0f an',xx/(1440*365));
if xx < 1440*365
    s = sprintf('%1.0f j',xx/1440);
end
if xx < 1440
    s = sprintf('%1.0f h',xx/60);
end
if xx < 60
    s = sprintf('%1.0f min.',xx);
end
if xx < 1
    s = sprintf('%1.0f s',xx*60);
end
if xx < 1/60
    s = sprintf('%1.0f Hz',1/(xx*60));
end
