%""""
    % plot the results from running encrustpfc_main.m  
%""""

clear, clc
%% load parameters and optimization output
load('control_params.mat')
load('initial_conditions.mat')
load('grid_params.mat')
load('tube_params.mat')
load('crys_params.mat')
load('encrust_params.mat')
load('HRFV_params.mat')
load('Case_Study_1.mat') 
% load('Case_Study_2.mat')
% load('AFC_Cycle_1.mat') 
% load('AFC_Cycle_2.mat') 
% load('AFC_Cycle_3.mat') 
% load('AFC_Cycle_4.mat') 
% load('AFC_Cycle_5.mat') 
% load('AFC_Cycle_6.mat') 

Af=pi*Rf.^2;
CA=fn(:,2*(Nr*Nx)+(NL*Nx)+2*Nx+1:2*(Nr*Nx)+(NL*Nx)+3*Nx);
Nt=size(t,1);

%% CSD profile across PFC at final time
figure;
subplot(2,2,1);mesh(x,L*1E6,f);zlabel('CSD [#/m^3 sol. \mum crys]',...
    'fontsize',16);
xlabel('length [m]','fontsize',16);
ylabel('crystal size [\mum]','fontsize',16);
set(gca,'Ytick',L(1)*1E6:(L(end)-L(1))*1E6/5:L(end)*1E6);
% set(gca,'Xlim',[0 2.5]);

%% temperature profile across different domains at final time
subplot(2,2,2);hold on;plot(x,T(end,:),':ob');plot(x,Te(1,:),':or');...
    plot(x,Tw(1,:),':ok');plot(x,Tw(end,:),':oc');...
    legend('tube','encrust-tube','wall-encrust',...
    'outerwall');ylabel('temperature [^{o}C]','fontsize',16);
    xlabel('length [m]','fontsize',16);
%     set(gca,'Xlim',[0 2.5]);

%% encrust thickness profile across different domains at final time
subplot(2,2,4);mesh(x,t(1:end)/60,delta(1:end,:)*1.*1e3);
zlabel('encrust [mm]','fontsize',16);
ylabel('time [min]','fontsize',16);
xlabel('length [m]','fontsize',16);
% set(gca,'Xlim',[0 2.5]);

%% crystal mass growth across time and length
ux=Vsol./Af; % fluid velocity
cflux=ux.*CA;
flomass=zeros(Nt,Nx); % mass flow rates
Gyflump=zeros(Nt,Nx); % lumped growth rates (across the different crystal
    % length)
crysmass=zeros(Nt,Nx);

Tetemp=zeros(Nt,Nx);
Tewall=zeros(Nt,Nx);
for ti=1:Nt
    Te=fn(ti,Nr*Nx+1:2*(Nr*Nx));Te=reshape(Te,Nr,Nx);
    Tetemp(ti,:)=Te(end,:); % encrust-tube side temp
    Tewall(ti,:)=Te(1,:); % wall-side
end

Tf=T+0.55*(Tetemp-T);
Csat_f=polyval(a_sol,Tf);
tempD=-Kd./(L.^q); % dissolution
tempG1=1-exp(-gamma*(L+beta)); % growth kinetic expression 1
    % (size factor)
tempG2=Kg0*exp(-delEg/Rg./(273.15+T)); % expression 2
S=(C./Csat_f); % [-], supersaturation
supersat=S-1;% [-], relative supersaturation

for ti=1:Nt
    flowmass=-1/delx*diff(cflux); % due to in/out flow
    GD=zeros(NL,Nx); % crystal growth/dissolution rate (size-dependent)
    for k=1:Nx
        if C(ti,k)>=Csat_f(ti,k) % in case of growth
            sigmaG=supersat(ti,k)^g; % reaction order
            GD(:,k)= tempG1*tempG2(ti,k)*sigmaG;
        else % dissolution
            sigmaG=(-supersat(ti,k))^d;
            GD(:,k)=tempD'*sigmaG;
        end
    end
    fA=fn(ti,2*(Nr*Nx)+Nx+1:2*(Nr*Nx)+Nx+(NL*Nx));fA=reshape(fA,NL,Nx);
    Gyf=GD.*fA; % [m/s]
    crysmass(ti,:)=(3*phiV*rho_c*delL)*(L.^2*Gyf)*(258.21/474.39)/rho_l;
end

subplot(2,2,3);mesh(x,t/60,crysmass*1E9);
zlabel('crystal mass growth (nm/s)','fontsize',16);
ylabel('time [min]','fontsize',16);
xlabel('length [m]','fontsize',16);
% set(gca,'Xlim',[0 2.5]);

%% supersaturation and concentration in the tube across time and length
Tetemp=zeros(Nt,Nx);
Tewall=zeros(Nt,Nx);
for ti=1:Nt
    Te=fn(ti,Nr*Nx+1:2*(Nr*Nx));Te=reshape(Te,Nr,Nx);
    Tetemp(ti,:)=Te(end,:); % encrust-tube side temp
    Tewall(ti,:)=Te(1,:); % wall-side
end

Tf=T+0.55*(Tetemp-T);
Csat_f=polyval(a_sol,Tf);
km=Diff./(2*Rf)*0.034*(Reynolds)^0.875*(eta/rho_l/Diff)^0.33;
    % mass transfer coeff
