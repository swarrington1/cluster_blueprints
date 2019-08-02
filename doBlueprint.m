function doBlueprint(subID)

addpath /software/imaging/fsl/6.0.1/etc/matlab
addpath /gpfs01/share/HCP/HCPyoung_adult/scripts/Tools/gifti-1.6/
addpath /gpfs01/share/HCP/HCPyoung_adult/scripts/Tools/Washington-University-cifti-matlab-f3aa924

%% pre-amble
ds = 3;
dt = {'00'};
threshold = 0.001;
StudyFolder='/gpfs01/share/HCP/HCPyoung_adult';
DiffStudyFolder=[StudyFolder '/Diffusion'];
StrucStudyFolder=[StudyFolder '/Structural'];
stdref='/software/imaging/fsl/6.0.1/data/standard/MNI152_T1_1mm_brain_mask';

%% Define tracts
fID=fopen('/gpfs01/share/HCP/HCPyoung_adult/scripts/tract_averaging/structList');
tline=fgetl(fID);
i=0;
while ischar(tline)
    i=i+1;
    line=strsplit(tline);
    tracts{i}=line{1};
    tline=fgetl(fID);
end
fclose(fID);

% Remove mcp
tracts([26])=[];

resultsFolder=[DiffStudyFolder '/' num2str(subID) '/MNINonLinear/Results/blueprint_forPaper'];
cmd=(['if [ ! -d "' resultsFolder '" ]; then mkdir ' resultsFolder '; else rm '...
    resultsFolder ' -r; mkdir ' resultsFolder '; fi']);
unix(cmd);

%% do hemisphere loop
sArr={'LH', 'RH'};
for s=1:2
    side=sArr{s}; disp(['Running ' side ' for ' num2str(subID) '...'])
    mat2Folder=([DiffStudyFolder '/' num2str(subID) '/MNINonLinear/Results/Tractography/'...
        num2str(ds) 'mm' num2str(dt{1}) '/' side]);
    
    if isfile([mat2Folder '/fdt_matrix2.dot.gz'])
        disp('Unzipping fdt_matrix2.dot.gz')
        unix(['gunzip ' mat2Folder '/fdt_matrix2.dot.gz']);
    end

    disp('Reading and converting fdt matrix...')
    fdt=full(spconvert(load([mat2Folder '/fdt_matrix2.dot'])));
    disp('Re-zipping fdt_matrix2.dot')
    unix(['gzip ' mat2Folder '/fdt_matrix2.dot --fast']);
    
    % Read in tract file to produce mask
    [maskL,~,~]=read_avw([mat2Folder '/Mat2_target.nii.gz']);
    maskL=0*maskL;
    % Read coord file
    coord=load([mat2Folder '/tract_space_coords_for_fdt_matrix2'])+1;
    ind=sub2ind(size(maskL),coord(:,1),coord(:,2),coord(:,3));
    
    %% Loop through Ptx tracts
    disp('Processing tracts...')
    PtxFolder=[DiffStudyFolder '/' num2str(subID) '/MNINonLinear/Results/autoPtx/tracts'];
    tractMap=cell(1,size(tracts,2));
    for i=1:size(tracts,2)
        t_in=[PtxFolder '/' tracts{i} '/densityNorm'];
        tempFolder=[PtxFolder '/' tracts{i} '/resampled'];
        t_out=[tempFolder '/densityNorm_' num2str(ds)];
        
        % Check if results folder/file exists - delete and create new
        cmd=['if [ -d "' tempFolder '" ]; then if [ -e "' t_out...
            '.nii.gz" ]; then rm ' t_out '.nii.gz; fi else mkdir ' tempFolder '; fi'];
        unix(cmd);
        
        % Downsample the tract file
        cmd=['/software/imaging/fsl/6.0.1/bin/flirt -in ' t_in '.nii.gz -ref ' stdref ' -out ' t_out...
            ' -applyisoxfm ' num2str(ds) ' -interp trilinear'];
        unix(cmd);
        
        %Threshold and mask the tract file using the Mat2_target file
        %Threshold here
        t_mask=[t_in '_' num2str(ds) '_masked'];
        cmd=['/software/imaging/fsl/6.0.1/bin/fslmaths ' t_out ' -thr ' num2str(threshold) ' ' t_mask];
        unix(cmd);
        cmd=['/software/imaging/fsl/6.0.1/bin/fslmaths ' t_mask ' -mas ' mat2Folder '/Mat2_target ' t_mask];
        unix(cmd);
        
        % Remove temp folder
        unix(['rm ' tempFolder ' -r']);
        
        % Read in masked tract file
        tractMat=read_avw(t_mask);
        dim=[size(tractMat,1),size(tractMat,2),size(tractMat,3)];
        tractMat=tractMat(:);
        % Loop through tract mat file, linearise and reorder to fdt coords
        tractMat_lin=zeros(size(fdt,2),1);
        for j=1:size(fdt,2)
            tractMat_lin(j)=tractMat(ind(j));
        end
        tractMap{i}=tractMat_lin;
        unix(['rm ' t_mask '.nii.gz']);
        
        disp(['Completed ' num2str(i) ' of ' num2str(size(tracts,2))]);
    end
    %% Convert tract map and multiply by fdt matrix
    tractMap=cell2mat(tractMap);
    bpMat=fdt*tractMap; bpMat=bpMat';
    
    bpPath=[resultsFolder '/' num2str(ds) 'mmbpMat' num2str(dt{1}) side '.mat'];
    fullfile(DiffStudyFolder, num2str(subID),'MNINonLinear/Results/blueprint_forPaper',...
        [num2str(ds) 'mmbpMat' num2str(dt{1}) side '.mat']);
    save(bpPath, 'bpMat');
