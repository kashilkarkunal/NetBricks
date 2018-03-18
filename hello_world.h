#include <stdint.h>
#include <inttypes.h>

typedef struct _packet_{
    char src_address[6];
    char dst_address[6];
    char data[6];
} packet;

typedef struct ethHeader{
    uint8_t dst_address[6];
    uint8_t src_address[6];
    uint8_t ethType[2];    
} ethHeader;

typedef struct ipHeader{
    uint8_t ver_ihl;
    uint8_t dscp_ecn;
    uint8_t tot_len[2];
    uint8_t identification[2];
    uint8_t flags_fraghosts[2];
    uint8_t ttl;
    uint8_t protocol;
    uint8_t chksum[2];
    uint8_t src_ip[4];
    uint8_t dst_ip[4];

} ipHeader;

typedef struct packet_hdrs{
    ethHeader ethHdr;
    ipHeader ipHdr;
} packet_hdrs;


typedef struct _GPUMbuf_ {

    uint8_t* buf_addr;

    uint64_t phys_addr;

    uint16_t data_off;

    uint16_t refcnt;

    uint8_t nb_segs;

    uint8_t port;

    uint64_t ol_flags;

    uint32_t packet_type;

    uint32_t pkt_len;

    uint16_t data_len;

    uint16_t vlan_tci;

    uint64_t hash;

    uint32_t vlan_tci_outer;

    uint16_t buf_len;

    uint64_t timestamp;

    uint64_t userdata;

    uint64_t pool;

    struct _GPUMbuf_ *next;

    uint64_t tx_offload;

    uint16_t priv_size;

    uint16_t timesync;

    uint32_t sync;
}GPUMbuf;



extern "C" {
void garble_packet(packet packets[], int num);

void swap_mac_address(GPUMbuf **packets, uint64_t size);
}
