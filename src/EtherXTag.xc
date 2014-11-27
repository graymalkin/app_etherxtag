/*
 * EtherXTag.xc
 *
 *  Created on: 22 Sep 2014
 *      Author: simonc
 */
#include <print.h>
#include <stdio.h>
#include <xscope.h>

#include "EtherXTag.h"
#include "jtag_interface.h"
#include "mdns.h"
#include "uid.h"
#include "uip_server.h"
#include "xscope_interface.h"
#include "xscope_server.h"
#include "xscope_udp.h"

// Parallel main
int main(void) {
    // Channels for communication to the xtcp server
    chan i_xtcp[CLIENT_SERVICES];

    ethernet_cfg_if i_cfg[CLIENT_SERVICES];
    ethernet_rx_if i_rx[CLIENT_SERVICES];
    ethernet_tx_if i_tx[CLIENT_SERVICES];

    chan c, udp_xscope, reset, ipc;

    interface xscope_interface xsi;
#if XTCP_SEPARATE_MAC
#endif
    par
    {
        // The main ethernet/tcp server
#if XTCP_SEPARATE_MAC
        on ETHERNET_DEFAULT_TILE: mii_ethernet_mac(i_cfg, CLIENT_SERVICES,
                                                   i_rx,  CLIENT_SERVICES,
                                                   i_tx,  CLIENT_SERVICES,
                                                   p_eth_rxclk, p_eth_rxerr,
                                                   p_eth_rxd, p_eth_rxdv,
                                                   p_eth_txclk, p_eth_txen,
                                                   p_eth_txd, p_eth_dummy,
                                                   eth_rxclk, eth_txclk,
                                                   ETH_RX_BUFFER_SIZE_WORDS);
#endif
        on ETHERNET_DEFAULT_TILE: handle_mdns_event(i_xtcp[MDNS_SERVICE]);

        // The xLINK code must be on the correct tile, or the ports won't match
        // the correct IO
//        on XTAG_DEFAULT_TILE:     uart_usb_thread(c_ep_out[2], c_ep_in[3], udp_xscope);
        on XTAG_DEFAULT_TILE:     uart_thread(udp_xscope, c, reset);
        restOfWorld(c);
/*
        on XTAG_DEFAULT_TILE:     handle_all_events(i_xtcp[0], reset, ipc);
/*/
        on XTAG_DEFAULT_TILE:     handle_xtag_event(i_xtcp[XTAG_SERVICE], reset, ipc);
        on XTAG_DEFAULT_TILE:     handle_http_event(i_xtcp[HTTP_SERVICE]);
        on XTAG_DEFAULT_TILE:     xscope_udp(i_xtcp[XSCOPE_SERVICE], xsi, ipc);
        on XTAG_DEFAULT_TILE:     xscope_server(xsi, udp_xscope);
//*/
    }
    return 0;
}

// Handle TCP events
void handle_all_events(chanend c_xtcp, chanend rst_a, chanend ip_out) {
    xtcp_connection_t conn;
    xtag_init(c_xtcp);
    httpd_init(c_xtcp);
    mdns_init(c_xtcp);
    while (1) {
        select
        {
            case xtcp_event(c_xtcp, conn):
            {
                // Handle EtherXTAG events
                if(conn.local_port == ETHER_XTAG_PORT)
                {
                    printstr("Event for XTAG_SERVICE: ");
                    print_event_nameln(conn.event);
                    unsafe { xtag_tcp_event(c_xtcp, conn, rst_a, ip_out); }
                    break;
                }

                if(conn.local_port == HTTP_PORT)
                {
                    printstr("Event for HTTP_SERVICE: ");
                    print_event_nameln(conn.event);
                    unsafe { http_tcp_event(c_xtcp, conn); }
                    break;
                }

                if(conn.event == XTCP_IFUP)
                {
                    // Register this device on the network using an mdns broadcast.
                    mdns_register_name("etherxtag");
                    mdns_register_canonical_name("etherxtag");
                    mdns_register_service("etherxtag", "_xtag._tcp", ETHER_XTAG_PORT, "uuid=" DEVICE_ID);
                }

                mdns_xtcp_handler(c_xtcp, conn);
                break;
            }
        }
    }
}

