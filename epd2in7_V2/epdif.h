#ifndef EPDIF_H
#define EPDIF_H

#include <Arduino.h>

// Pin definition - match your DEV_Config.h
#define RST_PIN         22  // Reset
#define DC_PIN          21  // D/C
#define CS_PIN          5   // Chip select (SS)
#define BUSY_PIN        19  // Busy
//#define PWR_PIN         -1  // Power ON (if your module has a PWR pin, else remove)

/*
 If you have separate SCK/MOSI defines in DEV_Config.h keep them there.
 SPI pins will be used via SPI.begin() for ESP32 - we won't hardcode SCK/MISO/MOSI here.
*/

class EpdIf {
public:
    EpdIf(void);
    ~EpdIf(void);

    static int  IfInit(void);
    static void DigitalWrite(int pin, int value); 
    static int  DigitalRead(int pin);
    static void DelayMs(unsigned int delaytime);
    static void SpiTransfer(unsigned char data);
};

#endif
