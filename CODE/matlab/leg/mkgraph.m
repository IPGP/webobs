function h = mkgraph(f,G,OPT);
%MKGRAPH Creates a PNG file from current figure.
%   MKGRAPH(F,G) adds header and footer to current figure and makes a file F.png using 
%   parameters defined in structure G. Image file is created in two places:
%	- G.ftp data directory
%	- /images/graphes Web directory (excepted for graphic request and RAP)
%
%   MKGRAPH(F,G,OPT) specifies additional options using structure OPT (from the request form):
%	- OPT.ppi = image resolution for F.png (default = MKGRAPH_VALUE_PPI)
%	- OPT.eps = 1 : creates a Postscript file F.ps
%	          = -1 : F.png will be made from F.ps (better quality)
%	- OPT.dsp = specific directory for images (default = Web directory MATLAB_PATH_IMAGES)
%
%   Attention: MKGRAPH needs an active X-display to produce PNG images; if the display is not
%   available, a PostScript image will be created first, then converted in PNG format using
%   external program "/usr/bin/convert" (ImageMagick).

%   Author: F. Beauducel, OVSG-IPGP
%   Created: 2002-12-03
%   Updated: 2013-02-20

X = readconf;

if nargin < 3
	OPT = 0;
end

p = sprintf('%s/%s/%s',X.RACINE_FTP,G.ftp,X.MKGRAPH_PATH_FTP);
if isfield(G,'sub')
	p = sprintf('%s/%s',p,G.sub);
end
scpr = 'OVSG-IPGP';

% [FB 2013-02-20]: now prints in /tmp local directory, then moves to final directories
ptmp = '/tmp/.webobs';
[s,mess] = mkdir(ptmp);

pwww = X.RACINE_WEB;
pimg = X.MATLAB_PATH_IMAGES;
convert = X.PRGM_CONVERT;
rvign = str2double(X.MKGRAPH_VALUE_VIGNETTE);
flogo0 = sprintf('%s/logo.jpg',X.RACINE_DATA_MATLAB);
flogo1 = sprintf('%s/logo_ipgp.jpg',X.RACINE_DATA_MATLAB);
flogo2 = [];
pps = get(gcf,'PaperPosition');
[s1,m1] = unix('whoami');
[s2,m2] = unix('hostname');

if isfield(OPT,'ppi')
	r = OPT.ppi;
else
	r = str2double(X.MKGRAPH_VALUE_PPI);
end
if isfield(OPT,'eps')
	ps = OPT.eps;
else
	ps = 0;
end
if isfield(G,'ico')
	vign = G.ico;
else
	vign = 0;
end
if isfield(G,'dsp')
	ds = G.dsp;
else
	ds = X.MKSPEC_PATH_WEB;
end
if isfield(G,'cpr')
    scpr = G.cpr;
end
if isfield(G,'lg2')
    flogo2 = sprintf('%s/%s',X.RACINE_DATA_MATLAB,G.lg2);
end

if isfield(G,'tit') & isfield(G,'inf')

	% creates an axis for the full page
	ha = axes('Position',[0,0,1,1],'Visible','off');
	axis([0 1 0 1]), axis off


	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% header

	A = imread(flogo0);
	isz = size(A);
	pos = [1-isz(2)/(r(1)*pps(3)),1-isz(1)/(r(1)*pps(4)),isz(2)/(r(1)*pps(3)),isz(1)/(r(1)*pps(4))];
	h0 = axes('Position',pos,'Visible','off');
	image(A), axis off

	A = imread(flogo1);
	isz = size(A);
	pos = [0,1-isz(1)/(r(1)*pps(4)),isz(2)/(r(1)*pps(3)),isz(1)/(r(1)*pps(4))];
	h1 = axes('Position',pos,'Visible','off');
	image(A), axis off

	axes(ha)
	if isfield(G,'eta')
	    sss = sprintf('%s %+d',datestr(G.eta(1)),G.utc);
		if length(G.eta) > 1
		    sss = [sss,sprintf(' - État %03d %% - Acquisition %03d %%',round(G.eta(2:3)))];
		end
	    G.tit = [G.tit,{sprintf('%s - %s - %s',sss,G.typ,G.acq)}];
	end
	ss = [G.tit,{['WEBOBS \copyright ',datestr(now,'yyyy'),', ',scpr]}];
	text(.5,1,ss,'HorizontalAlignment','center','VerticalAlignment','top','FontSize',8);

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% footer
	% display text from cell G.inf on a 4-row table

	ht = 0;
	pt = .01;
	for i = 1:4:length(G.inf)
		if ht
			et = get(ht,'Extent');
			pt = et(1) + et(3);
		end
		ht = text(pt,0,G.inf(i:min([i+3,length(G.inf)])),'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',8);
	end
