#!/usr/bin/env perl
use strict;

#############################################################################
#                               Variables                                   #
#############################################################################

my $wd = ".";                             # the working directory
my $length = 2500;                        # the "length" argument to ChunkChromosome
my $overlap = 500;                        # the "overlap" argument to ChunkChromosome
my $maxCPU = 20;                          # the maximum number of CPUs
my $pipelineLog = "mach_pipeline.log";    # Logfile for this pipeline script
my $chunkChrLog = "chunk_chromosome.log"; # Logfile for ChunkChromosome

#############################################################################
#                                  SETUP                                    #
#############################################################################

my @child_pids = ();             # A list for the process ids (pids) of child threads

open (PIPELINE_LOG, ">", $pipelineLog) 
  or die "Unable to open $pipelineLog (the log file for this pipeline)";

unlink $chunkChrLog;

#############################################################################
#                            PART 1:  Running MaCH                          #
#############################################################################

print PIPELINE_LOG "Beginning MaCH pipeline (part 1)...\n";

for my $chr ((1..22, 'X', 'Y')) {

  # Run ChunkChromosome for this chromosome
  system("ChunkChromosome -d chr${chr}.dat -n $length -o $overlap 2>&1 >> chunk_chromosome.log");

  # In the current directory, find all the files that were output from
  # ChunkChromosome.  Store the basename of these files in @chunks.
  my @chunks = get_chunks($chr);

  print PIPELINE_LOG "  In chr$chr, found ".scalar(@chunks)." chunks: @chunks\n";

  # Run mach on each chunk, using multiple processes
  # for my $chunk (@chunks) {
  for my $chunk (1..4) {

    # Fork execution into parent and child processes.  fork() returns the
    # process ID of the child process to the parent; and '0' to the child.
    my $pid = fork();

    # If this is the parent process, store the process ID of the child in
    # @child_pids
    if ($pid > 0) {
      push(@child_pids, $pid);
      wait_on_children(\@child_pids) if (scalar(@child_pids) >= $maxCPU);
    }

    # If this is a child process, execute mach
    elsif ($pid == 0) {
      my $command = "sleep 2; echo 'mach; chr${chr}, chunk${chunk}'";
      # my $command = "mach1 -d ${chunk} -p chr${chr}.ped --prefix ${chunk} ".
      #     "--rounds 20 --states 200 --phase --sample 5 2>&1 > ${chunk}mach.log &";
      print PIPELINE_LOG "  Executing '$command'\n";
      exec($command);
      exit 1;
    }

    # If $pid < 0, an error has occured.
    else {
      print PIPELINE_LOG "Error from mach_pipeline.pl: Forking error: $!\n";
      die "Error from mach_pipeline.pl: Forking error: $!\n"
    }
  }
}

# Important!  Wait for all children to finish at the end.
wait_on_children(\@child_pids);

print PIPELINE_LOG "...finished MaCH pipeline (part 1).\n";

#############################################################################
#                            PART 2:  Running minimac                       #
#############################################################################

print PIPELINE_LOG "Beginning minimac pipeline (part 2)...\n";

for my $chr ((1..22, 'X', 'Y')) {

  # In the current directory, find all the files that were output from
  # ChunkChromosome.  Store the basename of these files in @chunks.
  my @chunks = get_chunks($chr);

  my $numChunks = @chunks;
  print PIPELINE_LOG "  In chr$chr, found $numChunks chunks: @chunks\n";

  # Set the name for the vcf file. You may change this.
  my $vcf = "~/hsdfiles/groups/Projects/GWAS/Bangladesh/1KG_phase3v5".
  "reduced.ALL.chr22.phase3_shapeit2_mvncall_integrated_v5.20130502.genotypes.vcf";

  # Run minimac on each chunk, using multiple processes
  # for my $chunk (@chunks) {
  for my $chunk (1..4) {

    # Fork execution into parent and child processes.  fork() returns the
    # process ID of the child process to the parent; and '0' to the child.
    my $pid = fork();

    # If this is the parent process, store the process ID of the child in
    # @child_pids
    if ($pid > 0) {
      push(@child_pids, $pid);
      wait_on_children(\@child_pids) if (scalar(@child_pids) * 4 > $maxCPU);
    }

    # If this is a child process, execute mach
    elsif ($pid == 0) {
      my $command = "sleep 2; echo 'minimac; chr${chr}, chunk${chunk}'";
      # my $command = "minimac-omp --cpus 4 --vcfReference --refHaps ${vcf}  ".
      #   "--haps ${chunk}.gz --snps ${chunk}.snps --rounds 5 ".
      #   "--states 200  --probs --autoClip autoChunk-chr${chr} --rs ".
      #   "--snpAliases dbsnp134-merges.txt.gz  --prefix ${chunk}_minimac 2>&1 ".
      #   "${chunk}_minimac.log &";
      print PIPELINE_LOG "  Executing '$command'\n";
      exec($command);
      exit 1;
    }

    # If $pid < 0, an error has occured.
    else {
      print PIPELINE_LOG "Error from mach_pipeline.pl: Forking error: $!\n";
      die "Error from mach_pipeline.pl: Forking error: $!\n"
    }
  }
}

# Important!  Wait for all children to finish at the end.
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

# For a given chromosome, finds chunks files generated by ChunkChromosome
# Argument: $scalar, the chromosome number 
sub get_chunks {
  my $chr = shift;
  my @chunks = ();
  opendir(my $directory, ".") or die "Can't read from directory: $!";
  for my $file (readdir($directory)) {
    if ($file =~ /^(chunk\d+-)$/) {
      push(@chunks, $1);
    }
  }
  closedir $directory;
  return @chunks;
}
