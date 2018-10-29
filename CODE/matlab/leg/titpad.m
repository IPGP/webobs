function h=titpad(n,s1,s2,s3)
%TITPAD Ajoute un titre en bas à droite

if nargin<1, n = 10; end
if nargin<2, s1 = 'Carte des Réseaux Intégrés'; end
if nargin<3, s2 = 'OVSG-IPGP-INSU'; end
if nargin<4, s3 = sprintf('%s %s',datestr(now,'mmm'),datestr(now,'yyyy')); end
c = .5*[1 1 1];
h1 = axes('position',[.65 0 .32 .04]);
fill([0,0,1,1],[0,1,1,0],c)
%plot([0,0,1,1,0],[0,1,1,0,0],'-','LineWidth',.1,'Color',c)
axis([0 1 0 1]), axis(h1,'off');
text(.5,.7,s1,'HorizontalAlignment','center','FontSize',n,'Color','w')
text(.1,.3,s2,'HorizontalAlignment','left','FontSize',round(n*.6),'FontWeight','bold','Color','w')
text(.9,.3,s3,'HorizontalAlignment','right','FontSize',round(n*.6),'FontAngle','italic','Color','w')

if nargout
    h = h1;
end
