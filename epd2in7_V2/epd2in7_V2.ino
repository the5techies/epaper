#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include <SPI.h>
#include "epd2in7_V2.h"
#include "epdpaint.h"
#include "icons.h"
#include <LittleFS.h>
#include <ArduinoJson.h>

#define COLORED 0
#define UNCOLORED 1
#define WIFI_SSID "Tp-link"
#define WIFI_PASSWORD "vellimoozhayil"
#define API_KEY "AIzaSyCWUUIN2Lonf2fX2LCdxVKFdgN8jueEedk"
#define DATABASE_URL "https://e-papper-default-rtdb.firebaseio.com"
#define BTN_A 27
#define BTN_B 26
#define BTN_C 33
#define BTN_D 32
#define BUZZER_PIN 25
#define BATTERY_ADC_PIN 34
#define BATTERY_GND_SW 14

enum Screen { SCREEN_HOME = 0, SCREEN_TIMER = 1, SCREEN_TODO = 2, SCREEN_VERSE = 3, SCREEN_MESSAGE = 4 };

RTC_DATA_ATTR Screen currentScreen = SCREEN_HOME;
RTC_DATA_ATTR uint64_t timerEndTimeMicros = 0;
RTC_DATA_ATTR int timerPreset = 25;
RTC_DATA_ATTR bool timerRunning = false;
RTC_DATA_ATTR int selectedTodoIndex = 0;
RTC_DATA_ATTR int currentEventIndex = 0;
RTC_DATA_ATTR bool showQuote = false;
RTC_DATA_ATTR int verseScrollPage = 0;
RTC_DATA_ATTR int messageScrollPage = 0;
RTC_DATA_ATTR int todoScrollPage = 0;
RTC_DATA_ATTR int updateIntervalSeconds = 3600;

unsigned long lastInteractionTime = 0;
unsigned long lastTimerDisplayUpdate = 0;
bool lastBtnA = HIGH, lastBtnB = HIGH, lastBtnC = HIGH, lastBtnD = HIGH;

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
bool firebaseReady = false;

unsigned char canvas[5808];
Epd epd;

struct { String day, month, timestamp; int dayOfMonth; } cachedDateTime;
struct { int temperature; String icon, description, unit; } cachedWeather;
struct { String title, start, timeStr; } cachedEvents[5];
int eventCount = 0;
struct { String text; bool completed; } cachedTodos[20];
int todoCount = 0;
struct { String text, reference; } cachedVerse;
struct { String text; } cachedQuote;
struct { String message, sentAt; bool seen, active; } cachedMessage;
struct { String displayMode, temperatureUnit; int updateInterval; } cachedSettings;

// =================================================================
// BATTERY & BUZZER
// =================================================================

float readBatteryVoltage() {
  pinMode(BATTERY_GND_SW, OUTPUT);
  digitalWrite(BATTERY_GND_SW, LOW);
  delay(5);
  long sum = 0;
  for (int i = 0; i < 50; i++) {
    sum += analogRead(BATTERY_ADC_PIN);
    delayMicroseconds(150);
  }
  pinMode(BATTERY_GND_SW, INPUT);
  return ((sum / 50.0) / 4095.0) * 3.3 * 2.45;
}

int getBatteryPercentage() {
  float v = readBatteryVoltage();
  float p = ((v - 3.6) / 0.525) * 100.0;
  return (int)constrain(p, 0, 100);
}

void beep(int ms) {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(ms);
  digitalWrite(BUZZER_PIN, LOW);
}

void beepMessageAlert() { beep(100); delay(150); beep(100); }
void beepTimerDone() { beep(300); delay(200); beep(300); delay(200); beep(300); }

// =================================================================
// LittleFS
// =================================================================

