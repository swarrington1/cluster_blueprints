#!/bin/bash

##### produces the simple average and the population percent blueprints fromt the HCP data

# bash /gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting/aveBP.sh /gpfs01/share/HCP/HCPyoung_adult/Diffusion/all_subjects 2

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
    cmd="/software/connectome/workbench-v1.3.2/bin_rh_linux64/wb_command -cifti-average ${output}/blueprint_average.dtseries.nii"
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
    echo $cmd
    bash jobsub -q cpu -p 1 -t 01:00:00 -m 60 -s simp_aveBP -c "bash ${cmd}"
fi


if [ ! ${opt} -eq "1" ]; then
    # Create and enter a job submission directory
    subDir="/gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting/ave_jobs"
    curDir=`pwd`
    if [ -d ${subDir} ]; then
	i=0
	while [ i=0 ]; do
            if [ -d ${subDir} ]; then
		subDir="${subDir}+"
	    else
		i=1; break
	    fi
	done
	echo "${subDir}"
    fi
    mkdir ${subDir}; cd ${subDir}

    ### the population percent atlas
    echo "Running the population percent average"
    # initialise the averaging command
    AVEcmd="/software/connectome/workbench-v1.3.2/bin_rh_linux64/wb_command -cifti-average ${output}/blueprint_atlas.dscalar.nii"
    count=0
    for subID in `cat ${input}`; do
	echo ${subID}
	bpFile="${StudyFolder}/${subID}/MNINonLinear/Results/blueprint_forPaper/bpTracts.dtseries.nii"
	if [ -f $bpFile ]; then
	    #bash jobsub -q cpu -j -p 1 -t 00:30:00 -m 2 -s thrBP_${subID} -c "bash ${scriptsDir}/aveBP_thr.sh ${subID} ${thr}"
	    #sleep 0.1 
	    # build the averaging command
	    AVEcmd="${AVEcmd} -cifti ${output}/temp/${subID}.dscalar.nii"
	else
            count=$((count+1))
	fi
    done
    cd $curDir


    ### while loop to wait for all other jobs to finish
    i=0
    while [ $i -eq "0" ]
    do
	chk=`sacct | grep 'thrBP_' | grep 'RUNNING'`
	if [ "${chk}" == "" ]; then break; fi
	sleep 2
    done
    echo "Averaging $(($noSubs-$count)) subjects (population  percent atlas)"

    bash jobsub -q cpu -p 1 -t 01:00:00 -m 60 -s pop_perc_BP -c "${AVEcmd}"

    echo "Waiting for averaging to finish...";
    while true; do
	chk=`sacct | grep 'pop_perc_' | grep 'COMP'`
	if [ ! "${chk}" == "" ]; then break; fi
	echo -n "."; sleep 5
    done
    /software/connectome/workbench-v1.3.2/bin_rh_linux64/wb_command -set-map-names ${output}/blueprint_atlas.dscalar.nii -name-file ${tractNames}
    rm ${output}/temp -r
fi
