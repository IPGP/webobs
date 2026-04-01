function DOUT = waters(varargin)
%WATERS  WebObs SuperPROC: Updates graphs/exports of 'WATERS' FORM database.
%
%   WATERS(PROC) makes default outputs of PROC.
%
%   WATERS(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%       TSCALE = '%' : all timescales defined by PROC.conf (default)
%       TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%       (keywords must be in TIMESCALELIST of PROC.conf)
%
%   WATERS(PROC,[],REQ) makes graphs/exports for specific request directory REQ.
%   REQ must contain REQUEST.rc file with dedicated parameters.
%
%   D = WATERS(PROC,...) returns a structure D containing all the PROC data:
%       D(i).id = node ID
%       D(i).t = time vector (for node i)
%       D(i).d = matrix of processed data (NaN = invalid data)
%
%   This superproc is specificaly adapted to data from the FORM.WATERS genform
%   when using the PROC.WATERS template, but data from other source might be used.
%
%   See CODE/tplates/PROC.WATERS for specific paramaters of this superproc.
%
%	Authors: F. Beauducel + G. Hammouya + J.C. Komorowski + C. Dessert + O. Crispi, OVSG-IPGP
%	Created: 2001-12-21, in Guadeloupe (French West Indies)
%	Updated: 2026-01-19

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);

% gets PROC's configuration and associated nodes
[P,N,D] = readproc(WO,varargin{:});
G = cat(1,D.G);

V.name = P.NAME;
pernode_linestyle = field2str(P,'PERNODE_LINESTYLE','-');
pernode_title = field2str(P,'PERNODE_TITLE','{\fontsize{14}{\bf$node_alias: $node_name} ($timescale)}');
summary_linestyle = field2str(P,'SUMMARY_LINESTYLE','-');
summary_title = field2str(P,'SUMMARY_TITLE','{\fontsize{14}{\bf$name} ($timescale)}');
ternary1 = field2num(P,'SUMMARY_TERNARY1_CHANNELS');
ternary2 = field2num(P,'SUMMARY_TERNARY2_CHANNELS');
summary_channels = field2num(P,'SUMMARY_CHANNELS');

exthax = [.08,.02];
% types of sampling and associated markers (see PLOTMARK function)
%FT = readcfg(WO,sprintf('%s/%s',P.FORM.ROOT,P.FORM.FILE_TYPE));
%tcod = fieldnames(FT);
%tmkt = cell(size(tcod));
%tmks = ones(size(tcod));
%for i = 1:length(tcod)
%	tmkt{i} = FT.(tcod{i}).marker;
%	tmks(i) = str2double(FT.(tcod{i}).relsize);
%end


% ==== graphs per node
for n = 1:length(N)
	C = D(n).CLB;
	GN = graphstr(field2str(P,'PERNODE_CHANNELS',sprintf('%d,',1:C.nx),'notempty'));
	V.node_name = N(n).NAME;
	V.node_alias = N(n).ALIAS;
	V.last_data = datestr(D(n).tfirstlast(2));

	t = D(n).t;
	d = D(n).d;

	for r = 1:length(P.GTABLE)
		V.timescale = timescales(P.GTABLE(r).TIMESCALE);

		% renames main variables for better lisibility...
		k = D(n).G(r).k;
		ke = D(n).G(r).ke;
		tlim = D(n).G(r).tlim;

		% title and status
		OPT.GTITLE = varsub(pernode_title,V);
		OPT.GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];

		figure(1), clf, orient tall

		OPT.INFOS = {sprintf('Last meas.: {\\bf%s} {\\it%+d}',datestr(t(ke)),P.TZ),''};
        allchan = cat(2,GN.chan);
        for i = 1:length(allchan)
            OPT.INFOS = [OPT.INFOS{:}, ...
			{sprintf('  %s = {\\bf%g %s}',C.nm{allchan(i)},d(ke,allchan(i)),C.un{allchan(i)})}];
        end

        for p = 1:length(GN)

			subplot(GN(p).subplot{:}), extaxes(gca,exthax)
			pchan = GN(p).chan;
            for i = 1:length(pchan)
				col = scolor(i);
				plot(D(n).t(k),D(n).d(k,pchan(i)),pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
                hold on
            end
            hold off
            if isempty(D(n).d) || all(isnan(D(n).d(k,pchan(i))))
				nodata(tlim)
            end
            if length(pchan) > 1
                legend(C.nm(pchan),'location','SouthWest')
            end
            set(gca,'XLim',tlim,'FontSize',8)
            ylabel(nameunit(strcommon(C.nm(pchan)),strcommon(C.un(pchan))))
            datetick2('x',P.GTABLE(r).DATESTR)
            if (p < length(GN))
                set(gca,'XTickLabels',[])
            end
        end

		tlabel(tlim,P.TZ)

        OPT.STATUS = P.GTABLE(r).STATUS;
		OPT.EVENTS = N(n).EVENTS;
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P,OPT)
	end

