#!/bin/bash
# create analysis directories for a single or multiple subjects

if [ -z "$1" ]; then
  subjects="1 2 3 4"
else
  subjects="$1"
fi

for subject in ${subjects}; do
	
	pushd .

	sbjstr=$(printf %04d ${subject})
	mkdir ${sbjstr}
	cd ${sbjstr}
	
	mkdir analysis dicom masks matlab params ref_data reg_data regressions

	popd
	
done