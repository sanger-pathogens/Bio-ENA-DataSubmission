#!/usr/bin/env bash
find . -name 'receipt*.xml' -print0 | xargs -0 grep 'ANALYSIS' | sed 's/^.*\s\+<ANALYSIS accession="\(\w\+\)" alias="webin-\w\+-\([^"]\+\)".*$/\2,\1/'
