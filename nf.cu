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
	if(tid<size){
        uint8_t tmp_dst[4];
        uint8_t shouldBlock = 0;
        for(int i = 0; i < states_count; i+=1) {
            memcpy(&tmp_dst, &hst_hdrs[tid].ipHdr.dst_ip, sizeof(uint8_t)*4);
            int mask = dev_states[i].mask;
            uint8_t mask_bits[4];
            for(int j = 0; j < mask/8; j+=1) {
                mask_bits[j] = 255;
            }
            if(mask%8 != 0) {
                int bit = mask/8;
                int mask_val = 0;
                for(int j = 0; j < mask%8; j+=1) {
                    mask_val+=(1<<(8-j));
                }
                mask_bits[bit] = mask_val;
            }

            for(int j = 0; j < 4; j+=1) {
                tmp_dst[j]&=mask_bits[j];
            }

            uint8_t matchesIp = 1;
            for(int j = 0; j < 4; j+=1) {
                if(tmp_dst[j] != dev_states[i].src_ip[j])
                    matchesIp = 0;
            }
            if(matchesIp) {
                shouldBlock = 1;
            }
        }
	}
}

void gpu_kernel_call(packet_hdrs *dev_hdrs,uint64_t size){
    int numblocks=(size/32)+1;
     printf("here\n");
    // printf("hehre::%llu,%d\n",size,numblocks);
    mac_swap_kernel<<<numblocks,32>>>(dev_hdrs, size,dev_states,count_firewallNodes);
     // printf("hehre::%llu\n",size);
}

void cpu_nf_call(packet_hdrs *pack_hdr)
{
    uint8_t tmp_dst[4];
    uint8_t shouldBlock = 0;
    for(int i = 0; i < count_firewallNodes; i+=1) {
        memcpy(&tmp_dst, pack_hdr->ipHdr.dst_ip, sizeof(uint8_t)*4);
        int mask = hst_states[i].mask;
        uint8_t mask_bits[4];
        for(int j = 0; j < mask/8; j+=1) {
            mask_bits[j] = 255;
        }
        if(mask%8 != 0) {
            int bit = mask/8;
            int mask_val = 0;
            for(int j = 0; j < mask%8; j+=1) {
                mask_val+=(1<<(8-j));
            }
            mask_bits[bit] = mask_val;
        }

        for(int j = 0; j < 4; j+=1) {
            tmp_dst[j]&=mask_bits[j];
        }

        uint8_t matchesIp = 1;
        for(int j = 0; j < 4; j+=1) {
            if(tmp_dst[j] != hst_states[i].src_ip[j])
                matchesIp = 0;
        }
        if(matchesIp) {
            shouldBlock = 1;
        }
    }
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