else
	h0 = [];
	h1 = [];
    matpad(scpr,0,[],f);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Displays the secondary logo (for collaboration)

if exist(flogo2,'file')
	A = imread(flogo2);
	isz = size(A);
    pos = [1-isz(2)/(r(1)*pps(3)),0,isz(2)/(r(1)*pps(3)),isz(1)/(r(1)*pps(4))];
    h2 = axes('Position',pos,'Visible','off');
    image(A), axis off
	text(mean(get(gca,'XLim')),min(get(gca,'YLim')),'En collaboration avec','HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7)
else
    h2 = [];
end
%posr = sum(pos([1,3])) + .01;

%axes(h0)
%text(posr,0,{sprintf('(c) %s - %s',scpr,datestr(now)),sprintf('"%s" by %s on %s',f,deblank(m1),deblank(m2))}, ...
%        'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',7,'FontWeight','bold','Color',[.5,.5,.5],'Interpreter','none');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Creates images: PNG + optional PS + optional JPG (thumbnail)

if findstr(f,'_xxx')
    phtm = ds;
else
    phtm = X.MKGRAPH_PATH_WEB;
end

% case of no display or forced Postscript (better PNG quality)
if strcmp(get(gcf,'XDisplay'),'nodisplay') | ps==1
    print(gcf,'-dpsc','-painters',sprintf('%s/%s.ps',ptmp,f));
    disp(sprintf('Graph:  %s/%s.ps created.',ptmp,f))
end
if strcmp(get(gcf,'XDisplay'),'nodisplay')
    unix(sprintf('%s -colors 256 -density %dx%d %s/%s.ps %s/%s.png',convert,r(1),r(1),ptmp,f,ptmp,f));
else    
    print(gcf,'-dpng','-painters',sprintf('-r%d',r(1)),sprintf('%s/%s.png',ptmp,f))
end
disp(sprintf('Graph:  %s/%s.png created.',ptmp,f))
if vign
	IM = imfinfo(sprintf('%s/%s.png',ptmp,f));
	ims = [IM.Width IM.Height];
	unix(sprintf('%s -scale %dx%d %s/%s.png %s/%s.jpg',convert,round(ims(1)/rvign),round(ims(2)/rvign),ptmp,f,ptmp,f));
	unix(sprintf('mv -f %s/%s.jpg %s/%s/',ptmp,f,pwww,phtm));
	disp(sprintf('Thumbnail: %s/%s/%s.jpg created.',pwww,phtm,f));
end
if ps==1
	unix(sprintf('cp -f %s/%s.ps %s/',ptmp,f,p));
	disp(sprintf('Graph:  %s/%s.ps copied.',p,f))
	unix(sprintf('mv -f %s/%s.ps %s/%s/',ptmp,f,pwww,phtm));
	disp(sprintf('Graph:  %s/%s/%s.ps copied.',pwww,phtm,f))
end

% if ~findstr(f,'_rap')
if size(findstr(f,'_rap'),1)==0
	unix(sprintf('cp -f %s/%s.png %s/%s/',ptmp,f,pwww,phtm));
	disp(sprintf('Graph:  %s/%s/%s.png copied.',pwww,phtm,f))
end
unix(sprintf('mv -f %s/%s.{png,ps} %s/',ptmp,f,p));
disp(sprintf('Graph:  %s/%s.png copied.',p,f))

%unix(sprintf('/usr/bin/convert -colors 256 -density %dx%d images/%s.ps %s/%s.png',r,r,f,p,f));
%unix(sprintf('/usr/bin/gs -sDEVICE=png256 -sOutputFile=%s/%s.png -r100 -dNOPAUSE -dBATCH -q %s.ps',p,f,f));

if nargout
    h = [ha;h0;h1;h2];
end

