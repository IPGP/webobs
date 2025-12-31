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
%	Updated: 2025-12-29

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

% --- index of columns in matrix d
%   1 = type of site
i_ty = 1;
%   2 = temperature of air (�C)
i_ta = 2;
%   3 = temperature of water (�C)
i_ts = 3;
%   4 = pH
i_ph = 4;
%   5 = flux (l/mn)
i_db = 5;
%   6 = conductivity (�S)
i_cd = 6;
%   7 = level (m)
i_nv = 7;
%   8-18 = concentrations in ppm = mg/l, to be converted in mmol/l
%   8-12 = anions Li+, Na+, K+, Mg++, Ca++ (mmol/l)
i_li = 8;
i_na = 9;
i_ki = 10;
i_mg = 11;
i_ca = 12;
%   13-18 = cations F-,Cl-,Br-,NO3-,SO4--,HCO3-,I- (mmol/l)
i_fi = 13;
i_cl = 14;
i_br = 15;
i_no3 = 16;
i_so4 = 17;
i_hco3 = 18;
i_i = 19;
%   20-22 = isotopes d13C, d18O,dD
%   23 = ratio Cl-/SO4-- (computed)
%   24 = ratio HCO3-/SO4-- (computed)
%   25 = ratio Mg++/Cl- (computed)
%   26 = conductivity at 25�C
%   27 = ion budget (NICB)
i_bi = 27;


% ==== graphs per node
for n = 1:length(N)
	C = D(n).CLB;
	nx = C.nx;
	GN = graphstr(field2str(P,'PERNODE_CHANNELS',sprintf('%d,',1:nx),'notempty'));
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
		P.GTABLE(r).GTITLE = varsub(pernode_title,V);
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];

		figure(1), clf, orient tall

		P.GTABLE(r).INFOS = {sprintf('Last meas.: {\\bf%s} {\\it%+d}',datestr(t(ke)),P.TZ),''};
        allchan = cat(2,GN.chan);
        for i = 1:length(allchan)
            P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:}, ...
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

		OPT.EVENTS = N(n).EVENTS;
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
	end

end

% ==== Main summary graph
if any(strcmpi(P.SUMMARYLIST,'SUMMARY'))
	for r = 1:length(P.GTABLE)

		V.timescale = timescales(P.GTABLE(r).TIMESCALE);
		tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(tlim))
			tlim = minmax(cat(1,D.tfirstlast));
		end
		P.GTABLE(r).GTITLE = varsub(summary_title,V);
		if P.GTABLE(r).STATUS
			P.GTABLE(r).GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
		end
		P.GTABLE(r).INFOS = {sprintf('Last meas.: {\\bf%s} {\\it%+d}',datestr(max(cat(1,D.t))),P.TZ),'',''};


		figure(1), clf, orient tall

		% Ternary diagram Ca/Na/Mg
		subplot(9,2,[1 3])
		for n = 1:length(N)
			k = D(n).G(r).k;
			h = ternplot(D(n).d(k,i_ca),D(n).d(k,i_na),D(n).d(k,i_mg),'.',0);
			set(h,'Color',scolor(n));
			set(gca,'FontSize',8)
			hold on
		end
		hold off
		ternlabel('Ca','Na','Mg',0);
		pos = get(gca,'pos');  set(gca,'pos',[pos(1),pos(2)+.02,pos(3),pos(4)])

		% Ternary diagram SO4/HCO3/Cl
		subplot(9,2,[2 4])
		for n = 1:length(N)
			k = D(n).G(r).k;
			h = ternplot(D(n).d(k,i_so4),D(n).d(k,i_hco3),D(n).d(k,i_cl),'.',0);
			set(h,'Color',scolor(n));
			set(gca,'FontSize',8)
			hold on
		end
		hold off
		ternlabel('SO_4','HCO_3','Cl',0);
		pos = get(gca,'pos');  set(gca,'pos',[pos(1),pos(2)+.02,pos(3),pos(4)])

		% Legend
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

		% Temperatures
		subplot(13,1,4:5), extaxes
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
				plotmark(D(n).d(k,i_ty),D(n).t(k),D(n).d(k,i_ts),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on
		set(gca,'XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('Temperatures (�C)'))

		% Legend for site types
		pos = get(gca,'position');
		axes('position',[pos(1),pos(2)+pos(4),pos(3),pos(4)/7])
		axis([0 1 0 1]), hold on
		for i = 1:length(tcod)
		    plot((i-1)/length(tcod) + .05,.5,FT.(tcod{i}).marker,'Markersize',P.GTABLE(r).MARKERSIZE*str2double(FT.(tcod{i}).relsize),'MarkerFaceColor','k')
		    text((i-1)/length(tcod) + .05,.5,['   ',FT.(tcod{i}).name],'FontSize',8)
		end
		axis off, hold off

		% pH
		subplot(13,1,6:7), extaxes
		ddmm = nan(2,1);
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
				dd = D(n).d(k,i_ph);
				ddmm = minmax([ddmm;dd])';
				plotmark(D(n).d(k,i_ty),D(n).t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on, extylim(ddmm)
		set(gca,'XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('pH'))

		% Conductivity at 25C
		subplot(13,1,8:9), extaxes
		ddmm = nan(2,1);
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
				dd = D(n).d(k,26);
				ddmm = minmax([ddmm;dd])';
				plotmark(D(n).d(k,i_ty),D(n).t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on, extylim(ddmm)
		set(gca,'YScale','linear','XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Cond. 25�C (�S)')

		% Ratio Cl-/SO4-
		subplot(13,1,10:11), extaxes
		ddmm = nan(2,1);
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
			    dd = D(n).d(k,23);
			    ddmm = minmax([ddmm;dd])';
			    plotmark(D(n).d(k,i_ty),D(n).t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on, extylim(ddmm)
		set(gca,'YScale','linear','XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Cl^- / SO_4^{--}')

		% Ratio HCO3-/SO4-
		subplot(13,1,12:13), extaxes
		ddmm = nan(2,1);
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
			    dd = D(n).d(k,24);
			    ddmm = minmax([ddmm;dd])';
			    plotmark(D(n).d(k,i_ty),D(n).t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on, extylim(ddmm)
		set(gca,'YScale','linear','XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('HCO_3^- / SO_4^{--}')

		tlabel(tlim,P.TZ)

		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
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
