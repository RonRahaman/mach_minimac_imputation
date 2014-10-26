#!/usr/bin/env bash

length=400
overlap=100
logdir=logfiles

chr_list=($(seq 1 22) 'X' 'Y')
echo ${chr_list[@]}

if [ ! -d $logfiles ]; then
  mkdir -p $logfiles
fi

for chr in ${chr_list[@]}; do
  log="${logdir}/ChunkChromosome_chr${chr}.log"
  ChunkChromosome -d "chr${chr}.dat" -n $length -o $overlap 2>&1 | tee $log
done
