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

__global__ void mac_swap_kernel(GPUMbuf *packetStream, uint64_t size){
	int tid=threadIdx.x;
	if(tid<size){
		printf("GPU %d %lld %lld %lld \n", tid, packetStream[tid].pkt_len,  packetStream[tid].buf_addr,  packetStream[tid].phys_addr,  packetStream[tid].data_off);

	}
	//todo::actual macswap???
}

extern "C" {
void swap_mac_address(GPUMbuf **packetStream, uint64_t size){
    cudaError_t err = cudaSuccess;
    cudaDeviceReset();

 	err = cudaSetDeviceFlags(cudaDeviceMapHost);
	if (err != cudaSuccess){
		fprintf(stderr, "Failed to set flag %s)!\n", cudaGetErrorString(err));
		exit(EXIT_FAILURE);
	}

    err = cudaDeviceSynchronize();
	if (err != cudaSuccess){
		fprintf(stderr, "Failed to set flag %s)!\n", cudaGetErrorString(err));
		exit(EXIT_FAILURE);
	}

    GPUMbuf *dev_stream;
    GPUMbuf *stream;
   	err = cudaMallocHost((void**)&stream, size*sizeof(GPUMbuf)); 
	if (err != cudaSuccess){
		fprintf(stderr, "Failed cuda cudaHostAlloc(error code %s)!\n", cudaGetErrorString(err));
		exit(EXIT_FAILURE);
	}
	err = cudaHostGetDevicePointer( &dev_stream, stream, 0 );
	if (err != cudaSuccess){
		fprintf(stderr, "Failed cuda cudaHostGetDevicePointer(error code %s)!\n", cudaGetErrorString(err));
		exit(EXIT_FAILURE);
	}
	err=cudaThreadSynchronize();
	for (int i=0; i<size; i++) {
        stream[i]=*(packetStream[i]);
        printf("Outside GPU Size %d\n", stream[i].pkt_len);
        print_data(stream[i].buf_addr, stream[i].pkt_len);
    }

	mac_swap_kernel<<<1,size>>>(dev_stream, size);

    err = cudaGetLastError();
	if (err != cudaSuccess){
		fprintf(stderr, "Failed to launch vectorAdd kernel (error code %s)!\n", cudaGetErrorString(err));
		exit(EXIT_FAILURE);
	}

    err=cudaDeviceSynchronize();
	if (err != cudaSuccess){
		fprintf(stderr, "waitinf for cuda kernel fialed (error code %s)!\n", cudaGetErrorString(err));
		exit(EXIT_FAILURE);
	}
	for(int i=0;i<size;i++)
		*packetStream[i]=stream[i];

	cudaFreeHost( stream );
}

void print_data(uint8_t* buf_addr, uint32_t pkt_len){

        int i = 0;
        for( ; i < pkt_len; ++i )
            printf("inbuf %lld ", buf_addr[i]);

}

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



/*
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
        printf("The buff addr is %s\n", (char *)buf_addr);
        printf("The pkt_len size is %d\n", (*packet).pkt_len);
        printf("The buf_len size is %d\n", (*packet).buf_len);
        printf("The timestamp size is %lld\n", (*packet).timestamp);

        for(int i = 0; i < (*packet).pkt_len; i+=1) {
            printf("%c", (char) packet++);
        }
    }
}
*/
}

