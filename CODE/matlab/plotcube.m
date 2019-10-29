function plotcube(xyz,V,c,an,varargin)
%PLOTCUBE Plot a cube
%	PLOTCUBE plots an unitary cube on the current axis, one corner located
%	at coordinates (0,0,0).
%
%	PLOTCUBE(XYZ,V,C,NAMES) plots the cube at position XYZ=[X,Y,Z], using 
%	eigen vectors V, color C (RGB vector) and component NAMES={'X','Y',...}
%	as axis labels.

%	Author: F. Beauducel / WEBOBS
%	Created: 2019-10-23
%	Updated: 2019-10-24


% cube vertices
ver = [1 1 0;
    0 1 0;
    0 1 1;
    1 1 1;
    0 0 1;
    1 0 1;
    1 0 0;
    0 0 0];

% cube faces
fac = [1 2 3 4;
    4 3 5 6;
    6 7 8 5;
    1 2 8 7;
    6 7 1 4;
    2 3 5 8];

if nargin < 1
	xyz= [0,0,0];
end

if nargin < 2
	V = eye(3);
end
ver = ver*V';

if nargin < 3
	c = ones(1,3);
end
cl = 0.5 + c/2;

if nargin < 4
	an = {'X','Y','Z'};
end

patch('Faces',fac,'Vertices',[xyz(1)+ver(:,1),xyz(2)+ver(:,2),xyz(3)+ver(:,3)], ...
	'EdgeColor',cl,'FaceColor','none','FaceAlpha',.1,'LineWidth',.5)
hold on
plot3(xyz(1)+[zeros(1,3);V(1,:)],xyz(2)+[zeros(1,3);V(2,:)],xyz(3)+[zeros(1,3);V(3,:)], ...
	'-','Color',cl,'LineWidth',2,varargin{:})
text(xyz(1) + V(1,1)*1.1,xyz(2) + V(2,1)*1.1,xyz(3) + V(3,1)*1.1,an{1},'FontSize',14,'FontWeight','bold','Color',c,'HorizontalAlignment','center')
text(xyz(1) + V(1,2)*1.1,xyz(2) + V(2,2)*1.1,xyz(3) + V(3,2)*1.1,an{2},'FontSize',14,'FontWeight','bold','Color',c,'HorizontalAlignment','center')
text(xyz(1) + V(1,3)*1.1,xyz(2) + V(2,3)*1.1,xyz(3) + V(3,3)*1.1,an{3},'FontSize',14,'FontWeight','bold','Color',c,'HorizontalAlignment','center')
hold off