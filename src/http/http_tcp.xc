#include <inttypes.h>
#include <print.h>
#include <stdio.h>

#include "http_tcp.h"
#include "web_service.h"
#include "xtag_tcp.h"

#include "uid.h"

#ifdef DEBUGGING
#define DBG(x) x
#else
#define DBG(x)
#endif

typedef struct connection_type_t {
    int active;              //< Whether this state structure is being used
                             //  for a connection
    int conn_id;             //< The connection id
    char * unsafe dptr;      //< Pointer to the remaining data to send
    int dlen;                //< The length of remaining data to send
    char * unsafe prev_dptr; //< Pointer to the previously sent item of data
} connection_type_t;

connection_type_t http_tcp_connections[MAX_HTTP_TCP_CONNECTIONS];

void httpd_init(chanend c_xtcp)
{
    // Listen on the http port
    xtcp_listen(c_xtcp, HTTP_PORT, XTCP_PROTOCOL_TCP);
}

void http_connection_buffer_init()
{
    for (int i = 0; i < MAX_HTTP_TCP_CONNECTIONS; i++ )
    {
        http_tcp_connections[i].active = 0;
        http_tcp_connections[i].dptr = NULL;
    }
}

#pragma unsafe arrays
unsafe void http_tcp_event(chanend c_xtcp, xtcp_connection_t &conn)
{
    switch ((int)conn.event)
    {
        case XTCP_IFUP:
        {
            http_if_up(c_xtcp);
            return;
        }
        case XTCP_IFDOWN:
        case XTCP_ALREADY_HANDLED:
            return;
        default:
            break;
    }

    // Check if the connection is a http connection
    if (conn.local_port == HTTP_PORT)
    {
        switch(conn.event)
        {
            case XTCP_NEW_CONNECTION:
            {
                DBG(printstr("XTCP_NEW_CONNECTION\n");)
                http_accept_connection(c_xtcp, conn);
                return;
            }

            case XTCP_SENT_DATA:
            {
                DBG(printstr("XTCP_SENT_DATA\n");)
                http_tcp_send(c_xtcp, conn);
                break;
            }

            case XTCP_REQUEST_DATA:
            {
                DBG(printstr("XTCP_REQUEST_DATA\n");)
                http_tcp_send(c_xtcp, conn);
                break;
            }

            case XTCP_RESEND_DATA:
            {
                DBG(printstr("XTCP_RESEND_DATA\n");)
                http_tcp_send(c_xtcp, conn);
                break;
            }

            case XTCP_RECV_DATA:
            {
                DBG(printstr("XTCP_RECV_DATA\n");)
                http_recv_data(c_xtcp, conn);
                break;
            }

            case XTCP_TIMED_OUT:
            {
                DBG(printstr("XTCP_TIMED_OUT\n");)
                http_free_connection(conn);
                return;
            }

            case XTCP_ABORTED:
            {
                DBG(printstr("XTCP_ABORTED\n");)
                http_free_connection(conn);
                return;
            }

            case XTCP_CLOSED:
            {
                DBG(printstr("XTCP_CLOSED\n");)
                http_free_connection(conn);
                return;
            }
        }
        conn.event = XTCP_ALREADY_HANDLED;
    }
}

void http_free_connection(xtcp_connection_t &conn)
{
    int i;

    for ( i = 0; i < MAX_HTTP_TCP_CONNECTIONS; i++ )
      {
        if (http_tcp_connections[i].conn_id == conn.id)
          {
            http_tcp_connections[i].active = 0;
          }
      }
}

void http_accept_connection(chanend c_xtcp, xtcp_connection_t &conn)
{
    for(int i = 0; i < MAX_HTTP_TCP_CONNECTIONS; i++)
    {
        if(!http_tcp_connections[i].active)
        {
            http_tcp_connections[i].active = 1;
            http_tcp_connections[i].conn_id = conn.id;
            http_tcp_connections[i].dptr = NULL;
            xtcp_set_connection_appstate(c_xtcp, conn, (xtcp_appstate_t)&http_tcp_connections[i]);

            conn.event = XTCP_ALREADY_HANDLED;
        }
    }
}

unsafe void http_recv_data(chanend c_xtcp, xtcp_connection_t &conn)
{
#define hs ((connection_type_t *)conn.appstate)
    char data[XTCP_CLIENT_BUF_SIZE];
    int len;

    // Receive the data from the TCP stack
    len = xtcp_recv(c_xtcp, data);

    // If we already have data to send, return
    if ( hs == NULL || hs->dptr != NULL)
        return;

    page_t pg = getPage();
    hs->dlen = pg.length;
    hs->dptr = pg.data;

    // If we are required to send data
    if (hs->dptr != NULL)
    {
        xtcp_init_send(c_xtcp, conn);
    }
#undef hs
}

unsafe void http_tcp_send(chanend tcp_svr, xtcp_connection_t &conn)
{
    connection_type_t * alias hs = (connection_type_t *)conn.appstate;

    // Check if we need to resend previous data
    if (conn.event == XTCP_RESEND_DATA) {
        xtcp_send(tcp_svr, (char *)hs->prev_dptr, (hs->dptr - hs->prev_dptr));
        return;
    }

    // Check if we have no data to send
    if (hs->dlen == 0 || hs->dptr == NULL) {
      // Terminates the send process
      xtcp_complete_send(tcp_svr);
      // Reset the data pointer for the next send
      hs->dptr = NULL;

      // In the case of http, we can close the connection
      xtcp_close(tcp_svr, conn);
    }
    // We need to send some new data
    else {
        int len = hs->dlen;

        if (len > conn.mss)
          len = conn.mss;

        DBG(printstr("Length: "); printint(len); printstr("\n");)
        xtcp_send(tcp_svr, (char *)hs->dptr, len);

        hs->prev_dptr = hs->dptr;
        hs->dptr += len;
        hs->dlen -= len;
    }
}

void http_if_up(chanend c_xtcp) {
    xtcp_ipconfig_t ipconfig;
    xtcp_get_ipconfig(c_xtcp, ipconfig);

#if IPV6
    unsigned short a;
    unsigned int i;
    int f;
    xtcp_ipaddr_t *addr = &ipconfig.ipaddr;
    printstr("IPV6 Address = [");
    for(i = 0, f = 0; i < sizeof(xtcp_ipaddr_t); i += 2) {
      a = (addr->u8[i] << 8) + addr->u8[i + 1];
      if(a == 0 && f >= 0) {
        if(f++ == 0) {
          printstr("::");
         }
      } else {
          if(f > 0) {
            f = -1;
          } else if(i > 0) {
              printstr(":");
          }
        printhex(a);
      }
    }
    printstrln("]");
#else
    printstr("IP Address: ");
    printint(ipconfig.ipaddr[0]); printstr(".");
    printint(ipconfig.ipaddr[1]); printstr(".");
    printint(ipconfig.ipaddr[2]); printstr(".");
    printint(ipconfig.ipaddr[3]); printstr("\n");
#endif

}
