#include <print.h>
#include <stdio.h>
#include "ethernet_board_conf.h"    // Config for which ports to use on the sliceKIT
#include "ethernet_board_support.h"
#include "xtcp_client.h"
#include "tcp.h"
#include "mdns.h"
#include "web_service.h"
#include "jtag_interface.h"
//#define DEBUGGING

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

connection_type_t tcp_connections[MAX_TCP_CONNECTIONS];

void httpd_init(chanend c_xtcp)
{
    // Listen on the http port
    xtcp_listen(c_xtcp, 80, XTCP_PROTOCOL_TCP);
}

void xtag_init(chanend c_xtcp)
{
    xtcp_listen(c_xtcp, ETHER_XTAG_PORT, XTCP_PROTOCOL_TCP);
}


void connection_buffer_init()
{
    for (int i = 0; i < MAX_TCP_CONNECTIONS; i++ )
    {
        tcp_connections[i].active = 0;
        tcp_connections[i].dptr = NULL;
    }
}

unsafe void tcp_event(chanend c_xtcp, xtcp_connection_t conn)
{
    switch ((int)conn.event)
    {
      case XTCP_IFUP:
          {
              if_up(c_xtcp);

              // Register this device on the network using an mdns broadcast.
              mdns_register_name("etherxtag");
              mdns_register_service("EtherXTag Service", "_xtag._tcp", 1337, "xtag");
          }
        return;
        case XTCP_IFDOWN:
        case XTCP_ALREADY_HANDLED:
            return;
        default:
            break;
    }

    // Check if the connection is a http connection
    if (conn.local_port == 80 || conn.local_port == ETHER_XTAG_PORT)
    {
        switch (conn.event)
        {
            case XTCP_NEW_CONNECTION:
            {
                DBG(printstr("XTCP_NEW_CONNECTION\n");)
                accept_connection(c_xtcp, conn);
                return;
            }
            case XTCP_RECV_DATA:
            {
                DBG(printstr("XTCP_RECV_DATA\n");)
                recv_data(c_xtcp, conn);
                return;
            }

            case XTCP_SENT_DATA:
            {
                DBG(printstr("XTCP_SENT_DATA\n");)
                tcp_send(c_xtcp, conn);
                break;
            }

            case XTCP_REQUEST_DATA:
            {
                DBG(printstr("XTCP_REQUEST_DATA\n");)
                tcp_send(c_xtcp, conn);
                break;
            }

            case XTCP_RESEND_DATA:
            {
                DBG(printstr("XTCP_RESEND_DATA\n");)
                tcp_send(c_xtcp, conn);
                break;
            }

            case XTCP_TIMED_OUT:
            {
                DBG(printstr("XTCP_TIMED_OUT\n");)
                free_connection(conn);
                return;
            }

            case XTCP_ABORTED:
            {
                DBG(printstr("XTCP_ABORTED\n");)
                free_connection(conn);
                return;
            }

            case XTCP_CLOSED:
            {
                DBG(printstr("XTCP_CLOSED\n");)
                free_connection(conn);
                return;
            }

            default:
                // Ignore anything else
                break;
        }
        conn.event = XTCP_ALREADY_HANDLED;
    }
}

void free_connection(xtcp_connection_t conn)
{
    int i;

    for ( i = 0; i < MAX_TCP_CONNECTIONS; i++ )
      {
        if (tcp_connections[i].conn_id == conn.id)
          {
            tcp_connections[i].active = 0;
          }
      }
}

void accept_connection(chanend c_xtcp, xtcp_connection_t conn)
{
    for(int i = 0; i < MAX_TCP_CONNECTIONS; i++)
    {
        if(!tcp_connections[i].active)
        {
            tcp_connections[i].active = 1;
            tcp_connections[i].conn_id = conn.id;
            tcp_connections[i].dptr = NULL;
            xtcp_set_connection_appstate(c_xtcp, conn, (xtcp_appstate_t)&tcp_connections[i]);

            conn.event = XTCP_ALREADY_HANDLED;
        }
    }
}

unsafe void recv_data(chanend c_xtcp, xtcp_connection_t conn)
{
    struct connection_type_t *hs = (struct connection_type_t *)conn.appstate;

    char data[XTCP_CLIENT_BUF_SIZE];

    // Receive the data from the TCP stack
    int len = xtcp_recv(c_xtcp, data);

    // If we already have data to send, return
    if ( hs == NULL || hs->dptr != NULL)
        return;

    if (conn.local_port == ETHER_XTAG_PORT)
    {
        jtag_response_t jt = getResponse(data, len);
        hs->dptr = jt.data;
        hs->dlen = jt.length;
    }
    else if(conn.local_port == 80)
    {
        page_t pg = getPage();
        hs->dptr = pg.data;
        hs->dlen = pg.length;
    }


    // If we are required to send data
    if (hs->dptr != NULL)
    {
        // Initate a send request with the TCP stack.
        // It will then reply with event XTCP_REQUEST_DATA
        // when it's ready to send
        xtcp_init_send(c_xtcp, conn);
    }
}

// Send some data back for a HTTP request
unsafe void tcp_send(chanend tcp_svr, xtcp_connection_t conn)
{
  connection_type_t * alias hs = (connection_type_t *)conn.appstate;

  // Check if we need to resend previous data
  if (conn.event == XTCP_RESEND_DATA) {
    xtcp_send(tcp_svr, (char *)hs->prev_dptr, (hs->dptr - hs->prev_dptr));
    return;
  }

  // Check if we have no data to send
  if (hs->dlen == 0 || hs->dptr == NULL)
    {
      // Terminates the send process
      xtcp_complete_send(tcp_svr);
      // Reset the data pointer for the next send
      hs->dptr = NULL;

      // In the case of http, we can close the connection
      if(conn.local_port == 80)
          xtcp_close(tcp_svr, conn);
    }
  // We need to send some new data
  else {
    int len = hs->dlen;

    if (len > conn.mss)
      len = conn.mss;

    printstr("Length: "); printint(len); printstr("\n");
    xtcp_send(tcp_svr, (char *)hs->dptr, len);

    hs->prev_dptr = hs->dptr;
    hs->dptr += len;
    hs->dlen -= len;
  }
}

void if_up(chanend c_xtcp) {
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
