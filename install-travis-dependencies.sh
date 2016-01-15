#!/bin/bash

cpanm Dist::Zilla

git clone https://github.com/sanger-pathogens/Bio-Track-Schema.git
git clone https://github.com/sanger-pathogens/Bio-Sequencescape-Schema.git

cd Bio-Track-Schema
dzil authordeps --missing | cpanm
dzil listdeps --missing | cpanm
dzil install

cd ../Bio-Sequencescape-Schema
dzil authordeps --missing | cpanm
dzil listdeps --missing | cpanm
dzil install

