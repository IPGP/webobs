 function [y,tc] = movsum(varargin)
%MOVSUM Moving sum plot.
%	Y = MOVSUM(X,N) returns the "moving sum" of X on N consecutive values.
%	Y has the same size as X, and each element of Y is the sum of the N 
%	previous values of X. If X is a regularly spaced data vector, then Y
%	corresponds to a digital filter with N b-coefficient equal to one:
%		y(n) = x(n) + x(n-1) + ... + x(1)
%	This is nearly equivalent to a moving average, but instead of mean it 
%	is the sum. If X is a matrix, MOVSUM works down the columns.
%
%	[Y,TC] = MOVSUM(T,X,N) considers a monotonic vector X with 
%	corresponding time vector T at constant sampling interval but with 
%	possible gaps. In this case, the function fills the gaps first (with 
%	zero values) before computing the moving sum. TC is the returned new 
%	time vector (same size as Y).
%
%	[Y,TC] = MOVSUM(T,X,DTX,DTY) considers a possibly irregularly spaced
%	vector X with corresponding time vector T. DTX defines the sampling
%	period of X, and DTY the time interval, multiple of DTX, to compute the
%	moving sum. DTX and DTY are scalars and are in the same unit as T. A
%	second output argument TC can be returned containing the new monotonic 
%	time vector (same size as Y).
%
%	A typical use is for rainfall data vectors. For instance, if X contains
%	rainfall values at 1-minute interval, MOVSUM(X,60) will be the hourly
%	rainfall, expressed as a continous vector of the same size as X.
%	Compared to classical histogram representation, this method avoids some
%	artifacts due to windowing using a priori time intervals.
%
%   MOVSUM(...) without output arguments produces a plot of the results.
%
%	Author: Fran�ois Beauducel <beauducel@ipgp.fr>
%		Institut de Physique du Globe de Paris / WEBOBS
%	Created: 2005
%	Updated: 2023-09-14
%

switch nargin

	case 2
		
		x = varargin{1};
		n = varargin{2};
		if ~isnumeric(x)
			error('X argument must be numeric.')
		end
		if ~isnumeric(n) || numel(n) ~= 1 || n < 0 || mod(n,1)
			error('N argument must be a scalar positive integer.')
		end
		t = (1:size(x,1))';
		xc = x;

	case 3
		
		t = varargin{1};
		x = varargin{2};
		n = varargin{3};
		if ~isnumeric(t) || ~isnumeric(x) || size(t,1) ~= size(x,1)
			error('T and X must be numeric with same number of rows.')
		end
		if ~isnumeric(n) || numel(n) ~= 1 || n < 0 || mod(n,1)
			error('N argument must be a scalar positive integer.')
		end
		
		% tests if t is monotonic time vector with gaps
		dt = diff(t);
		dtx = min(dt);
		if dtx <= 0
			error('T must be monotonic non decreasing vector.');
		end
		if any(rem(dt,dtx))
			error('Cannot find a constant sampling interval for T.');
		end
		
	case 4
		
		t = varargin{1};
		x = varargin{2};
		dtx = varargin{3};
		dty = varargin{4};
		if ~isnumeric(t) || ~isnumeric(x) || size(t,1) ~= size(x,1)
			error('T and X must be numeric with same number of rows.')
		end
		if ~isnumeric(dtx) || numel(dtx) ~= 1 || dtx < 0
			error('DTX argument must be a positive scalar.')
		end
		if ~isnumeric(dty) || numel(dty) ~= 1 || dty < 0 || rem(dty,dtx)
			error('DTY argument must be a positive scalar multiple of DTX.')
		end
		n = dty/dtx;
			
		otherwise
			error('Wrong number of input arguments.')
end

if nargin > 2
	% makes a continuous monotonic time vector
	tc = (t(1):dtx:t(end))';
	r = dtx/2;
	%resamples vector x into xc (using sum)
	xc = zeros(size(tc));
	for i = 1:numel(tc)
		xc(i) = sum(x(t >= (tc(i) - r) & t < (tc(i) + r)));
	end
end


% uses FILTER to compute the moving sum
y = filter(ones(1,n),1,xc);


% --- without output argument, plots the data
if nargout == 0
	figure
	[ax,h1,h2] = plotyy(tc,y,t,cumsum(x),'area','plot');
	set(h2,'LineWidth',2);
	colormap(cool)
	ylabel(ax(1),sprintf('Moving sum on %d samples',n))
	ylabel(ax(2),'Cumulative sum')
	grid on
end