end

% ==== Main summary graph
if any(strcmpi(P.SUMMARYLIST,'SUMMARY')) && ~isempty(summary_channels)
	for r = 1:length(P.GTABLE)

		V.timescale = timescales(P.GTABLE(r).TIMESCALE);
		tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(tlim))
			tlim = minmax(cat(1,D.tfirstlast));
		end
		OPT.GTITLE = varsub(summary_title,V);
        OPT.STATUS = P.GTABLE(r).STATUS;
		if P.GTABLE(r).STATUS
			OPT.GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
		end
		OPT.INFOS = {sprintf('Last meas.: {\\bf%s} {\\it%+d}',datestr(max(cat(1,D.t))),P.TZ),'',''};


		figure(1), clf, orient tall

		% Ternary diagram 1 (e.g., Ca vs Na vs Mg)
        axes('Position',[0.1  0.63  0.33  0.25])
		for n = 1:length(N)
			k = D(n).G(r).k;
			h = ternplot(D(n).d(k,ternary1(1)),D(n).d(k,ternary1(2)),D(n).d(k,ternary1(3)),'.',0);
			set(h,'Color',scolor(n));
			set(gca,'FontSize',8)
			hold on
		end
		hold off
		ternlabel(C.nm{ternary1(1)},C.nm{ternary1(2)},C.nm{ternary1(3)},0);
		pos = get(gca,'pos');  set(gca,'pos',[pos(1),pos(2)+.02,pos(3),pos(4)])

		% Ternary diagram 2 (e.g., SO4 vs HCO3 vs Cl)
        axes('Position',[0.57  0.63  0.33  0.25])
		for n = 1:length(N)
			k = D(n).G(r).k;
			h = ternplot(D(n).d(k,ternary2(1)),D(n).d(k,ternary2(2)),D(n).d(k,ternary2(3)),'.',0);
			set(h,'Color',scolor(n));
			set(gca,'FontSize',8)
			hold on
		end
		hold off
		ternlabel(C.nm{ternary2(1)},C.nm{ternary2(2)},C.nm{ternary2(3)},0);
		pos = get(gca,'pos');  set(gca,'pos',[pos(1),pos(2)+.02,pos(3),pos(4)])

		% Legend for sites
		axes('position',[0,pos(2),1,pos(4)]);
		axis([0,1,0,1]);
		hold on
		for n = 1:length(N)
			xl = .5;
			yl = 1 - n/(length(N)+3);
			plot([xl xl]',yl+[.02 -.02]','-','Color',scolor(n))
			plot(xl+[.02 -.02],[yl yl],'-',xl,yl,'.','LineWidth',.1,'Color',scolor(n))
			text(xl+.03,yl,N(n).ALIAS,'Fontsize',8,'FontWeight','bold')
		end
		hold off
		axis off

        nx = length(summary_channels);
        for i = 1:nx
            subplot(6+nx*2,1,7+(i-1)*2+[0,1]), extaxes
            hold on
            for n = 1:length(N)
                col = scolor(n);
                k = D(n).G(r).k;
                if ~isempty(k)
                    plot(D(n).t(k),D(n).d(k,summary_channels(i)),summary_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
                end
            end
            hold off, box on
            set(gca,'XLim',tlim,'FontSize',8)
            ylabel(nameunit(C.nm{summary_channels(i)},C.un{summary_channels(i)}))
            datetick2('x',P.GTABLE(r).DATESTR)
            if (i < nx)
                set(gca,'XTickLabels',[])
            end
        end

		tlabel(tlim,P.TZ)

		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P,OPT)
	end
end
close

if P.REQUEST
	mkendreq(WO,P);
end

timelog(procmsg,2)


if nargout > 0
	DOUT = D;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function extylim(d)
%EXTYLIM Extends YLim

mm = minmax(d);
if diff(mm) > 0 && ~any(isnan(mm))
	set(gca,'YLim',mm)
end
