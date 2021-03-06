#!/usr/bin/env perl
use strict;
use File::Spec::Functions;
use File::Basename;

#############################################################################
#  mach_pipeline.pl
#  Version 0.4.2 (2014-10-21)
#  Author: Ron Rahaman (rahaman@gmail.com)
#
#  A pipeline for imputing 1000 Genomes data using MaCH and minimac.
#
#  This pipeline imputes chromosomes in chunks and processes multiple chunks 
#  in  parallel.  It is based on a tcsh script found here:
#  http://genome.sph.umich.edu/wiki/Minimac:_1000_Genomes_Imputation_Cookbook
#
#############################################################################

#############################################################################
#                               Variables                                   #
#############################################################################

my @chrList = (1..22);   # List of chromosomes to process
my $maxCPU = 24;                   # the maximum number of CPUs
my $minimacThreads = 4;            # the number of threads for minimac-omp

my $length = 2500;                  # the "length" argument to ChunkChromosome
my $overlap = 500;                 # the "overlap" argument to ChunkChromosome

my $logDir = "logfiles";           # directory for logfiles
my $pipelineLog = "pipeline.log";  # Logfile for this pipeline script


#############################################################################
#                                  SETUP                                    #
#############################################################################

my @child_pids = ();               # A list for the process ids (pids) of child threads

if (-d $logDir) {
  unlink glob(catfile($logDir, '*.log'));
}
else {
  mkdir $logDir or die "Unable to make directory ($logDir) for logfiles: $!";
}

open (PIPELINE_LOG, ">", catfile($logDir, $pipelineLog)) 
  or die "Unable to open the log file (".catfile($logDir, $pipelineLog).") for this pipeline: $!";

#############################################################################
#                 PART 1:  Running ChunkChromosome                          #
#############################################################################

for my $chr (@chrList) {

  # Run ChunkChromosome for this chromosome
  my $log = catfile($logDir, "ChunkChromosome_chr${chr}.log");
  system("ChunkChromosome -d chr${chr}.dat -n $length -o $overlap 2>&1 > $log");

}

#############################################################################
#                            PART 2:  Running MaCH                          #
#############################################################################

print PIPELINE_LOG "Beginning MaCH pipeline (part 1)...\n";

for my $chr (@chrList) {

  # In the current directory, find all the files that were output from
  # ChunkChromosome.  Store the basename of these files in @chunks.
  my @chunks = glob("chunk*-chr$chr.dat");

  print PIPELINE_LOG "  In chr$chr, found ".scalar(@chunks)." chunks: @chunks\n";

  # Run mach on each chunk, using multiple processes
  for my $chunk (@chunks) {

    $chunk = basename($chunk, ".dat");
    my $log = catfile($logDir, "mach_${chunk}.log");
    my $command = "mach1 -d ${chunk}.dat -p chr${chr}.ped --prefix ${chunk} ".
    "--rounds 20 --states 200 --phase --sample 5 2>&1 > $log &";

    # Fork execution into parent and child processes.  fork() returns the
    # process ID of the child process to the parent; and '0' to the child.
    my $pid = fork();

    # If this is the parent process, store the process ID of the child in
    # @child_pids
    if ($pid > 0) {
      print PIPELINE_LOG "    Process $pid is executing '$command'\n";
      push(@child_pids, $pid);
      if (scalar(@child_pids) >= $maxCPU) {
        print PIPELINE_LOG "    Waiting on ".scalar(@child_pids)." processes.\n";
        wait_on_children(\@child_pids);
      }
    }

    # If this is a child process, execute mach
    elsif ($pid == 0) {
      my $log = catfile($logDir, "mach_${chunk}.log");
      my $command = "mach1 -d ${chunk}.dat -p chr${chr}.ped --prefix ${chunk} ".
          "--rounds 20 --states 200 --phase --sample 5 2>&1 > $log &";
      print PIPELINE_LOG "  Executing '$command'\n";
      exec($command);
      exit 1;
    }

    # If $pid < 0, an error has occured.
    else {
      die "Error from mach_pipeline.pl: Forking error: $!\n"
    }
  }
}

