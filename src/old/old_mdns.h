#ifndef __mdns_h_
#define __mdns_h_

#include <inttypes.h>

#define SIZE_OF_DNS_HEADER 12  //< Size of header in a dns packet.

enum DNS_RETURN_CODE {
    DNS_NO_ERROR         = 0,  //< No error. The request completed successfully.   RFC 1035

    DNS_FORMAT_ERROR     = 1,  //< Format error. The name server was unable to interpret the query.    RFC 1035

    DNS_SERVER_FAIL      = 2,  //< Server failure. The name server was unable to process this query due to a problem with
                               //  the name server. RFC 1035

    DNS_NAME_ERROR       = 3,  //< Name Error. Meaningful only for responses from an authoritative name server, this code
                               //  signifies that the domain name referenced in the query does not exist.   RFC 1035

    DNS_NOT_IMPLEMENTED  = 4,  //< Not Implemented. The name server does not support the requested kind of query.  RFC 1035

    DNS_REFUSED          = 5,  //< Refused. The name server refuses to perform the specified operation for policy reasons.
                               //  For example, a name server may not wish to provide the information to the particular
                               //  requester, or a name server may not wish to perform a particular operation (e.g., zone
                               //  transfer) for particular data.  RFC 1035

    DNS_YX_DOMAIN        = 6,  //< YXDomain. Name Exists when it should not.   RFC 2136

    DNS_YX_RR_SET        = 7,  //< YXRRSet. RR Set Exists when it should not.  RFC 2136

    DNS_NX_RR_SET        = 8,  //< NXRRSet. RR Set that should exist does not. RFC 2136

    DNS_NOT_AUTHORITATIVE= 9,  //< NotAuth. Server Not Authoritative for zone. RFC 2136

    DNS_NOT_ZONE         = 10, //< NotZone. Name not contained in zone.    RFC 2136

    DNS_BAD_VERS         = 16, //< BADVERS.Bad OPT Version.

    DNS_BAD_KEY          = 17, //< BADKEY. Key not recognized. RFC 2845

    DNS_BAD_TIME         = 18, //< BADTIME. Signature out of time window.  RFC 2845

    DNS_BAD_MODE         = 19, //< BADMODE. Bad TKEY Mode. RFC 2930

    DNS_BAD_NAME         = 20, //< BADNAME. Duplicate key name.    RFC 2930

    DNS_BAD_ALG          = 21, //< BADALG. Algorithm not supported.    RFC 2930

    DNS_BAD_TRUNC        = 22, //< BADTRUNC. Bad truncation.
};


typedef union dns_flags_t {
    uint16_t            value;       //< The value of the whole flags bitfield
    uint16_t            qr     : 1;  //< 0      Query/Response
    uint16_t            opcode : 4;  //< 1-4    Opcode
    uint16_t            aa     : 1;  //< 5      Authoritative Answer
    uint16_t            tc     : 1;  //< 6      Truncated
    uint16_t            rd     : 1;  //< 7      Recursion Desired
    uint16_t            ra     : 1;  //< 8      Recursion Available
    uint16_t            z      : 1;  //< 9      Z
    uint16_t            ad     : 1;  //< 10     Authenticated data
    uint16_t            cd     : 1;  //< 11     Checking Disabled
    enum DNS_RETURN_CODE rcode  : 4; //< 12-15  Return code
} dns_flags_t;

/** \brief DNS Packet header.
 *
 * The header of a DNS packet.
 */
typedef struct dns_packet_header_t {
    uint16_t            id;
    dns_flags_t         flags;
    uint16_t            qdcount;
    uint16_t            ancount;
    uint16_t            nscount;
    uint16_t            arcount;
} dns_packet_header_t;

/** \brief DNS Packet
 *
 * DNS Packet header and payload
 */
typedef struct dns_packet_t {
    dns_packet_header_t header;
    char                *data;
    unsigned int        *questions;     // < ofsets of data for each question record
    unsigned int        *answer_rrs;    // < ofsets of data for each answer record
    unsigned int        *authority_rrs; // < ofsets of data for each authority record
    unsigned int        *aditional_rrs; // < ofsets of data for each aditional record
} dns_packet_t;

/** \brief returns the length of a packet
 *
 * returns the total length of a packet, including it's header and payload.
 */
int count_packet_length(dns_packet_t *pkt);

/** \brief Corrects the endianness of data in a DNS packet
 *
 * ARPA defines internet trafic to be big endian, but most machines now are little endian,
 * so this function corrects that for relevant parts of a packet.
 */
void correct_endianness(dns_packet_t *pkt);

/** \brief Corrects the endiannes of data in a DNS packet header
 *
 * ARPA defines internet trafic to be big endian, but most machines now are little endian,
 * so this function corrects that for relevant parts of a packet.
 */
void correct_header_endianness(dns_packet_header_t *pkt);

/** \brief Encode a packet into a buffer for transmission on a network
 *
 * Fills a given buffer with packet data for transmission on a network.
 */
void encode_packet(dns_packet_t *pkt, char *buffer, int len);

/** \brief Decode a packet from a buffer
 *
 * Read out a buffer, e.g. read from a network, and fill a dns_packet_t object.
 */
dns_packet_t decode_packet(char *buffer);

/** \brief Swap the endianness of a short value
 *
 * Swap the upper and lower octets of a 2 byte value.
 */
uint16_t ntohs(uint16_t val);



#endif // __mdns_h_
