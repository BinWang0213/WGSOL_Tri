function [Nodeh,Elemh, u,AD,b,ers,info] = Stokes_SWG_hexagon(node,elem,domain,pde,bdFlag,option)
% This is to solve the Stokes equation on triangular partition.
%
%   u = Stokes_SWG_hexagon(node,elem,domain,pde,bdFlag,option) produces the linear
%   SWG approximation of the Stokes equation
% 
%     -Delta u + \nabla p = (f1, f2), 
%                 div (u) = f3
%                       u = g on \partial \Omega
% 
%   The mesh is given by node and elem and the boundary edge is given by
%   bdFlag. See meshdoc, bddoc for details. The data is given by the
%   structure pde which contains function handles f, g_D or d.
%   
%   The function Stokes_SWG_hexagon assembes the matrix equation AD*u = b 
%   and solves it by the direct solver (small size <= 2e3). The Dirichlet 
%   boundary condition is built into the matrix AD and is build into b.
%
%  Copyright (C)  Yujie LIU. Junping WANG. See COPYRIGHT.txt for details.
%
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
NT = size(elem,1);
N  = size(node,1);
h  = sqrt(2)/sqrt(NT);
tic;

elem_area=zeros(NT,1);
elem_center=zeros(NT,2);
elem_edge_normal=zeros(NT,6,2);
elem_edge_length=zeros(NT,6,1);

[elem2edge,edge,elem2edgeSign] = dofedge(elem);
NE= size(edge,1);

Ndof = NT +  2*NE ;

Ndofh = NT +  2*NE + 2*NE;
Nodeh = zeros(N+NE,2);
mps = 0.5*(node(edge(:,1),:) + node(edge(:,2),:));

[fixedNode,bdEdge,isBdNode] = findboundary(elem,bdFlag);
idxD = (bdFlag(:) == 1);
isDirichlet = false(NE,1);
isDirichlet(elem2edge(idxD)) = true;
fixeEdgeIndex =find(isDirichlet);

elem2edgeSignisp =false(NT,3);
elem2edgeSignisp =(elem2edgeSign(:,:)==1);

meshtype=option.hexamesh;
switch meshtype
    case 'regular'
    Nodeh =[node;mps];   
    
    case'irregular_one'
    mpsc(:,1)=mps(:,1)+ h/3.;
    mpsc(:,2)=mps(:,2)+ h/6.;  
    Nodeh =[node;mpsc];
    Nodeh(fixedNode,:)= node(fixedNode,:);
    Nodeh(N+fixeEdgeIndex,:)= mps(fixeEdgeIndex,:);
    
    case'irregular_two'   
    mpsc(:,1)=mps(:,1)+ h/3.;
    mpsc(:,2)=mps(:,2)+ h/6.;  
    Nodeh =[node;mpsc];
    %if (option.lid==1)
    %error('This mesh is not suitable for Lid driven cavity, please try other options of option.hexamesh ...');
    %end
    case'irregular_three'       
    Nodeh =[node;mps];
    Nodeh(:,1)= Nodeh(:,1)+ (rand(N+NE,1)*2-1)*h/4;
    Nodeh(:,2)= Nodeh(:,2)+ (rand(N+NE,1)*2-1)*h/4;

    Nodeh(fixedNode,:)= node(fixedNode,:);
    Nodeh(N+fixeEdgeIndex,:)= mps(fixeEdgeIndex,:);   
end

Elemh =[elem(:,1) N+elem2edge(:,3) elem(:,2) N+elem2edge(:,1) elem(:,3) N+elem2edge(:,2)];


