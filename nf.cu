#include "hello_world.h"
#include <stdio.h>

typedef struct firewallNode{
    uint8_t src_ip[4];
    // uint8_t dst_ip[4];
    uint8_t mask;
}firewallNode;

firewallNode *hst_states;
firewallNode *dev_states;
int count_firewallNodes;
__global__ void mac_swap_kernel(packet_hdrs *hst_hdrs, uint64_t size,firewallNode *dev_states, int states_count){
	int tid=blockDim.x * blockIdx.x + threadIdx.x;
    int a=1;
    // printf("%d\n",tid );
    // if(tid==0)
    //     for(int i=0;i<states_count;i++)
    //         printf("%u.%u.%u.%u/%u\n", dev_states[i].src_ip[0],dev_states[i].src_ip[1],
    //             dev_states[i].src_ip[2],dev_states[i].src_ip[3],dev_states[i].mask);
	if(tid<size){

        // printf("gp::%d::%llu\n",tid,size );
        uint8_t tmp[6];
        
        for(int k=0;k<500;k++)
            a++;
        memcpy(&tmp,&hst_hdrs[tid].ethHdr.src_address,6);
        memcpy(&hst_hdrs[tid].ethHdr.src_address,&hst_hdrs[tid].ethHdr.dst_address,6);
        memcpy(&hst_hdrs[tid].ethHdr.dst_address,&tmp,6);
	}
}

void gpu_kernel_call(packet_hdrs *dev_hdrs,uint64_t size){
    int numblocks=(size/32)+1;
    // printf("here\n");
    // printf("hehre::%llu,%d\n",size,numblocks);
    mac_swap_kernel<<<numblocks,32>>>(dev_hdrs, size,dev_states,count_firewallNodes);
     // printf("hehre::%llu\n",size);
}

void cpu_nf_call(packet_hdrs *pack_hdr)
{
    uint8_t tmp[6];
    int a=0;
    for(int k=0;k<500;k++)
            a++;
    memcpy(&tmp,pack_hdr->ethHdr.src_address,6);
    memcpy(pack_hdr->ethHdr.src_address,pack_hdr->ethHdr.dst_address,6);
    memcpy(pack_hdr->ethHdr.dst_address,&tmp,6);
}

int init(firewallNode** hst_blockList)
{
    FILE *fptr;
    fptr = fopen ("blockList","r");
    fscanf(fptr,"%d\n",&count_firewallNodes) ;
    // printf("count found!! %d\n", count_firewallNodes);
    *hst_blockList=(firewallNode *)malloc(count_firewallNodes*sizeof(firewallNode));
    hst_states=*hst_blockList;
    for(int i=0;i<count_firewallNodes;i++)
    {
        fscanf(fptr,"%hhu.%hhu.%hhu.%hhu/%hhu\n",&hst_states[i].src_ip[0],&hst_states[i].src_ip[1],
            &hst_states[i].src_ip[2],&hst_states[i].src_ip[3],&hst_states[i].mask);
    }
    return count_firewallNodes;
}

void init_gpu_state(firewallNode* dev_blockList)
{
    dev_states=dev_blockList;

}
