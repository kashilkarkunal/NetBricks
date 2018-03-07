use super::packet_batch::PacketBatch;
use common::*;

pub trait GpuNf {

    #[inline]
    fn execute_gpu_nfv(&mut self);
}