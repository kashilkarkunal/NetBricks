#include <cuda.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "hello_world.h"

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
void garble_packet(packet packets[], int num) {


    printf("Starting Cuda Program %d \n", num);
    int size = num*sizeof(packet);

    packet *a;
    cudaMalloc((void **)&a, size);

    cudaMemcpy(a, packets, size, cudaMemcpyHostToDevice);
    cudaThreadSynchronize();

    VecAdd<<<num/10, 10>>> (a, num);

    cudaThreadSynchronize();
    cudaMemcpy(packets, a, size, cudaMemcpyDeviceToHost);
    cudaFree(a);

    for(int i = 0; i < num; i+=1) 
        printf("%s : %s \n", packets[i].src_address, packets[i].dst_address);
}

void swap_mac_address(GPUMbuf **packets, uint64_t size) {
    if(packets == NULL) {
        printf("Packets are null");
        return;
    }
    for(int i = 0; i < size; i+=1) {
        GPUMbuf *packet = packets[i];
        if(packet == NULL) {
            printf("Packet is null inside loop\n");
            continue;
        }
        uint8_t *buf_addr = (*packet).buf_addr;
        printf("The pool size is %s\n", buf_addr);
        printf("The pkt_len size is %d\n", (*packet).pkt_len);
        printf("The buf_len size is %d\n", (*packet).buf_len);
        printf("The pkt_len size is %lld\n", (*packet).timestamp);
    }
}
}

