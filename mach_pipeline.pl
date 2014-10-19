#!/usr/bin/perl
use strict;

#############################################################################
#                               Variables                                   #
#############################################################################

my $wd = ".";               # the working directory; you may change this
my $length = 2500;          # the "length" argument to ChunkChromosome; you may change this
my $overlap = 500;          # the "overlap" argument to ChunkChromosome; you may change this
my $maxNumThreads = 24;                 # the maximum number of process threads; you may change this
my $currentNumThreads = 0;             # the current number of threads;  PLEASE DON'T CHANGE THIS
my $pipelineLog = "mach_pipeline.log"; # Logfile for this pipeline script
my $chunkChrLog = "chunk_chromosome.log"; # Logfile for ChunkChromosome

my @child_pids;             # A list for the process ids (pids) of child threads

#############################################################################
#                            PART 1:  Running MaCH                          #
#############################################################################

open (PIPELINE_LOG, ">", $pipelineLog) 
  or die "Unable to open $pipelineLog (the log file for this pipeline)";

unlink $chunkChrLog or warn "Could not unlink $chunkChrLog: $!";

print PIPELINE_LOG "Beginning MaCH pipeline (part 1)...\n";

for my $chr ((22..22)) {

  # Run ChunkChromosome for this chromosome, using the $length and $overlap
  # variables.  
  system("ChunkChromosome -d chr${chr}.dat -n $length -o $overlap 2>&1 >> chunk_chromosome.log");

  # In the current directory, find all the files that were output from
  # ChunkChromosome.  Store the basename of these files in @chunks.
  my @chunks = get_chunks($chr);

  my $numChunks = @chunks;
  print PIPELINE_LOG "  In chr$chr, found $numChunks chunks: @chunks\n";

  # Run mach on each chunk, using multiple processes
  for my $chunk (@chunks) {
    wait_on_children() if ($currentNumThreads >= $maxNumThreads);
    $currentNumThreads++;

    # Fork execution into parent and child processes.  fork() returns the
    # process ID of the child process to the parent; and '0' to the child.
    my $pid = fork();

    # If this is the parent process, store the process ID of the child in
    # @child_pids
    if ($pid > 0) {
      push(@child_pids, $pid);
    }

    # If this is a child process, execute mach
    elsif ($pid == 0) {
      my $command = "mach1 -d ${chunk} -p chr${chr}.ped --prefix ${chunk} ".
          "--rounds 20 --states 200 --phase --sample 5 2>&1 > ${chunk}mach.log &";
      print PIPELINE_LOG "  Executing '$command'\n";
      exec($command);
    }

    # If $pid < 0, an error has occured.
    else {
      print PIPELINE_LOG "Error from mach_pipeline.pl: Forking error: $!\n";
      die "Error from mach_pipeline.pl: Forking error: $!\n"
    }
  }
}

# Important!  Wait for all children to finish at the end.
wait_on_children();

print PIPELINE_LOG "...finished MaCH pipeline (part 1).\n";

exit 0;

#############################################################################
#                            PART 2:  Running minimac                       #
#############################################################################

print PIPELINE_LOG "Beginning minimac pipeline (part 2)...\n";

for my $chr ((22..22)) {

  # In the current directory, find all the files that were output from
  # ChunkChromosome.  Store the basename of these files in @chunks.
  my @chunks = get_chunks($chr);

  my $numChunks = @chunks;
  print PIPELINE_LOG "  In chr$chr, found $numChunks chunks: @chunks\n";

  # Set the name for the vcf file. You may change this.
  my $vcf = "~/hsdfiles/groups/Projects\GWAS\Bangladesh\1KG_phase3v5".
  "reduced.ALL.chr22.phase3_shapeit2_mvncall_integrated_v5.20130502.genotypes.vcf";

  # Run minimac on each chunk, using multiple processes
  for my $chunk (@chunks) {
    wait_on_children() if ($currentNumThreads + 4 > $maxNumThreads);
    $currentNumThreads += 4;

    # Fork execution into parent and child processes.  fork() returns the
    # process ID of the child process to the parent; and '0' to the child.
    my $pid = fork();

    # If this is the parent process, store the process ID of the child in
    # @child_pids
    if ($pid > 0) {
      push(@child_pids, $pid);
    }

    # If this is a child process, execute mach
    elsif ($pid == 0) {
      my $command = "minimac-omp --cpus 4 --vcfReference --refHaps ${vcf}  ".
        "--haps ${chunk}.gz --snps ${chunk}.snps --rounds 5 ".
        "--states 200  --probs --autoClip autoChunk-chr${chr} --rs ".
        "--snpAliases dbsnp134-merges.txt.gz  --prefix ${chunk}_minimac 2>&1 ".
        "${chunk}_minimac.log &";
      print PIPELINE_LOG "  Executing '$command'\n";
      exec($command);
      exit 0;
    }

    # If $pid < 0, an error has occured.
    else {
      print PIPELINE_LOG "Error from mach_pipeline.pl: Forking error: $!\n";
      die "Error from mach_pipeline.pl: Forking error: $!\n"
    }
  }
}

# Important!  Wait for all children to finish at the end.
wait_on_children();

print PIPELINE_LOG "...finished minimac pipeline (part 2).\n";
close(PIPELINE_LOG);


#############################################################################
#                       Subroutines definitions                             #
#############################################################################

# This subroutine waits on the child processes in @child_pids to finish.
sub wait_on_children {
  for my $pid (@child_pids) {
    waitpid($pid, 0) ;
  }
  $currentNumThreads = 1;
  @child_pids = ();
}

# This subroutine gets the chunks from the working directory
sub get_chunks {
  my $chr = shift(@_);
  my @chunks = ();
  opendir(my $directory, $wd) or die "Can't read from directory: $!";
  for my $file (readdir($directory)) {
    if ($file =~ /^(chunk\d+-)$/) {
      push(@chunks, $1);
    }
  }
  closedir $directory;
  return @chunks;
}
