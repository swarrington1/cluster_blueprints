#!/bin/bash

scriptsdir="/gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting/mat2"
StudyFolder="/gpfs01/share/ukbiobank"
DiffStudyFolder=${StudyFolder}/Release_1
DiffStudyFolder_out=${StudyFolder}/Shaun_proc
StrucStudyFolder=${StudyFolder}/mszam/HCP

input="${StudyFolder}/Shaun_proc/split/StrucBioTBC"

MSMflag=0
DistanceThreshold=-1
DownsampleMat2Target=1
optsLH=" $DistanceThreshold $DownsampleMat2Target 1"
optsRH=" $DistanceThreshold $DownsampleMat2Target 2"

nSub=`cat ${input} | wc -w`; j=0
echo "Submitting for ${nSubs} subjects:"
echo -n ""
for i in `cat ${input}`
do
  j=$((j+1))
  echo -ne "\r${i}: ${j} of ${nSub}"
  jobID=`bash jobsub -j -q cpu -p 1 -t 01:00:00 -m 1 -s ${i}_Mat2PreProc \
         -c "bash ${scriptsdir}/PreTractography.sh $BioDir $i $MSMflag"`
  jobID=`echo -e $temp | awk '{print $NF}'`

  jobID=`bash jobsub -j -q gpu -g 1 -p 1 -t 01:00:00 -m 1 -w ${jobID} -s ${i}_Mat2Tract \
         -c "mkdir ${DiffStudyFolder_out}/${i}/Matrix2/LH; mkdir ${DiffStudyFolder_out}/${i}/Matrix2/RH; \
         bash ${scriptsdir}/RunMatrix2.sh $StudyFolder $i $optsLH; bash $scriptsdir/RunMatrix2.sh $StudyFolder $i $optsRH"`
  jobID=`echo -e $temp | awk '{print $NF}'`

  jobID=`bash jobsub -j -q cpu -p 1 -t 01:00:00 -m 1 -w ${jobID} -s ${i}_Mat2Post \
         -c "gzip ${DiffStudyFolder_out}/${i}/LH/fdt_matrix2.dot --fast; \
         gzip ${DiffStudyFolder_out}/${i}/RH/fdt_matrix2.dot --fast"`
done
