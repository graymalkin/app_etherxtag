/*
 * EtherXTag.xc
 *
 *  Created on: 22 Sep 2014
 *      Author: simonc
 */

#include <print.h>
#include <string.h>

#include "xtcp.h"
#include "xscope_cmd.h"
#include "xscope_udp.h"

xtcp_ipaddr_t current_ip;

int private_data[128] = {0};
char packet_seq = 0;

typedef struct connection_type_t {
    int active;              //< Whether this state structure is being used
                             //  for a connection
    int conn_id;             //< The connection id
    char * unsafe dptr;      //< Pointer to the remaining data to send
    int dlen;                //< The length of remaining data to send
    char * unsafe prev_dptr; //< Pointer to the previously sent item of data
} connection_type_t;
connection_type_t xscope_connection;

void xscope_udp(chanend c_xtcp, client interface xscope_interface xsi, chanend ip_in)
{
    xtcp_connection_t incoming, udp_conn;
    xtcp_ipaddr_t     ip;
    xtcp_listen(c_xtcp, 1338, XTCP_PROTOCOL_UDP);
//    xtcp_connect(c_xtcp, 1338, ip, XTCP_PROTOCOL_UDP);

    xtcp_ipaddr_t * unsafe current_ip_ptr;
    unsafe {
        current_ip_ptr = &current_ip;
    }
    memcpy(&ip, current_ip_ptr, 4);

    while(1)
    {
#pragma ordered
        select
        {
            case xtcp_event(c_xtcp, incoming):
            {
                switch((int)incoming.event)
                {
                    case XTCP_IFUP:
//                        ip_in :> ip_read[0];
//                        ip_in :> ip_read[1];
//                        ip_in :> ip_read[2];
//                        ip_in :> ip_read[3];
                        xtcp_ipconfig_t ipconfig;
                        xtcp_get_ipconfig(c_xtcp, ipconfig);
                        break;
                    case XTCP_NEW_CONNECTION:
                        if(xscope_connection.active == 0
                           && incoming.connection_type == XTCP_PROTOCOL_UDP)
                        {
                            xscope_connection.active = 1;
                            xscope_connection.conn_id = incoming.id;
                            xscope_connection.dptr = NULL;
                            xtcp_set_connection_appstate(c_xtcp, incoming, (xtcp_appstate_t)&xscope_connection);
                            xtcp_connect(c_xtcp, 1338, ip, XTCP_PROTOCOL_UDP);
                            udp_conn = incoming;
                        }
                        break;
                    case XTCP_CLOSED:
                    case XTCP_ABORTED:
                    case XTCP_TIMED_OUT:
                    case XTCP_IFDOWN:
                        //send_flag = -1;
                        break;
                    case XTCP_RECV_DATA:
                        if(incoming.id == xscope_connection.conn_id){
                            char buffer[128];
                            int len = xtcp_recv(c_xtcp, buffer);
                            xscope_cmd * alias recvd = (xscope_cmd * alias)&buffer;
                            if(recvd->cmd == XSCOPE_STOP)
                            {
                                xtcp_close(c_xtcp, udp_conn);
                                xscope_connection.active = 0;
                                udp_conn.id = -1;
                            }
                        }
                        break;
                    case XTCP_RESEND_DATA:
                    case XTCP_REQUEST_DATA:
                        if(incoming.id == xscope_connection.conn_id){
//                          private_data[0] = packet_seq++;
//                          if(incoming.id != -1 && send_flag != -1)
                            xtcp_send(c_xtcp, (private_data, char[]), 512);
                        }
                        break;
                    case XTCP_SENT_DATA:
                        if(incoming.id == xscope_connection.conn_id){
                            xtcp_complete_send(c_xtcp);
                        }
                        break;
                    default: break;
                }
                break;
            }

            case xsi.has_data():
            {
                xsi.get_data(private_data);

                if(xscope_connection.active == 1               // Established
                   && udp_conn.protocol == XTCP_PROTOCOL_UDP)  // Is UDP
                {
                     xtcp_init_send(c_xtcp, udp_conn);
                     // TODO: This is a hack to delay for the other threads
                     for(int i = 0; i < 1000; i++);
                }
                break;
            }
        }
    }
}