void saveToLittleFS() {
  DynamicJsonDocument doc(6144);
  doc["datetime"]["day"] = cachedDateTime.day;
  doc["datetime"]["month"] = cachedDateTime.month;
  doc["datetime"]["dayOfMonth"] = cachedDateTime.dayOfMonth;
  doc["datetime"]["timestamp"] = cachedDateTime.timestamp;
  doc["weather"]["temperature"] = cachedWeather.temperature;
  doc["weather"]["icon"] = cachedWeather.icon;
  doc["weather"]["description"] = cachedWeather.description;
  doc["weather"]["unit"] = cachedWeather.unit;
  doc["settings"]["displayMode"] = cachedSettings.displayMode;
  doc["settings"]["updateInterval"] = cachedSettings.updateInterval;
  doc["settings"]["temperatureUnit"] = cachedSettings.temperatureUnit;
  doc["eventCount"] = eventCount;
  for (int i = 0; i < eventCount; i++) {
    doc["events"][i]["title"] = cachedEvents[i].title;
    doc["events"][i]["start"] = cachedEvents[i].start;
    doc["events"][i]["timeStr"] = cachedEvents[i].timeStr;
  }
  doc["todoCount"] = todoCount;
  for (int i = 0; i < todoCount; i++) {
    doc["todos"][i]["text"] = cachedTodos[i].text;
    doc["todos"][i]["completed"] = cachedTodos[i].completed;
  }
  doc["verse"]["text"] = cachedVerse.text;
  doc["verse"]["reference"] = cachedVerse.reference;
  doc["quote"]["text"] = cachedQuote.text;
  doc["message"]["message"] = cachedMessage.message;
  doc["message"]["sentAt"] = cachedMessage.sentAt;
  doc["message"]["seen"] = cachedMessage.seen;
  doc["message"]["active"] = cachedMessage.active;
  
  File file = LittleFS.open("/data.json", "w");
  if (file) { serializeJson(doc, file); file.close(); }
}

void loadFromLittleFS() {
  File file = LittleFS.open("/data.json", "r");
  if (!file) return;
  
  DynamicJsonDocument doc(6144);
  if (deserializeJson(doc, file)) { file.close(); return; }
  
  cachedDateTime.day = doc["datetime"]["day"].as<String>();
  cachedDateTime.month = doc["datetime"]["month"].as<String>();
  cachedDateTime.dayOfMonth = doc["datetime"]["dayOfMonth"];
  cachedDateTime.timestamp = doc["datetime"]["timestamp"].as<String>();
  cachedWeather.temperature = doc["weather"]["temperature"];
  cachedWeather.icon = doc["weather"]["icon"].as<String>();
  cachedWeather.description = doc["weather"]["description"].as<String>();
  cachedWeather.unit = doc["weather"]["unit"].as<String>();
  cachedSettings.displayMode = doc["settings"]["displayMode"].as<String>();
  cachedSettings.updateInterval = doc["settings"]["updateInterval"];
  cachedSettings.temperatureUnit = doc["settings"]["temperatureUnit"].as<String>();
  eventCount = doc["eventCount"];
  for (int i = 0; i < eventCount; i++) {
    cachedEvents[i].title = doc["events"][i]["title"].as<String>();
    cachedEvents[i].start = doc["events"][i]["start"].as<String>();
    cachedEvents[i].timeStr = doc["events"][i]["timeStr"].as<String>();
  }
  todoCount = doc["todoCount"];
  for (int i = 0; i < todoCount; i++) {
    cachedTodos[i].text = doc["todos"][i]["text"].as<String>();
    cachedTodos[i].completed = doc["todos"][i]["completed"];
  }
  cachedVerse.text = doc["verse"]["text"].as<String>();
  cachedVerse.reference = doc["verse"]["reference"].as<String>();
  cachedQuote.text = doc["quote"]["text"].as<String>();
  cachedMessage.message = doc["message"]["message"].as<String>();
  cachedMessage.sentAt = doc["message"]["sentAt"].as<String>();
  cachedMessage.seen = doc["message"]["seen"];
  cachedMessage.active = doc["message"]["active"];
  file.close();
}

// =================================================================
// HELPERS
// =================================================================

String extractEventTime(String isoDateTime) {
  if (isoDateTime.length() < 16) return "";
  int tIndex = isoDateTime.indexOf('T');
  if (tIndex == -1) return "";
  String timePart = isoDateTime.substring(tIndex + 1, tIndex + 6);
  int hour = timePart.substring(0, 2).toInt();
  int minute = timePart.substring(3, 5).toInt();
  String result = "@";
  if (hour > 12) hour -= 12;
  else if (hour == 0) hour = 12;
  result += String(hour);
  if (minute != 0) result += (minute < 10 ? ":0" : ":") + String(minute);
  return result;
}

