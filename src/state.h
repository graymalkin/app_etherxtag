#ifndef __state_h_
#define __state_h_

/** \brief System state
 *
 * Represents the state of the system, including users, connected devices etc.
 */
typedef struct system_state_t {
    char* currentUser;  // < Current user of the device
} system_state_t ;

#endif // __state_h_
