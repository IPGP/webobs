function y=seismic_energy(x,law)
%SEISMIC_ENERGY magnitude to seismic energy in J conversion equations.
%	SEISMIC_ENERGY(MAGNITUDE) returns seismic energy in J for magnitude
%   according to Kanamori law
%
%	SEISMIC_ENERGY(MAGNITUDE,LAW) specifies the law for magnitude to energy 
%	calculation, using following available LAW:
%
%            kanamori : Kanamori et al. [1978]
%         feuillard80 : Feuillard [1980]
%
%	SEISMIC_ENERGY returns float numbers. Use FLOOR or ROUND to produce integers.
%
%
%   Author: J.M. Saurel, WEBOBS/IPGP
%   Created: 2019-01-36, Paris, France
%   Updated: 2019-04-22

if nargin < 2
	law = 'kanamori';
end

switch lower(law)
	case 'kanamori'
		y = 10.^(4.8+1.5.*x);
	case 'feuillard80'
		y = 10.^(2.4+2.14.*x-0.054.*x.^2);
	otherwise
		error('unknown law %s.',law);
end


