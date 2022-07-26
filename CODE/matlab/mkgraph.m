function varargout = mkgraph(WO,f,G,OPT);
%MKGRAPH Creates graphics file(s) from current figure.
%	MKGRAPH(WO,F,G) adds header and footer to current figure and makes a file F using
%	parameters defined in the graph structure G. Image files are created in:
%	   G.OUTDIR/[G.SUBDIR/]F.{eps,png,jpg}
%
%	MKGRAPH(WO,F,G,OPT) uses structure OPT as optional parameters:
%		OPT.IMAP: creates companion html map file for interactive graph
%	    OPT.EVENTS: addition background events structure
%		OPT.TYPES: adds a list of symbols on the upper plot
%		OPT.FIXEDPP: do not change initial paper size
%		OPT.INFOLINES: specifies the number of lines for INFOS footer (default is 4)
%
%	Attention: MKGRAPH needs external program "convert" (from ImageMagick package) to produce
%	PNG images. Binary location can be defined in PRGM_CONVERT variable in WEBOBS.rc.
%
%
%	Authors: F. Beauducel - D. Lafon, WEBOBS/IPGP
%	Created: 2002-12-03
%	Updated: 2022-07-26


wofun = sprintf('WEBOBS{%s}',mfilename);

% creates temporary directory
ptmp = sprintf('%s/%s/%s',WO.PATH_TMP_WEBOBS,G.SELFREF,randname(16));
wosystem(sprintf('mkdir -p %s',ptmp));

convert = field2str(WO,'PRGM_CONVERT','convert');
convertopt = field2str(WO,'CONVERT_COLORSPACE','-colorspace sRGB');
ps2pdf = field2str(WO,'PRGM_PS2PDF','ps2pdf');
thumbnailheight = field2num(WO,'MKGRAPH_THUMBNAIL_HEIGHT',112);
timestamp = field2num(WO,'MKGRAPH_TIMESTAMP',6);

% if PAPER_SIZE is defined, reformats paper size and figure position
psz = field2num(G,'PAPER_SIZE');
if numel(psz) == 2 && all(psz>0)
	set(gcf,'PaperUnit','inches','PaperSize',psz);
	if nargin < 4 || ~isok(OPT,'FIXEDPP')
		set(gcf,'PaperPosition',[0,0,psz]);
	end
	if nargin > 3 && isok(OPT,'FIXEDPP')
		pp = get(gcf,'PaperPosition');
		set(gcf,'PaperPosition',[0,0,psz(1),psz(1)*pp(4)/pp(3)]);
	end
else
	psz = get(gcf,'PaperSize');
end

% grid on
if isok(G,'PLOT_GRID')
	% Detects all axes in the current figure
	for h = findobj(gcf,'Type','axes')'
		set(h,'XGrid','on','YGrid','on');
	end
end

% events in background
if nargin > 3 && isfield(OPT,'EVENTS')
	I = plotevent(G.EVENTS_FILE,OPT.EVENTS);
else
	I = plotevent(G.EVENTS_FILE);
end

h0 = [];
h1 = [];

