function DOUT=mc3stats(varargin)
%MC3STATS WebObs SuperPROC: Updates graphs/exports of MainCourante statistics.
%
%       MC3STATS(PROC) makes default outputs of PROC.
%
%       MC3STATS(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	MC3STATS(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = MCSTATS(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       MC3STATS will use PROC's parameters from .conf file. Particularily, it
%       uses RAWFORMAT
%
%       MC3STATS can generate type of graphs which can be set with 'SUMMARYLIST|' parameter.
%       Available options are :
%           GUTENBERG-RICHTER   : Gutenberg/Richter law
%           GUTRICHTER_TIME     : Gutenberg/Richter law parameters over time
%           SWARM               : swarm detection on seismic rate
%           OMORI
%
%				Events filtering options (implicitly excludes any not located event)
%						LATLIM|13,19
%						LONLIM|-64,-58
%						DEPLIM|-10,200
%						MAGLIM|3,10
%						QUALITY_FILTER|Y
%
%       Other specific paramaters are:
%           MC_EVENTTYPE_LIST|
%           EVENTTYPE_EXCLUDED_LIST|
%           EVENTSTATUS_EXCLUDED_LIST|
%           EVENTCOMMENT_EXCLUDED_REGEXP|
%           SEISMIC_RATE|
%           SEISMIC_RATE_NUM_EVENTS|50
%           SEISMIC_RATE_SAMPLING_INTERVAL|10n
%           SWARM_DETECTOR_LTA|60d
%           SWARM_DETECTOR_THRESH|2.5
%           SWARM_MIN_DURATION|12h
%           RATE_YLOGSCALE|NO
%           CUMULATE_YLOGSCALE|NO
%           CUMULATE_PLOT|MOMENT
%
%
%	Authors: J.-M. Saurel and F. Beauducel / WEBOBS, IPGP
%	Created: 2019-01-31
%	Updated: 2021-01-01

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);


% gets PROC's configuration, associated nodes for any TSCALE and/or REQDIR and the data
[P,N,D] = readproc(WO,varargin{:});

% PROC's parameters
n_evts = field2num(P,'SEISMIC_RATE_NUM_EVENTS',50);
rate_type = lower(field2str(P,'SEISMIC_RATE','classic'));
samp_int = field2num(P,'SEISMIC_RATE_SAMPLING_INTERVAL',10/1440);
detect_LTA = field2num(P,'SWARM_DETECTOR_LTA',60);
swarm_min_dur = field2num(P,'SWARM_MIN_DURATION',12/24);
thresh = field2num(P,'SWARM_DETECTOR_THRESH',-1);
qualityfilter = isok(P,'QUALITY_FILTER');
ratelogscale = isok(P,'RATE_YLOGSCALE');
cumulate_logscale = isok(P,'CUMULATE_YLOGSCALE');
cumulate_plot = lower(field2str(P,'CUMULATE_PLOT','moment'));

% concatenates all nodes data
t = cat(1,D.t);
d = cat(1,D.d);
c = cat(1,D.c);
e = cat(1,D.e);
CLB = D(1).CLB;

% sort events by ascending time
[t,k] = sort(t);
d = d(k,:);
c = c(k,:);
e = e(k,:);

% selects events (quality filter)
k = find(e > 0 | ~qualityfilter);
tk = (t(k));
dk = d(k,:);
ck = c(k,:);
ek = e(k,:);
if qualityfilter
	fprintf('%s: ** WARNING ** %d events rejected after quality filters.\n',wofun,length(t)-length(k));
end


% at this stage, only one Node
n = 1;

% ====================================================================================================
% --- Seismic rate calculation, swarm detection and statistics


switch rate_type
    % Calculate classic events/day seismic rate
    case 'classic'
        t_rt = nan(1+length(tk)-n_evts,1);
        rt = nan(length(t_rt),1);
        for k = n_evts:length(tk)
          rt(1+k-n_evts) = n_evts/(tk(k)-tk(1+k-n_evts));
          t_rt(1+k-n_evts) = mean(tk(1+k-n_evts:k));
        end
    % Calculate aki formulae seismic rate
    case 'aki'
        t_rt = nan(1+length(tk)-n_evts,1);
        rt = nan(length(t_rt),1);
        for k = n_evts:length(tk)
          rt(1+k-n_evts) = n_evts/(2*sqrt(tk(k)-tk(1+k-n_evts)));
          t_rt(1+k-n_evts) = mean(tk(1+k-n_evts:k));
        end
    case 'movtimewindow'
        t_rt = tk(1)+1:samp_int:tk(end);
        rt = nan(length(t_rt),1);
        for k = 1:length(t_rt)
            rt(k) = length(find(tk>(t_rt(k)-1) & tk<t_rt(k)));
        end
    otherwise
        fprintf('%s: ** ERROR ** %s seismic rate algorithm unknown, abort.\n',wofun,rate_type);
        return
end


% --- Seismic rate interpolation
%[FBwas:] t_rate = floor(min([P.DATELIST{:}])):samp_int:ceil(P.NOW);
if ~any(rt)
    rt(1) = 0;
    rt(end) = 0;
end
t_rate = floor(P.DATELIM(1)):samp_int:ceil(P.DATELIM(2));
rate = interp1(t_rt,rt,t_rate);
k = find(~isnan(rate));
rate(isnan(rate(1:k(1)))) = rate(k(1));

% --- Swarm detection only if thresh > 0
swarms_datelim = [];
if thresh > 0
	% LtaFilt initialization
	C4 = 1-exp(-2*pi*samp_int/detect_LTA);

	rate_lta = zeros(1,length(rate));
	% If first rate data is already a swarm value, initialize lta to a low value
	if rate(1) > 20
	    rate_lta(1) = 20/thresh;
	else
	    rate_lta(1) = rate(1);
	end
	rate_lta_stale = rate_lta(1);

	Warning = nan(1,length(rate));

	for k = 2:length(rate)
	    % Update lta only if a detection is not ongoing, else keep frozen lta
	    if isnan(Warning(k-1))
	        rate_lta(k) = rate_lta(k-1)+C4*(rate(k)-rate_lta(k-1));
	    else
	        rate_lta(k) = rate_lta_stale;
	    end
	    % Check if threshold reached, if yes, freeze lta value
	    if (rate(k)>thresh.*rate_lta(k))
	        Warning(k) = 1;
	        rate_lta_stale = rate_lta(k);
	    end
	    % If a new detection just started, store the start timestamp
	    if isnan(Warning(k-1)) && ~isnan(Warning(k))
	        swarm_start = t_rate(k);
	    end
	    % If an ongoing detection ends and last more than the minimum duration, update swarm list
	    if ~isnan(Warning(k-1)) && isnan(Warning(k)) && (t_rate(k)-swarm_start > swarm_min_dur)
	        swarms_datelim = [swarms_datelim;swarm_start t_rate(k)];
	    end
	end
	% If still in detection at the end, close the ongoing detection now
	if ~isnan(Warning(end))
	    swarms_datelim = [swarms_datelim;swarm_start t_rate(end)];
	end
end

% --- Moment and NRJ calculation for each event
moment_MC = nan(length(t),1);
energy_MC = nan(length(t),1);
moment_catalog = nan(length(t),1);
energy_catalog = nan(length(t),1);

% Finds events that have a MC magnitude and no catalog magnitude, take MC magnitude
k = find(~isnan(d(:,4)) & isnan(d(:,8)));
moment_MC(k) = seismic_moment(d(k,4),'feuillard80');
energy_MC(k) = seismic_energy(d(k,4),'feuillard80');

% Finds events that have a MC magnitude and a catalog magnitude, take catalog magnitude
k = find(~isnan(d(:,4)) & ~isnan(d(:,8)));
moment_MC(k) = seismic_moment(d(k,8),'feuillard80');
energy_MC(k) = seismic_energy(d(k,8),'feuillard80');

% Finds events that have a catalog magnitude
k = find(~isnan(d(:,8)));
moment_catalog(k) = seismic_moment(d(k,8),'kanamori');
energy_catalog(k) = seismic_energy(d(k,8),'kanamori');


% --- Swarm statistics
% If swarms were found, update the statistics table
if find(swarms_datelim)
    n_swarms = size(swarms_datelim,1);
    % Init all 7 statistics :   number of events in swarm
    %                           inter-swarm time
    %                           swarm moment from MC
    %                           swarm moment from catalog
    %                           swarm energy from MC
    %                           swarm energy from catalog
    %                           percentage of events in the catalog
    swarms_statistics = nan(n_swarms,6);
    swarms_x = nan(4,n_swarms);
    swarms_y = nan(4,n_swarms);
    % Inter-swarm time
    swarms_statistics(2:n_swarms,2) = [swarms_datelim(2:end,1)-swarms_datelim(1:end-1,2)];
    for i = 1:n_swarms
        % Finds events between start and end of the swarm
        k = find(t_rt>=swarms_datelim(i,1) & t_rt<=swarms_datelim(i,2));
        if ~isempty(k)
          swarms_statistics(i,1) = length(k);
          vals = moment_MC(k);
          swarms_statistics(i,3) = sum(vals(~isnan(vals)))/10^6;
          vals = moment_catalog(k);
          swarms_statistics(i,4) = sum(vals(~isnan(vals)))/10^6;
          vals = energy_MC(k);
          swarms_statistics(i,5) = sum(vals(~isnan(vals)))/10^6;
          vals = energy_catalog(k);
          swarms_statistics(i,6) = sum(vals(~isnan(vals)))/10^6;
        end
        % Finds events between start and end of swarm and in the catalog (with a catalog magnitude)
        k = find(~isnan(d(k,8)));
        if swarms_statistics(i,1) > 0
          swarms_statistics(i,7) = 100*length(k)/swarms_statistics(i,1);
        end
        % Create swarm boxes for plot
        swarms_x(:,i) = [swarms_datelim(i,1);swarms_datelim(i,2);swarms_datelim(i,2);swarms_datelim(i,1)];
    end
end


% ====================================================================================================
% Make the graphs

for r = 1:length(P.GTABLE)

    k = D(n).G(r).k;
    ke = D(n).G(r).ke;
    tlim = D(n).G(r).tlim;
    tk = t(k);
    energy_MCk = energy_MC(k);
    energy_catalogk = energy_catalog(k);
    moment_MCk = moment_MC(k);
    moment_catalogk = moment_catalog(k);
    events_count = ones(length(t(k)),1);
    kk=find(t_rate>tlim(1));
    t_ratek=t_rate(kk);
    ratek=rate(kk);

    summary='SWARM';
    if any(strcmp(P.SUMMARYLIST,summary))
        stitre = sprintf('%s - Seismic rate and swarms',P.NAME);
        P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);

        switch rate_type
            % Calculate classic events/day seismic rate
            case 'classic'
                info = sprintf('Instantaneous seismic rate (%.1f/day samples) calculated on a fixed number of {\\bf%d} events with classic formulae : {\\bf %d/(t_{i+%d} - t_i) }',1/samp_int,n_evts,n_evts,n_evts);
           % Calculate aki formulae seismic rate
            case 'aki'
                info = sprintf('Instantaneous seismic rate (%.1f/day samples) calculated on a fixed number of {\\bf%d} events with Aki formulae : {\\bf %d/(2*sqrt(t_{i+%d} - t_i)) }',1/samp_int,n_evts,n_evts,n_evts);
            case 'movtimewindow'
                info = sprintf('Instantaneous seismic rate (%.1f/day samples) calculated on a moving, 24h fixed-size, time window',1/samp_int);
        end

        P.GTABLE(r).INFOS = {sprintf('%s',info),''};
        P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('Last event: {\\bf%s} {\\it%+d}',datestr(t(ke)),P.GTABLE(r).TZ)}];
        if thresh > 0
            P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{'dd/mm/yy: N.evts|NRJ MC|NRJ loc|% loc'}];
        end
        if ~isempty(swarms_datelim)
            kk=find(swarms_datelim(:,2)>tlim(1));
            sw_dt = swarms_datelim(kk,:);
            sw_stats = swarms_statistics(kk,:);
            if size(sw_dt,1)>0
                for i = 1:size(sw_dt,1)
                    P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('{\\bf%s}: %d | %.1f | %.1f | %.1f',datestr(sw_dt(i,1),20),sw_stats(i,1),sw_stats(i,5),sw_stats(i,6),sw_stats(i,7))}];
                end
            end
        end



        figure, clf, orient tall
        % Upper plot is seismic rate
        subplot(4,1,1:2); extaxes
        if any(ratek)
            if ratelogscale
                set(gca,'YScale','log');
                ylim = [10.^floor(log10(min(ratek))) 10.^ceil(log10(max(ratek)))];
            else
                ylim = [floor(min(ratek)) ceil(max(ratek))];
            end
        else
            ylim = [0 1];
        end
        if find(swarms_datelim)
            swarms_y(1:2,:) = ylim(1);
            swarms_y(3:4,:) = ylim(2);
            fill(swarms_x,swarms_y,'r','FaceColor',[1,.5,.5],'EdgeColor','none')
        end
        hold on
        plot(t_ratek,ratek,'k','LineWidth',P.GTABLE(r).LINEWIDTH);
        if thresh > 0		% Plot LTA value only if swarm detection activated
            kk=find(t_rate>tlim(1));
            rate_ltak=rate_lta(kk);
            plot(t_ratek,rate_ltak.*thresh,'Color',[.1,.3,.6],'LineWidth',P.GTABLE(r).LINEWIDTH);
        end
        hold off
        set(gca,'XLim',tlim,'YLim',ylim,'FontSize',8);
        datetick2('x',P.GTABLE(r).DATESTR);
        ylabel('Seismic rate (evts/day)');

        % Lower plot is cumulative plot
        subplot(4,1,3:4); extaxes
        switch cumulate_plot
            % Cumulated moment
            case 'moment'
                kk = find(~isnan(moment_MCk));
                plot(tk(kk),cumsum(moment_MCk(kk)),'Color',[.8,0,0],'LineWidth',P.GTABLE(r).LINEWIDTH);
                hold on
                kk = find(~isnan(moment_catalogk));
                plot(tk(kk),cumsum(moment_catalogk(kk)),'Color',[.3,.6,0],'LineWidth',P.GTABLE(r).LINEWIDTH);
                hold off
                ylabel('Cumulated moment (N.m)');
            % Cumulated energy
            case 'nrj'
                subplot(4,1,3:4); extaxes
                kk = find(~isnan(energy_MCk));
                plot(tk(kk),cumsum(energy_MCk(kk)),'Color',[.8,0,0],'LineWidth',P.GTABLE(r).LINEWIDTH);
                hold on
                kk = find(~isnan(energy_catalogk));
                plot(tk(kk),cumsum(energy_catalogk(kk)),'Color',[.3,.6,0],'LineWidth',P.GTABLE(r).LINEWIDTH);
                hold off
                ylabel('Cumulated energy (J)');
            % Cumulated events count
            case 'events'
                subplot(4,1,3:4); extaxes
                plot(tk,cumsum(events_count),'k','LineWidth',P.GTABLE(r).LINEWIDTH);
                ylabel('Cumulated number of events');
            otherwise
                fprintf('%s: ** ERROR ** %s cumulate plot type unknown.\n',wofun,cumulate_plot);
        end
        if cumulate_logscale
        	set(gca,'YScale','log');
        end
        set(gca,'XLim',tlim,'FontSize',8);
        datetick2('x',P.GTABLE(r).DATESTR);
        legend('MainCourante','catalog');
        legend('boxoff');
        legend('location','southeast');
        tlabel(tlim,P.GTABLE(r).TZ)
        tlabel(tlim,P.GTABLE(r).TZ)

        mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r))
        close

        % If swarm detection activated, output swarm characteristics
        if thresh > 0
            E.header = {'yyyy','mm','dd','HH','MM','SS','N.evts','Inter-event time(Day)','Moment-MC(MJ)','Moment-loc(MJ)','NRJ-MC(MJ)','NRJ-loc(MJ)','Located(%)'};
            E.fmt = {'%4d','%02d','%02d','%02d','%02d','%02d','%d','%.1f','%.1f','%.1f','%.1f','%.1f','%03.0f'};
            if ~isempty(swarms_datelim)
            	E.t = sw_dt(:,1);
            	E.d = [datevec(sw_dt(:,2)),sw_stats];
            else
                E.t = [];
                E.d = [];
            end
        % Else, output timeserie data
        else
            E.header = {'yyyy','mm','dd','HH','MM','SS','Cumulated-Moment(N.m)','Cumulated-NRJ(MJ)','Cumulated-events'};
            E.fmt = {'%4d','%02d','%02d','%02d','%02d','%02d','%.1f','%.1f','%d'};
        	E.t = tk;
        	E.d = [cumsum(moment_catalogk),cumsum(energy_catalogk)./10^6,cumsum(events_count)];
        end
        E.title = sprintf('%s {%s}',stitre,upper(N(n).ID));
        mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
    end

%    summary='GUTENBERG-RICHTER';
%    if any(strcmp(P.SUMMARYLIST,summary))
%    end

%    summary='GUTRICHTER_TIME';
%    if any(strcmp(P.SUMMARYLIST,summary))
%    end

%    summary='OMORI';
%    if any(strcmp(P.SUMMARYLIST,summary))
%    end
end

if P.REQUEST
	mkendreq(WO,P);
end

timelog(procmsg,2)


% Returns data in DOUT
if nargout > 0
	DOUT = D;
end
