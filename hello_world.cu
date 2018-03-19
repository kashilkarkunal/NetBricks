#include <cuda.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
// #include "hello_world.h"
#include <arpa/inet.h>
#include<pthread.h>
#include "nf.cu"



typedef struct pthread_struct {
    GPUMbuf **packetStream;
    uint64_t size;
} pthread_struct;

packet_hdrs *packet_hdr_ptr(GPUMbuf **packetStream,int i){
    GPUMbuf *mbuf= packetStream[i];
    // printf("%d\n", (*mbuf).pkt_len);
    packet_hdrs *buf=(packet_hdrs *)((*mbuf).buf_addr+(*mbuf).data_off);
    return buf;
}



void *cpu_nf_caller_call(void *arg){
    pthread_struct *args=(pthread_struct *)arg;
    GPUMbuf **packetStream=args->packetStream;
    uint64_t size=args->size;
    for(int i=0;i<size;i++){
        packet_hdrs *pck_hdrs=packet_hdr_ptr(packetStream,i);
        cpu_nf_call(pck_hdrs);
    }
    return NULL;
}




extern "C" {
void swap_mac_address(GPUMbuf **packetStream, uint64_t size){
    cudaError_t err = cudaSuccess;
    cudaDeviceReset();
    packet_hdrs hst_hdrs[size];
    packet_hdrs* dev_hdrs;

    pthread_t my_thread;
    pthread_struct pthread_Args;
    pthread_Args.packetStream=packetStream;
    pthread_Args.size=size;

    pthread_create(&my_thread, NULL, cpu_nf_caller_call, &pthread_Args); 
    pthread_join(my_thread, NULL);
    // cpu_nf_caller_call(packetStream,size);
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

    // gpu_kernel_call(dev_hdrs, size);
    
    
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
}

}

