#include <cuda.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
// #include "hello_world.h"
#include <arpa/inet.h>
#include<pthread.h>
#include "nf.cu"

#define timeIO 1
#define RunLevel 3

int kunal=5678;
int Cpu_BatchSize=100;
// int GPU_BatchSize;
int max_size=512;
packet_hdrs *hst_hdrs;
packet_hdrs* dev_hdrs;
int first=0;
cudaError_t err = cudaSuccess; 
size_t size_dev_hdrs;


unsigned long long diff(unsigned lo1,unsigned hi1, unsigned lo2, unsigned hi2)
{
    unsigned long long int a=( (unsigned long long)lo1)|( ((unsigned long long)hi1)<<32 );
    unsigned long long int b=( (unsigned long long)lo2)|( ((unsigned long long)hi2)<<32 );
    return b-a;
}

typedef struct timer_struct{
    unsigned cpu_hi1,cpu_hi2,cpu_lo1,cpu_lo2;
    unsigned gpu_mem_hi1,gpu_mem_hi2,gpu_mem_lo1,gpu_mem_lo2;
    unsigned gpu_hi1,gpu_hi2,gpu_lo1,gpu_lo2;
} timer_struct;

timer_struct timers;

//the time measurement code was inspired from https://www.mcs.anl.gov/~kazutomo/rdtsc.html



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

void GPU_startTime()
{
    asm volatile (
      "rdtsc\n\t"
      "mov %%edx, %0\n\t"
      "mov %%eax, %1\n\t"
      : "=r" (timers.gpu_hi1), "=r" (timers.gpu_lo1)
      :: "%rax", "%rbx", "%rcx", "%rdx");

}

void GPU_endTime()
{
  asm volatile ("cpuid\n\t"
  "rdtsc\n\t"
  "mov %%edx, %0\n\t"
  "mov %%eax, %1\n\t"
  : "=r" (timers.gpu_hi2), "=r" (timers.gpu_lo2)
  :: "%rax", "%rbx", "%rcx", "%rdx");
}

void CPU_startTime()
{
  asm volatile (
      "rdtsc\n\t"
      "mov %%edx, %0\n\t"
      "mov %%eax, %1\n\t"
      : "=r" (timers.cpu_hi1), "=r" (timers.cpu_lo1)
      :: "%rax", "%rbx", "%rcx", "%rdx");
}

void CPU_endTime()
{
  asm volatile (
  "rdtsc\n\t"
  "mov %%edx, %0\n\t"
  "mov %%eax, %1\n\t"
  : "=r" (timers.cpu_hi2), "=r" (timers.cpu_lo2)
  :: "%rax", "%rbx", "%rcx", "%rdx");
}

void GPU_Tot_startTime()
{
  asm volatile (
        "rdtsc\n\t"
        "mov %%edx, %0\n\t"
        "mov %%eax, %1\n\t"
        : "=r" (timers.gpu_mem_hi1), "=r" (timers.gpu_mem_lo1)
        :: "%rax", "%rbx", "%rcx", "%rdx");

}

