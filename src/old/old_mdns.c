/**
 * A super simple implementation of MDNS for the XCore.
 */
#include <assert.h>
#include <string.h>
#include <stdlib.h>

#include "old_mdns.h"

void encode_packet(dns_packet_t *pkt, char *buffer, int len)
{
    // Ensure the buffer is big enough to take the packet
    assert(count_packet_length(pkt) < len);
    int pos= 0;

    // header
    memcpy(&buffer + pos, &pkt->header.id, sizeof(uint16_t));
    pos += sizeof(uint16_t);
    memcpy(&buffer + pos, &pkt->header.flags, sizeof(dns_flags_t));
    pos += sizeof(uint16_t);
    memcpy(&buffer + pos, &pkt->header.qdcount, sizeof(uint16_t));

    pos += sizeof(uint16_t);
    memcpy(&buffer + pos, &pkt->header.ancount, sizeof(uint16_t));
    pos += sizeof(uint16_t);
    memcpy(&buffer + pos, &pkt->header.nscount, sizeof(uint16_t));
    pos += sizeof(uint16_t);
    memcpy(&buffer + pos, &pkt->header.arcount, sizeof(uint16_t));
    pos += sizeof(uint16_t);

    // body
    memcpy(&buffer + pos, &pkt->questions, sizeof(uint16_t));
    pos += strlen(pkt->questions);
    memcpy(&buffer + pos, &pkt->answer_rrs, sizeof(uint16_t));
    pos += strlen(pkt->answer_rrs);
    memcpy(&buffer + pos, &pkt->authority_rrs, sizeof(uint16_t));
    pos += strlen(pkt->authority_rrs);
    memcpy(&buffer + pos, &pkt->aditional_rrs, sizeof(uint16_t));
    strlen(pkt->aditional_rrs);
}

dns_packet_t decode_packet(char buffer[])
{
    dns_packet_t packet;
    packet.header.id        = (uint16_t) buffer[0];
    packet.header.flags.value=(buffer[2] << 8) + buffer[3];
    packet.header.qdcount   = (uint16_t) (buffer[4]<< 8) + buffer[5];
    packet.header.ancount   = (uint16_t) (buffer[6]<< 8) + buffer[7];
    packet.header.nscount   = (uint16_t) (buffer[8]<< 8) + buffer[9];
    packet.header.arcount   = (uint16_t) (buffer[10]<< 8) + buffer[11];

    unsigned int* questions = (unsigned int*)malloc(sizeof(int) * packet.header.qdcount);
    unsigned int* answers = (unsigned int*)malloc(sizeof(int) * packet.header.ancount);
    unsigned int* authorities = (unsigned int*)malloc(sizeof(int) * packet.header.nscount);
    unsigned int* aditionals = (unsigned int*)malloc(sizeof(int) * packet.header.arcount);

    int bodyPtr = SIZE_OF_DNS_HEADER;
    for(int i = 0; i < packet.header.qdcount; i++)
    {
        for(; buffer[bodyPtr] != '\0'; bodyPtr++)
            ;
        questions[i] = ++bodyPtr;
    }
    // If we find some questions keep the question count, otherwise set it to null
    packet.questions = packet.header.qdcount ? questions : NULL;

    for(int i = 0; i < packet.header.ancount; i++)
    {
        for(; buffer[bodyPtr] != '\0'; bodyPtr++)
            ;
        answers[i] = ++bodyPtr;
    }
    packet.answer_rrs = packet.header.ancount ? packet.answer_rrs : NULL;


    for(int i = 0; i < packet.header.nscount; i++)
    {
        for(; buffer[bodyPtr] != '\0'; bodyPtr++)
            ;
        authorities[i] = ++bodyPtr;
    }
    packet.authority_rrs = packet.header.nscount ? packet.authority_rrs : NULL;

    for(int i = 0; i < packet.header.arcount; i++)
    {
        for(; buffer[bodyPtr] != '\0'; bodyPtr++)
            ;
        aditionals[i] = ++bodyPtr;
    }
    packet.aditional_rrs = packet.header.arcount ? packet.aditional_rrs : NULL;

    return packet;
}

/*
 * These packets contain pointers to char *s which need to be counted too.
 */
int count_packet_length(dns_packet_t *pkt)
{
    // Take the size of a packet and minus the size of the 4 char points it contains
    int len = sizeof(dns_packet_t) - 4*sizeof(char*);

    // Add the actual size of the 4 char*s
    len += strlen(pkt->questions);
    len += strlen(pkt->answer_rrs);
    len += strlen(pkt->authority_rrs);
    len += strlen(pkt->aditional_rrs);

    return len;
}

uint16_t ntohs(uint16_t val)
{
    return (val >> 8) | (val << 8);
}

void correct_header_endianness(dns_packet_header_t *pkt)
{
    pkt->id = ntohs(pkt->id);
    pkt->qdcount = ntohs(pkt->qdcount);
    pkt->ancount = ntohs(pkt->ancount);
    pkt->nscount = ntohs(pkt->nscount);
    pkt->arcount = ntohs(pkt->arcount);
}

void correct_endianness(dns_packet_t *pkt)
{
    correct_header_endianness(&pkt->header);
}
