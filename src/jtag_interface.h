#ifndef __dbg_access_h_
#define __dbg_access_h_
#include "dbg_cmd_ext.h"

typedef struct jtag_response_t {
    int length;
    char data[(MAX_DBG_CMD_LEN)*sizeof(int)];
} jtag_response_t;

extern buffered out port:32 jtag_pin_TDI;
extern buffered in port:32 jtag_pin_TDO;
extern buffered out port:4 jtag_pin_TMS;
extern buffered out port:32 jtag_pin_TCK;
extern out port jtag_pin_SRST;
extern out port jtag_pin_TRST;

extern void dbg_cmd_manager_nochan(int input_size, int input[],
        int &output_size, int output[],
        chanend ?reset_signal_a, chanend ?reset_signal_b,
        chanend ?util_command);

jtag_response_t getResponse(char * unsafe data, unsigned int len);
void lock_to_user(dbg_cmd_packet * alias pkt);
char * alias get_current_user();
//char * movable getStringFromPkt(char *data);
int device_read(int ep, char *data, unsigned int length, unsigned int timeout);
int device_write(int ep, char * unsafe data, unsigned int length, unsigned int timeout);

#endif // __dbg_access_h_