const unsigned char* getWeatherIcon(String iconName) {
  if (iconName == "sunny") return gImage_sunny;
  if (iconName == "clear_night") return gImage_clear_night;
  if (iconName == "cloudy") return gImage_cloudy;
  if (iconName == "cloudy_night") return gImage_cloudy_night;
  if (iconName == "partly_cloudy") return gImage_partly_cloudy;
  if (iconName == "partly_rainy_night") return gImage_partly_rainy_night;
  if (iconName == "rainy") return gImage_rainy;
  if (iconName == "thunderstorm") return gImage_thunderstorm;
  if (iconName == "foggy") return gImage_foggy;
  if (iconName == "stormy_rain") return gImage_stormy_rain;
  if (iconName == "sunshower") return gImage_sunshower;
  if (iconName == "windy") return gImage_windy;
  if (iconName == "cloudy_stormy_rain") return gImage_cloudy_stormy_rain;
  return gImage_cloudy;
}

void blitIcon(unsigned char* canvas, int w, int x, int y, const unsigned char* icon, int iw, int ih) {
  int cbpr = w / 8, ibpr = iw / 8;
  for (int r = 0; r < ih; r++) {
    for (int c = 0; c < iw; c++) {
      int ibi = r * ibpr + (c / 8);
      uint8_t im = 0x80 >> (c % 8);
      bool ip = (icon[ibi] & im) != 0;
      int cx = x + (iw - 1 - c), cy = y + (ih - 1 - r);
      if (cx < 0 || cx >= w || cy < 0 || cy >= 264) continue;
      int cbi = cy * cbpr + (cx / 8);
      uint8_t cm = 0x80 >> (cx % 8);
      if (ip) canvas[cbi] &= ~cm;
      else canvas[cbi] |= cm;
    }
  }
}

int countTextLines(String text, int maxChars) {
  if (!text.length()) return 1;
  int lineCount = 0;
  while (text.length() > 0 && lineCount < 50) {
    if (text.length() <= maxChars) { lineCount++; break; }
    int bp = text.lastIndexOf(' ', maxChars);
    if (bp <= 0) bp = maxChars;
    text = text.substring(bp + 1);
    text.trim();
    lineCount++;
  }
  return max(1, lineCount);
}

// =================================================================
// FIREBASE
// =================================================================

void connectWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) { delay(500); attempts++; }
}

void initFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  if (Firebase.signUp(&config, &auth, "", "")) firebaseReady = true;
  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void fetchFirebaseData() {
  if (!firebaseReady) return;
  
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/settings/displayMode"))
    cachedSettings.displayMode = fbdo.stringData();
  if (Firebase.RTDB.getInt(&fbdo, "esp32_desk_display/settings/updateInterval")) {
    cachedSettings.updateInterval = fbdo.intData();
    updateIntervalSeconds = cachedSettings.updateInterval;
  }
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/settings/temperatureUnit"))
    cachedSettings.temperatureUnit = fbdo.stringData();
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/datetime/day"))
    cachedDateTime.day = fbdo.stringData();
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/datetime/month"))
    cachedDateTime.month = fbdo.stringData();
  if (Firebase.RTDB.getInt(&fbdo, "esp32_desk_display/datetime/dayOfMonth"))
    cachedDateTime.dayOfMonth = fbdo.intData();
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/datetime/timestamp"))
    cachedDateTime.timestamp = fbdo.stringData();
  if (Firebase.RTDB.getInt(&fbdo, "esp32_desk_display/weather/temperature"))
    cachedWeather.temperature = fbdo.intData();
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/weather/icon"))
    cachedWeather.icon = fbdo.stringData();
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/weather/description"))
    cachedWeather.description = fbdo.stringData();
  
  eventCount = 0;
  for (int i = 1; i <= 3; i++) {
    if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/calendar/events/event_" + String(i) + "/title")) {
      cachedEvents[eventCount].title = fbdo.stringData();
      if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/calendar/events/event_" + String(i) + "/start")) {
        cachedEvents[eventCount].start = fbdo.stringData();
        cachedEvents[eventCount].timeStr = extractEventTime(fbdo.stringData());
      }
      eventCount++;
    } else break;
  }
  
  todoCount = 0;
  for (int i = 1; i <= 10; i++) {
    if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/todos/todo_" + String(i) + "/text")) {
      cachedTodos[todoCount].text = fbdo.stringData();
      if (Firebase.RTDB.getBool(&fbdo, "esp32_desk_display/todos/todo_" + String(i) + "/completed"))
        cachedTodos[todoCount].completed = fbdo.boolData();
      todoCount++;
    } else break;
  }
  
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/dailyContent/verse/text"))
    cachedVerse.text = fbdo.stringData();
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/dailyContent/verse/reference"))
    cachedVerse.reference = fbdo.stringData();
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/dailyContent/quote"))
    cachedQuote.text = fbdo.stringData();
  
  bool wasActive = cachedMessage.active, wasSeen = cachedMessage.seen;
  if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/customMessage/message"))
    cachedMessage.message = fbdo.stringData();
  if (Firebase.RTDB.getBool(&fbdo, "esp32_desk_display/customMessage/active"))
    cachedMessage.active = fbdo.boolData();
  if (Firebase.RTDB.getBool(&fbdo, "esp32_desk_display/customMessage/seen"))
    cachedMessage.seen = fbdo.boolData();
  
  if (cachedMessage.active && !cachedMessage.seen && (!wasActive || wasSeen))
    beepMessageAlert();
  
  saveToLittleFS();
}