end

%% Load the blueprint.mat files and surface GIFTI files
bpMatL=load([resultsFolder '/' num2str(ds) 'mmbpMat' num2str(dt{1}) 'LH.mat']);
bpMatR=load([resultsFolder '/' num2str(ds) 'mmbpMat' num2str(dt{1}) 'RH.mat']);
bpMatL=bpMatL.bpMat;
bpMatL=bpMatL';
bpMatR=bpMatR.bpMat;
bpMatR=bpMatR';
fsAvpath=fullfile(StrucStudyFolder, num2str(subID), ['MNINonLinear/fsaverage_LR32k/' num2str(subID)]);
maskL=gifti([fsAvpath '.L.atlasroi.32k_fs_LR.shape.gii']);
maskL=maskL.cdata;
maskR=gifti([fsAvpath '.R.atlasroi.32k_fs_LR.shape.gii']);
maskR=maskR.cdata;

%% convert to 32k
bpLaug=zeros(size(maskL,1), size(bpMatL,2));
k=0;
for i=1:size(maskL,1)
    if maskL(i)==1
        bpLaug(i,:)=bpMatL(i-k,:);
    elseif maskL(i)==0
        bpLaug(i,:)=bpLaug(i,:);
        k=k+1;
    end
end
bpRaug=zeros(size(maskR,1), size(bpMatR,2));
k=0;
for i=1:size(maskR,1)
    if maskR(i)==1
        bpRaug(i,:)=bpMatR(i-k,:);
    elseif maskR(i)==0
        bpRaug(i,:)=bpRaug(i,:);
        k=k+1;
    end
end

%% save
bpLR=cat(1,bpLaug,bpRaug);
disp('Saving...')
% Save blueprint to /blueprint folder
svPath=fullfile(resultsFolder, [num2str(ds) 'mmbpMat' num2str(dt{1}) 'LR32k.mat']);
save(svPath, 'bpLR');

%% Create the CIFTI file
% the tracts are the "time series"
% Common L/R descriptors - use existent CIFTI as template
cPath='/gpfs01/share/HCP/HCPyoung_adult/scripts/Tools/template.dtseries.nii';
cifti=ft_read_cifti(cPath);

bpCii=cifti;
bpCii.time=linspace(1,size(tracts,2),size(tracts,2));
bpCii.hdr.dim(6)=size(bpLR,1);
bpCii.dtseries=bpLR;
ciftiPath=fullfile(resultsFolder, 'bpTracts');
ft_write_cifti(ciftiPath, bpCii, 'parameter', 'dtseries');
disp('Done!')

