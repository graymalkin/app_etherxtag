#include <jtag.h>
#include <string.h>
#include <stdlib.h>
#include <xs1.h>

#include "itoa.h"
#include "jtag_interface.h"
#include "web_service.h"

char user_name[122];

// Private function prototypes
/** \brief Clear the page datastructure */
void clearData(page_t &retVal);

/** \brief Fill the page data structure with page content */
unsafe void getPageContent(page_t &retVal);

/** \brief Returns a pointer to the string containing the current user's name */
void getUser();

const char* HTTP_HEADER =
        "HTTP/1.0 200 OK\n"
        "Server: xc2/pre-1.0 (http://xmos.com)\n"
        "Content-type: text/html\n"
        "\n";

unsafe page_t getPage() {
    page_t retVal;
    clearData(retVal);
    strcat(retVal.data, HTTP_HEADER);
    getPageContent(retVal);
    strcat(retVal.data, "\0");

    retVal.length = strlen(retVal.data);

    return retVal;
}

void clearData(page_t &retVal) {
    for(int i = 0; i < MAX_HTTP_RESPONSE_LENGTH; i++)
        retVal.data[i] = 0;
}

unsafe void getPageContent(page_t &retVal) {
#define WEBPAGE_TOP                           \
        "<!DOCTYPE html>\n"                   \
        "<html>\n"                            \
            "<head>\n"                        \
                "<title>EtherXTag</title>\n"  \
            "</head>\n"                       \
            "<body>\n"                        \
                "<h1>EtherXTag</h1>\n"        \
                "<p>In use by: "
#define WEBPAGE_MID                           \
            ".</p>\n"                         \
            "<pre>\n"
#define WEBPAGE_BOT                           \
            "</pre>\n"                        \
            "</body>\n"                       \
        "</html>\n\n"                         \

    int total_length = strlen(retVal.data) +
                       strlen(WEBPAGE_TOP) +
                       strlen(WEBPAGE_MID) +
                       strlen(WEBPAGE_BOT);
    strcat(retVal.data, WEBPAGE_TOP);
    //    getUser();
    char * usr = "Not implemented";
    strncat(retVal.data, usr, (MAX_HTTP_RESPONSE_LENGTH - total_length - 1));
    strcat(retVal.data, WEBPAGE_MID);
    /*
    unsafe {
        // dbg_init();
        strcat(retVal.data, "num JTAG taps = ");
        itoa(jtag_get_num_taps(), retVal.data, 4, 10);
        strcat(retVal.data, "\n");

        int numTaps = jtag_get_num_taps();
        for (int i = 0; i < numTaps; i++) {
            strcat(retVal.data, "JTAG TAP ID [");
            itoa(i, retVal.data, 4, 10);
            strcat(retVal.data, "] = 0x");
            append_hex(retVal.data, jtag_get_tap_id(i));
        }
    }
    // */
    strcat(retVal.data, WEBPAGE_BOT);
#undef WEBPAGE_TOP
#undef WEBPAGE_MID
#undef WEBPAGE_BOT
}

void append_hex(char * dst, int num)
{
    char hexbits[16] = { '0', '1', '2', '3', '4', '5', '6', '7',
                         '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };
    // Integers are 4 bytes wide (8 hex digits) -- we should strip the top 4
    //  bits and use that value to index into the lookup table
    for(char i = 0; i < 8; i++)
    {
        num <<= 4; // left shift 4 bits
        // Mask out the lower bits
        append(dst, hexbits[num & 0xF000]);
    }
}

void append(char* s, char c)
{
        int len = strlen(s);
        s[len] = c;
        s[len+1] = '\0';
}

void getUser() {
    get_current_user((char*)user_name);
}

void task_get_user(server interface get_user_interface i) {

}
