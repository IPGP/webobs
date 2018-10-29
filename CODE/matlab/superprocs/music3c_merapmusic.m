function [mtheta,mthetaerr,mvel,mvelerr,mphi,mphierr,mvelp,mvelperr]=music3c_merapmusic(xcor,fo,pos,stering,ns)
%
%
%
order=size(xcor,1);
[Q ,D]=eig(xcor);
[D,m]=sort(diag(D),1,'descend');%disp(D');
Q=Q (:,m);
for m=1:length(D)
    rsb=D(m)/max(D);
    if rsb<0.1;break;end
end
if ns==0;ns=m-1;end
Qb=Q(:,ns+1:order);
projector=Qb*Qb';

theta = stering{1};
phi   = stering{2};
vel   = stering{3};
spec=zeros(length(theta),length(vel));
for m=1:length(vel)
    for n=1:length(theta)
        uslowness=-[cos(theta(n)); sin(theta(n)); 0];
        delay=pos*uslowness/vel(m);
        w=-2*pi*fo*delay;
        beta=(exp(1i*w))/sqrt(order); %*3);
        estimator=1/(beta'*projector*beta);%(beta'*beta)
        spec(n,m)=abs(estimator);
     end
     nnD=spec(:,m);nnD=abs(nnD);nnD=music3c_fastsmooth(nnD,5,3,1);spec(:,m)=nnD;
end
spec=spec/max(max(spec));
indx=find(max(spec)>0.95);
n=1;mm=1;mtheta=[];mvel=[];mthetaerr=[];mvelerr=[];
for m=2:length(indx)
    if indx(m)-indx(m-1)~=1 || m==length(indx)
        if m==length(indx)
            m1=m+1;
        else
            m1=m;
        end
        spec1=spec(:,indx(n:m1-1));spec1=spec1/max(max(spec1));
        [xest,ind1]=max(max(spec1));
        mvel(mm)=vel(indx(ind1));
        mvelerr(mm)=(m1-1)*(vel(2)-vel(1))/2;
        [xest,ind2]=max(max(spec1.'));
        indy=spec(:,indx(ind1));indy=indy/max(indy);
        mtheta(mm)=theta(ind2);
        mthetaerr(mm)=length(find(indy>=.95))*(theta(2)-theta(1))/2;
        mm=mm+1;
        n=m;
    end
end
spec=zeros(length(phi),length(vel));mvelp=[];mphi=[];mphierr=[];mvelperr=[];
for mm=1:length(mtheta)
    for m=1:length(vel)
        for n=1:length(phi)
            uslowness=-[cos(mtheta(mm))*sin(phi(n)); sin(mtheta(mm))*sin(phi(n)); cos(phi(n))];
            delay=pos*uslowness/vel(m);
            w=-2*pi*fo*delay;
            beta=(exp(1i*w))/sqrt(order); %*3);
            estimator=1/(beta'*projector*beta);%(beta'*beta)
            spec(n,m)=abs(estimator);
        end
        nnD=spec(:,m);nnD=abs(nnD);nnD=music3c_fastsmooth(nnD,5,3,1);spec(:,m)=nnD;
    end
    spec=spec/max(max(spec));
    [mest,indx]=max(max(spec));
    mvelp(mm)=vel(indx);
    indy=spec(:,indx);
    mphierr(mm)=length(find(indy>=.95))*(phi(2)-phi(1))/2;
    [mest,indx]=max(max(spec.'));
    indy=spec(indx,:);
    mvelperr(mm)=length(find(indy>=.95))*(vel(2)-vel(1))/2;
    mphi(mm)=phi(indx);
end
