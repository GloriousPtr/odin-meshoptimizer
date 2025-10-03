clang -O3 -march=haswell -mavx2 -mfma -c main.cpp -o meshopt.obj
lib /OUT:meshopt.lib meshopt.obj
del meshopt.obj
PAUSE