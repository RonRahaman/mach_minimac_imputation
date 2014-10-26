#!/usr/bin/env bash

killgroup() {
  echo 'killing process group...'
  kill 0
}

max_CPU=3
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

    log="${logdir}/mach_chr${chr}.log"
    mach1 -d ${chunk}.dat -p chr${chr}.ped --prefix ${chunk} \
      --rounds 20 --states 200 --phase --sample 5 2>&1 | tee $log &

    n_procs=$(( n_procs + 1 ))

    if [ $n_procs -ge $max_CPU ]; then
      echo "Waiting on $n_procs processes..."
      wait
      n_procs=0
    fi

  done

done

echo "Waiting on $n_procs processes..."
wait




