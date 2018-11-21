# Bio-Path-Find
A tool for finding information about pathogen sequencing runs.

[![Build Status](https://travis-ci.org/sanger-pathogens/Bio-Path-Find.svg?branch=master)](https://travis-ci.org/sanger-pathogens/Bio-Path-Find)    
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-brightgreen.svg)](https://github.com/sanger-pathogens/Bio-Path-Find/blob/master/software-license)   

## Contents
  * [Introduction](#introduction)
  * [Installation](#installation)
    * [Required dependencies](#required-dependencies)
    * [From Source](#from-source)
    * [Running the tests](#running-the-tests)
  * [Usage](#usage)
  * [License](#license)
  * [Feedback/Issues](#feedbackissues)
  * [Further Information](#further-information)

## Introduction
These scripts can be used for accessing the results of the pathogen informatics analysis pipelines.

## Installation
Bio-Path-find has the following dependencies:

### Required dependencies
* [Bio-Metagenomics](https://github.com/sanger-pathogens/Bio-Metagenomics)
* [Bio-Track-Schema](https://github.com/sanger-pathogens/Bio-Track-Schema)
* [Bio-Sequencescape-Schema](https://github.com/sanger-pathogens/Bio-Sequencescape-Schema)

Details for installing Bio-Path-Find are provided below. If you encounter an issue when installing Bio-Path-Find please contact your local system administrator. If you encounter a bug please log it [here](https://github.com/sanger-pathogens/Bio-Path-Find/issues) or email us at path-help@sanger.ac.uk.

### From Source
Clone the repository:   
   
`git clone https://github.com/sanger-pathogens/Bio-Path-Find.git`   
   
Move into the directory and install all dependencies using [DistZilla](http://dzil.org/):   
  
```
cd Bio-Path-Find
dzil authordeps --missing | cpanm
dzil listdeps --missing | cpanm
```
  
Run the tests:   
  
`dzil test`   
If the tests pass, install Bio-Path-Find:   
  
`dzil install`   

### Running the tests
The test can be run with dzil from the top level directory:  
  
`dzil test`  

## Usage
```
usage:
      pf <command> --id <ID or file> --type <ID type> [options]

description:
    The pathfind commands find and display various kinds of information about
    sequencing projects.

    Run "pf man" to see full documentation for this main "pf" command. Run "pf
    man <command>" or "pf <command> --help" to see documentation for a
    particular sub-command.

global options:
    --csv-separator -c          field separator to use when writing CSV files
                                [Default:","; Env: PF_CSV_SEP]
    --file-id-type --ft         type of IDs in the input file [Default:"lane"
                                ; Possible values: lane, library, sample,
                                species, study]
    --force -F                  force commands to overwrite existing files [
                                Flag; Env: PF_FORCE_OVERWRITE]
    --help -h --usage -?        Prints this usage information. [Flag]
    --id -i                     ID or name of file containing IDs [Required;
                                Env: PF_ID]
    --ignore-processed-flag -I  ignore "processed" flag when finding lanes [
                                Flag]
    --no-progress-bars -N       don't show progress bars [Flag; Env: PF_NO_
                                PROGRESS_BARS]
    --rename -r                 replace hash (#) with underscore (_) in
                                filenames [Flag]
    --type -t                   ID type. Use "file" to read IDs from file [
                                Required; Possible values: database, file,
                                lane, library, sample, species, study; Env:
                                PF_TYPE]
    --verbose -v                show debugging messages [Default:"0"; Integer
                                ; Env: PF_VERBOSE]

available commands:
    accession        Find accessions for sequencing runs
    annotation       Find annotation results
    assembly         Find genome assemblies
    bash_completion  Bash completion automator
    data             Find files and directories
    help             Prints this usage information
    info             Find information about samples
    man              Full manpage
    map              Find mapped bam files for lanes
    qc               Find quality control information about samples
    ref              Find reference genomes
    rnaseq           Find RNA-Seq results
    snp              Find VCF files for lanes
    status           Find the status of samples
    supplementary    Get supplementary information about samples
```
## License
Bio-Path-Find is free software, licensed under [GPLv3](https://github.com/sanger-pathogens/Bio-Path-Find/blob/master/software-license).

## Feedback/Issues
Please report any issues to the [issues page](https://github.com/sanger-pathogens/Bio-Path-Find/issues) or email path-help@sanger.ac.uk

## Further Information 
Sanger Institute staff should refer to the [wiki](http://mediawiki.internal.sanger.ac.uk/index.php/Pathogen_Informatics_Command_Line_Scripts) for further information.