Edge1 =[edge(:,1) N+(1:NE)'];
Edge2 =[N+(1:NE)' edge(:,2)];

Edge1 =[edge(:,1) N+(1:NE)'];
Edge2 =[N+(1:NE)' edge(:,2)];
Edgeh =[Edge1;Edge2];

Elem2edgeh11=zeros(NT,1);
Elem2edgeh12=zeros(NT,1);
Elem2edgeh21=zeros(NT,1);
Elem2edgeh22=zeros(NT,1);
Elem2edgeh31=zeros(NT,1);
Elem2edgeh32=zeros(NT,1);

Elem2edgeh11(elem2edgeSignisp(:,1)) = elem2edge(elem2edgeSignisp(:,1),1);
Elem2edgeh11(~elem2edgeSignisp(:,1))= elem2edge(~elem2edgeSignisp(:,1),1) + NE;
Elem2edgeh12(~elem2edgeSignisp(:,1))= elem2edge(~elem2edgeSignisp(:,1),1);
Elem2edgeh12(elem2edgeSignisp(:,1)) = elem2edge(elem2edgeSignisp(:,1),1) + NE;

Elem2edgeh21(elem2edgeSignisp(:,2)) = elem2edge(elem2edgeSignisp(:,2),2);
Elem2edgeh21(~elem2edgeSignisp(:,2))= elem2edge(~elem2edgeSignisp(:,2),2) + NE;
Elem2edgeh22(~elem2edgeSignisp(:,2))= elem2edge(~elem2edgeSignisp(:,2),2);
Elem2edgeh22(elem2edgeSignisp(:,2)) = elem2edge(elem2edgeSignisp(:,2),2) + NE;


Elem2edgeh31(elem2edgeSignisp(:,3)) = elem2edge(elem2edgeSignisp(:,3),3);
Elem2edgeh31(~elem2edgeSignisp(:,3))= elem2edge(~elem2edgeSignisp(:,3),3) + NE;
Elem2edgeh32(~elem2edgeSignisp(:,3))= elem2edge(~elem2edgeSignisp(:,3),3);
Elem2edgeh32(elem2edgeSignisp(:,3)) = elem2edge(elem2edgeSignisp(:,3),3) + NE;

Elem2edgeh=[Elem2edgeh11 Elem2edgeh12 Elem2edgeh21 Elem2edgeh22 Elem2edgeh31 Elem2edgeh32 ];


NTh =size(Elemh,1);
Nh  =size(Nodeh,1);
NEh =size(Edgeh,1);

A    = sparse(Ndofh,Ndofh);
b    = zeros(Ndofh,1);
elem2elem =(1:NTh)';

elem2dofu   = Elem2edgeh;
elem2dofv   = NEh + Elem2edgeh;
elem2dofp   = 2*NEh + elem2elem;



for i=1:NTh
    NV=size(Elemh(i,:),2);
    nodal=[];
    for j=3:NV
        nodal = [nodal; Nodeh(Elemh(i,j),:)];
    end 
    nodal = [nodal; Nodeh(Elemh(i,1),:)];
    nodal = [nodal; Nodeh(Elemh(i,2),:)];
    %nodal
     Ndof_local    = 2*NV+1;
     
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%55
% Get the element information
%
% Element = struct ('Edge', edge_info, 'Vertex', nodal, 'NumberEdge', ...
%                   num_edge, 'NumberVertex', num_vertex);%
     num_edge=NV;
     num_vertex=NV;
% 
% get edge information
%
    for i_edge=1:num_edge-1
         MyEdge_info(i_edge,1)=i_edge;
         MyEdge_info(i_edge,2)=i_edge+1;
    end
         MyEdge_info(num_edge,1)=num_vertex;
         MyEdge_info(num_edge,2)=1;
%
% Get normal direction for each edge --- point outward of the domain
% Note that this information is supposed to be an input to the function
%
   for i_edge=1:num_edge
% Get the index for left and righ end points
        left_pt=MyEdge_info(i_edge,1);
        right_pt=MyEdge_info(i_edge,2);
% Get the tangent vector from left to right with lengh |e_i|
        edge_tangent_vec(i_edge,1)=nodal(right_pt, 1)-nodal(left_pt,1);
        edge_tangent_vec(i_edge,2)=nodal(right_pt,2)-nodal(left_pt,2);  
 % Get edge length
    mag_edge(i_edge) = sqrt(edge_tangent_vec(i_edge,1)^2 + edge_tangent_vec(i_edge,2)^2);
% 
%  Get outward normal vector (should be taken an an input to the function.
%  Need to make sure the vector points away from the polygon.
%
% safety check to make sure the edge is non-degenerate
%
   if mag_edge(i_edge) < 1.0e-14
    fprintf('WARMING --- WARNING ... WARNING \n');
    fprintf('One of the edges of the polygon is degenerate. Please check your \n');
    fprintf('polygonal partition ... \n');
   end
%
% The following assumes that the nodal points are in counterclockwise direction
% For clockwise nodal points, please change the direction of the
% following vector
%
    MyUnitNormal(i_edge,1)= edge_tangent_vec(i_edge,2)/mag_edge(i_edge);
    MyUnitNormal(i_edge,2)=-edge_tangent_vec(i_edge,1)/mag_edge(i_edge);
   end
%   
%
MyElement = struct('EdgeInfo', MyEdge_info, 'EdgeOrientation', MyUnitNormal,...
                   'VertexCoordinates', nodal, 'NumberOfEdge', num_edge);
%
%
% END OF Element Structure
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
     elem_edge_normal(i,1:6,:)=MyUnitNormal(1:6,:);
     elem_edge_length(i,1:6,1)=mag_edge(1:6);

     Ele_Stiffness = zeros(Ndof_local,Ndof_local);
     Ele_Load      = zeros(Ndof_local,1);
     
    [Ele_Stiffness, Ele_Load, Polygon_Area, Polygon_Center]=...
     Element_Stiffness_Matrix_Stokes(MyElement,pde,option);
     
     elem_center(i,1) = Polygon_Center(1);
     elem_center(i,2) = Polygon_Center(2);  
     elem_area(i) = Polygon_Area;
    
     ii =double( elem2dofu(i,:))';
     jj =double( elem2dofv(i,:))';
     kk =double( elem2dofp(i));
     A_localOne   = sparse(Ndofh,Ndofh);
     A_localTwo   = sparse(Ndofh,Ndofh);
     for iii=1:NV
         for jjj=1:NV
         A_localOne = A_localOne + sparse(ii(iii),ii(jjj),Ele_Stiffness(iii,jjj),Ndofh,Ndofh);
         A_localOne = A_localOne + sparse(jj(iii),jj(jjj),Ele_Stiffness(iii+NV,jjj+NV),Ndofh,Ndofh);
         end
         A_localTwo = A_localTwo + sparse(jj(iii),kk,Ele_Stiffness(NV+iii,2*NV+1),Ndofh,Ndofh);
         A_localTwo = A_localTwo + sparse(ii(iii),kk,Ele_Stiffness(iii,2*NV+1),Ndofh,Ndofh);
     end
     A = A + A_localOne + A_localTwo - A_localTwo';
     b(ii) = b(ii) + Ele_Load(1:NV);
     b(jj) = b(jj) + Ele_Load(1+NV:2*NV);
     b(kk) = b(kk) + Ele_Load(end);
end


[AD,b,u,freeDof,isPureNeumann] = getbdCCFVcoef_hexa(A,b);

%% Record assembling time
assembleTime = toc;
if ~isfield(option,'printlevel'), option.printlevel = 1; end
if option.printlevel >= 2
    fprintf('Time to assemble matrix equation %4.2g s\n',assembleTime);
end

%% Solve the system of linear equations
if isempty(freeDof), return; end
% Set up solver type
if isempty(option) || ~isfield(option,'solver')    % no option.solver
    if NE <= 1e3  % Direct solver for small size systems
        option.solver = 'direct';
    else         
    fprintf('WARMING --- WARNING : Solve the system of linear equations \n');
    fprintf('size of the system too large !\n');
    fprintf(' ... \n');
    end
end
solver = option.solver;
% solve
switch solver
    case 'direct'
        tic;
        %fprintf('Solver is Ok!\n')
        u(freeDof) = AD(freeDof,freeDof)\b(freeDof);
        residual = norm(b - AD*u);
        info = struct('solverTime',toc,'itStep',0,'err',residual,'flag',2,'stopErr',residual);                
end

%% Output information
eqn = struct('A',AD,'b',b,'edge',edge,'freeDof',freeDof);
info.assembleTime = assembleTime;

%% Compute DU
DU = zeros(NT,2);
DV = zeros(NT,2);
for i=1:6
DU(:,1)= DU(:,1) + u(Elem2edgeh(:,i)).*elem_edge_normal(:,i,1).*elem_edge_length(:,i);
DU(:,2)= DU(:,2) + u(Elem2edgeh(:,i)).*elem_edge_normal(:,i,2).*elem_edge_length(:,i);    

DV(:,1)= DV(:,1) + u(Elem2edgeh(:,i)+2*NE).*elem_edge_normal(:,i,1).*elem_edge_length(:,i);
DV(:,2)= DV(:,2) + u(Elem2edgeh(:,i)+2*NE).*elem_edge_normal(:,i,2).*elem_edge_length(:,i); 
end

DU(:,1)= DU(:,1)./elem_area;
DU(:,2)= DU(:,2)./elem_area;

DV(:,1)= DV(:,1)./elem_area;
DV(:,2)= DV(:,2)./elem_area;


%% Show solution
middle_points = 0.5*(node(edge(:,1),:) + node(edge(:,2),:));
middle_pointsh = 0.5*(Nodeh(Edgeh(:,1),:) + Nodeh(Edgeh(:,2),:));

uI =zeros(N,1);
uI = pde.exactu(node);
uIc = pde.exactu(middle_pointsh);
DUIc= pde.Du(elem_center);
uIn = pde.exactu(Nodeh);
pI  = pde.pp(elem_center);

pI_moyen=sum(pI.*elem_area)/sum(elem_area);
nump_moyen=sum(u(4*NE+1:end).*elem_area)/sum(elem_area);
u(4*NE+1:end)=u(4*NE+1:end) - nump_moyen + pI_moyen;

ppI =pde.pp(node);
ppppI = pde.pp(Nodeh);
magntitude=sqrt(u(1:2*NE).*u(1:2*NE)+u(2*NE+1:4*NE).*u(2*NE+1:4*NE));

info.Mid_Edge = middle_pointsh;
info.Elem_center= elem_center;
info.NE=NE;
info.erroru=u(1:2*NE)-uIc(:,1);
info.errorv=u(2*NE+1:4*NE)-uIc(:,2);
info.errorp=u(4*NE+1:end)-pI;
close all;
if(option.exact==1)
figure(314)
[x y]=meshgrid(domain(1):h:domain(2),domain(3):h:domain(4));
u1_new =griddata(middle_pointsh(:,1),middle_pointsh(:,2),u(1:2*NE),x,y,'v4');
u2_new =griddata(middle_pointsh(:,1),middle_pointsh(:,2),u(2*NE+1:4*NE),x,y,'v4');
p_new  =griddata(elem_center(:,1),elem_center(:,2),u(4*NE+1:end),x,y,'v4');
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
subplot(1,2,1)
h3 = patch('Faces', elem, 'Vertices', node);hold on;
set(h3,'FaceVertexCData',sqrt(uI(:,1).*uI(:,1)+uI(:,2).*uI(:,2)),...
    'FaceColor','interp','edgecolor','none');
view(2); axis equal; axis tight; axis off;
colorbar
quiver(x,y,u1_new, u2_new,'color',[0 0 0]);
title('Numerical velocity (u,v)_h');
hold off;
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
subplot(1,2,2)
[c,h3]=contourf(x,y,p_new,10);
%set(h3,'ShowText','on');
title('Numerical pressure p_h');
colorbar
view(2); axis equal; axis tight; axis off;
hold off;

figure(318);
subplot(1,3,1)
scatter3(middle_pointsh(:,1),middle_pointsh(:,2),magntitude,30,magntitude,'filled'), hold on;
title('Numerical speed |(u,v)_h|');
subplot(1,3,2)
showsolution(node,elem,sqrt(uI(:,1).*uI(:,1)+uI(:,2).*uI(:,2)) ,[-62,58]);
title('Exact speed |(u,v)|');
subplot(1,3,3)
error_plot = magntitude-sqrt(uIc(:,1).*uIc(:,1)+uIc(:,2).*uIc(:,2));
scatter3(middle_pointsh(:,1),middle_pointsh(:,2),error_plot,30,error_plot,'filled'); 
title('Speed error |(u,v)_h|-|(u,v)|');

figure(315);
subplot(3,3,1)
scatter3(middle_pointsh(:,1),middle_pointsh(:,2),u(1:2*NE),30,u(1:2*NE),'filled'), hold on;
title('Numerical velocity_1 u_h');
subplot(3,3,2)
showsolution(node,elem,uI(:,1) ,[-62,58]);
title('Exact velocity_1 u');
subplot(3,3,3)
scatter3(middle_pointsh(:,1),middle_pointsh(:,2),u(1:2*NE)-uIc(:,1),30,u(1:2*NE)-uIc(:,1),'filled'); 
title('Velocity_1 error u_h-u');
subplot(3,3,4)
scatter3(middle_pointsh(:,1),middle_pointsh(:,2),u(2*NE+1:4*NE),30,u(2*NE+1:4*NE),'filled'), hold on;
title('Numerical velocity_2 v_h');
subplot(3,3,5)
showsolution(node,elem,uI(:,2) ,[-62,58]);
title('Exact velocity_2 v');
subplot(3,3,6)
scatter3(middle_pointsh(:,1),middle_pointsh(:,2),u(2*NE+1:4*NE)-uIc(:,2),30,u(2*NE+1:4*NE)-uIc(:,2),'filled'); 
title('Velocity_2 error v_h-v');
subplot(3,3,7)
scatter3(elem_center(:,1),elem_center(:,2),u(4*NE+1:end),30,u(4*NE+1:end),'filled'), hold on;
title('Numerical pressure p_h');
subplot(3,3,8)
showsolution(node,elem,ppI ,[-62,58]);
title('Exact pressure p');
subplot(3,3,9)
scatter3(elem_center(:,1),elem_center(:,2),u(4*NE+1:end)-pI,30,u(4*NE+1:end)-pI,'filled'); 
title('Pressure error p_h-p');

u1I=griddata(middle_pointsh(:,1),middle_pointsh(:,2),u(1:2*NE),Nodeh(:,1),Nodeh(:,2),'v4');
u2I=griddata(middle_pointsh(:,1),middle_pointsh(:,2),u(2*NE+1:4*NE),Nodeh(:,1),Nodeh(:,2),'v4');
pppI=griddata(elem_center(:,1),elem_center(:,2),u(4*NE+1:end),Nodeh(:,1),Nodeh(:,2),'v4');

figure(316);
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'facecolor',[0.5 0.9 0.45],'edgecolor','k');
view(2); axis equal; axis tight; axis off;
hold off;

figure(317);
subplot(3,2,1)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'FaceVertexCData',u1I,'FaceColor','interp','edgecolor','k');
view(2); axis equal; axis tight; axis off;
colorbar
hold off;
title('Numerical velocity_1 u_h');
subplot(3,2,2)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'FaceVertexCData',uIn(:,1),'FaceColor','interp','edgecolor','k');
view(2); axis equal; axis tight; axis off;
colorbar
hold off;
title('Exact velocity_1 u');
subplot(3,2,3)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'FaceVertexCData',u2I,'FaceColor','interp','edgecolor','k');
view(2); axis equal; axis tight; axis off;
colorbar
hold off;
title('Numerical velocity_2 v_h');
subplot(3,2,4)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'FaceVertexCData',uIn(:,2),'FaceColor','interp','edgecolor','k');
view(2); axis equal; axis tight; axis off;
colorbar
hold off;
title('Exact velocity_2 v');
subplot(3,2,5)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'FaceVertexCData',pppI,'FaceColor','interp','edgecolor','k');
view(2); axis equal; axis tight; axis off;
colorbar
hold off;
title('Numerical pressure p_h');
subplot(3,2,6)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'FaceVertexCData',ppppI,'FaceColor','interp','edgecolor','k');
view(2); axis equal; axis tight; axis off;
colorbar
hold off;
title('Exact pressure p');
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
elseif(option.exact==0)
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

