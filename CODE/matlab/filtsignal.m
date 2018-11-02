function y = filtsignal(t,x,r,fn)
% FILTSIGNAL Signal filtering
% 	Y=FILTSIGNAL(T,X,SAMPRATE,FILTERNAME) processes vector signal X(T), 
%	supposing a sampling rate SAMPRATE (in Hz), using filter string name
%	FILTERNAME:
%	            [X]: constant offset value [X] (in count)
%	         median: median value correction (formerly 'auto')
%	          trend: linear detrend correction
%	          sp[X]: spline filter using [X] seconds interval points ([X] is integer)
%	      lp[N],[F]: [N]th-order lowpass butterworth with cutoff frequency [F] (in Hz)
%	      hp[N],[F]: [N]th-order highpass butterworth with cutoff frequency [F] (in Hz)
%	  bp[N],[L],[H]: [N]th-order bandpass butterworth with cutoff frequencies low [L] and high [H] (in Hz)
%	
%	and returns filtered signal Y, same length as original X.
%
%	Examples:
%		filtsignal(t,d,100,'sp5')
%		filtsignal(t,d,125,'hp3,0.2')
%		filtsignal(t,d,100,'bp2,0.05,0.5')
%
%
%	Author: F. Beauducel / WEBOBS
% 	Created: 2018-11-01 in Yogyakarta (Indonesia)
% 	Updated: 2018-11-01


ok = 1;
if ~isnan(str2double(fn))
	% removes constant value
	y = x - str2double(fn);
else
	xm = x - median(x);

	switch lower(fn(1:2))
	case {'me','au'}
		% median filter (removes median value)
		if strcmpi(fn,'median') || strcmpi(fn,'auto')
			y = xm;
		else
			ok = 0;
		end

	case 'tr'
		% removes linear trend
		if strcmpi(fn,'trend')
			ds = linfilter(t,xm,2,r);
		else
			ok = 0;
		end

	case 'sp'
		% spline filter (removes spline from decimated segments)
		spn = str2double(fn(3:end));
		if ~isnan(spn) && rem(60,spn) == 0
			ds = linfilter(t,xm,60/spn + 1,r);
		else
			ok = 0;
		end

	case 'lp'
		% lowpass Butterworth filter
		p = str2double(split(fn(3:end),','));
		if length(p) == 2 && all(~isnan(p))
			[b,a] = butter(p(1),p(2)/(r/2));
			y = filter(b,a,xm);
		else
			ok = 0;
		end
		
	case 'hp'
		% highpass Butterworth filter
		p = str2double(split(fn(3:end),','));
		if length(p) == 2 && all(~isnan(p))
			[b,a] = butter(p(1),p(2)/(r/2),'high');
			y = filter(b,a,xm);
		else
			ok = 0;
		end
		
	case 'bp'
		% bandpass Butterworth filter
		p = str2double(split(fn(3:end),','));
		if length(p) == 3 && all(~isnan(p))
			[b,a] = butter(p(1),p(2:3)/(r/2));
			y = filter(b,a,xm);
		else
			ok = 0;
		end
		
	otherwise
		ok = 0;
	end
end

if ~ok
	y = x;
	fprintf('*** Warning: unvalid filter name "%s". Keeps original signal... ***\n',fn);
end
