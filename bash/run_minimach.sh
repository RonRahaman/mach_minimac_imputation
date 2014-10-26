#!/usr/bin/env bash

killgroup() {
  echo 'killing process group...'
  kill 0
}

max_CPU=12
threads=4
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
    log="${logdir}/minimach_chr${chr}.log"
    vcf="~/hsdfiles/groups/Projects/GWAS/Bangladesh/1KG_phase3v5/reduced.ALL.chr${chr}.phase3_shapeit2_mvncall_integrated_v5.20130502.genotypes.vcf.gz";

    minimac-omp --cpus ${threads} --vcfReference --refHaps ${vcf} \
      --haps ${chunk}.gz --snps ${chunk}.dat.snps --rounds 5 --states 200  \
      --probs --autoClip autoChunk-chr${chr} --rs --snpAliases dbsnp134-merges.txt.gz  \
      --prefix ${chunk}_minimac 2>&1 | tee $log

    n_procs=$(( n_procs + 1 ))

    if [ $((n_procs*threads)) -ge $max_CPU ]; then
      echo "Waiting on $n_procs processes..."
      wait
      n_procs=0
    fi

  done

done

echo "Waiting on $n_procs processes..."
wait




