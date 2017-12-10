#include <msp430.h>

//#define HIMEM 0xF000
//unsigned int volatile * const port = (unsigned int *) PORTBASE;


//int *var = (int*)0x40001000;
//*var = 4;


long    __attribute__((section(".oper"))) upperVar[3];

int main() {
    long count;
    WDTCTL = WDTPW | WDTHOLD;
    PM5CTL0 &= ~LOCKLPM5;
    P3DIR |= 0xc0;
    upperVar[0] = P3DIR;
    count = upperVar[0];
    l1:
    WDTCTL = WDTPW | WDTHOLD;				// Just to mark the begin of loop
    P3OUT &= ~0xc0;  // BLANK 00
    P3OUT ^= 0x40;   // RED   01
    count++;
    if (count > 999999999L) count = 0;      // Artif.pause
    P3OUT |= 0xc0;   // BLANK 11
    P3OUT ^= 0x40;   // GREEN 10
    if (P3OUT != 0xFE) goto l1;
    return 0;
}

