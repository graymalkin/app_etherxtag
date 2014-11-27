/*
 * EtherXTag.xc
 *
 *  Created on: 22 Sep 2014
 *      Author: simonc
 */
#define ETHERNET_USE_TRIANGLE_SLOT  // Picking a slice slot to use
#define XTAG_USE_SOFT_MSEL_SRST     // Use soft reset

#include <print.h>
#include <stdio.h>
#include <xscope.h>

#include "ethernet_board_conf.h"    // Config for ports to use on the sliceKIT
#include "ethernet_board_support.h"
#include "mdns.h"
#include "tcp.h"
#include "xtcp.h"


xtcp_ipconfig_t ipconfig = { { 0, 0, 0, 0 },  // ip address (eg 192, 168, 0,  2)
        { 0, 0, 0, 0 },   // netmask    (eg 255, 255, 255,0)
        { 0, 0, 0, 0 }    // gateway    (eg 192, 168, 0,  1)
};

// These intializers are taken from the ethernet_board_support.h header for
// XMOS dev boards. If you are using a different board you will need to
// supply explicit port structure intializers for these values

ethernet_xtcp_ports_t xtcp_ports = {
on ETHERNET_DEFAULT_TILE: OTP_PORTS_INITIALIZER, ETHERNET_DEFAULT_SMI_INIT,
        ETHERNET_DEFAULT_MII_INIT_lite,
        ETHERNET_DEFAULT_RESET_INTERFACE_INIT };


on tile[1] : buffered out port:32 jtag_pin_TDI  = XS1_PORT_1A;
on tile[1] : buffered in port:32 jtag_pin_TDO   = XS1_PORT_1H;
on tile[1] : buffered out port:4 jtag_pin_TMS   = XS1_PORT_1D;
on tile[1] : buffered out port:32 jtag_pin_TCK  = XS1_PORT_1E;
on tile[1] : out port jtag_pin_SRST             = XS1_PORT_1I;
on tile[1] : out port jtag_pin_TRST             = XS1_PORT_1B;
on tile[1] : clock tck_clk                      = XS1_CLKBLK_1;
on tile[1] : clock other_clk                    = XS1_CLKBLK_2;

unsafe void handle_tcp_event(chanend c_xtcp) {
    xtcp_connection_t conn;
    httpd_init(c_xtcp);
    xtag_init(c_xtcp);
    mdns_init(c_xtcp);
    while (1) {
        select
        {
            case xtcp_event(c_xtcp, conn):
            {
                // Handle MDNS events.
                mdns_xtcp_handler(c_xtcp, conn);

                // Handle HTTP and EtherXTAG events
                tcp_event(c_xtcp, conn);
                break;
            }
        }
    }
}

void xscope_user_init(void) {
   xscope_register(0, 0, "", 0, "");
   xscope_config_io(XSCOPE_IO_BASIC);
}


unsafe int main(void) {
    chan c_xtcp[1];

    par
    {
        // The main ethernet/tcp server
        on ETHERNET_DEFAULT_TILE:// Tile 0 when in triangle slot
            ethernet_xtcp_server(xtcp_ports, ipconfig, c_xtcp, 1);
        on tile[1]:
            handle_tcp_event(c_xtcp[0]);
    }
    return 0;
}
