function [dc,C]=calib(t,d,CLB,cco);
%CALIB  Calibrate data
%       [DC,C] = CALIB(T,D,CLB) calibrates data D(T) using information
%       from structure CLB (imported from stations using readnode), and
%       returns a matrix DC of calibrated data, and a structure C with
%       last valid informations about channels.
%
%	[...] = CALIB(T,D,CLB,'ChannelCodeOrder') reorders the channels using
%	indexes in the Channel Code field. This is done before applying the calibration.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2004-09-01
%	Updated: 2017-02-01

if isempty(t) | (isscalar(t) & isnan(t))
	t = now;
end

if isempty(d)
	d = nan(1,CLB.nx);
end

if nargin > 3 & strcmp(lower(cco),'channelcodeorder')
	cco = 1;
else
	cco = 0;
end

if CLB.nx > 0
	dc = nan(size(d,1),CLB.nx);
else
	dc = d;
	CLB = [];
end

% Possibilitiy to transmit a single value for time (example: RAP)
if length(t) < size(d,1)
	t = t(1)*ones(size(d,1),1);
end

% main loop on calibration file lines
for j = 1:length(CLB)
	% loop on data columns
	nv = unique(CLB.nv);
	for i = 1:length(nv)
		ki = find(CLB(j).nv == nv(i));
		if ~isempty(ki)
			[tt,kii] = sort(CLB(j).dt(ki));
			ki = ki(kii);
			tt = [tt,realmax];
			% loop on each calibration line for channel i
			for ii = 1:(length(tt)-1)
				k = find(t >= tt(ii) & t < tt(ii+1));
				if ~isempty(k)
					% selects the right column of raw data
					col = str2double(CLB(j).cd{ki(ii)});
					if cco == 0 || col <= 0 || col > size(d,2) || isnan(col)
						col = i;
					end
					fprintf('WEBOBS{calib}: channel %d ("%s") calibrated from %s column %d (%d data).\n',i,CLB(j).nm{ki(ii)},datestr(tt(ii)),col,length(k))
					if CLB(j).vn(ki(ii)) ~= 0 | CLB(j).vm(ki(ii)) ~= 0
						kk = find(d(k,col) < CLB(j).vn(ki(ii)) | d(k,col) > CLB(j).vm(ki(ii)));
						if ~isempty(kk)
							d(k(kk),col) = NaN;
						end
					end
					dc(k,i) = d(k,col)*CLB(j).et(ki(ii))*CLB(j).ga(ki(ii)) + CLB(j).of(ki(ii));
					for f = {'nm','un','ns','cd','of','et','ga','vn','vm','az','la','lo','al','dp','sf','db','lc'}
						C.(char(f))(i) = CLB(j).(char(f))(ki(ii));
					end
				end
			end
		else
			% no channel info in CLB: just copy the raw data in same column
			dc(:,i) = d(:,i);
		end
	end
end

if isempty(CLB)
	C = struct('nx',0);
else
	C.nx = length(unique(CLB.nv));
end
