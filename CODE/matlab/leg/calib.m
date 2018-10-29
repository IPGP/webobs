function [dc,C]=calib(t,d,CLB);
%CALIB  Calibrate data
%       [DC,C] = CALIB(T,D,CLB) calibrates data D(T) using information
%       from structure CLB (imported from stations using READST), ans
%       returns a matrix DC of calibrated data, and a structure C with
%       last valid informations about channels.
%

%   Author: F. Beauducel, OVSG-IPGP
%   Created : 2004-09-01
%   Updated : 2009-09-10

% Possibilitiy to transmit a single value for time (example: RAP)
if length(t) < size(d,1)
    t = t(1)*ones(size(d,1),1);
end

for j = 1:length(CLB)
    for i = 1:size(d,2)
        ki = find(CLB(j).nv == i);
        if ~isempty(ki)
            [tt,kii] = sort(CLB(j).dt(ki));
            ki = ki(kii);
            tt = [tt,realmax];
            for ii = 1:(length(tt)-1)
                k = find(t >= tt(ii) & t < tt(ii+1));
                disp(sprintf(' * Channel %d ("%s"): calibrated from %s (%d data)...',i,CLB(j).nm{ki(ii)},datestr(tt(ii)),length(k)))
		if CLB(j).vn(ki(ii)) ~= 0 | CLB(j).vm(ki(ii)) ~= 0
                	kk = find(d(k,i) < CLB(j).vn(ki(ii)) | d(k,i) > CLB(j).vm(ki(ii)));
                	if ~isempty(kk)
                    		d(k(kk),i) = NaN;
                	end
		end
                d(k,i) = d(k,i)*CLB(j).et(ki(ii))*CLB(j).ga(ki(ii)) + CLB(j).of(ki(ii));
            end
            C.nv(i) = CLB(j).nv(ki(end));
            C.nm(i) = CLB(j).nm(ki(end));
            C.un(i) = CLB(j).un(ki(end));
            C.ns(i) = CLB(j).ns(ki(end));
            C.cd(i) = CLB(j).cd(ki(end));
            C.of(i) = CLB(j).of(ki(end));
            C.et(i) = CLB(j).et(ki(end));
            C.ga(i) = CLB(j).ga(ki(end));
            C.vn(i) = CLB(j).vn(ki(end));
            C.vm(i) = CLB(j).vm(ki(end));
            C.az(i) = CLB(j).az(ki(end));
            C.la(i) = CLB(j).la(ki(end));
            C.lo(i) = CLB(j).lo(ki(end));
            C.al(i) = CLB(j).al(ki(end));
        end
    end
end
dc = d;