figure(315);
subplot(1,3,1)
scatter3(middle_pointsh(:,1),middle_pointsh(:,2),u(1:2*NE),30,u(1:2*NE),'filled'), hold on;
title('Numerical velocity_1 u_h');
subplot(1,3,2)
scatter3(middle_pointsh(:,1),middle_pointsh(:,2),u(2*NE+1:4*NE),30,u(2*NE+1:4*NE),'filled'), hold on;
title('Numerical velocity_2 v_h');
subplot(1,3,3)
scatter3(elem_center(:,1),elem_center(:,2),u(4*NE+1:end),30,u(4*NE+1:end),'filled'), hold on;
title('Numerical pressure p_h');
hold off;

u1I=griddata(middle_pointsh(:,1),middle_pointsh(:,2),u(1:2*NE),Nodeh(:,1),Nodeh(:,2),'v4');
u2I=griddata(middle_pointsh(:,1),middle_pointsh(:,2),u(2*NE+1:4*NE),Nodeh(:,1),Nodeh(:,2),'v4');
pppI=griddata(elem_center(:,1),elem_center(:,2),u(4*NE+1:end),Nodeh(:,1),Nodeh(:,2),'v4');

figure(314)
[x y]=meshgrid(domain(1):h:domain(2),domain(3):h:domain(4));
u1_new =griddata(middle_pointsh(:,1),middle_pointsh(:,2),u(1:2*NE),x,y,'v4');
u2_new =griddata(middle_pointsh(:,1),middle_pointsh(:,2),u(2*NE+1:4*NE),x,y,'v4');
p_new  =griddata(elem_center(:,1),elem_center(:,2),u(4*NE+1:end),x,y,'v4');
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
subplot(1,2,1)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);hold on;
set(h3,'FaceVertexCData',sqrt(u1I.*u1I+u2I.*u2I),...
    'FaceColor','interp','edgecolor','none');
