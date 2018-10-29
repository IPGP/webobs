function t = smartdatenum(d,k)
%SMARTDATENUM Converts various date and time matrix
%	SMARTDATENUM(D) where D is a 2 to 6-column matrix containing elements 
%	of a date and time with unknown column meaning, returns a vector T in 
%	the DATENUM format.
%
%	Standard known cases for D colums are for example:
%	   [yyyy,ddd]
%	   [yyyy,mm,dd]
%	   [yyyy,dd,mm]
%	   [yyyy,mm,dd,HH,MM,SS]
%	   [mm,dd,yyyy,HH,MM,SS]
%
%	SMARTDATENUM(D,ORDER) specifies the column order in an index vector
%	ORDER = [yyyy mm dd HH MM SS] where each element corresponds to its index.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2015-12-23
%	Updated: 2018-09-28


if size(d,2) < 2 || size(d,2) > 6 || ~isnumeric(d) || any(d(:)) < 0 || any(isnan(d(:)))
	error('D must be a 2 to 6-column matrix of positive numbers (NaN not allowed).')
end

if nargin > 1 && isnumeric(k) && any(length(k)==[2,3,6])
	kk = find(d(:,k(1))<100);
	if ~isempty(kk)
		d(kk,k(1)) = d(kk,k(1)) + 1900 + 100*(d(kk,k(1))<50);
	end
	if length(k)==2
		t = datenum(d(:,k(1)),1,d(:,k(2))); % yyyy ddd case
	else
		t = datenum(d(:,k));
	end
else

	if size(d,1) > 1
		vlim = [min(d);max(d)];
	else
		vlim = [d;d];
	end


	% tests several cases: the order of appearance is mostly consistent with probability...

	if test(vlim,{'yyyy','mm','dd','HH','MM','SS'})
		t = datenum(d);
	 
	elseif test(vlim,{'yyyy','mm','dd','HH','MM'})
		t = datenum(d(:,1),d(:,2),d(:,3),d(:,4),d(:,5),0);

	elseif test(vlim,{'yyyy','mm','dd'})
		t = datenum(d);

	elseif test(vlim,{'yyyy','ddd'})
		t = datenum(d(:,1),1,d(:,2));

	elseif test(vlim,{'yyyy','ddd','HH','MM'})
		t = datenum(d(:,1),1,d(:,2),d(:,3),d(:,4),0);

	elseif test(vlim,{'dd','mm','yyyy','HH','MM','SS'})
		t = datenum(d(:,[3,2,1,4,5,6]));

	elseif test(vlim,{'dd','mm','yyyy','HH','MM'})
		t = datenum(d(:,3),d(:,2),d(:,1),d(:,4),d(:,5),0);

	elseif test(vlim,{'dd','mm','yyyy'})
		t = datenum(d(:,[3,2,1]));
	 
	elseif test(vlim,{'mm','dd','yyyy','HH','MM','SS'})
		t = datenum(d(:,[3,1,2,4,5,6]));

	elseif test(vlim,{'mm','dd','yyyy','HH','MM'})
		t = datenum(d(:,3),d(:,1),d(:,2),d(:,4),d(:,5),0);

	elseif test(vlim,{'mm','dd','yyyy'})
		t = datenum(d(:,[3,1,2]));

	elseif test(vlim,{'HH','MM','SS','dd','mm','yyyy'})
		t = datenum(d(:,[6,5,4,1,2,3]));

	else
		disp(vlim);
		error('Cannot guess the column order with these column limits...');
	end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ok=test(vlim,k)

ok = false;

if size(vlim,2) == length(k)
	ok = true;
	for x = 1:length(k)
		switch k{x}
		case 'yyyy'
			% not tested because year has no limits of validity
		case 'mm'
			ok = (ok && vlim(1,x) >= 1 && vlim(2,x) <= 12);
		case 'dd'
			ok = (ok && vlim(1,x) >= 1 && vlim(2,x) <= 31);
		case 'ddd'
			ok = (ok && vlim(1,x) >= 1 && vlim(2,x) <= 366);
		case 'HH'
			ok = (ok && vlim(1,x) >= 0 && vlim(2,x) <= 23);
		case 'MM'
			ok = (ok && vlim(1,x) >= 0 && vlim(2,x) <= 59);
		case 'SS'
			ok = (ok && vlim(1,x) >= 0 && vlim(2,x) < 60);
		otherwise
			ok = false;
		end
	end
end