kr=Kr0*exp(-37143./(8.314*(273.14+Tf))); % reaction rate, [brahim et al.]
P_by_K6=83.2*w.^0.54; % [N]

% for 2nd order reaction
temp1=km./(rho_e*K_e).*(0.5.*(km./kr)+rho_l.*(C-Csat_f)-...
    (1/4*(km.^2./kr.^2)+km./kr.*rho_l.*(C-Csat_f) ).^0.5)...
    -1./P_by_K6*(1+Kt.*(Tewall-Tetemp)).*dp*(rho_l^2*eta*Grav).^...
    (1/3).*w.^2.*delta./K_e; % thermal resistance, multiplication by liquid
        % density rho_l  in the above expression is to convert the
        % concentration from kg/kg to kg/m^3

temp2=alpha_e*(C-Csat_f); % decrustation rate

temp=zeros(Nt,Nx);
for ti=1:Nt
    for k=1:Nx
        if C(ti,k)>=Csat_f(ti,k) % encrustation
            temp(ti,k)=K_e*temp1(ti,k); % encrust thickness
        else % decrustation
            if delta(ti,k)<=1e-6
                temp(ti,k)=0;% prevent negative delta
            else
                temp(ti,k)=temp2(ti,k);
            end
        end
    end
end

crustmass=rho_e/rho_l*2*pi*(Ri-delta).*temp; % en/decrustation

% CV calculation
CV=nan(1,Nt);
L43(1)=nan;
for i=2:Nt
    fAtemp=fn(i,2*(Nr*Nx)+Nx+1:2*(Nr*Nx)+Nx+(NL*Nx));fAtemp=...
        reshape(fAtemp,NL,Nx);
    ftemp=fAtemp./(ones(NL,1)*Af(i,:));
    CV(i)=sqrt((trapz(L,L'.^5.*ftemp(:,end))*trapz(L,L'.^3.*ftemp(:,end))/...
 	trapz(L,L'.^4.*ftemp(:,end))^2)-1);
end

figure;
subplot(2,2,1);mesh(x,t/60,supersat);
zlabel('supersaturation [-]','fontsize',16);
ylabel('time [min]','fontsize',16);
xlabel('reactor length [m]','fontsize',16);

subplot(2,2,2);mesh(x,t'/60,C);zlabel('concentration [g crystal/g sol]',...
    'fontsize',16);
ylabel('time [min]','fontsize',16);
xlabel('reactor length [m]','fontsize',16);

%% track blockage and residence time
subplot(2,2,3);
[hAx,hLine1,hLine2] = plotyy(t/60,rest/60,t/60,blockage);
set(hLine1,'LineStyle',':','Marker','o');
set(hLine2,'LineStyle',':','Marker','o');
ylabel(hAx(1),'residence time (min)','fontsize',16);
ylabel(hAx(2),'blockage (%)','fontsize',16); 
xlabel('time (min)','fontsize',16);

%% track L_{43} and CV across time
subplot(2,2,4);
[hAx,hLine1,hLine2] = plotyy(t/60,L43,t/60,CV);
set(hLine1,'LineStyle',':','Marker','o');
set(hLine2,'LineStyle',':','Marker','o');
ylabel(hAx(1),'L43 (\mum)','fontsize',16);
ylabel(hAx(2),'CV (%)','fontsize',16)
xlabel('time (min)','fontsize',16);

hFig=figure(1);
set(hFig, 'Position', [20.0 180.0 704 543]);
set(hFig, 'PaperPosition', [0.25 2.5 8 6]);
hFig=figure(2);
set(hFig, 'Position', [730.0 180.0 704 543]);
set(hFig, 'PaperPosition', [0.25 2.5 8 6]);

%% track mass flow/yield across time
Ri_temp=Ri*ones(1,Nx);
CrustMass=sum(rho_e*(pi*(Ri_temp.^2-Rf(end,:).^2).*delx),2); 
    % [kg], Encrust mass
MassInFlow=C(1,1)*ones(Nt,1)*flow*1E-3*rho_l;
MassOutFlow=C(:,end)*flow*1E-3*rho_l;
figure;subplot(2,1,1)
plot(t/60,MassInFlow,':ob');hold on;
plot(t/60,MassOutFlow,':or');
xlabel('time (min)','fontsize',16);
ylabel('mass flow (g solute/min)','fontsize',16);

%% track concentration as correlated with temprature
subplot(2,1,2)
plot(T(end,:),Csat_f(end,:),'-ob')
hold on;plot(T(end,:),C(end,:),'-or')
hold on;plot(T(end,:),Csat_f(end,:),'-ok')
xlabel('temperature (^{o}C)','fontsize',16);
ylabel('concentration (g solute/g solvent)','fontsize',16);

%% display average L_{43}, CV and encrust mass
avg_L43=mean(L43(2:end));
avg_CV=mean(CV(2:end));
disp(['avg_L43: ' num2str(avg_L43)]);
disp(['avg_CV: ' num2str(avg_CV)]);
disp(['crustmass: ' num2str(CrustMass)]);
hFig=figure(3);
set(hFig, 'Position', [370.0 370.0 600 600]);
set(hFig, 'PaperPosition', [0.25 2.5 5 3]);
