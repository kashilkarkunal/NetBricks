typedef struct _packet_{
    char src_address[6];
    char dst_address[6];
    char data[6];
} packet;

void garble_packet(packet packets[], int num);
