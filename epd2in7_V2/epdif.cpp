/**
 * epdif.cpp - ESP32-friendly implementation
 */

#include "epdif.h"
#include <SPI.h>

EpdIf::EpdIf() {
};

EpdIf::~EpdIf() {
};

void EpdIf::DigitalWrite(int pin, int value) {
    if (value == 0) digitalWrite(pin, LOW);
    else digitalWrite(pin, HIGH);
}

int EpdIf::DigitalRead(int pin) {
    return digitalRead(pin);
}

void EpdIf::DelayMs(unsigned int delaytime) {
    delay(delaytime);
}

void EpdIf::SpiTransfer(unsigned char data) {
    // Drive CS low for one byte transfer (library expects this behaviour)
    digitalWrite(CS_PIN, LOW);
    SPI.transfer(data);
    digitalWrite(CS_PIN, HIGH);
}

int EpdIf::IfInit(void) {
    // Configure pins
    pinMode(CS_PIN, OUTPUT);
    pinMode(RST_PIN, OUTPUT);
    pinMode(DC_PIN, OUTPUT);
    pinMode(BUSY_PIN, INPUT_PULLUP); // busy often open-collector; pullup is safe
    
    #ifdef PWR_PIN
    pinMode(PWR_PIN, OUTPUT);
    DigitalWrite(PWR_PIN, 1); // power on the module if supported
    #endif

    // Initialize SPI for ESP32
    // Use default VSPI (the Arduino SPI.begin() will use default pins if none provided).
    // If you changed SCK/MOSI pins elsewhere, you can call SPI.begin(SCK, MISO, MOSI, SS)
    SPI.begin(); // safe default - uses VSPI default pins (GPIO18=SCK GPIO19=MISO GPIO23=MOSI)
    // Set transaction speed and mode
    // 10-20 MHz is reasonable for EPD; keep it conservative initially.
    SPI.beginTransaction(SPISettings(20000000, MSBFIRST, SPI_MODE0));

    // Ensure CS is HIGH by default
    digitalWrite(CS_PIN, HIGH);
    // Reset pins default
    digitalWrite(RST_PIN, HIGH);
    digitalWrite(DC_PIN, LOW);

    return 0;
}
