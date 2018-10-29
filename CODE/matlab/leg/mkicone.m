function mkicone(fprog,t,c,f)
%MKICONE Créer une icone d'état (%)
%       MKICONE(P,T,C,F) crée une icone PNG (fichier F), au moyen du programme CONVERT 
%       (défini par P) avec le texte T et la couleur de fond C.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-11-26
%   Mise à jour : 2002-11-26

x = .9;  rx = .1;
y = .4;  ry = .15;

figure, axis([0 1 -1 2])
rectangle('position',[x-rx,y-ry,2*rx,2*ry],'Facecolor',c,'Curvature',[0 0]);
text(x,y,t,'FontSize',24,'FontWeight','bold','HorizontalAlignment','center')
axis off
print(gcf,'-dpsc','etat.ps');
close
unix(sprintf('%s -colors 256 -density 40x40 etat.ps %s',fprog,f));
unix(sprintf('/bin/touch %s',f));
disp(sprintf('Icone:   %s créée.',f))
