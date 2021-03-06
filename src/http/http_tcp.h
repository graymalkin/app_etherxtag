#ifndef __http_tcp_h_
#define __http_tcp_h_

#include <xccompat.h>

#include "xtcp.h"

#ifndef NULL
#define NULL 0
#endif

#define MAX_HTTP_TCP_CONNECTIONS 2
#define HTTP_PORT 80                // The network port to use for HTTP traffic

/** \brief Initialize the HTTP state
 *
 * Adds a tcp listener on the HTTP port (80)
 */
void httpd_init(chanend tcp_svr);


/** \brief Initialise the connection buffer
 *
 * Sets all the connections in the buffer to inactive, so they can be used by
 * incoming connections as they are established.
 */
void http_connection_buffer_init();

/** \breif Sends a webpage back down the tcp connection
 *
 * Sends a webpage generated by web_service back down the tcp connection.
 */
unsafe void http_tcp_send(chanend tcp_svr, xtcp_connection_t &conn);

/** \brief If there's room, adds an incoming connection to the connections buffer
 *
 * This will set-up state in the 1st available slot in the connections buffer to
 * represent this connection.
 */
void http_accept_connection(chanend c_xtcp, xtcp_connection_t &conn);

/** \brief Removes a connection from the connections buffer
 *
 * This sets a given connection to inactive, so it may be claimed in
 * `accept_connection`
 */
void http_free_connection(xtcp_connection_t &conn);

/** \brief Handles a TCP event
 *
 * Switches through various TCP event scenarios, and handles them apropriately.
 */
unsafe void http_tcp_event(chanend c_xtcp, xtcp_connection_t &conn);

/** \brief Receives HTTP requests
 *
 * Takes an HTTP request, calls a function to create a reponse and sends it.
 */
unsafe void http_recv_data(chanend c_xtcp, xtcp_connection_t &conn);

/** \brief This is called when the interface has been initialsed with an IP
 *
 * Currently only prints the IP the device has been configured with.
 */
void http_if_up(chanend c_xtcp);


#endif // __http_tcp_
