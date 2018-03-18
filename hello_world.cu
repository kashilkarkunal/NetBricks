#include <cuda.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
// #include "hello_world.h"
#include <arpa/inet.h>
#include<pthread.h>
#include "nf.cu"


packet_hdrs *packet_hdr_ptr(GPUMbuf **packetStream,int i){
    GPUMbuf *mbuf= packetStream[i];
    // printf("%d\n", (*mbuf).pkt_len);
    packet_hdrs *buf=(packet_hdrs *)((*mbuf).buf_addr+(*mbuf).data_off);
    return buf;
}



void cpu_nf_caller_call(GPUMbuf **packetStream,uint64_t size){
    for(int i=0;i<size;i++){
        packet_hdrs *pck_hdrs=packet_hdr_ptr(packetStream,i);
        cpu_nf_call(pck_hdrs);
        // uint8_t tmp[6];
        // // for(int j=0;j<6;j++)
        // //     printf("%02x::",(*pck_hdrs).ethHdr.src_address[j] );
        // // printf("\n");
        // memcpy(&tmp,pck_hdrs->ethHdr.src_address,6);
        // memcpy(pck_hdrs->ethHdr.src_address,pck_hdrs->ethHdr.dst_address,6);
        // memcpy(pck_hdrs->ethHdr.dst_address,&tmp,6);

    }
}




extern "C" {
void swap_mac_address(GPUMbuf **packetStream, uint64_t size){
    cudaError_t err = cudaSuccess;
    cudaDeviceReset();
    packet_hdrs hst_hdrs[size];
    packet_hdrs* dev_hdrs;
    cpu_nf_caller_call(packetStream,size);
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

}