view(2); axis equal; axis tight; axis off;
colorbar
quiver(x,y,u1_new, u2_new,2,'color',[0 0 0]);
title('Numerical velocity (u,v)_h');
hold off;
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
subplot(1,2,2)
[c,h3]=contourf(x,y,p_new,20);
set(h3,'ShowText','on');
title('Numerical pressure p_h');
colorbar
view(2); axis equal; axis tight; axis off;
hold off;

figure(316);
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'facecolor',[0.5 0.9 0.45],'edgecolor','k');
view(2); axis equal; axis tight; axis off;
hold off;

figure(317);
subplot(1,3,1)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'FaceVertexCData',u1I,'FaceColor','interp','edgecolor','k');
view(2); axis equal; axis tight; axis off;
colorbar
hold off;
title('Numerical velocity_1 u_h');
subplot(1,3,2)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'FaceVertexCData',u2I,'FaceColor','interp','edgecolor','k');
view(2); axis equal; axis tight; axis off;
colorbar
hold off;
title('Numerical velocity_2 v_h');
subplot(1,3,3)
h3 = patch('Faces', Elemh, 'Vertices', Nodeh);
set(h3,'FaceVertexCData',pppI,'FaceColor','interp','edgecolor','k');
view(2); axis equal; axis tight; axis off;
colorbar
hold off;
title('Numerical pressure p_h');
end

