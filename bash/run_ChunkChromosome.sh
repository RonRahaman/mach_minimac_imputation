#!/usr/bin/env bash

length=100
overlap=20
logdir=logfiles

chr_list=($(seq 1 22) 'X' 'Y')

if [ ! -d $logfiles ]; then
  mkdir -p $logfiles
fi

for chr in ${chr_list[@]}; do
  log="${logdir}/ChunkChromosome_chr${chr}.log"
  ChunkChromosome -d "chr${chr}.dat" -n $length -o $overlap 2>&1 | tee $log
done
