#!/usr/bin/env bash

#############################################################################
#  run_minimac.sh
#  Author: Ron Rahaman (rahaman@gmail.com)
#  Date: 2014-10-26
#
#  Runs minimac as part of an imputation pipeline.
#
#  Features: Stopping this script with Ctrl-C will stop all running mach
#  processes.
#
#  This pipeline processes multiple chromosome chunks in  parallel.  It is
#  based on a tcsh script from the University of Michican Center for
#  Statistical Genomics:
#  http://genome.sph.umich.edu/wiki/Minimac:_1000_Genomes_Imputation_Cookbook
#
#############################################################################

max_CPU=12                        # Maximum number of CPUs to use
threads=4                         # Number of threads for minimac
logdir=logfiles                   # Directory for logfiles
chr_list=($(seq 1 22) 'X' 'Y')    # List of chromosomes to process

# Function to kill all running MaCH processes
killgroup() {
  echo 'killing process group...'
  kill 0
}

# If script is stopped with Ctrl-C is, kill all MaCH processes
trap killgroup SIGINT

# If logifle directory doesn't exist, create it
if [ ! -d $logfiles ]; then
  mkdir -p $logfiles
fi

# The number of running minimac proceeses
n_procs=0

for chr in ${chr_list[@]}; do

  # Find all the chunks for this chromosome
  chunk_list=($(ls chunk*chr${chr}.dat 2>/dev/null))

  for chunk in ${chunk_list[@]}; do

    chunk=$(basename $chunk .dat)
    log="${logdir}/minimach_chr${chr}.log"

    vcf="~/hsdfiles/groups/Projects/GWAS/Bangladesh/1KG_phase3v5/reduced.ALL.chr${chr}.phase3_shapeit2_mvncall_integrated_v5.20130502.genotypes.vcf.gz";

    # Run minimac
    minimac-omp --cpus ${threads} --vcfReference --refHaps ${vcf} \
      --haps ${chunk}.gz --snps ${chunk}.dat.snps --rounds 5 --states 200  \
      --probs --autoClip autoChunk-chr${chr} --rs --snpAliases dbsnp134-merges.txt.gz  \
      --prefix ${chunk}_minimac 2>&1 | tee $log

    n_procs=$(( n_procs + 1 ))

    # If the number of running threads is greater than maxCPUs, wait till
    # they're finished.
    if [ $((n_procs*threads)) -ge $max_CPU ]; then
      echo "Waiting on $n_procs processes..."
      wait
      n_procs=0
    fi

  done

done

# Wait for the remaining processs
echo "Waiting on $n_procs processes..."
wait




