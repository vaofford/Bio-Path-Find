#!/bin/bash

cpanm Dist::Zilla --notest

git clone https://github.com/sanger-pathogens/Bio-Track-Schema.git
git clone https://github.com/sanger-pathogens/Bio-Sequencescape-Schema.git

cd Bio-Track-Schema
dzil authordeps --missing | cpanm --notest
dzil listdeps --missing | cpanm --notest
dzil install

cd ../Bio-Sequencescape-Schema
dzil authordeps --missing | cpanm --notest
dzil listdeps --missing | cpanm --notest
dzil install

