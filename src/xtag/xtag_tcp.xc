#include <inttypes.h>
#include <print.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ethernet_board_conf.h"
#include "ethernet_board_support.h"
#include "xtag_tcp.h"
#include "mdns.h"
#include "jtag_interface.h"

volatile char * unsafe user;
extern xtcp_ipaddr_t current_ip;

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

connection_type_t xtag_tcp_connections[MAX_XTAG_TCP_CONNECTIONS];

void xtag_init(chanend c_xtcp)
{
    xtcp_listen(c_xtcp, ETHER_XTAG_PORT, XTCP_PROTOCOL_TCP);
    xtag_connection_buffer_init();
    user = calloc(sizeof(char), 122);
}

void xtag_connection_buffer_init()
{
    for (int i = 0; i < MAX_XTAG_TCP_CONNECTIONS; i++ )
    {
        xtag_tcp_connections[i].active = 0;
        xtag_tcp_connections[i].dptr = NULL;
    }
}

int given_ip = 0;
#pragma unsafe arrays
void xtag_tcp_event(chanend c_xtcp, xtcp_connection_t &conn, chanend rst_a, chanend ip_out)
{
    switch ((int)conn.event)
    {
        case XTCP_IFUP:
        {
            DBG(printstr("XTCP_IFUP\n");)
            xtag_if_up(c_xtcp);
            return;
        }
        case XTCP_IFDOWN:
        case XTCP_ALREADY_HANDLED:
            return;
        case XTCP_NEW_CONNECTION:
        {
            DBG(printstr("XTCP_NEW_CONNECTION\n");)
            xtag_accept_connection(c_xtcp, conn);

            // We have an IP address, out it to the UDP thread, so it has a destination
            // for packets
            xtcp_ipaddr_t * unsafe current_ip_ptr;
            unsafe {
                current_ip_ptr = &current_ip;
            }
            memcpy(current_ip, conn.remote_addr, 4);

//            if(!given_ip)
//            {
//                given_ip = 1;
//                ip_out <: conn.remote_addr[0];
//                ip_out <: conn.remote_addr[1];
//                ip_out <: conn.remote_addr[2];
//                ip_out <: conn.remote_addr[3];
//            }
            return;
        }

        case XTCP_SENT_DATA:
        {
            DBG(printstr("XTCP_SENT_DATA\n");)
            xtag_tcp_send(c_xtcp, conn);
            break;
        }

        case XTCP_REQUEST_DATA:
        {
            DBG(printstr("XTCP_REQUEST_DATA\n");)
            xtag_tcp_send(c_xtcp, conn);

            break;
        }

        case XTCP_RESEND_DATA:
        {
            DBG(printstr("XTCP_RESEND_DATA\n");)
            xtag_tcp_send(c_xtcp, conn);
            break;
        }

        case XTCP_RECV_DATA:
        {
            DBG(printstr("XTCP_RECV_DATA\n");)
            xtag_recv_data(c_xtcp, conn, rst_a);
            break;
        }

        case XTCP_TIMED_OUT:
        {
            DBG(printstr("XTCP_TIMED_OUT\n");)
            xtag_free_connection(conn);
            return;
        }

        case XTCP_ABORTED:
        {
            DBG(printstr("XTCP_ABORTED\n");)
            xtag_free_connection(conn);
            return;
        }

        case XTCP_CLOSED:
        {
            DBG(printstr("XTCP_CLOSED\n");)
            xtag_free_connection(conn);
            return;
        }
    }
    conn.event = XTCP_ALREADY_HANDLED;
}

void xtag_free_connection(xtcp_connection_t &conn)
{
    int i;

    for ( i = 0; i < MAX_XTAG_TCP_CONNECTIONS; i++ )
      {
        if (xtag_tcp_connections[i].conn_id == conn.id)
          {
            xtag_tcp_connections[i].active = 0;
          }
      }
}

void xtag_accept_connection(chanend c_xtcp, xtcp_connection_t &conn)
{
    for(int i = 0; i < MAX_XTAG_TCP_CONNECTIONS; i++)
    {
        if(!xtag_tcp_connections[i].active)
        {
            xtag_tcp_connections[i].active = 1;
            xtag_tcp_connections[i].conn_id = conn.id;
            xtag_tcp_connections[i].dptr = NULL;
            xtcp_set_connection_appstate(c_xtcp, conn, (xtcp_appstate_t)&xtag_tcp_connections[i]);

            conn.event = XTCP_ALREADY_HANDLED;
        }
    }
}

uint8_t using_b2;
void xtag_recv_data(chanend c_xtcp, xtcp_connection_t &conn, chanend rst_a)
{
#define hs ((connection_type_t *)conn.appstate)
    unsafe {
        if(!hs) return;

        // If we already have data to send, read data into a different buffer
        if (hs->dptr != NULL) {
            using_b2++;
            DBG(printf("Using buffer: %d.\n", (int)using_b2);)
        }

        char buffer_1[XTCP_CLIENT_BUF_SIZE];
        char buffer_2[XTCP_CLIENT_BUF_SIZE];
        jtag_response_t jt;

        int len;

        if(hs->dptr != NULL) {
            len = xtcp_recv(c_xtcp, buffer_1);
            jt = getResponse(buffer_1, len, rst_a);
        } else {
            len = xtcp_recv(c_xtcp, buffer_2);
            jt = getResponse(buffer_2, len, rst_a);
        }

        // Set the data to send
        hs->dptr = jt.data;
        hs->dlen = jt.length;


        if (hs->dptr != NULL){
            if(using_b2 > 0)
                using_b2--;
            xtcp_init_send(c_xtcp, conn);
        }
    }
    conn.event = XTCP_ALREADY_HANDLED;
#undef hs
}

void xtag_tcp_send(chanend tcp_svr, xtcp_connection_t &conn)
{
    unsafe {
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
          if(conn.local_port == 80)
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
}

void xtag_if_up(chanend c_xtcp) {
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