// =================================================================
// SCREEN DRAWING
// =================================================================

void drawHomeScreen() {
  Paint p(canvas, 176, 264);
  p.Clear(UNCOLORED);
  blitIcon(canvas, 176, 9, 65, getWeatherIcon(cachedWeather.icon), 56, 56);
  p.SetRotate(ROTATE_270);
  p.DrawStringAt(5, 10, cachedDateTime.day.c_str(), &Font24, COLORED);
  String t = String(cachedWeather.temperature) + (cachedSettings.temperatureUnit == "fahrenheit" ? "F" : "C");
  p.DrawStringAt(210, 30, t.c_str(), &Font20, COLORED);
  String d = cachedDateTime.month.substring(0, 3) + " " + String(cachedDateTime.dayOfMonth);
  p.DrawStringAt(5, 40, d.c_str(), &Font24, COLORED);
  p.DrawStringAt((264 - cachedWeather.description.length() * 11) / 2, 75, cachedWeather.description.c_str(), &Font16, COLORED);
  p.DrawHorizontalLine(5, 100, 256, COLORED);
  
  String dt;
  bool comp = false;
  if (cachedSettings.displayMode == "calendar") {
    dt = (eventCount > 0 && currentEventIndex < eventCount) ? 
         cachedEvents[currentEventIndex].title + " " + cachedEvents[currentEventIndex].timeStr : "NO EVENTS TODAY";
  } else {
    dt = "NO TODOS";
    for (int i = 0; i < todoCount; i++) {
      if (!cachedTodos[i].completed) {
        dt = cachedTodos[i].text;
        comp = cachedTodos[i].completed;
        break;
      }
    }
  }
  int cx = (264 - dt.length() * 11) / 2;
  p.DrawStringAt(cx, 130, dt.c_str(), &Font16, COLORED);
  if (cachedSettings.displayMode == "todo" && comp)
    p.DrawHorizontalLine(cx, 138, min(cx + (int)(dt.length() * 11), 250), COLORED);
  p.SetRotate(ROTATE_0);
  epd.Display(canvas);
}