void GPU_Tot_endTime()
{
        asm volatile (
        "rdtsc\n\t"
        "mov %%edx, %0\n\t"
        "mov %%eax, %1\n\t"
        : "=r" (timers.gpu_mem_hi2), "=r" (timers.gpu_mem_lo2)
        :: "%rax", "%rbx", "%rcx", "%rdx");

}
extern "C" {
void swap_mac_address(GPUMbuf **packetStream, uint64_t size){
  if(size==0)
    return;

  if(!first){
    size_dev_hdrs=max_size*sizeof(packet_hdrs);
    hst_hdrs=(packet_hdrs *)malloc(max_size*sizeof(packet_hdrs));
    
    if(RunLevel>1){
      GPU_startTime();
      err=cudaMalloc((void **)&dev_hdrs, size_dev_hdrs);
      if (err != cudaSuccess){
          fprintf(stderr, "Failed to allocate device vector (error code %s)!\n", cudaGetErrorString(err));
          exit(EXIT_FAILURE);
      GPU_endTime();  
      if(timeIO)
      printf("CUDA MALLOC::%llu\n", diff(timers.gpu_lo1,timers.gpu_hi1,timers.gpu_lo2,timers.gpu_hi2));
      }
    } 
    init();
    first=1; 
  }
  unsigned long long int cpu_time;
  unsigned long long int gpu_time;
  unsigned long long int hyb_time;

  if(RunLevel==2)
    Cpu_BatchSize=0;
  else
    Cpu_BatchSize=100;
  


  if(timeIO)
    printf("%llu\n",size );

  if(RunLevel==1){
    CPU_startTime();

    pthread_t my_thread;
    pthread_struct pthread_Args;
    pthread_Args.packetStream=packetStream;
    pthread_Args.size=size;
    pthread_create(&my_thread, NULL, cpu_nf_caller_call, &pthread_Args); 
    pthread_join(my_thread, NULL);

    CPU_endTime();
    cpu_time=diff(timers.cpu_lo1,timers.cpu_hi1,timers.cpu_lo2,timers.cpu_hi2);
  }
  else{
    CPU_startTime();
    pthread_t my_thread2;
    pthread_struct pthread_Args2;
    pthread_Args2.packetStream=packetStream;
    pthread_Args2.size=Cpu_BatchSize;
   
    pthread_create(&my_thread2, NULL, cpu_nf_caller_call, &pthread_Args2); 

    
    GPU_Tot_startTime();
    GPU_startTime();
    for(int i=Cpu_BatchSize;i<size;i++){
        GPUMbuf mbuf=*(packetStream[i]);
        uint8_t* buf=mbuf.buf_addr+mbuf.data_off;
        memcpy((uint8_t*)&hst_hdrs[i],buf,sizeof(packet_hdrs));
    }
    GPU_endTime();
    if(timeIO)
      printf("CPU Copy time::%llu\n", diff(timers.gpu_lo1,timers.gpu_hi1,timers.gpu_lo2,timers.gpu_hi2));
      
    GPU_startTime();
    err = cudaMemcpy(dev_hdrs, hst_hdrs,size_dev_hdrs, cudaMemcpyHostToDevice);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to copy to GPU device (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
    GPU_endTime();

    if(timeIO)
      printf("GPU Copy time::%llu\n", diff(timers.gpu_lo1,timers.gpu_hi1,timers.gpu_lo2,timers.gpu_hi2));

    GPU_startTime();
    gpu_kernel_call(dev_hdrs, size-Cpu_BatchSize);  
    err=cudaDeviceSynchronize();
    err = cudaGetLastError();
    if (err != cudaSuccess){
        fprintf(stderr, "Failed to launch mac_swap_kernel kernel (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
    GPU_endTime();
    if(timeIO)
      printf("GPU Run time::%llu\n", diff(timers.gpu_lo1,timers.gpu_hi1,timers.gpu_lo2,timers.gpu_hi2));
    
    GPU_startTime();
    err = cudaMemcpy(hst_hdrs, dev_hdrs, size_dev_hdrs, cudaMemcpyDeviceToHost);
    if (err != cudaSuccess){
         fprintf(stderr, "Failed to copy vectorC from device to host (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
      // cudaFree(dev_hdrs);
    GPU_endTime();
    if(timeIO)
      printf("GPU copy back time::%llu\n", diff(timers.gpu_lo1,timers.gpu_hi1,timers.gpu_lo2,timers.gpu_hi2));

    GPU_startTime();
    for(int i=0;i<size;i++){
        GPUMbuf mbuf=*(packetStream[i]);
        uint8_t* buf=mbuf.buf_addr+mbuf.data_off;
        // memcpy((uint8_t*)&hst_hdrs[i],buf,sizeof(packet_hdrs));
        memcpy(buf,(uint8_t*)&hst_hdrs[i],sizeof(packet_hdrs));
    }
    GPU_endTime();
    if(timeIO)
      printf("CPU Copy back time::%llu\n", diff(timers.gpu_lo1,timers.gpu_hi1,timers.gpu_lo2,timers.gpu_hi2));
    GPU_Tot_endTime();
    pthread_join(my_thread2, NULL);
    CPU_endTime();
    hyb_time=diff(timers.cpu_lo1,timers.cpu_hi1,timers.cpu_lo2,timers.cpu_hi2);

    gpu_time=diff(timers.gpu_mem_lo1,timers.gpu_mem_hi1,timers.gpu_mem_lo2,timers.gpu_mem_hi2);
    printf("GPU::%llu\n", gpu_time);
    printf("CPU::%llu\n",cpu_time );
    printf("HYB::%llu,\n",hyb_time);

  }
  
}


}

