use e2d2::headers::*;
use e2d2::operators::*;


#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct _packet_ {
    pub src_address: [::std::os::raw::c_char; 6usize],
    pub dst_address: [::std::os::raw::c_char; 6usize],
    pub data: [::std::os::raw::c_char; 6usize],
}

pub type pckt = _packet_;
#[link(name = "gpu")]
extern {
        pub fn garble_packet(packets: *mut [pckt; 100], num: ::std::os::raw::c_int);
}


pub fn macswap<T: 'static + Batch<Header = NullHeader>>(
    parent: T,
) -> TransformBatch<MacHeader, ParsedBatch<MacHeader, T>> {
    parent.parse::<MacHeader>().transform(box move |pkt| {
        assert!(pkt.refcnt() == 1);
        let hdr = pkt.get_mut_header();
        hdr.swap_addresses();
        let pt = pckt{
            src_address: [65,66,66,66,66,66],
            dst_address: [65,66,66,66,66,66],
            data: [65,66,66,66,66,66],
        };

        let mut packets = [pt; 100];

        unsafe{
            garble_packet(&mut packets, 100);
        }
    })
}