void drawTimerScreen() {
  Paint p(canvas, 176, 264);
  p.Clear(UNCOLORED);
  p.SetRotate(ROTATE_270);
  p.DrawStringAt(90, 10, "TIMER", &Font24, COLORED);
  
  if (timerRunning) {
    uint64_t now = esp_timer_get_time();
    if (now >= timerEndTimeMicros) {
      String msg = "0 min LEFT";
      int tw = msg.length() * 16;
      int cx = (264 - tw) / 2;
      p.DrawStringAt(cx, 80, msg.c_str(), &Font24, COLORED);
      p.DrawStringAt(40, 140, "Great work!", &Font20, COLORED);
      p.DrawStringAt(50, 170, "Take a break", &Font16, COLORED);
    } else {
      uint64_t rem = timerEndTimeMicros - now;
      int mins = (rem / 60000000) + 1;  // Round up
      String minStr = String(mins) + " min LEFT";
      int tw = minStr.length() * 16;
      int cx = (264 - tw) / 2;
      p.DrawStringAt(cx, 80, minStr.c_str(), &Font24, COLORED);
    }
  } else {
    String presetStr = String(timerPreset) + " min LEFT";
    int tw = presetStr.length() * 16;
    int cx = (264 - tw) / 2;
    p.DrawStringAt(cx, 80, presetStr.c_str(), &Font24, COLORED);
    p.DrawStringAt(50, 160, "Press C to start", &Font16, COLORED);
  }
  p.SetRotate(ROTATE_0);
  epd.Display(canvas);
}

void drawTodoScreen() {
  Paint p(canvas, 176, 264);
  p.Clear(UNCOLORED);
  p.SetRotate(ROTATE_270);
  p.DrawStringAt(10, 10, "TODO LIST", &Font20, COLORED);
  int comp = 0;
  for (int i = 0; i < todoCount; i++) if (cachedTodos[i].completed) comp++;
  p.DrawStringAt(220, 10, (String(comp) + "/" + String(todoCount)).c_str(), &Font16, COLORED);
  const int TPP = 8;
  int tp = (todoCount + TPP - 1) / TPP;
  if (tp > 1)
    p.DrawStringAt(220, 30, (String(todoScrollPage + 1) + "/" + String(tp)).c_str(), &Font16, COLORED);
  int si = todoScrollPage * TPP, ei = min(si + TPP, todoCount), y = 40;
  for (int i = si; i < ei; i++) {
    if (i == selectedTodoIndex) p.DrawRectangle(5, y - 2, 250, y + 18, COLORED);
    p.DrawStringAt(10, y, cachedTodos[i].text.c_str(), &Font16, COLORED);
    if (cachedTodos[i].completed)
      p.DrawHorizontalLine(10, y + 8, min(10 + (int)(cachedTodos[i].text.length() * 11), 250), COLORED);
    y += 22;
  }
  p.SetRotate(ROTATE_0);
  epd.Display(canvas);
}

void drawVerseScreen() {
  Paint p(canvas, 176, 264);
  p.Clear(UNCOLORED);
  p.SetRotate(ROTATE_270);
  const int LPP = 7, LH = 20;
  
  String text = showQuote ? cachedQuote.text : cachedVerse.text;
  if (!showQuote && cachedVerse.reference.length() > 0) text += " - " + cachedVerse.reference;
  
  p.DrawStringAt(10, 10, showQuote ? "QUOTE OF THE DAY" : "VERSE OF THE DAY", &Font16, COLORED);
  
  String lines[20];
  int lc = 0, mc = 22;
  while (text.length() > 0 && lc < 20) {
    if (text.length() > mc) {
      int bp = text.lastIndexOf(' ', mc);
      if (bp == -1) bp = mc;
      lines[lc++] = text.substring(0, bp);
      text = text.substring(bp + 1);
    } else { lines[lc++] = text; text = ""; }
  }
  
  int tp = (lc + LPP - 1) / LPP;
  if (tp > 1)
    p.DrawStringAt(220, 10, (String(verseScrollPage + 1) + "/" + String(tp)).c_str(), &Font16, COLORED);
  int sl = verseScrollPage * LPP, y = 40;
  for (int i = sl; i < min(sl + LPP, lc); i++) {
    p.DrawStringAt(10, y, lines[i].c_str(), &Font16, COLORED);
    y += LH;
  }
  p.SetRotate(ROTATE_0);
  epd.Display(canvas);
}

