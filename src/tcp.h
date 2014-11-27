#ifndef __tcp_h_
#define __tcp_h_

#ifndef NULL
#define NULL 0
#endif

#define MAX_TCP_CONNECTIONS 10
#define ETHER_XTAG_PORT 1337        // The network port to use for xtag trafic

/** \brief Initialize the HTTP state
 *
 * Adds a tcp listener on the HTTP port (80)
 */
void httpd_init(chanend tcp_svr);

/** \brief Initialise the XTAG state
 *
 * Adds a tcp listener to the EtherXTAG port (1337)
 */
void xtag_init(chanend tcp_svr);

/** \brief Initialise the connection buffer
 *
 * Sets all the connections in the buffer to inactive, so they can be used by
 * incoming connections as they are established.
 */
void connection_buffer_init();

/** \breif Sends a webpage back down the tcp connection
 *
 * Sends a webpage generated by web_service back down the tcp connection.
 */
unsafe void tcp_send(chanend tcp_svr, xtcp_connection_t conn);

/** \brief If there's room, adds an incoming connection to the connections buffer
 *
 * This will set-up state in the 1st available slot in the connections buffer to
 * represent this connection.
 */
void accept_connection(chanend c_xtcp, xtcp_connection_t conn);

/** \brief Removes a connection from the connections buffer
 *
 * This sets a given connection to inactive, so it may be claimed in
 * `accept_connection`
 */
void free_connection(xtcp_connection_t conn);

/** \brief Handles a TCP event
 *
 * Switches through various TCP event scenarios, and handles them apropriately.
 */
unsafe void tcp_event(chanend c_xtcp, xtcp_connection_t conn);


unsafe void recv_data(chanend c_xtcp, xtcp_connection_t conn);
void if_up(chanend c_xtcp);


#endif
