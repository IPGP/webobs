function k=selectnode(N,tlim,excl,incl,llr)
%SELECTNODE Select nodes
%	K=SELECTNODE(N,TLIM,EXCLUDE,INCLUDE,TARGET) selects nodes from structure
%	N and returns index vector K using criteria:
%	   - TLIM = [DATE1,DATE2] time interval (datenum format)
%	   - EXCLUDE = node FID to exclude (cell of strings)
%	   - INCLUDE = node FID to include (cell of strings, optional)
%	   - TARGET = [LATITUDE,LONGITUDE,RADIUS] excludes nodes located outside
%	     a radius (in km) from target LATITUDE, LONGITUDE when RADIUS is
%	     positive, or inside when RADIUS is negative (in km).
%	   - TARGET = latitude and longitude of the target
%
%	Structure N comes from READNODE or READPROC and must contains fields FID,
%	INSTALL_DATE, END_DATE, LAT_WGS84, and LON_WGS84.
%
%	Use function GREATCIRCLE.
%
%	Author: F. Beauducel
%	Created: 2021-01-17 in Yogyakarta, Indonesia
%	Updated: 2022-07-22

% selects from lifetime dates
date1 = cat(1,N.INSTALL_DATE);
date2 = cat(1,N.END_DATE);
k = find((isnan(tlim(1)) | isnan(date2) | date2 >= tlim(1)) & (isnan(tlim(2)) | isnan(date1) | date1 <= tlim(2)));

% excludes some nodes from all
if nargin > 2 && ~isempty(excl)
	k = k(~ismemberlist({N(k).FID},split(excl,',')));
end

% excludes from target
if nargin > 4 && numel(llr)==3 && llr(3) ~= 0
	lat = cat(1,N.LAT_WGS84);
	lon = cat(1,N.LON_WGS84);
	if llr(3) > 0
		kk = greatcircle(llr(1),llr(2),lat(k),lon(k)) <= llr(3);
	else
		kk = greatcircle(llr(1),llr(2),lat(k),lon(k)) >= -llr(3);
	end
	k = k(kk);
end

% (re)includes some nodes
if nargin > 3 && ~isempty(incl)
	ki = find(ismemberlist({N.FID},split(incl,',')));
	k = unique([k;ki(:)]);
end
fprintf('---> %d/%d nodes selected.\n',numel(k),numel(N));