void drawMessageScreen() {
  Paint p(canvas, 176, 264);
  p.Clear(UNCOLORED);
  p.SetRotate(ROTATE_270);
  p.DrawStringAt(10, 10, "MESSAGE", &Font20, COLORED);
  
  if (cachedMessage.active) {
    const int LPP = 7, LH = 20;
    String text = cachedMessage.message, lines[20];
    int lc = 0, mc = 22;
    while (text.length() > 0 && lc < 20) {
      if (text.length() > mc) {
        int bp = text.lastIndexOf(' ', mc);
        if (bp == -1) bp = mc;
        lines[lc++] = text.substring(0, bp);
        text = text.substring(bp + 1);
      } else { lines[lc++] = text; text = ""; }
    }
    int tp = (lc + LPP - 1) / LPP;
    if (tp > 1)
      p.DrawStringAt(220, 10, (String(messageScrollPage + 1) + "/" + String(tp)).c_str(), &Font16, COLORED);
    int sl = messageScrollPage * LPP, y = 50;
    for (int i = sl; i < min(sl + LPP, lc); i++) {
      p.DrawStringAt(10, y, lines[i].c_str(), &Font16, COLORED);
      y += LH;
    }
  } else {
    p.DrawStringAt(60, 120, "No new messages", &Font16, COLORED);
  }
  p.SetRotate(ROTATE_0);
  epd.Display(canvas);
}

void updateDisplay() {
  switch (currentScreen) {
    case SCREEN_HOME: drawHomeScreen(); break;
    case SCREEN_TIMER: drawTimerScreen(); break;
    case SCREEN_TODO: drawTodoScreen(); break;
    case SCREEN_VERSE: drawVerseScreen(); break;
    case SCREEN_MESSAGE: drawMessageScreen(); break;
  }
}

// =================================================================
// BUTTONS
// =================================================================

void handleButtonC() {
  switch (currentScreen) {
    case SCREEN_HOME:
      if (cachedSettings.displayMode == "calendar")
        currentEventIndex = (currentEventIndex + 1) % max(eventCount, 1);
      break;
    case SCREEN_TIMER:
      if (!timerRunning) {
        timerRunning = true;
        timerEndTimeMicros = esp_timer_get_time() + ((uint64_t)timerPreset * 60 * 1000000ULL);
        lastTimerDisplayUpdate = millis();
      } else {
        timerRunning = false;
        timerEndTimeMicros = 0;
      }
      break;
    case SCREEN_TODO:
      if (todoCount > 0 && selectedTodoIndex < todoCount) {
        cachedTodos[selectedTodoIndex].completed = !cachedTodos[selectedTodoIndex].completed;
        saveToLittleFS();
        Firebase.RTDB.setBool(&fbdo, "esp32_desk_display/todos/todo_" + String(selectedTodoIndex + 1) + "/completed", 
                             cachedTodos[selectedTodoIndex].completed);
      }
      break;
    case SCREEN_VERSE:
      showQuote = !showQuote;
      verseScrollPage = 0;
      break;
    case SCREEN_MESSAGE:
      cachedMessage.seen = true;
      saveToLittleFS();
      Firebase.RTDB.setBool(&fbdo, "esp32_desk_display/customMessage/seen", true);
      Firebase.RTDB.setString(&fbdo, "esp32_desk_display/customMessage/seenAt", String(millis()));
      break;
  }
}

void handleButtonD() {
  switch (currentScreen) {
    case SCREEN_HOME:
      if (cachedSettings.displayMode == "todo") {
        for (int i = 0; i < todoCount; i++) {
          if (!cachedTodos[i].completed) {
            cachedTodos[i].completed = true;
            saveToLittleFS();
            Firebase.RTDB.setBool(&fbdo, "esp32_desk_display/todos/todo_" + String(i + 1) + "/completed", true);
            break;
          }
        }
      }
      break;
    case SCREEN_TIMER:
      if (!timerRunning) {
        if (timerPreset == 5) timerPreset = 10;
        else if (timerPreset == 10) timerPreset = 20;
        else if (timerPreset == 20) timerPreset = 25;
        else if (timerPreset == 25) timerPreset = 30;
        else if (timerPreset == 30) timerPreset = 60;
        else timerPreset = 5;
      } else {
        timerRunning = false;
        timerEndTimeMicros = 0;
      }
      break;
    case SCREEN_TODO:
      if (todoCount > 0) {
        selectedTodoIndex = (selectedTodoIndex + 1) % todoCount;
        todoScrollPage = selectedTodoIndex / 8;
      }
      break;
    case SCREEN_VERSE:
      {
        String txt = showQuote ? cachedQuote.text : cachedVerse.text;
        if (!showQuote && cachedVerse.reference.length() > 0) txt += " - " + cachedVerse.reference;
        verseScrollPage = (verseScrollPage + 1) % max(1, (countTextLines(txt, 22) + 6) / 7);
      }
      break;
    case SCREEN_MESSAGE:
      messageScrollPage = (messageScrollPage + 1) % max(1, (countTextLines(cachedMessage.message, 22) + 6) / 7);
      cachedMessage.seen = true;
      saveToLittleFS();
      break;
  }
}

