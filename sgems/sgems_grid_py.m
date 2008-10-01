function [py_script,S,XML]=sgems_grid_py(S,py_script);

if nargin<1
    S.xml_file='sgsim.par'; % GET DEF PAR FILE
end

if isfield(S,'xml_file')==0
    S.xml_file=sgems_write_xml(S);
end

alg=S.XML.parameters.algorithm.name;

if nargin<2;
    try    
        py_script=[alg,'.py'];
    catch
        py_script='sgems.py';
    end
end



if ~isfield(S,'dim'), S.dim.null=0;end
if ~isfield(S.dim,'nx');S.dim.nx=30;end
if ~isfield(S.dim,'ny');S.dim.ny=30;end
if ~isfield(S.dim,'nz');S.dim.nz=1;end

if ~isfield(S.dim,'dx');S.dim.dx=1;end
if ~isfield(S.dim,'dy');S.dim.dy=1;end
if ~isfield(S.dim,'dz');S.dim.dz=1;end

if ~isfield(S.dim,'x0');S.dim.x0=0;end
if ~isfield(S.dim,'y0');S.dim.y0=0;end
if ~isfield(S.dim,'z0');S.dim.z0=0;end


if isfield(S,'XML')
    S.xml_file=sgems_write_xml(S.XML,S.xml_file);
end


alg=S.XML.parameters.algorithm.name;

if nargin<2;
    try    
        py_sccript=[alg,'.py'];
    catch
        py_script='sgems.py';
    end
end

%% 
% HARD DATA ?
if isfield(S,'d_obs');
    header{1}='X';
    header{2}='Y';
    header{3}='Z';
    header{4}='DATA';
    sgems_write_pointset('obs.sgems',S.d_obs,header,'OBS');
    S.f_obs='obs.sgems';
end

if isfield(S,'f_obs');
    O=sgems_read(S.f_obs,0);    
    if isempty(S.XML.parameters.Hard_Data.grid)
        S.XML.parameters.Hard_Data.grid=O.point_set;
    end
    if isempty(S.XML.parameters.Hard_Data.property)
        S.XML.parameters.Hard_Data.property=O.property_name{1};
    end
    S.XML.parameters.Assign_Hard_Data.value=1;
end

% USING PROBABILITY FIELDS FOR SNESIM/FILTERSIM
try
    % only valid/available for snesim/filtersim
    if isfield(S,'f_probfield');
        S.XML.parameters.Use_ProbField.value=1;
        O=sgems_read(S.f_probfield,0);
        grid_name=O.grid_name;
        S.XML.parameters.GridSelector_Sim.value=grid_name;
        n_prop=length(O.property);
        p=[];
        for i=1:n_prop
            p=sprintf('%s%s',p,O.property{i});
            if i<n_prop;p=[p,';'];end
        end
        S.XML.parameters.ProbField_properties.count=n_prop;
        S.XML.parameters.ProbField_properties.value=p;
    end
end


try
    % sgsim, dssim, LU_sim
    grid_name=S.XML.parameters.Grid_Name.value;
catch
    % snesim_std
    grid_name=S.XML.parameters.GridSelector_Sim.value;
end


try
    % sgsim, dssim, LU_sim
    property_name=S.XML.parameters.Property_Name.value;
catch
    % snesim_std
    property_name=S.XML.parameters.Property_Name_Sim.value;
end

nsim=S.XML.parameters.Nb_Realizations.value;



%% Write XML file to disk
sgems_write_xml(S.XML,S.xml_file);


%% Read and reformat XML file to string
fid=fopen(S.xml_file,'r');
xml_string=char(fread(fid,'char')');
xml_string=regexprep(xml_string,char(10),''); % remove line change
xml_string=regexprep(xml_string,char(13),''); % remove line change
fclose(fid);



%% WRITE PYTHON SCRIPTS
fid=fopen(py_script,'w');

i=0;
i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''DeleteObjects %s'')',grid_name);
i=i+1;sgems_cmd{i}='sgems.execute(''DeleteObjects finished'')';

if isfield(S,'f_probfield');
  i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''LoadObjectFromFile  %s::All'')',S.f_probfield);
end


i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''NewCartesianGrid  %s::%d::%d::%d::%g::%g::%g::%g::%g::%g'')',grid_name,S.dim.nx,S.dim.ny,S.dim.nz,S.dim.dx,S.dim.dy,S.dim.dz,S.dim.x0,S.dim.y0,S.dim.z0);


if isfield(S,'f_obs')
    % LOAD SGEMS OBJECT
    % HERE IS SOME PROBLEM.....
    i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''LoadObjectFromFile  %s::All'')',S.f_obs);
end

if isfield(S,'ti_file')
    if exist(S.ti_file,'file')==2;
        i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''LoadObjectFromFile %s::s-gems'')',S.ti_file);
    else
        mgstat_verbose(sprintf('%s : Could not load %s',mfilename,S.ti_file))
    end
end
i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''DeleteObjects finished'')');
i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''RunGeostatAlgorithm  %s::/GeostatParamUtils/XML::%s'')',alg,xml_string);

i=i+1;sgems_cmd{i}=sprintf('\n');

p='';
for j=1:nsim; p=sprintf('%s::%s__real%d',p,property_name,j-1);end
i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''SaveGeostatGrid  %s::%s.out::gslib::0%s'')',grid_name,property_name,p);
i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''SaveGeostatGrid  %s::%s.sgems::s-gems::0%s'')',grid_name,property_name,p);

i=i+1;sgems_cmd{i}=sprintf('\n');


i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''NewCartesianGrid  finished::1::1::1::1.0::1.0::1.0::0::0::0'')');
i=i+1;sgems_cmd{i}=sprintf('data=[]');
i=i+1;sgems_cmd{i}=sprintf('data.append(1)');
i=i+1;sgems_cmd{i}=sprintf('sgems.set_property(''finished'',''dummy'',data)');

i=i+1;sgems_cmd{i}=sprintf('sgems.execute(''SaveGeostatGrid  finished::finished::gslib::0::dummy'')');


fprintf(fid,'import sgems\n\n');

for i=1:length(sgems_cmd)
    %fprintf(fid,'sgems.execute(''%s'')\n',sgems_cmd{i});
    fprintf(fid,'%s\n',sgems_cmd{i});
end



fclose(fid);