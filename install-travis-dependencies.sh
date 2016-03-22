#!/bin/bash

start_dir=$(pwd)

cpanm Dist::Zilla --notest

git clone https://github.com/sanger-pathogens/Bio-Metagenomics.git
git clone https://github.com/sanger-pathogens/Bio-Track-Schema.git
git clone https://github.com/sanger-pathogens/Bio-Sequencescape-Schema.git

cd Bio-Metagenomics
mkdir -p build/fake_bin && cd build/fake_bin
touch kraken kraken-build kraken-report merge_metaphlan_tables.py metaphlan_hclust_heatmap.py
chmod u+x $(ls) && export PATH=$(pwd):$PATH
cd ../..
dzil authordeps --missing | cpanm --notest
dzil listdeps --missing | cpanm --notest
dzil install

cd ../Bio-Track-Schema
dzil authordeps --missing | cpanm --notest
dzil listdeps --missing | cpanm --notest
dzil install

cd ../Bio-Sequencescape-Schema
dzil authordeps --missing | cpanm --notest
dzil listdeps --missing | cpanm --notest
dzil install

cd $start_dir
dzil authordeps --missing | cpanm --notest
dzil listdeps --missing | cpanm --notest

