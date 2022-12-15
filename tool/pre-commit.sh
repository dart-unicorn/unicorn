#!/bin/bash

ROOT_DIR=${0%/*/*}

PACKAGES=("unicorn" "unicorn_codegen")

for PACKAGE in "${PACKAGES[@]}"; do
  cd $ROOT_DIR/packages/$PACKAGE
  dart analyze
  dart test
done