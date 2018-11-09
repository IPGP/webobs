function y = filtsignal(t,x,r,f)
% FILTSIGNAL Signal filtering
% 	Y=FILTSIGNAL(T,X,SAMPRATE,FILTERNAME) processes vector signal X(T), 
%	supposing a sampling rate SAMPRATE (in Hz), using filter string name
%	FILTERNAME:
%	                [X]: constant offset value [X] (in count)
%	             median: median value correction (formerly 'auto')
%	              trend: linear detrend correction
%	              sp[X]: spline filter using [X] seconds interval points
%	                     ([X] is a positive integer)
%	[ft][fn][N],[F],[S]: filter type [ft], name [fn], order [N], cutoff
%	                     frequency [F] and attenuation [A]
%	                     - [ft] is 'lp' (lowpass), 'hp' (highpass), 
%	                       'bp' (bandpass) or 'bs' (bandstop);
%	                     - [fn] is 'bu' (Butterworth), 'be' (Bessel),
%	                       'c1' or 'c2' (Chebyshev type I or II);
%	                     - [N] is a positive integer;
%	                     - [F] is frequency (in Hz), use [FL,FH] for 'bp' 
%	                       and 'bs' type;
%	                     - [S] is stopband attenuation/ripple (in dB)
%	                       for Chebyshev only.
%	
%	and returns filtered signal Y, same length as original X.
%
%	Examples:
%		filtsignal(t,d,100,'sp5')
%		filtsignal(t,d,125,'hpbu3,0.2')
%		filtsignal(t,d,100,'bpbe2,0.05,0.5')
%
%
%	Author: F. Beauducel / WEBOBS
% 	Created: 2018-11-01 in Yogyakarta (Indonesia)
% 	Updated: 2018-11-08


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

	case {'lp','hp','bp','bs'}
		p = str2double(split(f(5:end),','));

		% number of parameters must equal 2 + 1 for band* + 1 for cheby*
		if any(isnan(p)) || (length(p) ~= (2 + strcmpi(f(1),'b') + strcmpi(f(3),'c')))
			ok = 0;
		end
		if strcmpi(f(1),'b')
			w = p(2:3)/(r/2); % band* : 2-element vector for frequency
		else
			w = p(2)/(r/2); % low/highpass
		end
		if any(w) > 1
			ok = 0;
		end

		switch lower(f(3:4))
		case 'bu'
			% Butterworth
			fn = @butter;
			arg = { p(1) , w };
		case 'be'
			% Bessel
			fn = @besself;
			arg = { p(1) , w };
		case 'c1'
			% Chebyshev I
			fn = @cheby1;
			arg = { p(1) , p(end) , w };
		case 'c2'
			% Chebyshev II
			fn = @cheby2;
			arg = { p(1) , p(end) , w };
		otherwise
			ok = 0;
		end

		switch lower(f(1:2))
		case 'hp'
			% highpass filter
			arg = cat(2,arg,'high');
		case 'bs'
			% bandstop filter
			arg = cat(2,arg,'stop');
		end

		if ok
			[b,a] = fn(arg{:});
			y = filter(b,a,xm);
		end
		
	otherwise
		ok = 0;
	end
end

if ~ok
	y = xm;
	fprintf('*** Warning: unvalid filter "%s". Keeps original signal... ***\n',f);
end
