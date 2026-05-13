#include <SPI.h>
#include "epd2in7_V2.h"
#include "epdpaint.h"
#include "icons.h"       // <-- include all icons

#define COLORED   0
#define UNCOLORED 1

// BUTTONS
#define BTN_A 32   // next icon
#define BTN_B 33   // previous icon

unsigned char canvas[5808];   // 176×264 / 8 = 5808 bytes
Epd epd;

// -----------------------------------------------------
//  ICON BLIT FUNCTION (your working version)
// -----------------------------------------------------
void blitIcon(unsigned char* canvas, int canvasWidth,
              int x, int y,
              const unsigned char* icon, int w, int h)
{
    int canvasBytesPerRow = canvasWidth / 8;
    int iconBytesPerRow = w / 8;

    for (int row = 0; row < h; row++) {
        for (int col = 0; col < w; col++) {

            int iconByteIndex = row * iconBytesPerRow + (col / 8);
            uint8_t iconMask = 0x80 >> (col % 8);
            bool iconPixelOn = (icon[iconByteIndex] & iconMask) != 0;

            int cx = x + col;
            int cy = y + row;
            if (cx < 0 || cx >= canvasWidth || cy < 0 || cy >= 264) continue;

            int canvasByteIndex = cy * canvasBytesPerRow + (cx / 8);
            uint8_t canvasMask = 0x80 >> ((cx % 8));

            if (iconPixelOn)
                canvas[canvasByteIndex] &= ~canvasMask;
            else
                canvas[canvasByteIndex] |= canvasMask;
        }
    }
}

// -----------------------------------------------------
// LIST OF ICONS FOR CYCLING
// (Add/remove icons here based on what you want)
// -----------------------------------------------------
const unsigned char* iconList[] = {
  gImage_clear_night,
  gImage_cloudy,
  gImage_cloudy_night,
  gImage_cloudy_stormy_rain,
  gImage_foggy,
  gImage_partly_cloudy,
  gImage_partly_rainy_night,
  gImage_rain_with_hail,
  gImage_rainy,
  gImage_snowing,
  gImage_stormy_rain,
  gImage_sunny,
  gImage_sunshower,
  gImage_thunderstorm,
  gImage_windy
};
const int ICON_COUNT = sizeof(iconList) / sizeof(iconList[0]);

int currentIconIndex = 0;   // start with first icon

// -----------------------------------------------------
// DRAW SCREEN FUNCTION (called each time icon changes)
// -----------------------------------------------------
void drawScreen()
{
  Paint painter(canvas, 176, 264);
  painter.Clear(UNCOLORED);

  const int ICON_W = 56;
  const int ICON_H = 56;
  const int RIGHT_MARGIN = 10;

  const int ICON_X = 176 - RIGHT_MARGIN - ICON_W; // top-right corner
  const int ICON_Y = 164; // PERFECT position based on your test

  // Draw selected ICON (already rotated in Photoshop)
  blitIcon(canvas, 176, ICON_X, ICON_Y, iconList[currentIconIndex], ICON_W, ICON_H);

  painter.SetRotate(ROTATE_90);   // rotate ONLY text

  // -------------------------
  // Your original UI layout
  // -------------------------
  painter.DrawStringAt(5, 10, "Tuesday", &Font24, COLORED);
  painter.DrawStringAt(140, 70, "26 - 30C", &Font20, COLORED);

  painter.DrawStringAt(5, 40, "Nov 19", &Font24, COLORED);

  painter.DrawHorizontalLine(5, 100, 256, COLORED);

  painter.DrawStringAt(48, 130, "NO EVENTS TODAY", &Font16, COLORED);

  painter.SetRotate(ROTATE_0);

  epd.Display(canvas);
}

void setup() {
  Serial.begin(115200);
  Serial.println("Home Page Render + Icon Switch");

  pinMode(BTN_A, INPUT_PULLUP);
  pinMode(BTN_B, INPUT_PULLUP);

  if (epd.Init() != 0) {
    Serial.println("EPD init failed!");
    return;
  }

  epd.Clear();

  drawScreen();   // draw first screen
}

void loop() {

  // NEXT icon
  if (digitalRead(BTN_A) == LOW) {
    currentIconIndex = (currentIconIndex + 1) % ICON_COUNT;
    drawScreen();
    delay(400);  // debounce
  }

  // PREVIOUS icon
  if (digitalRead(BTN_B) == LOW) {
    currentIconIndex = (currentIconIndex - 1 + ICON_COUNT) % ICON_COUNT;
    drawScreen();
    delay(400);  // debounce
  }
}
