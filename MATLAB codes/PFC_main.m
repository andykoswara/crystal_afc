%""""
    % Main file for initializing and solving PFC-encrust-PBM ODE 
        % using encrustpfcV6.m. The initial control and system parameters 
        % and ODE output are saved in a series of .mat files all of  which
        % can be visualized using PFC_plot.m         
%""""

clc;clear
%% Initialize parameters
flow=40; % [ml/min], volumetric flow
Tfeed=38; % feed temperature

% Control temperatures   
% Tseg=[Tfeed,29.3119,23.6231,20.0005,20.0000]; % e.g. from GA optimization
    % (case study 1, maximizing growth)
% Tseg=[Tfeed,35.8,34.9,33.4,32.5]; % e.g. xfrom GA optimization
    % (case study 2, minimizing encrust)
    
% temperature cycling - AFC
% Tseg=[38,37.9,37.9,34,34]; % 1st
% Tseg=[38,34,34,40,40]; % 2nd
% Tseg=[38,34,34,36,36]; % 3rd
% Tseg=[38,41,41,34,34]; % 4th
% Tseg=[38,40,40,34,34]; % 4th (softer)
% Tseg=[38,38,38,34,34]; % 5th
% Tseg=[38,34,34,40,40]; % 6th (same as 2nd for now)
% Tseg=[38,34,34,40,40]; % 6th (softer dissolution)
% Tseg=[38,34,34,36,36]; % 7th (same as 3rd for now)
    
resol=5;
noseg=size(Tseg,2)-1;
T=stepT(Tseg,noseg+1,resol);
T(1:3)=T(4);
% SizSeg=1.2; % for segmentation=2
SizSeg=0.6; % -----------------4
% SizSeg=0.3; % -------------------8
xmax=SizSeg*noseg;
xmin=0;
Nx=size(Tseg,2)*resol-resol;
ID=1.50E-2; % [m], inner tube diameter
Ri=ID/2; % [7.5E-3 m], radius
Vsol=flow/60*1e-6; % [m^3/sec]
RT=12; % no of residence time
tf=pi*Ri^2*xmax/Vsol*RT; % residence time
ti=0;
Nt=50;
Tc=T';
Tmax=T+1;
savefilename='latest_pfc_run.mat';

save('control_params.mat', 'flow', 'Tfeed', 'Tseg', 'resol', 'noseg', ...
    'SizSeg', 'xmin', 'xmax', 'Nx', 'Tc', 'Tmax', 'ti', 'tf', 'Nt', ...
    'savefilename')

%% calculating initial conditions
NL=20;
Lmax=200e-6; % [m], maximum size of the crystals considered
Lmin=0; % minimum size 
delL = (Lmax-Lmin)/NL; % [m], grid size
L=(delL/2:delL:Lmax-delL/2); % [m], grid range
L3 = L'.^3*ones(1,Nx); % grid volume range
phiV=0.62; % [-], volume shape factor
rho_c=1750; % [kg/m^3], crystal density
rho_l=1080; % [kg/m^3], density
T0=Tmax';
Tw0=ones(NL,1)*Tmax'*0.99;
Te0=ones(NL,1)*Tmax'*0.98;
a_sol=[0.0000458354514087806  0.000243183573604693 ...
    0.04633927075106140]; % solubility
C0=ones(1,Nx)*polyval(a_sol,Tfeed);
seed_mass_input=1.88; % [g crystal/g solvent]
fin=zeros(NL,Nx); % initial CSD
mu=54*1e-6; % [m], average crystal size
Sigma=15e-6; % [m], stdev crystal size
for i=1:NL
    fin(i,1)=1/(Sigma*sqrt(2*pi))*exp(-1/2*((L(i)-mu)/Sigma).^2)*1e10;
        % [#/m^3 reactor.m^3 solvent] Seed (Gaussian) density
end
Vtot=delL*sum(fin.*L3); % [1/m^2], total # of crystals per unit area
seed_mass_percent=(Vtot(1)*phiV*rho_c/rho_l)/C0(1)*100; 
    % [%,g crystal/g solvent/m^2], initial seed mass in the PFC

% iterate to get the right seed_mass_percent
for i=1:NL
    fin(i,1)=1/(Sigma*sqrt(2*pi))*exp(-1/2*((L(i)-mu)/Sigma).^2)*1e10*...
        seed_mass_input/seed_mass_percent; % initial (load) CSD
end
f0=fin;

delta0=ones(1,Nx)*1e-6;% [m], initial encrustation thickness
    % (set for numerical purpose)

clear T 

save('initial_conditions.mat', 'Tw0', 'Te0', 'T0', 'C0', 'delta0',... 
    'f0', 'fin')

%% Plotting
figure;plot(T0,'-or');hold on;
plot(Te0(1,:),'-ok')
plot(Tw0(1,:),'-oc')
plot(Tc,':ob')
xlabel('reactor length coordinate','fontsize',16)
ylabel('temperature [^{o}C]', 'fontsize',16)
title('initial tube temperature', 'fontsize', 16)
legend('Tube','Tube-Encrust Interface','Encrust-Wall Interface',...
    'Outerwall', 'fontsize', 12)
figure;plot(delta0,'-o');title('initial encrust thickness',...
    'fontsize', 16)
xlabel('reactor length coordinate','fontsize',16)
ylabel('thickness [m]', 'fontsize',16)
figure;plot(C0,'-o');title('initial tube concentration', ...
    'fontsize', 16)
ylabel('concentration [kg/kg]', 'fontsize',16)
disp('Check initial conditions. Press any key to continue');
pause; % make sure initial conditions look okay

[fn,Tw,Te,T,f,delta,Rf,C,Sigma,rest,L43,blockage,t,x,r,L] = ...
encrustpfcV6(Nx,flow,xmax,ti,tf,Nt,Tc,Tw0,Te0,T0,Tfeed,C0,delta0,f0);

save(savefilename,'fn','Tw','Te','T','f','delta','Rf','C',...
        'Sigma','rest','t','x','r','L','L43','blockage');