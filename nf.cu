#include "hello_world.h"

__global__ void mac_swap_kernel(packet_hdrs *hst_hdrs, uint64_t size){
	int tid=threadIdx.x;
	if(tid<size){
        uint8_t tmp[6];
        memcpy(&tmp,&hst_hdrs[tid].ethHdr.src_address,6);
        memcpy(&hst_hdrs[tid].ethHdr.src_address,&hst_hdrs[tid].ethHdr.dst_address,6);
        memcpy(&hst_hdrs[tid].ethHdr.dst_address,&tmp,6);
	}
}

void gpu_kernel_call(packet_hdrs *dev_hdrs,uint64_t size){
    mac_swap_kernel<<<1,size>>>(dev_hdrs, size);
}

void cpu_nf_call(packet_hdrs *pack_hdr)
{
    uint8_t tmp[6];
        // for(int j=0;j<6;j++)
        //     printf("%02x::",(*pck_hdrs).ethHdr.src_address[j] );
        // printf("\n");
    memcpy(&tmp,pack_hdr->ethHdr.src_address,6);
    memcpy(pack_hdr->ethHdr.src_address,pack_hdr->ethHdr.dst_address,6);
    memcpy(pack_hdr->ethHdr.dst_address,&tmp,6);
}
