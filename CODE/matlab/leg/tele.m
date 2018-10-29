function [nr,na,nt,TT,T] = tele(S,ixy);
%TELE   Trace les liaisons télémétrées de stations OVSG.
%       TELE(S) trace les liaisons point à point des stations S sur le graphe 
%       courant UTM (éventuellement via un relais) et renvoie le nombre de relais 
%       trouvé pour ces stations.
%       Utilise le fichier de configuration "typeTransmission.conf"

%   Auteurs: F. Beauducel + C. Anténor-Habazac, OVSG-IPGP
%   Création : 2002-06-24
%   Mise à jour : 2007-09-16

X = readconf;

T = {{1,'radio','-',[0,0,0]}, ...
     {2,'cablé','-.',[0,0,0]}, ...
     {3,'RTC',':',[0,0,0]}, ...
     {4,'laser','--',[0,0,0]}};
f = sprintf('%s/Tele_OVSG.txt',X.RACINE_FICHIERS_CONFIGURATION);
[sta,acq,rel1,rel2,rel3,typ] = textread(f,'%q%q%q%q%q%n','commentstyle','shell');

ST = readst('',{'G','M'});
stcoo = [ST.utm,ST.geo,ST.wgs];

ST = ST.cod;
ix = ixy(1);
iy = ixy(2);

n = 0;
nt = 0;
ka = 0;
kt = [];
for i = 1:length(sta)
    k = find(strcmp(S,sta(i)));
    if ~isempty(k)
        k0 = find(strcmp(ST,sta{i})); % station
        k1 = find(strcmp(ST,acq{i})); % acquisition
        k2 = find(strcmp(ST,rel1{i})); % relais 1
        k3 = find(strcmp(ST,rel2{i})); % relais 2
        k4 = find(strcmp(ST,rel3{i})); % relais 3
        kk = [k0 k2 k3 k4 k1];
        nt = nt + length(kk) - 1;
        if find(abs(stcoo(kk,ix))<10)
            sta(i)
        end
        plot(stcoo(kk,ix),stcoo(kk,iy),'LineStyle',T{typ(i)}{3},'Color',T{typ(i)}{4},'LineWidth',.1);
        if isempty(kt)
            kt = typ(i);
        else
            if isempty(find(kt==typ(i))), kt = [kt,typ(i)]; end
        end
        plot(stcoo([k2 k3 k4],ix),stcoo([k2 k3 k4],iy),'LineStyle','none','Marker','p', ...
            'MarkerEdgeColor','k','MarkerSize',6,'MarkerFaceColor',[1 1 1]);
        if isempty(find(k1==ka))
            plot(stcoo(k1,ix),stcoo(k1,iy),'LineStyle','none','Marker','p', ...
                'MarkerEdgeColor','k','MarkerSize',12);
            ka = [ka,k1];
        end
        n = n + length([k2 k3 k4]);
    end
end
nr = n;
na = length(find(ka));
TT = T(kt);
