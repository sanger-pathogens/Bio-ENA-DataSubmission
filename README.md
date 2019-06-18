# Bio-ENA-DataSubmission
Scripts for submitting data to the ENA.   
[![Build Status](https://travis-ci.org/sanger-pathogens/Bio-ENA-DataSubmission.svg?branch=master)](https://travis-ci.org/sanger-pathogens/Bio-ENA-DataSubmission)  
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-brightgreen.svg)](https://github.com/sanger-pathogens/Bio-ENA-DataSubmission/blob/master/GPL-LICENCE)    
[![codecov](https://codecov.io/gh/sanger-pathogens/Bio-ENA-DataSubmission/branch/master/graph/badge.svg)](https://codecov.io/gh/sanger-pathogens/Bio-ENA-DataSubmission) 
## Contents
  * [Introduction](#introduction)
  * [Installation](#installation)
    * [Required dependencies](#required-dependencies)
    * [From Source](#from-source)
    * [Running the tests](#running-the-tests)
  * [Usage](#usage)
    * [generate\_sample\_manifest](#generate_sample_manifest)
    * [validate\_sample\_manifest](#validate_sample_manifest)
    * [compare\_sample\_metadata](#compare_sample_metadata)
    * [update\_sample\_metadata](#update_sample_metadata)
    * [generate\_analysis\_manifest](#generate_analysis_manifest)
    * [submit\_analysis\_objects](#submit_analysis_objects)
    * [validate\_embl](#validate_embl)
  * [Development using vagrant](#Development using vagrant)
  * [License](#license)
  * [Feedback/Issues](#feedbackissues)

## Introduction
Bio-ENA-DataSubmission provides tools for generating, validating and submitting manifests to the ENA. The following scripts are included:

* **generate_sample_manifest**    Generate a sample manifest for preparation of sample metadata updates at ENA
* **validate_sample_manifest**    Validate the sample manifest and check that all compulsory fields are filled out, the formatting, and that the taxon ID and species name match up
* **compare_sample_metadata**    Compare sample manifest to the existing data on the ENA public records
* **update_sample_metadata**    Convert the sample manifest to an xml file and send it to datahose to submit to ENA
* **generate_analysis_manifest**    Generate an analysis manifest for preparation of genome assemblies to the ENA
* **submit_analysis_objects**    Submit genome assemblies or annotated assemblies to the ENA
* **validate_embl**    Run the ENA EMBL validator to check for issues with the EMBL file before submission

## Installation
Bio-ENA-DataSubmission has the following dependencies:

### Required dependencies
* [vr-codebase](https://github.com/sanger-pathogens/vr-codebase)

Details for installing Bio-ENA-DataSubmission are provided below. If you encounter an issue when installing Bio-ENA-DataSubmission please contact your local system administrator. If you encounter a bug please log it [here](https://github.com/sanger-pathogens/Bio-ENA-DataSubmission/issues) or email us at path-help@sanger.ac.uk.

### From Source
Clone the repository:   
   
`git clone https://github.com/sanger-pathogens/Bio-ENA-DataSubmission.git`   
   
Move into the directory and install all dependencies using [DistZilla](http://dzil.org/):   
  
```
cd Bio-ENA-DataSubmission
dzil authordeps --missing | cpanm
dzil listdeps --missing | grep -v 'VRTrack::Lane' | cpanm
```
  
Run the tests:   
  
`dzil test`   
If the tests pass, install Bio-ENA-DataSubmission:   
  
`dzil install`   

### Running the tests
The test can be run with dzil from the top level directory:  
  
`dzil test`  

### Running end to end tests (requires database and correct directory structure
To enable the end 2 end tests, set the environment variable ```ENA_SUBMISSIONS_E2E``` to anything. Then run

`dzil test`

### Prerequisite
  * Java needs to be installed to run webin cli
  * environment variable ```ENA_SUBMISSIONS_WEBIN_CLI``` should point to the webin cli jar
  * environment variable ```ENA_SUBMISSIONS_CONFIG``` should point to the general configuration of ena submissions
  * environment variable ```ENA_SUBMISSIONS_DATA``` should point to the folder containing
    * SRA.common.xsd
    * embl-client.jar
    * sample.xsd
    * submission.xml
    * submission.xsd
    * valid_countries.txt


### Containers
If running in a container, java and webin cli will be setup as well as ENA_SUBMISSIONS_WEBIN_CLI.

## Usage
The following scripts are included in Bio-ENA-DataSubmission.

### generate_sample_manifest
```
Usage: generate_sample_manifest [options]

  -t|type          lane|study|file|sample
  --file_id_type   lane|sample  define ID types contained in file. default = lane
  -i|id            lane ID|study ID|file of lane IDs|file of sample accessions|sample ID
  --empty          generate empty manifest
  -o|outfile       path for output manifest
  -h|help          this help message

  When supplying a file of sample IDs ("-t file --file_id_type sample"), the IDs should
  be ERS numbers (e.g. "ERS123456"), not sample accessions.
```
### validate_sample_manifest
```
Usage: validate_sample_manifest [options]

    -f|file       input manifest for validation
    -r|report     output path for validation report
    --edit        create additional manifest with mistakes fixed (where possible)
    -o|outfile    output path for edited manifest
    -h|help       this help message
```
### compare_sample_metadata
```
Usage: validate_sample_manifest [options]

    -f|file       input manifest for comparison
    -o|outfile    output path for comparison report
    -h|help       this help message
```
### update_sample_metadata
```
Usage: update_sample_manifest [options]

    -f|file       input manifest for update
    -o|outfile    output path for validation report
    --no_validate skip validation step (for cases where validation has already been done)
    -h|help       this help message
```
### generate_analysis_manifest
```
Usage: generate_analysis_manifest [options]

    -t|type          lane|study|file|sample
    -i|id            lane ID|study ID|file of lanes|file of samples|sample ID
    -o|outfile       path for output manifest
    --empty          generate empty manifest
    -p|pubmed_id     pubmed ID associated with analysis
    -a|file_type     [assembly|annotation] defaults to assembly
    -h|help          this help message
```
### submit_analysis_objects
This script does not work anymore due to changes in the interface at ENA
```
Usage: submit_analysis_objects [options] -f manifest.xls

    -f|file        Input file in .xls format (required)
    -a|action      Add a new or modify an existing assembly (ADD|MODIFY) [ADD]
    -o|outfile     Output file for report ( .xls format )
    -t|type        Type of assembly [sequence_assembly]
    --no_validate  Do not run manifest validation step [FALSE]
    -p|processors  Number of threads to use [1]
    -h|help        This help message
```
### submit_analysis_objects_via_cli.pl
```
Usage: submit_analysis_objects_via_cli.pl [options] -f manifest.xls

	-f|file        Excel spreadsheet manifest file (required)
	-o|output_dir  Base output directory. A subdirectory within that will be created for the submission (required)
	-c|context     Submission context ( one of genome, transcriptome, sequence, reads. Default: genome)
	--no_validate  Do not run validation step
	--no_submit    Do not run submit step
	--test         Use the ENA test submission service
	-h|help        This help message    
    
    
```
### validate_embl 
This script is not longer required as embl validation is performed while submitting using submit_analysis_objects_via_cli.pl
```
Usage: validate_embl [options] embl_files
    -h|help        This help message
```
## Development using vagrant
Follow instructions [here](vagrant/README.md)

## Building with docker:
To build the docker immage:
```docker build -t ena-submissions:latest --build-arg TAG=<tag or branch to use> .```

## Building the singularity image using local docker repo
Run your own local repository:
```sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2```
To tag the local registry:
```sudo docker tag ena-submissions localhost:5000/ena-submissions```
To push the docker image to the repo
```sudo docker push localhost:5000/ena-submissions```
To build the singularity image
```sudo SINGULARITY_NOHTTPS=1 singularity build ena-submissions.simg sing.recipe```
If you wished to run the docker container:
```sudo docker run --rm -it ena-submissions:latest```

## Docker House keeping
  * List images: ```sudo docker images```
  * List containers: ```sudo docker ps -a```
  * Delete images: ```sudo docker rmi <image_ids>```
  * Delete containers: ```sudo docker rm <container_ids>```
  * Stop registry: ```sudo docker container stop registry```
  * Delete registry: ```sudo docker container rm -v registry```


## License
Bio-ENA-DataSubmission is free software, licensed under [GPLv3](https://github.com/sanger-pathogens/Bio-ENA-DataSubmission/blob/master/GPL-LICENCE).

## Feedback/Issues
Please report any issues to the [issues page](https://github.com/sanger-pathogens/Bio-ENA-DataSubmission/issues) or email path-help@sanger.ac.uk.
