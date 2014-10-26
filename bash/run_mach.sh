#!/usr/bin/env bash

killgroup() {
  echo 'killing process group...'
  kill 0
}

max_CPU=4
logdir=logfiles
chr_list=($(seq 1 22) 'X' 'Y')

trap killgroup SIGINT

if [ ! -d $logfiles ]; then
  mkdir -p $logfiles
fi

n_procs=0
for chr in ${chr_list[@]}; do

  chunk_list=($(ls chunk*chr${chr}.dat 2>/dev/null))

  for chunk in ${chunk_list[@]}; do
    chunk=$(basename $chunk .dat)
    echo $chunk

    # log="${logdir}/mach_chr${chr}.log"

    # $n_procs=$(( n_procs + 1 ))

    # if [ $n_procs -ge $max_CPU ]; then
    #   echo "Waiting on $n_procs processes..."
    #   wait
    # fi

  done

done