// =================================================================
// SLEEP
// =================================================================

void goToSleep() {
  epd.Sleep();
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  
  esp_sleep_enable_ext0_wakeup((gpio_num_t)BTN_A, 0);
  esp_sleep_enable_timer_wakeup((uint64_t)updateIntervalSeconds * 1000000ULL);
  
  esp_deep_sleep_start();
}

// =================================================================
// SETUP & LOOP
// =================================================================

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  pinMode(BTN_A, INPUT_PULLUP);
  pinMode(BTN_B, INPUT_PULLUP);
  pinMode(BTN_C, INPUT_PULLUP);
  pinMode(BTN_D, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(BATTERY_GND_SW, INPUT);
  digitalWrite(BUZZER_PIN, LOW);
  
  if (!LittleFS.begin(true)) return;
  
  esp_sleep_wakeup_cause_t wr = esp_sleep_get_wakeup_cause();
  
  if (wr == ESP_SLEEP_WAKEUP_EXT0) {
    lastInteractionTime = millis();
    if (epd.Init() != 0) return;
    loadFromLittleFS();
    connectWiFi();
    if (WiFi.status() == WL_CONNECTED) {
      initFirebase();
      for (int i = 0; i < 50 && !firebaseReady; i++) delay(100);
    }
    updateDisplay();
    
  } else if (wr == ESP_SLEEP_WAKEUP_TIMER) {
    if (epd.Init() != 0) return;
    epd.Clear();
    connectWiFi();
    if (WiFi.status() == WL_CONNECTED) {
      initFirebase();
      for (int i = 0; i < 50 && !firebaseReady; i++) delay(100);
      if (firebaseReady) {
        fetchFirebaseData();
        Firebase.RTDB.setInt(&fbdo, "esp32_desk_display/device_status/battery", getBatteryPercentage());
        Firebase.RTDB.setInt(&fbdo, "esp32_desk_display/device_status/wifiStrength", WiFi.RSSI());
        Firebase.RTDB.setString(&fbdo, "esp32_desk_display/device_status/lastSeen", cachedDateTime.timestamp);
        Firebase.RTDB.setBool(&fbdo, "esp32_desk_display/device_status/isOnline", true);
      }
    }
    updateDisplay();
    goToSleep();
    
  } else {
    if (epd.Init() != 0) return;
    epd.Clear();
    connectWiFi();
    if (WiFi.status() == WL_CONNECTED) {
      initFirebase();
      for (int i = 0; i < 50 && !firebaseReady; i++) delay(100);
      if (firebaseReady) {
        fetchFirebaseData();
        if (updateIntervalSeconds == 0) updateIntervalSeconds = 3600;
        Firebase.RTDB.setInt(&fbdo, "esp32_desk_display/device_status/battery", getBatteryPercentage());
        Firebase.RTDB.setInt(&fbdo, "esp32_desk_display/device_status/wifiStrength", WiFi.RSSI());
        Firebase.RTDB.setString(&fbdo, "esp32_desk_display/device_status/lastSeen", cachedDateTime.timestamp);
        Firebase.RTDB.setBool(&fbdo, "esp32_desk_display/device_status/isOnline", true);
      }
    }
    updateDisplay();
    if (cachedMessage.active && !cachedMessage.seen) {
      currentScreen = SCREEN_MESSAGE;
      messageScrollPage = 0;
      updateDisplay();
      beepMessageAlert();
    }
    lastInteractionTime = millis();
  }
}

