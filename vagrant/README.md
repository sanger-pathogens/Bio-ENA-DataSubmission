# Bio-ENA-DataSubmission vagrant build
Instruction to build Bio-ENA-DataSubmission under vagrant.   

## Contents
  * [Setup](#Setup)
  * [Build](#Build)

## Setup
   * Create a working directory somewhere.
   * Download the following repos in the working directory
      * git clone https://github.com/sanger-pathogens/vr-codebase
      * git clone https://github.com/sanger-pathogens/PathFind
      * git clone https://github.com/sanger-pathogens/Bio-ENA-DataSubmission
   * Copy the following files in the working directory
      * Vagrantfile
      * .profile
   * vagrant up
   
## Build
   * vagrant ssh
   * cd /vagrant/Bio-ENA-DataSubmission
   * dzil test   
