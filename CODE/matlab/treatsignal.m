function [tc,dc,lr,tr,kk] = treatsignal(t,d,r,OPT)
% TREATSIGNAL Signal treatment: decimating and cleaning
% 	[TC,DC]=TREATSIGNAL(T,D,R,OPT) processes vector signal D(T) in the following order:
% 	   1. if OPT.FLAT_IS_NAN is OK, removes flat signals
% 	   2. if OPT.PICKS_CLEAN_PERCENT exists and >0, removes picks above the value %
% 	   3. if OPT.PICKS_CLEAN_STD exists and >0, removes picks above value*STD around mean
% 	   4. if OPT.MEDIAN_FILTER_SAMPLES exists and >0, filters the signal using value samples 
% 	   5. decimates by a factor of R (integer) using moving average,
% 	   6. if OPT.UNDERSAMPLING is OK, decimation is undersampling instead of averaging
%
%   [TC,DC,LR,TR,K]=TREATSIGNAL(...) also returns linear regression LR and trend value TRD 
%   and associated error TRE as TR = [TRD TRE], using optional second column of D as errors,
%   and some other parameters:
%       OPT.TREND_FACTOR is a dimensionless factor applied to the trend value initially in data unit/day
%       OPT.TREND_MIN_DAYS is minimum time window (in days) needed to compute a trend
%       OPT.TREND_MIN_PERC is minimum time window (in percent) needed to compute a trend
%       OPT.TREND_TLIM_DAYS is trend time limits: extreme parts (in days) of time window to be used in trend computation
%       OPT.TREND_TLIM_PERC is trend time limits: extreme parts (in percent) of time window to be used in trend computation
%       OPT.TREND_ERROR_MODE is trend error calculation mode: 1 = lscov, 2 = std, 3 = corrcoef
%       OPT.TREND_ERROR_COMPLETION is trend error factor based on the data completion
%
%   TREATSIGNAL uses ISOK, FIELD2NUM, CLEANPICKS, MMED, and RDECIM functions.
%
%	Author: F. Beauducel / WEBOBS
% 	Created: 2015-08-24
% 	Updated: 2025-03-01

if size(d,2) > 1
    e = d(:,2); % data error vector
    d = d(:,1);
else
    e = ones(size(d));
end

% removes flat intervals
if isok(OPT,'FLAT_IS_NAN')
	k = find(diff(d)==0);
	if ~isempty(k)
		d(k+1) = NaN;
	end
end

% cleanpicks filters
d = cleanpicks(d,OPT);

% median filter
m = field2num(OPT,'MEDIAN_FILTER_SAMPLES');
if m > 1
	d = mmed(d,m);
end

% decimation
if isok(OPT,'UNDERSAMPLING')
	tc = t(1:r:end);
	dc = d(1:r:end);
	ec = e(1:r:end);
else
	tc = rdecim(t,r);
	dc = rdecim(d,r);
	ec = rdecim(e,r);
end

% linear trend
lr = nan(1,2);
tr = nan(1,2);
k = find(~isnan(dc));
dtlim = diff(minmax(t));
if nargout > 3 && ~isempty(k) && dtlim > 0
    terrmod = field2num(OPT,'TREND_ERROR_MODE',1);
    trendfact = field2num(OPT,'TREND_FACTOR',1);
    trendmindays = field2num(OPT,'TREND_MIN_DAYS',1);
    trendminperc = field2num(OPT,'TREND_MIN_PERCENT',50);
    trendtlimdays = field2num(OPT,'TREND_TLIM_DAYS');
    trendtlimperc = field2num(OPT,'TREND_TLIM_PERC');
    trendcompletion = isok(OPT,'TREND_ERROR_COMPLETION',0);

    tk = tc(k);
    dk = dc(k);
    ek = ec(k);
    tlim = minmax(tk);
    dt = diff(tlim);
    if numel(k) >= 2 && dt >= trendmindays && 100*dt/dtlim >= trendminperc && ~all(isnan(dk))
        if trendtlimdays > 0
            kk = find((tk-tlim(1)) <= trendtlimdays | (tlim(2)-tk) <= trendtlimdays);
        elseif trendtlimperc > 0
            kk = find(100*(tk-tlim(1))/dt <= trendtlimperc | 100*(tlim(2)-tk)/dt <= trendtlimperc);
        else
            kk = find(tk);
        end
        [lr,stdx] = wls(tk(kk)-tk(1),dk(kk),1./ek(kk));
        % different modes for error estimation
        switch terrmod
        case 2
            tr(2) = std(dk(kk) - polyval(lr,tk(kk)-tk(1)))/dtlim;
        case 3
            cc = corrcoef(tk(kk)-tk(1),dk(kk));
            r2 = sqrt(abs(cc(2)));
            tr(2) = stdx(1)/r2;
        otherwise
            tr(2) = stdx(1);
        end
        % all errors are adjusted with sampling completeness factor
        if trendcompletion
            acq = numel(kk)*median(diff(tk))/dtlim;
            if acq > 0
                tr(2) = tr(2)/sqrt(acq);
            end
        end
        tr(1) = lr(1);
        tr = tr*trendfact; % multiplies by trend factor (from data unit/day)
    end

end