#ifndef __EtherXTag_h_
#define __EtherXTag_h_

//#define DEBUGGING
#define ETHERNET_USE_TRIANGLE_SLOT  // Picking a slice slot to use
#define XTAG_USE_SOFT_MSEL_SRST     // Use soft reset
#define XTAG_DEFAULT_TILE tile[1]   // Set the XTAG to use the 2nd tile

#define CLIENT_SERVICES 4
enum SERVICES {
    XTAG_SERVICE,
    MDNS_SERVICE,
    HTTP_SERVICE,
    XSCOPE_SERVICE
} SERVICES;

#include "ethernet_board_conf.h"
#include "ethernet_board_support.h"
#include "http_tcp.h"
#include "xtag_tcp.h"
#include "xtcp.h"
#include "xtcp_client_conf.h"

void print_event_nameln(int event);

/*******************************************************************************
 *                             Configure xtcp
 ******************************************************************************/
#if XTCP_SEPARATE_MAC
void start_ethernet_server(chanend c_mac_rx[], chanend c_mac_tx[]);

port p_eth_rxclk = PORT_ETH_RXCLK;
port p_eth_rxd   = PORT_ETH_RXD;
port p_eth_txd   = PORT_ETH_TXD;
port p_eth_rxdv  = PORT_ETH_RXDV;
port p_eth_txen  = PORT_ETH_TXEN;
port p_eth_txclk = PORT_ETH_TXCLK;
port p_eth_rxerr = PORT_ETH_ERR;
port p_eth_dummy = PORT_ETH_INT; // May be incorrect.
clock eth_rxclk = on tile[1]: XS1_CLKBLK_3;
clock eth_txclk = on tile[1]: XS1_CLKBLK_4;

on ETHERNET_DEFAULT_TILE: otp_ports_t otp_ports = OTP_PORTS_INITIALIZER;
#define ETH_RX_BUFFER_SIZE_WORDS 1024

#else
// Initialise the xtcp_ports structure
ethernet_xtcp_ports_t xtcp_ports = {
    on ETHERNET_DEFAULT_TILE:
        OTP_PORTS_INITIALIZER,
        ETHERNET_DEFAULT_SMI_INIT,
        ETHERNET_DEFAULT_MII_INIT_lite,
        ETHERNET_DEFAULT_RESET_INTERFACE_INIT
};
#endif

// Initialise an IP Config to use DHCP
xtcp_ipconfig_t ipconfig = {
        { 0,   0,   0,   0 },   // ip address (eg 192, 168, 0,   2) 0.0.0.0 auto
        { 255, 255, 255, 0 },   // netmask    (eg 255, 255, 255, 0)
        { 192, 168, 0,   1 }    // gateway    (eg 192, 168, 0,   1)
};



/*******************************************************************************
 *                          Define the jtag pins
 ******************************************************************************/
on XTAG_DEFAULT_TILE : buffered out port:32 jtag_pin_TDI  = XS1_PORT_1A;
on XTAG_DEFAULT_TILE : buffered in port:32 jtag_pin_TDO   = XS1_PORT_1H;
on XTAG_DEFAULT_TILE : buffered out port:4 jtag_pin_TMS   = XS1_PORT_1D;
on XTAG_DEFAULT_TILE : buffered out port:32 jtag_pin_TCK  = XS1_PORT_1E;
on XTAG_DEFAULT_TILE : out port jtag_pin_SRST             = XS1_PORT_1I;
on XTAG_DEFAULT_TILE : port jtag_pin_soft_msel            = XS1_PORT_1J;
on XTAG_DEFAULT_TILE : clock tck_clk                      = XS1_CLKBLK_1;
on XTAG_DEFAULT_TILE : clock other_clk                    = XS1_CLKBLK_2;



/*******************************************************************************
 *                           Function prototypes
 ******************************************************************************/
/** \breif Multicore main
 *
 * Start the ethernet stack and tcp event handeler on the 2 tiles
 */
int main(void);

/** \breif Event handler for a tcp event
 *
 * Handles tcp events from the tcp/ip stack. This is the main codepath for all
 * events in the system. HTTP requests and XTAG packets will be handled in this
 * function.
 */
void handle_all_events(chanend c_xtcp, chanend rst_a, chanend ip_out);
void handle_mdns_event(chanend c_xtcp);
void handle_xtag_event(chanend c_xtcp, chanend rst_a, chanend ip_out);
void handle_http_event(chanend c_xtcp);

/** \breif Intialise xSCOPE
 *
 * Set up basic xSCOPE IO for printing information back to the host. This is
 * orders of magnitude faster than JTAG printing.
 */
void xscope_user_init(void);

void donothing(chanend c);

#endif // __EtherXTag_h_
