function [t,s,n]=readclb(f);
%READCLB Read calibration .CLB files.
%        [T,S,N] = READCLB(FILENAME) reads the calibration file FILENAME (µGRAPH compatible) and 
%        returns a title T and calibration information into a single structure S:
%           S.name = sensor names
%           S.unit = sensor units
%           S.vmin = minimum physical values
%           S.vmax = maximum physical values
%           S.fact = generic factor
%           S.cst  = generic constant
%           S.x0 to x3 = numerator polynomial factors
%           S.y0 to y3 = denominator polynomial factors
%
%        (c) F. Beauducel, OVSG, 2001.

if nargin==0
    [f,p] = uigetfile({'*.clb;*.cal','Calibration file'},'Select a file to open');
else
    p ='';
end

fid = fopen([p f]);
if fid==-1
    error(sprintf('Cannot open %s file.',[p f]))
end

t = '';
n = 0;
while ~feof(fid)
    tline = fgetl(fid);
    n = n + 1;
    if findstr(tline,'# TITLE:')
        t = tline(10:end);
    end
    if findstr(tline,'SENSOR_NAME')
        break;
    end
end        

fclose(fid);

[sn,su,vn,vm,fc,cs,x0,x1,x2,x3,y0,y1,y2,y3] = textread([p f],'%s%s%f%f%f%f%f%f%f%f%f%f%f%f','headerlines',n);

s = struct('name',{sn},'unit',{su},'vmin',vn,'vmax',vm, ...
    'fact',fc,'cst',cs, ...
    'x0',x0,'x1',x1,'x2',x2,'x3',x3, ...
    'y0',y0,'y1',y1,'y2',y2,'y3',y3);

n = length(fc);
disp(sprintf('Fichier: %s importé. %d canaux.',[p f],n))
