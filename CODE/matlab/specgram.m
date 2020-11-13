function [yo,fo,to] = specgram(varargin)
%SPECGRAM Spectrogram using a Short-Time Fourier Transform (STFT).
%	SPECGRAM(X)
%	SPECGRAM(X,NFFT)
%	SPECGRAM(X,NFFT,FS)
%	SPECGRAM(X,NFFT,FS,WINDOW)
%	SPECGRAM(X,NFFT,FS,WINDOW,NOVERLAP)
%	[S,F,T] = SPECGRAM(...)

%   Based on a former obsolete source code from:
%		L. Shure (1991) and T. Krauss (1993) / MathWorks

narginchk(1,5)
[x,nfft,Fs,window,noverlap] = specgramchk(varargin);
    
nx = numel(x);
nwind = numel(window);
if nx < nwind
    x(nwind) = 0;
	nx = nwind;
end

ncol = fix((nx - noverlap)/(nwind - noverlap));
colindex = 1 + (0:(ncol-1))*(nwind-noverlap);
rowindex = (1:nwind)';
if numel(x) < (nwind + colindex(ncol) - 1)
    x(nwind + colindex(ncol) - 1) = 0;
end

if numel(nfft) > 1
    df = diff(nfft);
    evenly_spaced = all(abs(df-df(1))/Fs<1e-12);
    use_chirp = evenly_spaced & (numel(nfft)>20);
else
    use_chirp = 0;
end

if numel(nfft) == 1 || use_chirp
    y = zeros(nwind,ncol);
    y(:) = x(rowindex(:,ones(1,ncol))+colindex(ones(nwind,1),:)-1);
    y = window(:,ones(1,ncol)).*y;

    if ~use_chirp
        y = fft(y,nfft);
        if ~any(any(imag(x)))
            if rem(nfft,2)
                select = 1:(nfft+1)/2;
            else
                select = 1:nfft/2+1;
            end
            y = y(select,:);
        else
            select = 1:nfft;
        end
        f = (select - 1)'*Fs/nfft;
	else
        f = nfft(:);
        f1 = f(1);
        f2 = f(end);
        m = length(f);
        w = exp(-1i*2*pi*(f2-f1)/(m*Fs));
        a = exp(1i*2*pi*f1/Fs);
        y = czt(y,m,w,a);
    end
else
    f = nfft(:);
    q = nwind - noverlap;
    extras = floor(nwind/q);
    x = [zeros(q-rem(nwind,q)+1,1); x];
    D = window(:,ones(1,numel(f))).*exp((-1i*2*pi/Fs*((nwind-1):-1:0)).'*f'); 
    y = upfirdn(x,D,1,q).';
    y(:,[1:extras+1 end-extras+1:end]) = []; 
end

t = (colindex-1)'/Fs;

switch nargout
	case 0
		newplot
		if numel(t)==1
			imagesc([0 1/f(2)],f,20*log10(abs(y)+eps))
		else
			t = ((colindex-1)+((nwind)/2)')/Fs; 
			imagesc(t,f,20*log10(abs(y)+eps))
		end
		axis xy
		colormap(jet)
		xlabel('Time')
		ylabel('Frequency')
	case 1
		yo = y;
	case 2
		yo = y;
		fo = f;
	case 3
		yo = y;
		fo = f;
		to = t;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [x,nfft,Fs,window,noverlap] = specgramchk(P)
%SPECGRAMCHK Helper function for SPECGRAM.

x = P{1}(:); 
if (numel(P) > 1) && ~isempty(P{2})
    nfft = P{2};
else
    nfft = min(numel(x),256);
end
if numel(P) > 2 && ~isempty(P{3})
    Fs = P{3};
else
    Fs = 2;
end
if numel(P) > 3 && ~isempty(P{4})
    window = P{4}(:); 
else
    if numel(nfft) == 1
        window = hanning(nfft);
    else
      error('Needs window.');
    end
end
if numel(window) == 1
	window = hanning(window);
end
if (numel(P) > 4) && ~isempty(P{5})
    noverlap = P{5};
else
    noverlap = ceil(numel(window)/2);
end
if (numel(nfft) == 1) && (nfft<numel(window))
    error('Window is too big.');
end
if (noverlap >= length(window))
    error('Overlap is too big.');
end
if (numel(nfft) == 1) && (nfft ~= abs(round(nfft)))
    error('FFT must be a positive integer.');
end
if (noverlap ~= abs(round(noverlap)))
    error('Overlap must be a positive integer.');
end
if min(size(x)) ~= 1
    error('X must be vector.');
end