if isfield(G,'GTITLE') && isfield(G,'INFOS')

	% creates an axis for the full page
	ha = axes('Position',[0,0,1,1],'Visible','off');
	axis([0 1 0 1])
	axis off

	% --- header
	h0 = plotlogo(G.LOGO_FILE,G.LOGO_HEIGHT,'left');
	h1 = plotlogo(G.LOGO2_FILE,G.LOGO2_HEIGHT,'right');

	if isfield(G,'GSTATUS')
		if G.STATUS && length(G.GSTATUS) > 2 && all(~isnan(G.GSTATUS(2:3)))
			G.GTITLE = [G.GTITLE, ...
			   {sprintf('%s %+02d - Status %03d %% - Sampling %03d %% ',datestr(G.GSTATUS(1)),G.TZ,round(G.GSTATUS(2:3)))}];
		end
	end
	if ~isempty(G.COPYRIGHT2)
		cpr2 = sprintf(' + \\copyright %s, %s',G.COPYRIGHT2,datestr(now,'yyyy'));
	else
		cpr2 = '';
	end
	% for request, print the user ID
	if ~isok(G,'ANONYMOUS') && isfield(G,'UID')
		[s,w] = wosystem(sprintf('sqlite3 %s "select FULLNAME from users where UID = ''%s''"|tr -d "\\n"|iconv -f UTF-8 -t ISO_8859-1',WO.SQL_DB_USERS,G.UID));
		uid = sprintf('Request by %s [%s] ',w,G.UID);
	else
		uid = '';
	end
	ss = [{''},strrep(G.GTITLE,'()',''),{sprintf('%s\\copyright %s, %s%s',uid,G.COPYRIGHT,datestr(now,'yyyy'),cpr2)}];
	text(.5,1,ss,'HorizontalAlignment','center','VerticalAlignment','top','FontSize',8);

	% --- footer
	% display text from cell G.INFOS on a 4-row table

	ht = [];
	pt = .01;
	nl = 4;
	if nargin > 3
		nl = field2num(OPT,'INFOLINES',4);
	end
	for i = 1:nl:length(G.INFOS)
		if ~isempty(ht)
			et = get(ht,'Extent');
			pt = et(1) + et(3) + .05;
		end
		st = [G.INFOS(i:min([i+nl-1,length(G.INFOS)])),{' '}];
		ht = text(pt,0,st,'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',8);
	end
	if isfield(G,'INFOS2')
		text(.5,0,{strjoin(G.INFOS2,' '),'','','','','',''}, ...
			'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8);
	end

	% --- timestamp
	if timestamp > 0
		ST = dbstack;
		[spath,sname,sext] = fileparts(ST(2).file);
		superproc = sprintf('%s%s',sname,sext);
		w1 = wosystem('echo "$(whoami)@$(hostname)"','chomp','print');
		% gets the updated date of superproc's code... (note: mkgraph is always called by a superproc)
		[s,w2] = wosystem(sprintf('grep "Updated:" superprocs/%s',superproc),'chomp');
		if s
			w2 = 'no source';
		else
			w2 = regexprep(w2,'.*Updated: ','');
		end
		text(1,0,sprintf('%s / %s - %s - %s %+02d - %s (%s) / WebObs %s  ', ...
			G.SELFREF,f,w1,datestr(G.NOW),G.TZ,superproc,w2,num2roman(str2num(datestr(now,'yyyy')))), ...
			'HorizontalAlignment','right','VerticalAlignment','bottom', ...
			'FontSize',timestamp,'Color',.5*ones(1,3),'FontWeight','bold', ...
			'Interpreter','none');
	end

end


% --- Adds a legend for types (markers)
if nargin > 3 && isfield(OPT,'TYPES')
	T = T;
	tcod = fieldnames(T);
	tmkt = cell(size(tcod));
	tmks = ones(size(tcod));
	hold on
	for i = 1:length(tcod)
		ht = text(0,0,'X','FontSize',8);
		et = get(ht,'Extent');
		delete(ht);
		tmkt{i} = T.(tcod{i}).marker;
		tmks(i) = str2double(T.(tcod{i}).relsize);
		xx = .5*(i-1)/length(tcod) + .5;
		plot(xx,et(4),T.(tcod{i}).marker,'Markersize',G.MARKERSIZE*str2double(T.(tcod{i}).relsize),'Color','k','MarkerFaceColor','k')
		text(xx,et(4),['   ',htm2tex(T.(tcod{i}).name)],'FontSize',8)
	end
	hold off
end

% --- Creates images: EPS + PNG + optional PDF + JPG (thumbnail)

if isfield(G,'EVENTS') && ~isempty(G.EVENTS)
	pout = sprintf('%s/%s/%s',G.OUTDIR,WO.PATH_OUTG_EVENTS,G.EVENTS);
else
	pout = sprintf('%s/%s',G.OUTDIR,WO.PATH_OUTG_GRAPHS);
end

wosystem(sprintf('mkdir -p %s',pout))

% creates the main EPS image
fprintf('%s: exporting %s/%s.eps ...',wofun,ptmp,f);
print(gcf,'-depsc','-loose','-painters',sprintf('%s/%s.eps',ptmp,f));
fprintf(' done.\n');

% converts to PNG
fprintf('%s: converting EPS image to PNG ',wofun);
wosystem(sprintf('%s %s -density %dx%d %s/%s.eps %s/%s.png',convert,convertopt,G.PPI,G.PPI,ptmp,f,ptmp,f))
fprintf('ok,');

% optional converts to PDF
if isok(G,'PDFOUTPUT')
	fprintf(' to PDF ');
	wosystem(sprintf('%s -sPAPERSIZE=a4 %s/%s.eps %s/%s.pdf',ps2pdf,ptmp,f,ptmp,f))
	fprintf('ok,');
end

fprintf(' to JPG (thumbnail) ');
wosystem(sprintf('%s -scale x%g %s/%s.png %s/%s.jpg',convert,thumbnailheight,ptmp,f,ptmp,f));
wosystem(sprintf('mv -f %s/%s.jpg %s/',ptmp,f,pout));
fprintf('ok.\n');

if isok(G,'SVGOUTPUT')
	fprintf('%s: exporting %s/%s.svg ...',wofun,ptmp,f);
	plot2svg(sprintf('%s/%s.svg',ptmp,f))
	%print(gcf,'-dsvg',sprintf('%s/%s.svg',ptmp,f))
	fprintf('ok.\n');
end


% --- Creates optional interactive MAP (html map)
% appends IMAP from proc to events
if nargin > 3 && isfield(OPT,'IMAP')
	if ~isempty(I)
		I = cat(2,I,OPT.IMAP);
	else
		I = OPT.IMAP;
	end
end

IM = imfinfo(sprintf('%s/%s.png',ptmp,f));
ims = [IM.Width IM.Height];
fid = fopen(sprintf('%s/%s.map',ptmp,f),'wt');
% note: empty events will create an empty file
for g = 1:length(I)
	set(I(g).gca,'Units','normalized');
	axp = plotboxpos(I(g).gca);
	xylim = [get(I(g).gca,'XLim'),get(I(g).gca,'YLim')];
	if strcmp(get(I(g).gca,'XDir'),'reverse')
		xylim(1:2) = xylim([2,1]);
	end
	if strcmp(get(I(g).gca,'YDir'),'reverse')
		xylim(3:4) = xylim([4,3]);
	end
	% reverse loop to make most recent events on top layer
	for n = size(I(g).d,1):-1:1
		if ~isempty(I(g).l{n})
			lnk = sprintf(' wolbsrc="%s"',I(g).l{n});
		else
			lnk = '';
		end
		x = round(ims(1)*((axp(3)*(I(g).d(n,1) - xylim(1))/diff(xylim(1:2)) + axp(1))));
		y = round(ims(2) - ims(2)*((axp(4)*(I(g).d(n,2) - xylim(3))/diff(xylim(3:4)) + axp(2))));

		if size(I(g).d,2) < 4
			% r is given in points
			r = ceil(I(g).d(n,3)*G.PPI/72);
			fprintf(fid,'<AREA%s onMouseOut="nd()" onMouseOver="overlib(%s)" shape=circle coords="%d,%d,%d">\n',lnk,I(g).s{n},x,y,r);
		else
			x2 = round(ims(1)*((axp(3)*(I(g).d(n,3) - xylim(1))/diff(xylim(1:2)) + axp(1))));
			y2 = round(ims(2) - ims(2)*((axp(4)*(I(g).d(n,4) - xylim(3))/diff(xylim(3:4)) + axp(2))));
			fprintf(fid,'<AREA%s onMouseOut="nd()" onMouseOver="overlib(%s)" shape=rect coords="%d,%d,%d,%d">\n',lnk,I(g).s{n},x,y,x2,y2);
		end
	end
end
%fprintf(fid,'<AREA nohref shape=default>\n');
fclose(fid);
fprintf('%s: interactive map %s/%s.map created.\n',wofun,pout,f);

wosystem(sprintf('mv -f %s/%s.* %s/',ptmp,f,pout));
fprintf('%s: %s/%s.* copied.\n',wofun,pout,f);

% removes the temporary directory
wosystem(sprintf('rm -rf %s',ptmp));

if nargout > 0
    varargout{1} = [ha;h0;h1];
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function h = plotlogo(f,rh,pos)
%PLOTLOGO plots logo image(s).
%	PLOTLOGO(LOGO_FILE,LOGO_HEIGHT,PAPERPOSITION,POS)

h = [];
ha = gca;
pp = get(gcf,'PaperPosition');

if ~isempty(f)
	ff = split(f,',');
	pos0 = 0;
	for i = 1:length(ff)
		if exist(ff{i},'file')
			try
				[A,map,alpha] = imread(ff{i});
				% applies transparency channel manually (for Octave compatibility)
				M = repmat(double(alpha)/double(intmax(class(alpha))),[1,1,3]);
				I = M.*double(A)/double(intmax(class(A))) + (1 - M);
				isz = size(A);
				lgh = rh*pp(3)/pp(4);
				lgw = lgh*isz(2)*pp(4)/isz(1)/pp(3);
				posx = pos0 + strcmp(pos,'right')*(1-lgw);
				h = axes('Position',[posx,1-lgh,lgw,lgh],'Visible','off');
				image(I)
				axis off
				pos0 = pos0 + (lgw + 0.005)*(1 - 2*strcmp(pos,'right'));
			catch
				fprintf('WEBOBS{mkgraph:plotlogo}: ** WARNING ** Cannot read image file "%s".\n',ff{i});
			end
		end
	end
end

axes(ha);
