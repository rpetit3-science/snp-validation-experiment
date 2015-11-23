#! /bin/bash
#$ -V
#$ -S /bin/bash

MAKEFILE="/home/rpetit/variant-validation-experiment"
TMP_DIR=`/bin/mktemp -d`
mkdir -p ${TMP_DIR}

make -C ${MAKEFILE} run_simulation TMP_DIR=${TMP_DIR} START=$1 END=$2 TOTAL_VARIANTS=$3

rsync -av ${TMP_DIR}/simulation/ ./simulation/
rm -rf ${TMP_DIR}