// Handle xtag TCP events
void handle_xtag_event(chanend c_xtcp, chanend rst_a, chanend ip_out) {
    xtcp_connection_t conn;
    xtag_init(c_xtcp);
    while (1) {

        select
        {
            case xtcp_event(c_xtcp, conn):
            {
                // Handle EtherXTAG events
//                printstr("Event for XTAG_SERVICE: ");
//                print_event_nameln(conn.event);
                unsafe { xtag_tcp_event(c_xtcp, conn, rst_a, ip_out); }
                break;
            }
        }
    }
}


// Handle mdns TCP events
void handle_mdns_event(chanend c_xtcp) {
    xtcp_connection_t conn;
    mdns_init(c_xtcp);
    while (1) {
        select
        {
            case xtcp_event(c_xtcp, conn):
            {
//                printstr("Event on MDNS_SERVICE, event: ");
//                print_event_nameln(conn.event);
                if(conn.event == XTCP_IFUP)
                {
                    // Register this device on the network using an mdns broadcast.
                    mdns_register_name("etherxtag");
                    mdns_register_canonical_name("etherxtag");
                    mdns_register_service("etherxtag", "_xtag._tcp", ETHER_XTAG_PORT, "uuid=" DEVICE_ID);
                    mdns_register_service("etherxtag", "_http._tcp", ETHER_XTAG_PORT, "EtherXTag Web Service");
                }

                mdns_xtcp_handler(c_xtcp, conn);
                break;
            }
        }
    }
}

// Handle http TCP events
void handle_http_event(chanend c_xtcp) {
    xtcp_connection_t conn;
    httpd_init(c_xtcp);
    while (1) {
        select
        {
            case xtcp_event(c_xtcp, conn):
            {
                // Handle HTTP events
//                printstr("Event on HTTP_SERVICE, event: ");
//                print_event_nameln(conn.event);
                unsafe { http_tcp_event(c_xtcp, conn); }
                break;
            }
        }
    }
}

//// Register an xSCOPE connection, for fast debug printing
//void xscope_user_init(void) {
////   xscope_register(1, XSCOPE_CONTINUOUS, "xCONNECT to target", XSCOPE_UINT, "mV");
//   xscope_config_io(XSCOPE_IO_BASIC);
//}

void donothing(chanend c) {
    int k;
    while (1) {
        c :> k;
        printintln(k);
    }
}

// Print out a XTCP event name (useful for debugging)
void print_event_nameln(int event)
{
    switch(event)
    {
        case XTCP_IFUP:
        {
            printstr("XTCP_IFUP\n");
            return;
        }

        case XTCP_IFDOWN:
        {
            printstr("XTCP_IFDOWN\n");
            return;
        }

        case XTCP_ALREADY_HANDLED:
        {
            printstr("XTCP_ALREADY_HANDLED\n");
            return;
        }

        case XTCP_NEW_CONNECTION:
        {
            printstr("XTCP_NEW_CONNECTION\n");
            return;
        }

        case XTCP_SENT_DATA:
        {
            printstr("XTCP_SENT_DATA\n");
            return;
        }

        case XTCP_REQUEST_DATA:
        {
            printstr("XTCP_REQUEST_DATA\n");
            return;
        }

        case XTCP_RESEND_DATA:
        {
            printstr("XTCP_RESEND_DATA\n");
            return;
        }

        case XTCP_RECV_DATA:
        {
            printstr("XTCP_RECV_DATA\n");
            return;
        }

        case XTCP_TIMED_OUT:
        {
            printstr("XTCP_TIMED_OUT\n");
            return;
        }

        case XTCP_ABORTED:
        {
            printstr("XTCP_ABORTED\n");
            return;
        }

        case XTCP_CLOSED:
        {
            printstr("XTCP_CLOSED\n");
            return;
        }
    }
}