void loop() {
  bool btnA = (digitalRead(BTN_A) == LOW);
  bool btnB = (digitalRead(BTN_B) == LOW);
  bool btnC = (digitalRead(BTN_C) == LOW);
  bool btnD = (digitalRead(BTN_D) == LOW);
  
  bool bAn = btnA && !lastBtnA;
  bool bBn = btnB && !lastBtnB;
  bool bCn = btnC && !lastBtnC;
  bool bDn = btnD && !lastBtnD;
  
  lastBtnA = btnA; lastBtnB = btnB; lastBtnC = btnC; lastBtnD = btnD;
  
  if (bAn) {
    lastInteractionTime = millis();
    if (currentScreen == SCREEN_MESSAGE && !cachedMessage.seen) {
      cachedMessage.seen = true;
      saveToLittleFS();
      Firebase.RTDB.setBool(&fbdo, "esp32_desk_display/customMessage/seen", true);
      Firebase.RTDB.setString(&fbdo, "esp32_desk_display/customMessage/seenAt", String(millis()));
    }
    currentScreen = (Screen)((currentScreen + 1) % 5);
    if (currentScreen == SCREEN_TODO) {
      todoCount = 0;
      for (int i = 1; i <= 10; i++) {
        if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/todos/todo_" + String(i) + "/text")) {
          cachedTodos[todoCount].text = fbdo.stringData();
          if (Firebase.RTDB.getBool(&fbdo, "esp32_desk_display/todos/todo_" + String(i) + "/completed"))
            cachedTodos[todoCount].completed = fbdo.boolData();
          todoCount++;
        } else break;
      }
      saveToLittleFS();
    }
    updateDisplay();
  }
  
  if (bBn) {
    lastInteractionTime = millis();
    if (currentScreen == SCREEN_MESSAGE && !cachedMessage.seen) {
      cachedMessage.seen = true;
      saveToLittleFS();
      Firebase.RTDB.setBool(&fbdo, "esp32_desk_display/customMessage/seen", true);
      Firebase.RTDB.setString(&fbdo, "esp32_desk_display/customMessage/seenAt", String(millis()));
    }
    currentScreen = (Screen)((currentScreen - 1 + 5) % 5);
    if (currentScreen == SCREEN_TODO) {
      todoCount = 0;
      for (int i = 1; i <= 10; i++) {
        if (Firebase.RTDB.getString(&fbdo, "esp32_desk_display/todos/todo_" + String(i) + "/text")) {
          cachedTodos[todoCount].text = fbdo.stringData();
          if (Firebase.RTDB.getBool(&fbdo, "esp32_desk_display/todos/todo_" + String(i) + "/completed"))
            cachedTodos[todoCount].completed = fbdo.boolData();
          todoCount++;
        } else break;
      }
      saveToLittleFS();
    }
    updateDisplay();
  }
  
  if (bCn) {
    lastInteractionTime = millis();
    if (currentScreen == SCREEN_MESSAGE && !cachedMessage.seen) {
      cachedMessage.seen = true;
      saveToLittleFS();
      Firebase.RTDB.setBool(&fbdo, "esp32_desk_display/customMessage/seen", true);
      Firebase.RTDB.setString(&fbdo, "esp32_desk_display/customMessage/seenAt", String(millis()));
    }
    handleButtonC();
    updateDisplay();
  }
  
  if (bDn) {
    lastInteractionTime = millis();
    if (currentScreen == SCREEN_MESSAGE && !cachedMessage.seen) {
      cachedMessage.seen = true;
      saveToLittleFS();
      Firebase.RTDB.setBool(&fbdo, "esp32_desk_display/customMessage/seen", true);
      Firebase.RTDB.setString(&fbdo, "esp32_desk_display/customMessage/seenAt", String(millis()));
    }
    handleButtonD();
    updateDisplay();
  }
  
  // Timer update logic - stays awake when running
  if (timerRunning) {
    uint64_t now = esp_timer_get_time();
    if (now >= timerEndTimeMicros) {
      timerRunning = false;
      timerEndTimeMicros = 0;
      beepTimerDone();
      if (currentScreen == SCREEN_TIMER) updateDisplay();
    } else if (currentScreen == SCREEN_TIMER) {
      if (millis() - lastTimerDisplayUpdate >= 61000) {
        lastTimerDisplayUpdate = millis();
        updateDisplay();
      }
    }
  }
  
  // Don't sleep if timer is running
  if (!timerRunning && millis() - lastInteractionTime > 30000) {
    goToSleep();
  }
  
  delay(50);
}