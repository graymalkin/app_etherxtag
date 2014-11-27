#ifndef __web_service_h_
#define __web_service_h_

#define MAX_HTTP_RESPONSE_LENGTH 512
typedef struct page_t {
    unsigned int length;                 //< Length of the page in bytes
    char data[MAX_HTTP_RESPONSE_LENGTH]; //< Page data
} page_t;

/** \brief Return a datastructure for containing an HTTP response.
 *
 * Builds a webpage, and returns a pointer to a datastructure which has the
 * webpage and HTTP header built.
 */
unsafe page_t getPage();
void append_hex(char * dst, int num);
void append(char* s, char c);

#endif //__web_service_h_
