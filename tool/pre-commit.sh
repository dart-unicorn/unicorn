#!/bin/bash

ROOT_DIR=${0%/*/*}
PACKAGES_DIR=$ROOT_DIR/packages

PACKAGES=$(find $PACKAGES_DIR -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

echo $PACKAGES

for package in $PACKAGES; do
  cd $ROOT_DIR/packages/$package
  dart analyze
  dart test
done