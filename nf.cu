#include "hello_world.h"
typedef struct firewallNode{
    uint8_t src_ip[4];
    uint8_t dst_ip[4];
    int mask[4];
}firewallNode;

firewallNode *blockIpsList;

__global__ void mac_swap_kernel(packet_hdrs *hst_hdrs, uint64_t size){
	int tid=threadIdx.x;
    int a=1;
	if(tid<size){
        uint8_t tmp[6];
        for(int k=0;k<100;k++)
            a++;
        memcpy(&tmp,&hst_hdrs[tid].ethHdr.src_address,6);
        memcpy(&hst_hdrs[tid].ethHdr.src_address,&hst_hdrs[tid].ethHdr.dst_address,6);
        memcpy(&hst_hdrs[tid].ethHdr.dst_address,&tmp,6);
	}
}

void gpu_kernel_call(packet_hdrs *dev_hdrs,uint64_t size){
    int numblocks=(size/32)+1;
    mac_swap_kernel<<<numblocks,32>>>(dev_hdrs, size);
}

void cpu_nf_call(packet_hdrs *pack_hdr)
{
    uint8_t tmp[6];
    int a=0;
    for(int k=0;k<100;k++)
            a++;
    memcpy(&tmp,pack_hdr->ethHdr.src_address,6);
    memcpy(pack_hdr->ethHdr.src_address,pack_hdr->ethHdr.dst_address,6);
    memcpy(pack_hdr->ethHdr.dst_address,&tmp,6);
}

void init()
{
    // File *fptr;
    // fptr = fopen ("blockList.txt","r");

 
}
