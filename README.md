# MaCh and minimac imputation

Scripts for imputing 1000 Genomes data using MaCh and minimac.

## mach\_pipeline.pl

This pipeline imputes chromosomes in chunks and processes multiple chunks in
parallel (using multiple processes for MaCH/minimac, as well as multiple
threads for minimac).  It is based on a tcsh script from the University of
Michigan Center of Statistical Genetics ([source](http://genome.sph.umich.edu/wiki/Minimac:_1000_Genomes_Imputation_Cookbook#Target_based_chunking)).
