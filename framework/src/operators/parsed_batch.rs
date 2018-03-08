use super::Batch;
use super::act::Act;
use super::gpunf::GpuNf;
use super::iterator::*;
use super::packet_batch::PacketBatch;
use common::*;
use headers::EndOffset;
use interface::*;
use std::marker::PhantomData;

pub struct ParsedBatch<T, V>
where
    T: EndOffset<PreviousHeader = V::Header>,
    V: Batch + BatchIterator + Act + GpuNf,
{
    parent: V,
    phantom: PhantomData<T>,
}

impl<T, V> Act for ParsedBatch<T, V>
where
    T: EndOffset<PreviousHeader = V::Header>,
    V: Batch + BatchIterator + Act + GpuNf,
{
    act!{}
}

impl<T, V> Batch for ParsedBatch<T, V>
where
    V: Batch + BatchIterator + Act + GpuNf,
    T: EndOffset<PreviousHeader = V::Header>,
{
}

impl<T, V> ParsedBatch<T, V>
where
    V: Batch + BatchIterator + Act + GpuNf,
    T: EndOffset<PreviousHeader = V::Header>,
{
    #[inline]
    pub fn new(parent: V) -> ParsedBatch<T, V> {
        ParsedBatch {
            parent: parent,
            phantom: PhantomData,
        }
    }
}

impl <T, V> GpuNf for ParsedBatch<T, V>
where
    V: Batch + BatchIterator + Act + GpuNf,
    T: EndOffset<PreviousHeader = V::Header>,
{
    fn execute_gpu_nfv(&mut self) {
        self.parent.execute_gpu_nfv();
    }
}

impl<T, V> BatchIterator for ParsedBatch<T, V>
where
    V: Batch + BatchIterator + Act + GpuNf,
    T: EndOffset<PreviousHeader = V::Header>,
{
    type Header = T;
    type Metadata = V::Metadata;
    unsafe fn next_payload(&mut self, idx: usize) -> Option<PacketDescriptor<T, V::Metadata>> {
        self.parent.next_payload(idx).map(|p| PacketDescriptor {
            packet: p.packet.parse_header(),
        })
    }

    #[inline]
    fn start(&mut self) -> usize {
        self.parent.start()
    }
}
