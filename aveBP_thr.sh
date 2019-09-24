#!/bin/bash

module load connectome-uon/workbench-1.3.2

StudyFolder=/gpfs01/share/HCP/HCPyoung_adult/Diffusion
scriptsDir=/gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting
output=${StudyFolder}/blueprint_atlas

tractNames=${scriptsDir}/blueprint_tracts
subID=$1
thr=$2

bpFile="${StudyFolder}/${subID}/MNINonLinear/Results/blueprint_forPaper/bpTracts.dtseries.nii"

cp ${bpFile} ${output}/temp/${subID}.dtseries.nii
mx=(`wb_command -cifti-stats ${bpFile} -reduce MAX`)
ind=0; 

# initialise the merge command
MERGEcmd='wb_command -cifti-merge ${output}/temp/${subID}.dscalar.nii'

for i in "${mx[@]}"; do
    t=$(echo $thr*$i | bc) # the threshold value, thr as a percent of the column max 
    ind=$((ind+1)) # current column index
    
    # threshold the blueprint and then append to ave command
    THRcmd="wb_command -cifti-math '(x>${t})' ${output}/temp/${subID}_${ind}.dscalar.nii -var x ${output}/temp/${subID}.dtseries.nii -select 1 ${ind}"
    eval ${THRcmd}

    # build the merge command
    MERGEcmd="${MERGEcmd} -cifti ${output}/temp/${subID}_${ind}.dscalar.nii "  
done

# run merge and then clean-up
eval ${MERGEcmd}
rm ${output}/temp/${subID}_*.dscalar.nii 
