#!/bin/env sh

appDir=$(dirname $0)
appName="metamor"

cd $appDir
gio trash \
    dub.selections.json \
    $appName \
    $appName.exe \
    $appName.pdb
