function y=sumsq(x,dim)
if nargin < 2
	dim = 1;
end
y = sum (x .* conj (x), dim);