# Important!  Wait for all children to finish at the end.
print PIPELINE_LOG "    Waiting on ".scalar(@child_pids)." processes.\n";
wait_on_children(\@child_pids);

print PIPELINE_LOG "...finished MaCH pipeline (part 1).\n";

#############################################################################
#                            PART 3:  Running minimac                       #
#############################################################################

print PIPELINE_LOG "Beginning minimac pipeline (part 2)...\n";

for my $chr (@chrList) {

  # In the current directory, find all the files that were output from
  # ChunkChromosome.  Store the basename of these files in @chunks.
  my @chunks = glob("chunk*-chr$chr.dat");
  print PIPELINE_LOG "  In chr$chr, found ".scalar(@chunks)." chunks: @chunks\n";

  # Run minimac on each chunk, using multiple processes
  for my $chunk (@chunks) {
    
    # Path to VCF file
    my $vcf = "~/hsdfiles/groups/Projects/GWAS/Bangladesh/1KG_phase3v5/".
    "reduced.ALL.chr${chr}.phase3_shapeit2_mvncall_integrated_v5.20130502.genotypes.vcf.gz";

    $chunk = basename($chunk, ".dat");
    my $log = catfile($logDir, "minimac_${chunk}.log");
    my $command = "minimac-omp --cpus ${minimacThreads} --vcfReference ".
    "--refHaps ${vcf} --haps ${chunk}.gz --snps ${chunk}.dat.snps --rounds 5 ".
    "--states 200  --probs --autoClip autoChunk-chr${chr} --rs ".
    "--snpAliases dbsnp134-merges.txt.gz  --prefix ${chunk}_minimac".
    " 2>&1 > $log &";


    # Path to VCF file
    my $vcf = "~/hsdfiles/groups/Projects/GWAS/Bangladesh/1KG_phase3v5/".
      "reduced.ALL.chr${chr}.phase3_shapeit2_mvncall_integrated_v5.20130502.genotypes.vcf.gz";

    # Fork execution into parent and child processes.  fork() returns the
    # process ID of the child process to the parent; and '0' to the child.
    my $pid = fork();

    # If this is the parent process, store the process ID of the child in
    # @child_pids
    if ($pid > 0) {
      print PIPELINE_LOG "    Process $pid is executing '$command'\n";
      push(@child_pids, $pid);
      if (scalar(@child_pids) * $minimacThreads > $maxCPU) {
        print PIPELINE_LOG "    Waiting on ".scalar(@child_pids)." processes.";
        wait_on_children(\@child_pids);
      }
    }

    # If this is a child process, execute mach
    elsif ($pid == 0) {
      my $log = catfile($logDir, "minimac_${chunk}.log");
      my $command = "minimac-omp --cpus ${minimacThreads} --vcfReference ".
        "--refHaps ${vcf} --haps ${chunk}.gz --snps ${chunk}.dat.snps --rounds 5 ".
        "--states 200  --probs --autoClip autoChunk-chr${chr} --rs ".
        "--snpAliases dbsnp134-merges.txt.gz  --prefix ${chunk}_minimac".
       " 2>&1 > $log &";
      print PIPELINE_LOG "  Executing '$command'\n";
      exec($command);
      exit 1;
    }

    # If $pid < 0, an error has occured.
    else {
      print PIPELINE_LOG "Error from mach_pipeline.pl: Forking error: $!\n";
      die "Error from mach_pipeline.pl: Forking error: $!\n";
    }
  }
}

# Important!  Wait for all children to finish at the end.
print PIPELINE_LOG "    Waiting on ".scalar(@child_pids)." processes.\n";
wait_on_children(\@child_pids);

print PIPELINE_LOG "...finished minimac pipeline (part 2).\n";

#############################################################################
#                                  CLEANUP                                  #
#############################################################################

close(PIPELINE_LOG);

#############################################################################
#                       SUBROUTINE DEFINITIONS                              #
#############################################################################

# Waits on a list of children to finish
# Argument: \@array, a ref to a list of child pids
sub wait_on_children {
  my $children = shift;
  for my $pid (@$children) {
    waitpid($pid, 0) ;
  }
  @$children = ();
}
