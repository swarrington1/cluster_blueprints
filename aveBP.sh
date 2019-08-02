#!/bin/bash

##### produces the simple average and the population percent blueprints fromt the HCP data

# bash jobsub -q imghmemq -p 1 -t 24:00:00 -m 60 -s BP_ave -c "bash /gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting/aveBP.sh /gpfs01/share/HCP/HCPyoung_adult/Diffusion/all_subjects 2"

module load connectome-uon/workbench-1.3.2

input=$1
opt=$2 # which averaging to do? 0 does both, 1 does simple and 2 does pop percent
scriptsDir=/gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting
StudyFolder=/gpfs01/share/HCP/HCPyoung_adult/Diffusion

tractNames=${scriptsDir}/blueprint_tracts

thr=0.05 # as a fraction, 0.05 (i.e. 5%) based on what looks best

output=${StudyFolder}/blueprint_atlas
if [ ! -d ${output} ]; then
    mkdir ${output}; mkdir ${output}/temp
fi
if [ ! -d ${output}/temp ]; then
    mkdir ${output}/temp
fi

noSubs=$((`wc -l < ${input}`))

if [ ! ${opt} -eq "2" ]; then
### the simple average
echo "Running the simple average"
cmd="wb_command -cifti-average ${output}/blueprint_average.dtseries.nii"
count=0
for subID in `cat ${input}`; do
    echo ${subID}
    bpFile="${StudyFolder}/${subID}/MNINonLinear/Results/blueprint_forPaper/bpTracts.dtseries.nii"   
    if [ -f $bpFile ]; then
	cmd="${cmd} -cifti ${bpFile}"
    else
        count=$((count+1))
    fi
done
echo "Averaging $(($noSubs-$count)) subjects (simple average)"
${cmd}
wb_command -set-map-names ${output}/blueprint_average.dtseries.nii -name-file ${tractNames}
fi

if [ ! ${opt} -eq "1" ]; then
### the population percent atlas
echo "Running the population percent average"
# initialise the averaging command
AVEcmd="wb_command -cifti-average ${output}/blueprint_atlas.dscalar.nii"
count=0
for subID in `cat ${input}`; do
    echo ${subID}
    bpFile="${StudyFolder}/${subID}/MNINonLinear/Results/blueprint_forPaper/bpTracts.dtseries.nii"
    if [ -f $bpFile ]; then
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

	# build the averaging command
	AVEcmd="${AVEcmd} -cifti ${output}/temp/${subID}.dscalar.nii"
    else
        count=$((count+1))
    fi
done
echo "Averaging $(($noSubs-$count)) subjects (population  percent atlas)"
${AVEcmd}
wb_command -set-map-names ${output}/blueprint_atlas.dscalar.nii -name-file ${tractNames}
rm ${output}/temp -r
fi
