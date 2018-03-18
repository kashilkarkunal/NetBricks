#include <cuda.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "hello_world.h"
#include <arpa/inet.h>


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

__global__ void mac_swap_kernel(packet_hdrs *hst_hdrs, uint64_t size){
	int tid=threadIdx.x;
	if(tid<size)
    {
  //       printf("GPU::");
		// // printf("GPU DATA %d %lld %lld %lld \n", tid, packetStream[tid].pkt_len,  packetStream[tid].buf_addr,  packetStream[tid].phys_addr,  packetStream[tid].data_off);
  //       for(int j=0;j<6;j++)
  //           printf("%02x::", hst_hdrs[tid].ethHdr.dst_address[j]);
  //       printf("<---->");
  //       for(int j=0;j<6;j++)
  //           printf("%02x::", hst_hdrs[tid].ethHdr.src_address[j]);
  //       printf("\n");
        for(int i=0;i<6;i++)
        {
            uint8_t tmp=hst_hdrs[tid].ethHdr.src_address[i];
            hst_hdrs[tid].ethHdr.src_address[i]=hst_hdrs[tid].ethHdr.dst_address[i];
            hst_hdrs[tid].ethHdr.dst_address[i]=tmp;
        }
	}
	//todo::actual macswap???
}

extern "C" {
void swap_mac_address(GPUMbuf **packetStream, uint64_t size){
    cudaError_t err = cudaSuccess;
    cudaDeviceReset();
    packet_hdrs hst_hdrs[size];
    packet_hdrs* dev_hdrs;
    for(int i=0;i<size;i++)
    {
        GPUMbuf mbuf=*(packetStream[i]);
        uint8_t* buf=mbuf.buf_addr+mbuf.data_off;
        memcpy((uint8_t*)&hst_hdrs[i],buf,sizeof(packet_hdrs));
        // for(int j=0;j<6;j++)
        //     printf("%02x::", hst_hdrs[i].ethHdr.dst_address[j]);
        // printf("<---->");
        // for(int j=0;j<6;j++)
        //     printf("%02x::", hst_hdrs[i].ethHdr.src_address[j]);
        // printf("\n");
        // struct in_addr ip_addr;
        // ip_addr.s_addr=;
        //  memcpy(&ip_addr.s_addr, &hst_hdrs[i].ipHdr.src_ip, 4);
        // printf("\nThe src IP address is %s\n", inet_ntoa(ip_addr));
        // memcpy(&ip_addr.s_addr, &hst_hdrs[i].ipHdr.dst_ip, 4);
        // printf("\nThe src IP address is %s\n", inet_ntoa(ip_addr));
    }
    size_t size_dev_hdrs=size*sizeof(packet_hdrs);
    err = cudaMalloc((void **)&dev_hdrs, size_dev_hdrs);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to allocate device vector (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
    err = cudaMemcpy(dev_hdrs, hst_hdrs,size_dev_hdrs, cudaMemcpyHostToDevice);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to copy to GPU device (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
    err=cudaDeviceSynchronize();

    mac_swap_kernel<<<1,size>>>(dev_hdrs, size);
    
    err=cudaDeviceSynchronize();
    err = cudaGetLastError();
    if (err != cudaSuccess){
        fprintf(stderr, "Failed to launch mac_swap_kernel kernel (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaMemcpy(hst_hdrs, dev_hdrs, size_dev_hdrs, cudaMemcpyDeviceToHost);
    if (err != cudaSuccess){
         fprintf(stderr, "Failed to copy vectorC from device to host (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

     for(int i=0;i<size;i++)
    {
        GPUMbuf mbuf=*(packetStream[i]);
        uint8_t* buf=mbuf.buf_addr+mbuf.data_off;
        // memcpy((uint8_t*)&hst_hdrs[i],buf,sizeof(packet_hdrs));
        memcpy(buf,(uint8_t*)&hst_hdrs[i],sizeof(packet_hdrs));
    }

 // 	err = cudaSetDeviceFlags(cudaDeviceMapHost);
	// if (err != cudaSuccess){
	// 	fprintf(stderr, "Failed to set flag %s)!\n", cudaGetErrorString(err));
	// 	exit(EXIT_FAILURE);
	// }

 //    err = cudaDeviceSynchronize();
	// if (err != cudaSuccess){
	// 	fprintf(stderr, "Failed to set flag %s)!\n", cudaGetErrorString(err));
	// 	exit(EXIT_FAILURE);
	// }

    // GPUMbuf *dev_stream;
    
	// if (err != cudaSuccess){
	// 	fprintf(stderr, "Failed cuda cudaHostAlloc(error code %s)!\n", cudaGetErrorString(err));
	// 	exit(EXIT_FAILURE);
	// }
	// err = cudaHostGetDevicePointer( &dev_stream, stream, 0 );
	// if (err != cudaSuccess){
	// 	fprintf(stderr, "Failed cuda cudaHostGetDevicePointer(error code %s)!\n", cudaGetErrorString(err));
	// 	exit(EXIT_FAILURE);
	// }
	// err=cudaThreadSynchronize();
    
    /*
    GPUMbuf *stream;
    cudaMallocHost((void**)&stream, size*sizeof(GPUMbuf)); 
	for (int i=0; i<size; i++) {
        stream[i]=*(packetStream[i]);
        printf("Outside GPU Size %d::%d::%d\n", stream[i].pkt_len,stream[i].data_len, stream[i].sync);
        int buff_dat = stream[i].data_off;
        for( ; buff_dat < stream[i].data_off+6; ++buff_dat )
            printf("%2x::", stream[i].buf_addr[buff_dat]);
        printf("<------->");
        for( ; buff_dat < stream[i].data_off+12; ++buff_dat )
            printf("%02x::", stream[i].buf_addr[buff_dat]);
        printf("==========");
        for( ; buff_dat < stream[i].data_off+14; ++buff_dat )
            printf("%02x::", stream[i].buf_addr[buff_dat]);
        struct in_addr ip_addr;
        // ip_addr.s_addr = *((int*)(stream[i].buf_addr+buff_dat+3*4));
        memcpy(&ip_addr.s_addr, stream[i].buf_addr+buff_dat+3*4, 4);
        printf("\nThe src IP address is %s\n", inet_ntoa(ip_addr));
        memcpy(&ip_addr.s_addr, stream[i].buf_addr+buff_dat+4*4, 4);
        printf("The dst IP address is %s\n", inet_ntoa(ip_addr));

        printf("----%d::", stream[i].buf_addr[buff_dat+1]);
        printf("\n");
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
    */
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

