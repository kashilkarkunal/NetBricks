#!/bin/bash

nvcc  -Xcompiler -fPIC -rdc=true -c -o temp.o hello_world.cu
nvcc -Xcompiler -fPIC -dlink -o hello_world.o temp.o -lcudart
rm -f libgpu.a
ar cru libgpu.a hello_world.o temp.o
