#ifndef __web_service_h_
#define __web_service_h_

typedef struct page_t {
    unsigned int length;
    char data[1024];
} page_t;

page_t getPage();
char * alias getPageContent();
char * alias getUser();

#endif //__web_service_h_
