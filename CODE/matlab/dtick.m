function dd = dtick(dlim)
%DTICK Tick intervals

m = 10^floor(log10(abs(dlim)));
p = ceil(abs(dlim)/m);
if p <= 1
	dd = .1*m;
elseif p == 2
	dd = .2*m;
elseif p <= 5
	dd = .5*m;
else
	dd = m;
end

dd = sign(dlim)*dd;
