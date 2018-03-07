use e2d2::headers::*;
use e2d2::operators::*;

#[link(name = "gpu")]
extern{
    fn garble_packet();
}

pub fn macswap<T: 'static + Batch<Header = NullHeader>>(
    parent: T,
) -> TransformBatch<MacHeader, ParsedBatch<MacHeader, T>> {
    parent.parse::<MacHeader>().transform(box move |pkt| {
        assert!(pkt.refcnt() == 1);
        let hdr = pkt.get_mut_header();
        hdr.swap_addresses();
        unsafe{
            garble_packet();
        }
    })
}
