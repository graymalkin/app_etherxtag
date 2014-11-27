#include "dbg_cmd_ext.h"

#ifndef __jtag_interface_h_
#define __jtag_interface_h_

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

jtag_response_t getResponse(char data[(MAX_DBG_CMD_LEN)*sizeof(int)],
        unsigned int len, chanend rst_a);
void lock_to_user(dbg_cmd_packet &
        pkt);

void get_current_user(char *dst);
//char * movable getStringFromPkt(char *data);
int device_read(int ep, char *data, unsigned int length, unsigned int timeout);
int device_write(int ep, int data[MAX_DBG_CMD_LEN], unsigned int length, unsigned int timeout, chanend rst_a);

interface get_user_interface {
    void get_username(char *dst);
};

void delayus(unsigned int us);
void delayms(unsigned int ms);

#endif // __dbg_access_h_
