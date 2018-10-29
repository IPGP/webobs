function ploterup(OPT)
%PLOTERUP Affiche les éruptions sur le graphe courant.
%   PLOTERUP(OPT) utilise les options définies dans la structure OPT.
%

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-07-21
%   Mise à jour : 2005-08-28

X = readconf;

f = sprintf('%s/Phenom/Eruptions/ERUPTIONS.DAT',X.RACINE_FTP);
[y1,m1,d1,y2,m2,d2,nom,typ,com] = textread(f,'%n-%n-%n%n-%n-%n%s%s%s','delimiter','|','commentstyle','shell');
dt1 = datenum(y1,m1,d1);
dt2 = datenum(y2,m2,d2);
disp(sprintf('File: %s imported.',f));

% Détection des axes dans la figure courante
ha = findobj(gcf,'Type','axes');

for i = 1:length(ha)
    xlim = get(ha(i),'XLim');
    k = find(dt1 <= xlim(2) & dt2 >= xlim(1));
    if ~isempty(k)
        ylim = get(ha(i),'YLim');
        for ii = 1:length(k)
            x1 = dt1(k(ii));
            x2 = dt2(k(ii));
            y1 = ylim(1);
            y2 = ylim(2);
            cc = col(typ{k(ii)});
            axes(ha(i));
            hold on
            h = fill3([x1,x1,x2,x2],[y1,y2,y2,y1],[-1,-1,-1,-1],cc);
            set(h,'EdgeColor',cc);
            hold off
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function rvb = col(x)
switch x
case 'magmatique'
    rvb = [1 .5 .5];
case 'phréatique'
    rvb = [.7 .7 .8];
otherwise
    rvb = [.8 .8 .8];
end
