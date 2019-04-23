function y=seismic_moment(x,law)
%SEISMIC_MOMENT magnitude to seismic moment in N.m conversion equations.
%	SEISMIC_MOMENT(MAGNITUDE) returns seismic moment in N.m for magnitude
%   according to Kanamori law
%
%	SEISMIC_MOMENT(MAGNITUDE,LAW) specifies the law for magnitude to moment 
%	calculation, using following available LAW:
%
%            kanamori : Kanamori et al. [1978]
%         feuillard80 : Feuillard [1980]
%
%	SEISMIC_MOMENT returns float numbers. Use FLOOR or ROUND to produce integers.
%
%
%   Author: J.M. Saurel, WEBOBS/IPGP
%   Created: 2019-01-36, Paris, France
%   Updated: 2019*04-22

if nargin < 2
	law = 'kanamori';
end

switch lower(law)
	case 'kanamori'
		y = 10.^(9.1+1.5.*x);
	case 'feuillard80'
		y = 10.^(6.7+2.14.*x-0.054.*x.^2);
	otherwise
		error('unknown law %s.',law);
end


