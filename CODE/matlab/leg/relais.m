function n = relais(ST,utm);
%RELAIS Trace les relais de stations OVSG.
%       RELAIS(S,UTM) renvoie le nombre de relais trouvés à partir des codes
%       de stations S et des coordonnées UTM, et trace un graphe

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-06-21
%   Mise à jour : 2002-06-21

f = 'data/Relais_OVSG.txt';
[cod,st1,st2,r,v,b] = textread(f,'%q%q%q%n%n%n','commentstyle','shell');
rvb = [r,v,b];
%X = struct('cod',cod,'st1',st1,'st2',st2,'rvb',[r v b]);

SX = readst('X','B');
SR = cellstr(char(SX.cod));
stutm = cat(1,SX.utm);
n = 0;
for i = 1:length(SX)
    k1 = find(strcmp(SR,cod(i))); % relais
    k2 = find(strcmp(ST,st1(i))); % station
    k0 = find(strcmp(SR,st2(i))); % obs
    if ~isempty(k2)
        plot(stutm(k1,1),stutm(k1,2),'LineStyle','none','Marker','p', ...
            'MarkerEdgeColor','k','MarkerSize',7,'MarkerFaceColor',[1 1 1]);
        plot([stutm([k0 k1],1);utm(k2,1)],[stutm([k0 k1],2);utm(k2,2)],'-w','LineWidth',.1);
        n = n + 1;
    end
end
