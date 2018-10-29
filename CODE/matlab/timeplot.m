function varargout=timeplot(t,d,samp,varargin)
%TIMEPLOT Time series plot
%	TIMEPLOT(T,D,SAMP) plots time series D(T) using continuous line
%	where sampling rate is regular (about SAMP value), showing gaps
%	where time interval is more than 150%.
%
%	TIMEPLOT(T,D) or TIMEPLOT(T,D,[],...) will guess the sampling rate
%	automatically (using median value of time interval).
%
%	TIMEPLOT(T,D,0) will force a continuous plot.
%
%	TIMEPLOT(...,'Param',value,...) adds any parameter to plot function.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2015-08-25 in Yogyakarta, Indonesia
%	Updated: 2018-04-20

if nargin < 2
	error('Not enough input argument.')
end

dt = diff(t);

if nargin < 3
	samp = [];
end

if isempty(samp) || isnan(samp) || ~isnumeric(samp)
	% guess the sampling rate
	samp = median(dt);
end

if samp > 0

	k = find(dt > 1.5*samp);

	tk = cat(2,t(k),t(k+1));
	t = cat(1,t,mean(tk,2));
	d = cat(1,d,nan(length(k),1));

	[t,kk] = sort(t);

	h = plot(t,d(kk),varargin{:});
else
	h = plot(t,d,varargin{:});
end

if nargout > 0
	varargout{1} = h;
end

