% G_to_visim : Setup VISIM using classical d,G,m0,Cd
%
% use :
%    V=G_to_visim(x,y,z,d_obs,G,m0,Cd,parfile);
%
%    [x,y,z] : arrays indicating the geometry
%    [d_obs] : Number of data observations
%    [G]     [size(d_obs),nx*ny*nz] : Sensitivity kernel
%    [Cd]    [size(d_obs),size(d_obs)] : Data covariance table
%    [parfiele] [string] : VISIM parameter file.
%
%
function V=G_to_visim(x,y,z,d_obs,G,m0,Cd,parfile);

    if nargin<6
        m0=0;
    end
    if nargin<7
        Cd=eye(length(d_obs)).*1e-3;
    end

    if nargin<8
        parfile='lsq.par';
    end

    [p,txt,e]=fileparts(parfile);
    
    V=visim_init(x,y,z);
    
    nx=V.nx;ny=V.ny;
    nobs=length(d_obs);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % WRITE VISIM PARAMETER FILES
    %V=read_visim('knud.par');
    [xx,yy]=meshgrid(V.x,V.y);
    for i=1:nobs;
        Gg=reshape(G(i,:),ny,nx);
        
        ig=find(Gg>0);    
        Gg_sparse{i}.x=xx(ig);
        Gg_sparse{i}.y=yy(ig);
        Gg_sparse{i}.g=Gg(ig);        
        n(i)=length(ig);       
    end
    % SETUP VOLSUM AND VOLGEOM
    %nobs=1;
    volgeom=zeros(sum(n(1:nobs)),5);
    volsum=zeros(nobs,4);
    k=0;
    
    for i=1:nobs;
        progress_txt(i,nobs,'setting up kernel')
        for j=1:n(i);
            k=k+1;
            volgeom(k,1)=Gg_sparse{i}.x(j);
            volgeom(k,2)=Gg_sparse{i}.y(j);
            volgeom(k,3)=V.z(1);
            volgeom(k,4)=i;
            volgeom(k,5)=Gg_sparse{i}.g(j);
        end
        volsum(i,1)=i;
        volsum(i,2)=n(i);
        volsum(i,3)=d_obs(i);
        volsum(i,4)=Cd(i,i);
    end

    
    V.fvolgeom.fname=sprintf('%s_volgeom.eas',txt);
    V.fvolsum.fname=sprintf('%s_volsum.eas',txt);

    write_eas(V.fvolgeom.fname,volgeom);
    write_eas(V.fvolsum.fname,volsum);

    % Write Cd
    write_eas('visim_datacov.eas',Cd(:));

    
    V.Va.a_hmax=.01;
    V.Va.a_hmin=.01;
    
    V.gmean=m0;
    V.gvar=1;
    
    V.cond_sim=3;
    
    V.parfile=parfile;
    V=visim_init(V);
    write_visim(V);
    %
    V=read_visim(parfile);
    
    