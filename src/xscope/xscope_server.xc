/*
 * EtherXTag.xc
 *
 *  Created on: 22 Sep 2014
 *      Author: simonc
 */

#include <print.h>
#include <xs1.h>

#include "xscope_interface.h"
#include "xscope_config.h"
int from_host_buf_uart[ETH_HOST_BUF_WORDS];

/**
 * \see xlink.S
 *
 * This function fills xscope packets, and pushes them into a ring buffer. This
 * can then be read (unsafely) by other threads.
 */
extern void uart_readAll(chanend a, chanend b, chanend c, in port d,
        unsigned char buffer[NUM_BUFFERS][BUF_WORDS], int x);
extern void progSwitchRegBlind(unsigned int a, unsigned int b, unsigned int c);

#pragma unsafe arrays
void xscope_server(server interface xscope_interface xsi, chanend to_uart)
{
    unsigned char buf_num;
    unsigned started_tx = 0;
    while(1) {
        if (!started_tx) {
          outuint(to_uart, 1);
          started_tx = 1;
        }
        inuchar_byref(to_uart, buf_num);

        xsi.has_data();

        select {
            case xsi.get_data(int data[128]):
            {
                int non_zero_count = 0;
                for (int i = 0; i < 128; i++){
                    // Move whole ints at a time, for speed. data_buffer_ should
                    // be 512 bytes long. (128 * sizeof(int))
                    data[i] = (data_buffer_[buf_num], unsigned[])[i];
                    if(data[i] != 0)
                        non_zero_count++;
                }
                if(non_zero_count > 1)
                    printintln(non_zero_count);

                outuint(to_uart, 1);
                // printhexln(from_host_buf_uart[1]);
                unsigned int i = 0;
                // read_node_config_reg(tile[1], 0x82, i);
                // printhexln(i);
                // Got data from xlink -- send to the host.
                // printstr("Got XLINK data...\n");
                break;
            }
        }
    }
}

void uart_thread(chanend from_udp, chanend xlink_data, chanend reset) {
    unsigned int usb_signal = 0;
    unsigned char device_reset_cmd = 0;
    unsigned int device_reset_signal = 0;
    bit_time  = XS1_TIMER_MHZ * 1000000 / (unsigned) 115200;

    while (1) {
        // Must wait for reset to be finished
        while (!usb_signal) {
            select {
                case inuint_byref(from_udp, usb_signal):
                    break;
                case inuchar_byref(reset, device_reset_cmd):
                    chkct(reset, 1);
                    device_reset_signal = do_xlink_reset(device_reset_cmd, reset);
                    break;
            }
        }

        data_buffer[1][0] = 0;
        outuchar(from_udp, 1);          // acknowledge empty queue

        UART_TX_PORT <: 1;              // Start bit high
        set_port_use_on(UART_RX_PORT);  // And safely open UART port.
        set_port_pull_down(UART_RX_PORT);
        configure_in_port_no_ready(UART_RX_PORT, uart_clk);
        start_clock(uart_clk);

#ifdef XC_MAINLOOP
        uart_xc_readAll(from_usb, reset, xlink_data);
#else
        uart_readAll(from_udp, reset, xlink_data, UART_RX_PORT, data_buffer, bit_time);
#endif

        set_port_use_off(UART_RX_PORT);
    }
}

unsigned int do_xlink_reset(unsigned int reset_cmd, chanend reset) {
    unsigned int device_reset_flag = 0;
    timer tmr;
    unsigned s;

    /* Tell the xlink to use direction 2 */
    /* (n.b. 0x1 = d1, 0x10 = d2, 0x100) */
    progSwitchRegBlind(0x22, 0x8002, 0x200);

    // Change directions
    progSwitchRegBlind(0x0C, 0x8002, 0x11111102);
    switch (reset_cmd) {
    case 0:
        progSwitchRegBlind(0x82, 0x8002, XLINK_VAL);

        tmr :> s;
        tmr when timerafter(s + 1000) :> void;
        progSwitchRegBlind(0x82, 0x8002, XLINK_VAL | 0x800000);

        device_reset_flag = 1;
        break;
    case 1:
        progSwitchRegBlind(0x82, 0x8002, XLINK_VAL | 0x800000);
        progSwitchRegBlind(0x82, 0x8002, 0x00000000);
        device_reset_flag = 1;
        break;
    case 2:
        progSwitchRegBlind(0x82, 0x8002, XLINK_VAL_HELLO);
        device_reset_flag = 0;
        break;
    case 0xff:
        // Device restart main loop
        device_reset_flag = 0xff;
        break;
    }
    outct(reset, 1);
    return device_reset_flag;
}
