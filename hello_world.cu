#include <cuda.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>

typedef struct _packet_{
    char src_address[6];
    char dst_address[6];
    char data[300];
} packet;


packet create_packet() {
    packet p;
    for(int i = 0; i < 5; i+=1) {
        char srch = (rand()%26) + 65;
        char dstch = (rand()%26) + 65;

        p.src_address[i] = srch;
        p.dst_address[i] = dstch;
    }

    p.src_address[5] = '\0';
    p.dst_address[5] = '\0';

    for(int i = 0; i < 100; i+=1) {
        char data = (rand()%26) + 65;
        p.data[i] = data;
    }

    return p;
}

__global__ void VecAdd(packet *A, int n) {
    
    int tx = threadIdx.x, ty = threadIdx.y;

    int I = blockIdx.y*blockDim.y + ty;
    int J = blockIdx.x*blockDim.x + tx;

    int i = I*n + J;

    if( i < n) { 
        for(int j = 0; j < 5; j+=1) {
            A[i].src_address[j] = 'a';
            A[i].dst_address[j] = 'b';
        }
    }
}

extern "C" {
void garble_packet() {

    packet packets[100];
    for(int i = 0; i < 100; i+=1) {
        packets[i] = create_packet();
    }

    int size = 100*sizeof(packet);

    packet *a;
    cudaMalloc((void **)&a, size);

    cudaMemcpy(a, packets, size, cudaMemcpyHostToDevice);
    cudaThreadSynchronize();

    VecAdd<<<10, 10>>> (a, 100);

    cudaThreadSynchronize();
    cudaMemcpy(packets, a, size, cudaMemcpyDeviceToHost);
    cudaFree(a);

    for(int i = 0; i < 100; i+=1) 
        printf("%s : %s \n", packets[i].src_address, packets[i].dst_address);
}
}
