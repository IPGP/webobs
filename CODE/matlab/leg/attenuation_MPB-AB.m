function att=attenuation(loi,magn,dist_hypo,prof)
% ATTENUATION
%       Calcul d'une loi d'atténuation sur une grille de points
dist_epi=sqrt(dist_hypo.^2-prof^2);
switch loi
	case 1 %B3 rocher
		att = 1000*10.^(0.611377*magn -0.00584334*dist_hypo - log10(dist_hypo) -3.216674);
	case 2 %B3 sol
		att = 3*1000*10.^(0.611377*magn -0.00584334*dist_hypo - log10(dist_hypo) -3.216674);
	case 3 %Youngs et al., 1997 (globale), rocher --- > Vérifié dist
		if prof < 51
		    intraslab = 1;
		else
		    intraslab = 0;
		end
		att = 1000*exp(0.2418 + 1.414*magn - 2.552*log(dist_hypo + 1.7818*exp(0.554*magn)) + 0.00607*prof + 0.3846*intraslab);
	case 4 %Youngs et al., 1997 (globale), sol --- > Vérifié dist
		if prof < 51
		    intraslab = 1;
		else
		    intraslab = 0;
		end
		att = 1000*exp(-0.6687 + 1.438*magn - 2.329*log(dist_hypo + 1.097*exp(0.617*magn)) + 0.00648*prof + 0.3643*intraslab);
	case 5 %Chang et al., 2001 shallow --- > Vérifié dist + ln
		att = 1000*exp(2.8096 + 0.8993*magn - 0.4381*log(prof) - (1.0954 - 0.0079*prof)*log(dist_epi))/981;
	case 6 %Chang et al., 2001 subd --- > Vérifié dist + ln
		att = 1000*exp(4.7141 + 0.8468*magn - 0.1745*log(prof) - 1.2972*log(dist_hypo))/981;
	case 7 %Fukushima et Tanaka, 1990 (Japon)
		att=1000*exp(0.41*magn - log10(dist_hypo + 0.0032*10^(0.41*magn)) - 0.0034*dist_hypo + 1.30);
	case 8 %Atkinson et Boore, 2003 (Cascades)
		att=1000*exp(-3.70012 + 1.1169*magn + 0.00615*prof - 0.00045*dist_hypo )/981;
	case 9 %Sadigh et al., 1997 --- > Vérifié ln + dist + unité
		if magn <= 6.5
			att=1000*exp(-0.624 + magn - 2.1*log(dist_hypo + exp(1.29649 + 0.250*magn)));
		else
			att=1000*exp(-1.274 + 1.1*magn - 2.1*log(dist_hypo + exp(-0.48451 + 0.524*magn)));
		end
	case 10 %Ambraseys et al., 2005 --- > Vérifié log10 dist + unité
		att = 1000*10.^(2.522 - 0.142*magn +(-3.184+0.314*magn)*log10(sqrt(dist_hypo.^2+7.6^2))-0.084)/9.81;
	case 11 %Kanno et al., 2006 --- > Vérifié log10 + dist_hypo
		att = 1000*10.^(0.56*magn-0.0031*dist_hypo-log10(dist_hypo+0.0055*10^(0.37*magn))+0.26+0.37)/981;
	case 12 %Kanno et al., 2006 deep --- > Vérifié log10 + dist_hypo
		att = 1000*10.^(0.41*magn-0.0039*dist_hypo-log10(dist_hypo)+1.56+0.40)/981;
end
% size(att)
