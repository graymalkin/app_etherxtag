/*
 * xscope_cmd.h
 *
 *  Created on: 20 Jan 2015
 *      Author: simonc
 */


#ifndef XSCOPE_CMD_H_
#define XSCOPE_CMD_H_

typedef struct xscope_cmd {
    int cmd;
    char data[124];
} xscope_cmd __attribute__((packed));

enum xscope_cmd_types {
    XSCOPE_STOP
};

#endif /* XSCOPE_CMD_H_ */
