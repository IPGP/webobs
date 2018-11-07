function y = filtsignal(t,x,r,f)
% FILTSIGNAL Signal filtering
% 	Y=FILTSIGNAL(T,X,SAMPRATE,FILTERNAME) processes vector signal X(T), 
%	supposing a sampling rate SAMPRATE (in Hz), using filter string name
%	FILTERNAME:
%	            [X]: constant offset value [X] (in count)
%	         median: median value correction (formerly 'auto')
%	          trend: linear detrend correction
%	          sp[X]: spline filter using [X] seconds interval points ([X] is integer)
%	[ft][fn][N],[F]: filter type [ft], name [fn], order [N] and cutoff frequency [F]
%	                 - [ft] is 'lp' (lowpass), 'hp' (highpass) or 'bp' (bandpass)
%	                 - [fn] is 'bu' (Butterworth)
%	                 - [N] is a positive integer
%	                 - [F] is frequency (in Hz), use [FL,FH] for 'bp' type
%	
%	and returns filtered signal Y, same length as original X.
%
%	Examples:
%		filtsignal(t,d,100,'sp5')
%		filtsignal(t,d,125,'hpbu3,0.2')
%		filtsignal(t,d,100,'bpbu2,0.05,0.5')
%
%
%	Author: F. Beauducel / WEBOBS
% 	Created: 2018-11-01 in Yogyakarta (Indonesia)
% 	Updated: 2018-11-07


ok = 1;
if ~isnan(str2double(f))
	% removes constant value
	y = x - str2double(f);
else
	xm = x - median(x);

	switch lower(f(1:2))
	case {'me','au'}
		% median filter (removes median value)
		if strcmpi(f,'median') || strcmpi(f,'auto')
			y = xm;
		else
			ok = 0;
		end

	case 'tr'
		% removes linear trend
		if strcmpi(f,'trend')
			ds = linfilter(t,xm,2,r);
		else
			ok = 0;
		end

	case 'sp'
		% spline filter (removes spline from decimated segments)
		spn = str2double(f(3:end));
		if ~isnan(spn) && rem(60,spn) == 0
			ds = linfilter(t,xm,60/spn + 1,r);
		else
			ok = 0;
		end

	case {'lp','hp','bp'}
		switch lower(f(3:4))
		case 'bu'
			fn = @butter;
		otherwise
			ok = 0;
		end
		p = str2double(split(f(5:end),','));

		switch lower(f(1:2))
		case 'lp'
			% lowpass Butterworth filter
			if ok && length(p) == 2 && all(~isnan(p))
				[b,a] = fn(p(1),p(2)/(r/2));
			else
				ok = 0;
			end
		case 'hp'
			% highpass Butterworth filter
			if ok && length(p) == 2 && all(~isnan(p))
				[b,a] = fn(p(1),p(2)/(r/2),'high');
			else
				ok = 0;
			end
		case 'bp'
			% bandpass Butterworth filter
			if ok && length(p) == 3 && all(~isnan(p))
				[b,a] = fn(p(1),p(2:3)/(r/2));
			else
				ok = 0;
			end
		end
		if ok
			y = filter(b,a,xm);
		end
		
	otherwise
		ok = 0;
	end
end

if ~ok
	y = xm;
	fprintf('*** Warning: unvalid filter "%s". Keeps original signal... ***\n',fn);
end
