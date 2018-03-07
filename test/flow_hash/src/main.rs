#![feature(box_syntax)]
#![feature(asm)]
extern crate e2d2;
extern crate fnv;
extern crate getopts;
extern crate rand;
extern crate time;
use self::nf::*;
use e2d2::config::{basic_opts, read_matches};
use e2d2::interface::*;
use e2d2::operators::*;
use e2d2::scheduler::*;
use std::env;
use std::fmt::Display;
use std::process;
use std::sync::Arc;
use std::thread;
use std::time::Duration;
mod nf;

fn test<T, S> (ports: Vec<T>, sched: &mut S)
where
    T: PacketRxTx + Display + Clone + 'static,
    S: Scheduler + Sized
{
    let pipelines : Vec<_> = ports.
        iter().
        map(|p| flow_hash(p.clone(), 4, sched).send(p.clone())).
        collect();

    for pipeline in pipelines.iter() {
       sched.add_task(pipeline);
    }
}

fn main() {
    let opts = basic_opts();
    let args: Vec<_> = env::args().collect();
    let matches = match opts.parse(&args[1..]) {
        Some(m) => m,
        Err(msg) => panic!("Error while parsing the args {}", msg),
    };

    let mut configuration = read_matches(&matches, &opts);

    match initialize_system(&configuration) {
        Ok(mut context) => {
            context.start_schedulers();
            context.add_pipeline_to_run(Arc::new(move |ports, s: &mut StandaloneScheduler| {
                test(ports, s)
            }));
            context.execute();
        },
        Err(ref err) => {

        }
    };

}