errorr=h*h*((u(1:2*NE)-uIc(:,1)).*(u(1:2*NE)-uIc(:,1))...
      + (u(2*NE+1:4*NE)-uIc(:,2)).*(u(2*NE+1:4*NE)-uIc(:,2)));
err=sqrt(sum(errorr));

errordu=h*h*((DU(:,1)-DUIc(:,1,1)).*(DU(:,1)-DUIc(:,1,1)) ...
        + (DU(:,2)-DUIc(:,1,2)).*(DU(:,2)-DUIc(:,1,2))... 
        + (DV(:,1)-DUIc(:,2,1)).*(DV(:,1)-DUIc(:,2,1)) ...
        + (DV(:,2)-DUIc(:,2,2)).*(DV(:,2)-DUIc(:,2,2)));
errdu=sqrt(sum(errordu));

errorp=h*h*(pI-u(4*NE+1:end)).*(pI-u(4*NE+1:end));
errp=sqrt(sum(errorp));

ers.L2=err;
ers.H1=errdu;
ers.p =errp;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% subfunctions getbdWG
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [AD,b,u,freeDof,isPureNeumann]= getbdCCFVcoef_hexa(A,b)
    %% GETBDCR Boundary conditions for Poisson equation: WG element.
    
    u =zeros(Ndofh,1);
    %% Initial check
    if ~isfield(pde,'g_D'), pde.g_D = []; end
    if ~isfield(pde,'g_N'), pde.g_N = []; end
    if ~isfield(pde,'g_R'), pde.g_R = []; end

    %% Part 1: Modify the matrix for Dirichlet condition
    % Find Dirichlet boundary nodes: fixedNode
        fixedNode = []; freeNode = [];
    if ~isempty(bdFlag) % find boundary edges and boundary nodes
        %fprintf('Boundary node is Ok!\n')
        [fixedNode,bdEdge,isBdNode] = findboundary(elem,bdFlag);
        freeNode = find(~isBdNode);
        freeEdge = [];fixeEdge =[];
        idxD = (bdFlag(:) == 1);
        isDirichlet = false(NE,1);
        isDirichlet(elem2edge(idxD)) = true;
        fixEdge = edge(isDirichlet,:);  
        freeEdge =edge(~isDirichlet,:);
        fixeEdgeIndex =find(isDirichlet);
        freeEdgeIndex =find(~isDirichlet);
    end
    if isempty(bdFlag) && ~isempty(pde.g_D) && isempty(pde.g_N) && isempty(pde.g_R)
        % no bdFlag, only pde.g_D is given
        [fixedNode,bdEdge,isBdNode] = findboundary(elem);
        freeNode = find(~isBdNode);
    end
    isPureNeumann = false;    

