function att=gmpe(law,magn,dist_hypo,dep)
%GMPE Empirical ground motion prediction equation for PGA.
% 	GMPE(LAW,MAG,HYP,DEP) returns theoretical Peak Ground Acceleration
% 	(PGA, in g) from magnitude MAG, hypocentral distance HYP (km), and optional
% 	depth DEP (km), using one of the following laws:
%
% 	  beauducel04 : Beauducel et al. [2004] B3 Guadeloupe rock
%	  beauducel09 : Beauducel et al. [2009] new B3 average
% 	     youngs97 : Youngs et al. [1997] rock
%	    youngs97b : Youngs et al. [1997] soil
% 	     chang01a : Chang et al. [2001] shallow
% 	     chang01b : Chang et al. [2001] subduction
%	         ft90 : Fukushima et Tanaka [1990] Japon
%	         ab03 : Atkinson et Boore [2003] Cascades
%	     sadigh97 : Sadigh et al. [1997]
%	  ambraseys05 : Ambraseys et al. [2005]
%	      kanno06 : Kanno et al. [2006]
%	     kanno06b : Kanno et al. [2006] deep
%
% 	MAG, DHP or DEP can be either scalars, vectors or matrices, but all
% 	non-scalar variables must have the same size.
%
%	Authors: M.P. Bouin, A. Bosson, F. Beauducel, WEBOBS/IPGP
%	Created: 2008-10-30
%	Updated: 2015-04-04

if nargin < 4
	dep = 0;
end

dist_epi = sqrt(dist_hypo.^2 - dep^2);

switch lower(law)
	case 'beauducel04'
		rmin = 5;
		dist_hypo(dist_hypo<rmin) = rmin;
		att = 10.^(0.611377*magn -0.00584334*dist_hypo - log10(dist_hypo) -3.216674);
	case 'beauducel09'
		rmin = 10.^((magn - 4.5)/2);
		dist_hypo(dist_hypo<rmin) = rmin;
		att = 10.^(0.617550*magn -0.00307456*dist_hypo - log10(dist_hypo) -3.396810);
	case 'youngs97'
		intraslab = (dep < 51);
		att = exp(0.2418 + 1.414*magn - 2.552*log(dist_hypo + 1.7818*exp(0.554*magn)) + 0.00607*dep + 0.3846*intraslab);
	case 'youngs97b'
		intraslab = (dep < 51);
		att = exp(-0.6687 + 1.438*magn - 2.329*log(dist_hypo + 1.097*exp(0.617*magn)) + 0.00648*dep + 0.3643*intraslab);
	case 'chang01a'
		att = exp(2.8096 + 0.8993*magn - 0.4381*log(dep) - (1.0954 - 0.0079*dep)*log(dist_epi))/981;
	case 'chang01b'
		att = exp(4.7141 + 0.8468*magn - 0.1745*log(dep) - 1.2972*log(dist_hypo))/981;
	case 'ft90'
		att = exp(0.41*magn - log10(dist_hypo + 0.0032*10^(0.41*magn)) - 0.0034*dist_hypo + 1.30);
	case 'ab03'
		att = exp(-3.70012 + 1.1169*magn + 0.00615*dep - 0.00045*dist_hypo )/981;
	case 'sadigh97'
		att = exp(-0.624 + magn - 2.1*log(dist_hypo + exp(1.29649 + 0.250*magn)));
		k = find(magn > 6.5);
		att(k) = exp(-1.274 + 1.1*magn(k) - 2.1*log(dist_hypo + exp(-0.48451 + 0.524*magn(k))));
	case 'ambraseys05'
		att = 10.^(2.522 - 0.142*magn +(-3.184+0.314*magn)*log10(sqrt(dist_hypo.^2+7.6^2))-0.084)/9.81;
	case 'kanno06'
		att = 10.^(0.56*magn-0.0031*dist_hypo-log10(dist_hypo+0.0055*10^(0.37*magn))+0.26+0.37)/981;
	case 'kanno06b'
		att = 10.^(0.41*magn-0.0039*dist_hypo-log10(dist_hypo)+1.56+0.40)/981;
	otherwise
		error('unknown law %s.',law);
end

