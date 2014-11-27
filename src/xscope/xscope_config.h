/*
 * xscope_config.h
 *
 *  Created on: 9 Jan 2015
 *      Author: simonc
 */

#ifndef XSCOPE_CONFIG_H_
#define XSCOPE_CONFIG_H_
#include <platform.h>


/*******************************************************************************
 *                            Configure xSCOPE
 ******************************************************************************/

#define XSCOPE_DEFAULT_TILE tile[1]

#define BUF_WORDS 512
#define NUM_BUFFERS 4
#define ETH_HOST_BUF_WORDS 128
#define ASECOND 100000000
#define HEADER_SIZE 4
#define XLINK_VAL 0x8000a014
#define XLINK_VAL_HELLO (XLINK_VAL | 0x1000000)

int from_host_buf_uart[ETH_HOST_BUF_WORDS];
int from_host_buf[ETH_HOST_BUF_WORDS];
int to_host_buf[ETH_HOST_BUF_WORDS];
unsigned bit_time = 0;
unsigned int xlink_byte_count = 0;

extern unsigned char data_buffer[NUM_BUFFERS][BUF_WORDS];
extern unsigned char data_buffer_[NUM_BUFFERS][BUF_WORDS];
extern in port UART_RX_PORT;
on XSCOPE_DEFAULT_TILE : out port UART_TX_PORT              = XS1_PORT_1K;
on XSCOPE_DEFAULT_TILE : clock clk                          = XS1_CLKBLK_3;
on XSCOPE_DEFAULT_TILE : clock uart_clk                     = XS1_CLKBLK_4;




#endif /* XSCOPE_CONFIG_H_ */
