#!/bin/bash

subID=$1

scriptsDir=/gpfs01/share/HCP/HCPyoung_adult/scripts/blueprinting
module load matlab-uon

module load matlab-uon

matlab -nodisplay -nosplash -r "cd ${scriptsDir}; run 'doBlueprint(${subID})'; quit;"



