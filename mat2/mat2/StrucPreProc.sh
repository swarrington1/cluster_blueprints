#!/bin/bash

scriptsdir="/gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting/mat2"
BioDir="/gpfs01/share/ukbiobank"
dirIn="${BioDir}/Release_1"
dirOut="${BioDir}/mszam/HCP"

input="${BioDir}/Shaun_proc/split/StrucBioTBC"

nSub=`cat ${input} | wc -w`; j=0
echo "Running for ${nSubs} subjects:"
echo -n ""
for i in `cat ${input}`
do
  j=$((j+1))
  echo -ne "\r${i}: ${j} of ${nSub}"
  mkdir ${dirOut}/${i}
  ln -s ${dirIn}/${i}/T1/T1.nii.gz ${dirOut}/${i}/T1.nii.gz
  ln -s ${dirIn}/${i}/T2_FLAIR/T2_FLAIR.nii.gz ${dirOut}/${i}/T2_FLAIR.nii.gz
done
echo ""
bash /gpfs01/software/imaging/HCP_Pipelines/Notts/Struc_Pipeline.sh --parameterFile=$StudyFolder/InputParameterFile.sh
