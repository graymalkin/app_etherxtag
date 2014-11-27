#include <string.h>
#include <stdlib.h>
#include "web_service.h"
#include "jtag_interface.h"

page_t retVal;
const char* HTTP_HEADER =
        "HTTP/1.0 200 OK\n"
        "Server: xc2/pre-1.0 (http://xmos.com)\n"
        "Content-type: text/html\n"
        "\n";

page_t getPage() {
     char* pageContent = getPageContent();

    int length = (strlen(HTTP_HEADER) + strlen(pageContent)) + 1;
    char * buffer = (char*)calloc(length, sizeof(char));

    strcpy(retVal.data, buffer);
    retVal.length = length;

    strcat(retVal.data, HTTP_HEADER);
    strcat(retVal.data, pageContent);
    strcat(retVal.data, "\0");

    return retVal;
}

char * alias getPageContent() {
    // Create a buffer and initialise it to 0
    char buffer[1024] = {0};

    // strcat a webpage into this buffer
    strcat(buffer, "<!DOCTYPE html>\n"
        "<html>\n"
            "<head>\n"
                "<title>EtherXTag</title>\n"
            "</head>\n"
            "<body>\n"
                "<h1>EtherXTag</h1>\n"
                "<p>In use by: ");
    char * usr = getUser();
    strcat(buffer, usr);
    strcat(buffer, ".</p>\n"
            "</body>\n"
        "</html>\n\n");

    // Calloc some memory on the heap for the buffer
    char * rtnVal = (char*)calloc(strlen(buffer)+1, sizeof(char));

    // Copy the buffer into that memory
    strcpy(rtnVal, buffer);

    // Return a pointer to the calloc'd memory
    return rtnVal;
//    return "";
}

char * alias getUser() {
    return get_current_user();
}
