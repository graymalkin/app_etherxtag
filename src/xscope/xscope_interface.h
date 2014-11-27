/*
 * xscope_interface.h
 *
 *  Created on: 8 Jan 2015
 *      Author: simonc
 */

#ifndef XSCOPE_INTERFACE_H_
#define XSCOPE_INTERFACE_H_
#include <xs1.h>

interface xscope_interface {
  [[clears_notification]] void get_data(int packet[128]);
  [[notification]]        slave void has_data();
};

void uart_thread(chanend from_udp, chanend xlink_data, chanend reset);
unsigned int do_xlink_reset(unsigned int reset_cmd, chanend reset);
void uart_usb_thread(chanend from_host, chanend to_host, chanend to_uart);


#endif /* XSCOPE_INTERFACE_H_ */
