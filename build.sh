#!/bin/bash
clang -O3 -march=haswell -mavx2 -mfma -c main.cpp -o meshopt.o
ar rcs meshopt.a meshopt.o
rm meshopt.o
read -p "Press enter to continue..."
