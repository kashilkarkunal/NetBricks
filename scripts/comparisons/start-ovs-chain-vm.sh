#!/bin/bash
set -o errexit
# args
# 1: Master core (5)
# 2: PMD mask (0x60)
# 4: Number of rings (1)

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
OVS_HOME="$BASE_DIR/../ovs"
DPDK_LIB="$BASE_DIR/../dpdk/build/lib"
export LD_LIBRARY_PATH="${DPDK_LIB}:${LD_LIBRARY_PATH}"
echo $OVS_HOME
#HUGEPAGES_HOME=/opt/e2d2/libhugetlbfs

INP_LCORE=${1-"4"}
MASTER_LCORE=$((INP_LCORE - 1))
CORE0=$((MASTER_LCORE + 1))
CORE1=$((MASTER_LCORE + 2))
PMD_MASK=$(printf "0x%x" $((2**(CORE0) + 2**(CORE1))))
echo $PMD_MASK
PHYNICS=1
RINGS=${2-1}
IFACE=${BENCH_IFACE-"07:00.0"}
${BASE_DIR}/kill-ovs-chain.py

pushd $OVS_HOME
$( $OVS_HOME/utilities/ovs-dev.py env )
#$OVS_HOME/utilities/ovs-dev.py kill
$OVS_HOME/utilities/ovs-dev.py \
    reset run --dpdk -c ${MASTER_LCORE} -n 4 -r 1 --socket-mem 1024,0 \
	--file-prefix "ovs" -w ${IFACE}
ovs-vsctl set Open . other_config:n-dpdk-rxqs=1
ovs-vsctl add-br b -- set bridge b datapath_type=netdev
ovs-vsctl set Open . other_config:pmd-cpu-mask="$PMD_MASK"
ovs-vsctl set Open . other_config:n-handler-threads=1
ovs-vsctl set Open . other_config:n-revalidator-threads=1
ovs-vsctl set Open . other_config:max-idle=10000

for (( pinterface=0; pinterface<$PHYNICS; pinterface++ )); do
	iface="dpdk${pinterface}"
	echo "Setting up physical interface ${iface}"
	ovs-vsctl add-port b ${iface} -- set Interface ${iface} type=dpdk
done

for (( rinterface=0; rinterface<$RINGS; rinterface++ )); do
	iface="v${rinterface}"
	echo "Setting up VHOST user interface ${iface}"
	ovs-vsctl add-port b ${iface} -- set Interface ${iface} type=dpdkvhostuser
done
ovs-ofctl del-flows b

ports=$((PHYNICS+RINGS))
for (( port=0; port<$((ports - 1)); port++ )); do
    src_port=$((port+1))
    dst_port=$((port+2))
    echo ovs-ofctl add-flow b in_port=${src_port},actions=output:${dst_port}
    ovs-ofctl add-flow b in_port=${src_port},actions=output:${dst_port}
done
ovs-ofctl add-flow b in_port=${ports},actions=output:1
odd=$((RINGS%2))

start_vm () {
    MCORE=$1
    LCORE=$2
    VDEV=$3
    PORT=$4
    MONITOR_PORT=$5
    DISPLAY=$6
    echo "Using VDEV ${VDEV}"

    CORE_MASK=$(printf "0x%x" $((2**(MCORE) + 2**(LCORE))))
    OUT_FILE=$(mktemp)
    echo "Core Mask" ${CORE_MASK}
    sudo taskset ${CORE_MASK} qemu-system-x86_64 --enable-kvm --cpu host,migratable=off --smp 2,cores=2,threads=1,sockets=1 -snapshot -hda \
    ${BASE_DIR}/../debian/debian-nb.img -m 2048M -object memory-backend-file,id=mem,size=2048M,mem-path=/dev/hugepages,share=on -numa \
    node,memdev=mem -mem-prealloc -monitor telnet:127.0.0.1:${MONITOR_PORT},server,nowait -device e1000,netdev=user.0 -netdev \
    user,id=user.0,hostfwd=tcp::${PORT}-:22 -vga std  -serial file:${OUT_FILE} -daemonize -vnc :${DISPLAY},password \
    -chardev socket,id=char0,path=${OVS_HOME}/_run/run/v${VDEV} -netdev type=vhost-user,id=v${VDEV},chardev=char0,vhostforce \
    -device virtio-net-pci,mac=00:16:3d:22:33:57,netdev=v${VDEV}
    echo "Out file is ${OUT_FILE}"
    until [ -e ${OUT_FILE} ]; do
        sleep 0.1
    done
    until cat $OUT_FILE | grep "login:"; do
        sleep 0.1
    done
    echo "Booted"
}

start_app () {
    PORT=$1
    extra_args=$2
    ssh -p${PORT} -i ${BASE_DIR}/../debian/vm_key -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost \
        /opt/netbricks/scripts/bind-virtio.sh
    devs=$( ssh -p${PORT} -i ${BASE_DIR}/../debian/vm_key -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost \
            /opt/netbricks/3rdparty/dpdk/tools/dpdk-devbind.py --status \
            | grep 'Virtio' \
            | awk '{print $1}' )
    echo "Active ports are $devs"
    ports_string=""
    for dev in $devs; do
        ports_string+="-p ${dev} -c 1"
    done
    ssh -p${PORT} -i ${BASE_DIR}/../debian/vm_key -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no root@localhost \
    "nohup /opt/netbricks/build.sh run zcsi-chain -l 1 -m 0 ${ports_string} ${extra_args} &> /var/log/nb < /dev/null &"
}
BASE_CORE=$(( CORE1 + 1 ))
BASE_VDEV=0
BASE_PORT=5555
BASE_MONITOR=1234
BASE_DISPLAY=1
start_vm ${BASE_CORE} $(( BASE_CORE + 1)) ${BASE_VDEV} ${BASE_PORT} ${BASE_MONITOR} ${BASE_DISPLAY}
if ((odd == 1)); then
    start_app ${BASE_PORT} ""
else
    start_app ${BASE_PORT} "-j 1"
fi

for (( vm = 1; vm < ${RINGS}; vm++ )); do
    PORT=$(( BASE_PORT + vm ))
    CORE=$(( BASE_CORE + 2*vm ))
    start_vm ${CORE} $(( CORE + 1 )) $(( BASE_VDEV + vm )) $PORT $(( BASE_MONITOR + vm )) \
        $(( BASE_DISPLAY + vm ))
    start_app ${PORT}
done

popd
