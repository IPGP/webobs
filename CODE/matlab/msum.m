 function y = msum(varargin)
%MSUM Moving sum.
%	Y = MSUM(X,N) returns the "moving sum" of X on N consecutive values.
%	Y has the same size as X, and each element of Y is the sum of the N 
%	previous values of X. X is supposed to be a regularly spaced data vector.
%   The first N-1 values of Y are NaN.
%
%	Y = MSUM(T,X,TW) computes the sum of values of X(T) in each preceeding
%   time window TW (in days), where T is a time vector in DATENUM format,
%   same length as the number of lines in X. X can be an irregularly space
%   data vector.
%
%	If X is a matrix, MSUM works down the columns. Y has the same size as X.
%
%	Author: F. Beauducel / WebObs
%	Created: 2023-09-14 inspired by previous MOVSUM function (2005)
%	Updated: 2023-09-14
%

verbose = any(strcmpi(varargin,'verbose'));

switch nargin-verbose

	case 2
		y = vmsum(varargin{1},varargin{2});

	case 3
		t = varargin{1};
		x = varargin{2};
		tw = varargin{3};

		% makes a monotonic time series
		[t,i] = sort(t);
		x = x(i,:);
		y = nan(size(x));

		% detects the regularly spaced data blocks
		dt2 = [0;0;diff(t,2)];
		edt = 1e-3/86400; % ms in datenum
		l = size(x,1);
		n = 1;
		% while loop on the data blocks
		while n < l
			k1 = n:n+find(abs(dt2(n:l))>edt,1)-2; % block indexes
			if length(k1) > 1
				n1 = round(tw/median(diff(t(k1)))); % number of samples for the median time interval
				if verbose
					fprintf('block %d (%d @%g)...',n,length(k1),n1);
				end
				y(k1,:) = vmsum(x(k1,:),n1);
				n = k1(end);
			else
				n = n + 1;
			end
		end

		% completes NaN with a loop (general case)
		for k = find(isnan(y(:,1)))'
			y(k,:) = sum(x(t>t(k)-tw & t<=t(k),:),1);
		end
	
	otherwise
		error('Wrong number of input arguments.')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y = vmsum(x,n)
%VMSUM Vectorized moving sum

if size(x,1) >= n
	% uses FILTER function with 1 coefficients
	y = filter(ones(1,n),1,x);

	% replaces first N-1 values by NaN
	y(1:n-1,:) = NaN;
else
	y = nan(size(x));
end
