#include <jtag_pins.h>
#include <jtag.h>
#include <print.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xs1.h>

#include "dbg_cmd_ext.h"
#include "jtag_interface.h"

extern volatile char * unsafe user;

#define DEVICE_ACCESS_SUCCESS 0
#define DEVICE_ACCESS_TIMEOUT -1
#define DEVICE_ACCESS_DISCONNECTED -2
#define DEVICE_ACCESS_ERROR -3

jtag_response_t jtRetVal = { };
int return_data[MAX_DBG_CMD_DATA_LEN];
int return_length;


#pragma unsafe arrays
jtag_response_t getResponse(char data[496], unsigned int len, chanend rst_a)
{
    dbg_cmd_packet c = (data, dbg_cmd_packet);
    switch(c.type)
    {
        case DBG_CMD_ETHERXTAG_LOCK_REQ:
            lock_to_user(c);
            jtRetVal.length = sizeof(dbg_cmd_packet);
            memcpy(jtRetVal.data, &c, len);
            break;
        default:
            // Write to the jtag device
            device_write(0, (int *)data, MAX_DBG_CMD_LEN*sizeof(int), 0, rst_a);

            // Copy the result back to the send buffer & set the length
            device_read(0, jtRetVal.data, return_length, 0);
            jtRetVal.length = return_length;
            break;
    }

    return jtRetVal;
}

void lock_to_user(dbg_cmd_packet &pkt)
{
    if(pkt.type != DBG_CMD_ETHERXTAG_LOCK_REQ)
        return;

    // Copy each int from the packet into a character in the string user.
//    for(int i = 1; i < sizeof(user) && pkt.data[i] != 0; i ++)
//        user[i-1] = pkt.data[i];
    unsafe {
        user = "";
//        printint((unsigned int)&pkt.data);
//        memcpy(user, pkt.data + sizeof(char), 122);
    }
    pkt.type = DBG_CMD_ETHERXTAG_LOCK_ACK;
}

void get_current_user(char * dst)
{
//    memcpy(dst, user, 20);
}

int device_read(int ep, char *data, unsigned int length, unsigned int timeout) {
    // Copy data from the buffer back to the caller
    memcpy(data, return_data, length);

    return DEVICE_ACCESS_SUCCESS;
}

#pragma unsafe arrays
int device_write(int ep, int data[MAX_DBG_CMD_LEN], unsigned int length, unsigned int timeout, chanend rst_a) {
    // Ask the cmd_manager to write data into the buffer
    // chan rst_a, rst_b, util_cmd;
    dbg_cmd_manager_nochan(length, data, return_length, return_data, rst_a, NULL, NULL);

    return DEVICE_ACCESS_SUCCESS;
}

timer xTimer;
#define TIME_US 98
#define TIME_MS 999998

void delayus(unsigned int us)
{
    unsigned time, i;
    xTimer :> time; /* save current time */

    for (i=0;i<us;i++) {
        time += TIME_US;
        xTimer when timerafter(time) :> void;
    }
}
void delayms(unsigned int ms)
{
    unsigned time, i;
    xTimer :> time; /* save current time */

    for (i=0;i<ms;i++) {
        time += TIME_MS;
        xTimer when timerafter(time) :> void;
    }
}


