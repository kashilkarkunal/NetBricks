use e2d2::operators::*;
use e2d2::utils::*;
use e2d2::headers::*;
use e2d2::scheduler::*;

pub fn flow_hash<T: 'static + Batch<Header = NullHeader>, S: Scheduler + Sized> (
    parent: T,
    num_groups: i32,
    sched: &mut S) -> CompositionBatch
{
    let groups = parent
        .parse::<IpHeader>().group_by(num_groups,
        move |pkt| {
            let payload = pkt.get_payload();
            let flow_hash = ipv4_flow_hash(payload, 0);
            let group = flow_hash % num_groups;
            group
        },
        sched);
}