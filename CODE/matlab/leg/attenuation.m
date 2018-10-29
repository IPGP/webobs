function att=attenuation(loi,magn,dist_hypo,prof)
% ATTENUATION Seismic attenuation law for PGA.
% 	ATTENUATION(LAW,MAG,HYP,DEP) returns theoretical Peak Ground Acceleration
% 	(PGA, in g) from magnitude MAG, hypocentral distance HYP, and optional
% 	depth DEP, using one of the following laws:
% 		 1 = Beauducel et al. [2004] B3 rock
% 		 2 = Beauducel et al. [2009] new B3 average
% 		 3 = Youngs et al. [1997] rock
% 		 4 = Youngs et al. [1997] soil
% 		 5 = Chang et al. [2001] shallow
% 		 6 = Chang et al. [2001] subduction
%		 7 = Fukushima et Tanaka [1990] Japon
%		 8 = Atkinson et Boore [2003] Cascades
%		 9 = Sadigh et al. [1997]
%		10 = Ambraseys et al. [2005]
%		11 = Kanno et al. [2006]
%		12 = Kanno et al. [2006] deep
%
% 	MAG, DHP or DEP can be either scalars, vectors or matrices, but all
% 	non-scalar variables must have the same size.
%
%	Authors: M.P. Bouin, A. Bosson, F. Beauducel
%	Date: 2008-10-30, modified 2009-02-19

if nargin < 4
	prof = 0;
end

dist_epi = sqrt(dist_hypo.^2i - prof^2);

switch loi
	case 1 %B3 rocher (2004)
		att = 10.^(0.611377*magn -0.00584334*dist_hypo - log10(dist_hypo) -3.216674);
	case 2 %nouvelle B3 moyenne (2009)
		att = 10.^(0.617550*magn -0.00307456*dist_hypo - log10(dist_hypo) -3.396810);
	case 3 %Youngs et al., 1997 (globale), rocher --- > Vérifié dist
		intraslab = (prof < 51);
		att = exp(0.2418 + 1.414*magn - 2.552*log(dist_hypo + 1.7818*exp(0.554*magn)) + 0.00607*prof + 0.3846*intraslab);
	case 4 %Youngs et al., 1997 (globale), sol --- > Vérifié dist
		intraslab = (prof < 51);
		att = exp(-0.6687 + 1.438*magn - 2.329*log(dist_hypo + 1.097*exp(0.617*magn)) + 0.00648*prof + 0.3643*intraslab);
	case 5 %Chang et al., 2001 shallow --- > Vérifié dist + ln
		att = exp(2.8096 + 0.8993*magn - 0.4381*log(prof) - (1.0954 - 0.0079*prof)*log(dist_epi))/981;
	case 6 %Chang et al., 2001 subd --- > Vérifié dist + ln
		att = exp(4.7141 + 0.8468*magn - 0.1745*log(prof) - 1.2972*log(dist_hypo))/981;
	case 7 %Fukushima et Tanaka, 1990 (Japon)
		att = exp(0.41*magn - log10(dist_hypo + 0.0032*10^(0.41*magn)) - 0.0034*dist_hypo + 1.30);
	case 8 %Atkinson et Boore, 2003 (Cascades)
		att = exp(-3.70012 + 1.1169*magn + 0.00615*prof - 0.00045*dist_hypo )/981;
	case 9 %Sadigh et al., 1997 --- > Vérifié ln + dist + unité
		att = exp(-0.624 + magn - 2.1*log(dist_hypo + exp(1.29649 + 0.250*magn)));
		k = find(magn > 6.5);
		att(k) = exp(-1.274 + 1.1*magn(k) - 2.1*log(dist_hypo + exp(-0.48451 + 0.524*magn(k))));
	case 10 %Ambraseys et al., 2005 --- > Vérifié log10 dist + unité
		att = 10.^(2.522 - 0.142*magn +(-3.184+0.314*magn)*log10(sqrt(dist_hypo.^2+7.6^2))-0.084)/9.81;
	case 11 %Kanno et al., 2006 --- > Vérifié log10 + dist_hypo
		att = 10.^(0.56*magn-0.0031*dist_hypo-log10(dist_hypo+0.0055*10^(0.37*magn))+0.26+0.37)/981;
	case 12 %Kanno et al., 2006 deep --- > Vérifié log10 + dist_hypo
		att = 10.^(0.41*magn-0.0039*dist_hypo-log10(dist_hypo)+1.56+0.40)/981;
end

