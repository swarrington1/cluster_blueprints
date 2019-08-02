#!/bin/bash

#input=/gpfs01/share/HCP/HCPyoung_adult/Diffusion/all_subjects
input=/gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting/templist
scriptsDir=/gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting

# Create and enter a job submission directory
subDir="/gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting/jobs"
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

for subID in `cat ${input}`; do
    echo "${subID}"
    bash jobsub -j -q imgcomputeq -p 1 -t 06:00:00 -m 80 -s ${subID}_bp -c "bash ${scriptsDir}/matlab_job.sh ${subID}"
    sleep 180
done

cd ${curDir}
