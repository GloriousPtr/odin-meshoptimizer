cl /Ox /arch:AVX /c main.cpp -Fomeshopt
lib /OUT:meshopt.lib meshopt.obj
del meshopt.obj
PAUSE