% Modify the matrix
        if ~isempty(fixedNode)
        bdidx = zeros(Ndofh,1); 
        bdidx(fixeEdgeIndex) = 1;
        bdidx(fixeEdgeIndex+NE) = 1;
        bdidx(fixeEdgeIndex+2*NE)=1;
        bdidx(fixeEdgeIndex+3*NE) = 1;
        bdidx(4*NE+1)=1;     
        Tbd = spdiags(bdidx,0,Ndofh,Ndofh);
        T = spdiags(1-bdidx,0,Ndofh,Ndofh);
        AD = T*A*T + Tbd;
%       figure(5) 
%       spy(AD)
    else
        AD = A;
    end
    
    %% Part 2: Find boundary edges and modify the right hand side b
     % Dirichlet boundary condition
    if isnumeric(pde.g_D) && all(pde.g_D == 0)   % zero g_D
        pde.g_D = [];
    end
    if ~isPureNeumann && ~isempty(fixedNode) && ~isempty(pde.g_D)
        if isnumeric(pde.g_D)  % pde.g_D could be a numerical array  
            
            %fprintf('Boundary node fixe is Ok!\n')
        else % pde.g_D is a function handle
            % case exact
%             u_fix1 = pde.g_D(0.5*(Nodeh(Edge1(fixeEdgeIndex,1),:) ...
%                            + Nodeh(Edge1(fixeEdgeIndex,2),:)));
%             u_fix2 = pde.g_D(0.5*(Nodeh(Edge2(fixeEdgeIndex,1),:)...
%                            + Nodeh(Edge2(fixeEdgeIndex,2),:)));
            % case moyen
            u_fix1 = (pde.g_D(Nodeh(Edge1(fixeEdgeIndex,1),:))...
            + 4* pde.g_D(0.5*(Nodeh(Edge1(fixeEdgeIndex,1),:) ...
                            + Nodeh(Edge1(fixeEdgeIndex,2),:)))...
            +   pde.g_D(Nodeh(Edge1(fixeEdgeIndex,2),:)))/6.;
            %
            u_fix2 = (pde.g_D(Nodeh(Edge2(fixeEdgeIndex,1),:))...
            + 4* pde.g_D(0.5*(Nodeh(Edge2(fixeEdgeIndex,1),:) ...
                            + Nodeh(Edge2(fixeEdgeIndex,2),:)))...
            +   pde.g_D(Nodeh(Edge2(fixeEdgeIndex,2),:)))/6.;
            %
            u(fixeEdgeIndex) = u_fix1(:,1); 
            u(NE + fixeEdgeIndex) = u_fix2(:,1);
            u(2*NE + fixeEdgeIndex) = u_fix1(:,2); 
            u(3*NE + fixeEdgeIndex) = u_fix2(:,2);  
           %u(4*NE + 1) = pde.pp(elem_center(1,:));
            u(4*NE + 1) = 0.;
            %fprintf('Boundary node fixe is Ok!\n')
        end
        b = b - A*u;
    end
    if ~isPureNeumann % non-empty Dirichlet boundary condition
        b(fixeEdgeIndex) = u(fixeEdgeIndex);
        b(NE+fixeEdgeIndex) = u(NE+fixeEdgeIndex);
        b(2*NE+fixeEdgeIndex) = u(2*NE+fixeEdgeIndex);
        b(3*NE+fixeEdgeIndex) = u(3*NE+fixeEdgeIndex);
        b(4*NE+1) = u(4*NE+1);
    end
    
    freeDof = [freeEdgeIndex;NE+freeEdgeIndex;2*NE+freeEdgeIndex;3*NE+freeEdgeIndex;4*NE+(2:NT)'];
end

end