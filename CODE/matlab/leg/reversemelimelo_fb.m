function R = reversemelimelo(D)
%REVERSEMELIMELO Calculate real resistance values R.time and D.data from 
%   "melimelo" structure D.time and D.data.
%   Use functions MELIMELO, MINMELIMELO and LSQNONLIN from the Matlab OPTIM
%   toolbox.
%
%   F. Beauducel, IPGP
%   Created: 2009-05-25
%   Modified: 2009-05-30

global dm

r0 = [2.3092,2.4254,2.0936,1.6980,1.4353,1.6547,2.4622,0.1865,0.1850,1.6179,2.1299,1.8943,2.1067,1.7795,2.3278,2.4229];

options = optimset('MaxFunEvals',1000,'Display','off');

dm = zeros(2,8);
t = zeros(floor(size(D.time,1)/2),1);
r = zeros(size(t,1),16);

for i = 1:length(t)
    ii = [i*2-1,i*2];
    relais = D.data(ii,9:10);
    donnees = D.data(ii,1:8);
    t(i) = mean(D.time(ii));
    %datestr(t(i))
    dm(2,:) = donnees(find(relais(:,1)),:);
    dm(1,:) = donnees(find(relais(:,2)),:);
    %if i==1
        r(i,:) = lsqnonlin('minmelimelo',2*ones(1,16),[],[],options);
        %r(i,:) = lsqnonlin('minmelimelo',r0,[],[],options);
    %else
    %    r(i,:) = lsqnonlin('minmelimelo',r(i-1,:),[],[],options);
    %end
end
R.time = t;
R.data = r;
