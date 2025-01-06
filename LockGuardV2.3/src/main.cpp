#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>  // MQTT library
#include <TinyGPSPlus.h>
#include <HardwareSerial.h>
#include "FS.h"
#include <SPI.h>
#include <TFT_eSPI.h>  // Hardware-specific library
#include <Firebase_ESP_Client.h>

// Firebase credentials
#define API_KEY "APIKEY"
#define DATABASE_URL "DATABASEURL"

// WiFi credentials
#define WIFI_SSID "OPPO A3 Pro 5G"
#define WIFI_PASSWORD "aaaaaaa1"

// Firebase Data object
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// GPS object
TinyGPSPlus gps;
HardwareSerial SerialGPS(2);  // Create an instance of the HardwareSerial class

const int relayPin = 27;  // Relay pin for solenoid lock

// Timing variables
unsigned long sendDataPrevMillis = 0;
bool doorLocked = true;  // Initial door state is locked
bool invalidattempt = false; 
int count = 0;
bool signupOK = false;

// Set global variables
float currentLat = 0.0;
float currentLon = 0.0;
char timeString[9] = "00:00:00";  // Initialize with a default time

// TFT display setup
TFT_eSPI tft = TFT_eSPI();
#define DISP_X 1
#define DISP_Y 30
#define DISP_W 238
#define DISP_H 50
#define DISP_TCOLOR TFT_WHITE

#define NUM_LEN 12
char numberBuffer[NUM_LEN + 1] = "";
uint8_t numberIndex = 0;
uint16_t threshold = 100;  
#define PASSWORD "1234"  // Set the password here

// Keypad configuration
#define KEY_X 48 // Centre of key
#define KEY_Y 105
#define KEY_W 72 // Width and height
#define KEY_H 40
#define KEY_SPACING_X 1 // X and Y gap
#define KEY_SPACING_Y 1
#define KEY_TEXTSIZE 1   // Font size multiplier

// Create 12 keys for the keypad
char keyLabel[12][5] = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "X", "0", "OK"};
uint16_t keyColor[12] = {
                         TFT_DARKGREY, TFT_DARKGREY, TFT_DARKGREY,
                         TFT_DARKGREY, TFT_DARKGREY, TFT_DARKGREY,
                         TFT_DARKGREY, TFT_DARKGREY, TFT_DARKGREY,
                         TFT_RED, TFT_DARKGREY, TFT_DARKGREEN
                        };

// Setup TFT buttons and keypad
TFT_eSPI_Button key[12];

// Function prototypes
// void updateDistance(float distance);
void updateStatus(String status);
void updateDoorStatus();
void drawKeypad();
void touch_calibrate();  // Add function prototype for touch calibration
void connectToWiFi();

// Function Prototypes (Declarations)
bool sendToFirebaseFloat(const String &path, float value);
bool sendToFirebaseString(const String &path, const char* value);

void setup() {
  Serial.begin(115200);
  while (!Serial);

  // Connect to Wi-Fi
  connectToWiFi();

  // Initialize GPS
  SerialGPS.begin(9600, SERIAL_8N1, 16, 17); // GPS Serial on RX=16, TX=17
  // Initialize the relay pin
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, HIGH); // Initially locked (no power to solenoid)

  // Firebase setup
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  // No need to define tokenStatusCallback again. It is defined in the Firebase library.

  // Sign-up (authenticate Firebase)
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase sign-up successful");
    signupOK = true;
  } else {
    Serial.printf("%s\n", config.signer.signupError.message.c_str());
  }

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Initialize the TFT screen
  tft.init();

  // Set the rotation before we calibrate
  tft.setRotation(0);

  // Calibrate the touch screen and retrieve the scaling factors
  touch_calibrate();

  // Clear the screen
  tft.fillScreen(TFT_BLACK);

  // Draw keypad background
  tft.fillRect(0, 0, 240, 320, TFT_LIGHTGREY);

  // Draw number display area and frame
  tft.fillRect(DISP_X, DISP_Y, DISP_W, DISP_H, TFT_BLACK);
  tft.drawRect(DISP_X, DISP_Y, DISP_W, DISP_H, TFT_WHITE);

  // Draw title of the project
  tft.setFreeFont(&FreeSansBold12pt7b);
  tft.setTextColor(TFT_BLACK);
  tft.drawString("LockGuard", 60, 5);

  updateDoorStatus();
  drawKeypad();
}

void loop() {

  // if (!client.connected()) {
  //   reconnectMQTT();
  // }
  // client.loop();

  if (millis() - sendDataPrevMillis > 15000 || sendDataPrevMillis == 0 || doorLocked == false || invalidattempt == true) {
    sendDataPrevMillis = millis();

    // Read and process GPS data
    while (SerialGPS.available() > 0) {
      char gpsData = SerialGPS.read();
      gps.encode(gpsData);
    }

    // Check if GPS data is available
    if (gps.location.isUpdated() || gps.time.isValid()) {
      // Get the current GPS coordinates
      float currentLat = gps.location.lat();
      float currentLon = gps.location.lng();

      // Get the current time in UTC from GPS
      int hour = gps.time.hour();
      int minute = gps.time.minute();
      int second = gps.time.second();

      // Adjust the time to GMT+7
      hour += 7;
      if (hour >= 24) {
        hour -= 24;
      }

      // Format the time as a string
      char timeString[9];  // HH:MM:SS
      snprintf(timeString, sizeof(timeString), "%02d:%02d:%02d", hour, minute, second);

      // Send GPS data to Firebase with retries
      sendToFirebaseFloat("/gps/latitude", currentLat);
      sendToFirebaseFloat("/gps/longitude", currentLon);
      sendToFirebaseString("/gps/time", timeString);
      
      if(doorLocked) {
        sendToFirebaseString("/gps/lock", "Locked");
      } else if (!doorLocked) {
        sendToFirebaseString("/gps/lock", "Unlocked");
      }

      if(invalidattempt == true) {
        sendToFirebaseString("/gps/lock", "Failed Attempt to Unlock");
      }

      // Print GPS coordinates and Google Maps link to Serial Monitor
      Serial.print("Latitude: ");
      Serial.print(currentLat, 6);  // Print latitude with 6 decimal places
      Serial.print(", Longitude: ");
      Serial.print(currentLon, 6);  // Print longitude with 6 decimal places

      // Google Maps link
      String googleMapsLink = "https://www.google.com/maps?q=" + String(currentLat, 6) + "," + String(currentLon, 6);
      Serial.print(", Google Maps: ");
      Serial.println(googleMapsLink);

    } else {
      Serial.println("No GPS location data available yet.");
      // Send GPS data to Firebase with retries
      sendToFirebaseFloat("/gps/latitude", 0);
      sendToFirebaseFloat("/gps/longitude", 0);
      sendToFirebaseString("/gps/time", "Cannot get GPS Time Data");
      
      if(doorLocked) {
        sendToFirebaseString("/gps/lock", "Locked");
      } else if (!doorLocked) {
        sendToFirebaseString("/gps/lock", "Unlocked");
      }

      if(invalidattempt == true) {
        sendToFirebaseString("/gps/lock", "Failed Attempt to Unlock");
      }
    }
  }

  // Check if the OK button was pressed on the TFT keypad
  uint16_t t_x = 0, t_y = 0; // To store the touch coordinates
  bool pressed = tft.getTouch(&t_x, &t_y, threshold);

  for (uint8_t b = 0; b < 12; b++) {
    if (pressed && key[b].contains(t_x, t_y)) {
      key[b].press(true);  // tell the button it is pressed
    } else {
      key[b].press(false);  // tell the button it is NOT pressed
    }

    if (b == 9 || b == 11) tft.setFreeFont(&FreeMono12pt7b);
    else tft.setFreeFont(&FreeMonoBold12pt7b);

    if (key[b].justReleased()) key[b].drawButton();     // draw normal

    if (key[b].justPressed()) {
      key[b].drawButton(true);  // draw invert

      // OK button pressed (button index 11)
      if (b == 11) {
        if (doorLocked) {
          if (strcmp(numberBuffer, PASSWORD) == 0) {
            updateStatus("Valid Password");
            delay(1000);  // Wait for 1 second
            doorLocked = false;  // Unlock the door
            updateStatus("Unlocked");
            sendToFirebaseString("/gps/lock", "Unlocked");
            updateDoorStatus();  // Update the door status on TFT
            // Unlock the door for 5 seconds
            digitalWrite(relayPin, LOW);  // Unlock the solenoid (open the door)
            delay(5000);  // Wait for 5 seconds
            digitalWrite(relayPin, HIGH);  // Lock the solenoid (close the door)
            doorLocked = true;
            updateStatus("Locked");
            sendToFirebaseString("/gps/lock", "Locked");
            updateDoorStatus();  // Update the door status on TFT
          } else {
            updateStatus("Invalid Password");
            invalidattempt = true;
            sendToFirebaseString("/gps/lock", "Failed Attempt to Unlock");
            delay(5000);  // Wait for 5 second
            updateStatus(""); // Clear the status message
            updateDoorStatus();  // Update the door status on TFT
            invalidattempt = false;
          }
        } 
        numberIndex = 0;  // Reset the number input after pressing OK
        delay(2000); // Wait for 2 seconds before resetting status message
        numberIndex = 0;
        numberBuffer[numberIndex] = 0; // Reset number buffer
        tft.fillRect(DISP_X, DISP_Y, DISP_W, DISP_H, TFT_BLACK);
        tft.drawRect(DISP_X, DISP_Y, DISP_W, DISP_H, TFT_WHITE);
        Serial.println(numberBuffer);
      }

      // if a numberpad button, append the relevant # to the numberBuffer
      if (b < 9 || b == 10) {
        if (numberIndex < NUM_LEN) {
          numberBuffer[numberIndex] = keyLabel[b][0];
          numberIndex++;
          numberBuffer[numberIndex] = 0; // zero terminate
        }
        updateStatus(""); // Clear the old status
      }

      // Del button, so delete last char
      if (b == 9) {
        numberBuffer[numberIndex] = 0;
        if (numberIndex > 0) {
          numberIndex--;
          numberBuffer[numberIndex] = 0;
        }
        updateStatus(""); // Clear the old status
      }

      // Update the number display field
      tft.setTextDatum(TL_DATUM);
      tft.setFreeFont(&FreeMono18pt7b);
      tft.setTextColor(DISP_TCOLOR);
      int xwidth = tft.drawString(numberBuffer, DISP_X + 4, DISP_Y + 12);
      tft.fillRect(DISP_X + 4 + xwidth, DISP_Y + 1, DISP_W - xwidth - 5, DISP_H - 2, TFT_BLACK);
      tft.drawRect(DISP_X, DISP_Y, DISP_W, DISP_H, TFT_WHITE);
      delay(50); // UI debouncing
    }
  }
}

void updateDoorStatus() {
  tft.fillRect(1, 260, 250, 20, TFT_LIGHTGREY);
  tft.drawRect(1, 260, 250, 20, TFT_LIGHTGREY);
  if (doorLocked) {
    tft.setTextColor(TFT_BLACK);
    tft.setFreeFont(&FreeMono9pt7b);
    tft.drawString("Door: Locked", 1, 260);
  } else if (!doorLocked) {
    tft.setTextColor(TFT_BLACK);
    tft.setFreeFont(&FreeMono9pt7b);
    tft.drawString("Door: Unlocked", 1, 260);
  }
}

void updateStatus(String status) {
  tft.fillRect(DISP_X, DISP_Y, DISP_W, DISP_H, TFT_BLACK);
  tft.drawRect(DISP_X, DISP_Y, DISP_W, DISP_H, TFT_WHITE);
  tft.setTextPadding(DISP_W - 8);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setFreeFont(&FreeMono12pt7b);
  tft.setTextDatum(TL_DATUM);
  tft.setTextSize(1);
  tft.drawString(status, DISP_X + 4, DISP_Y + 12);
}

void drawKeypad() {
  // Draw the keys
  for (uint8_t row = 0; row < 4; row++) {
    for (uint8_t col = 0; col < 3; col++) {
      uint8_t b = col + row * 3;

      if (b == 9 || b == 11) tft.setFreeFont(&FreeMono12pt7b);
      else tft.setFreeFont(&FreeMonoBold12pt7b);

      key[b].initButton(&tft, KEY_X + col * (KEY_W + KEY_SPACING_X),
                        KEY_Y + row * (KEY_H + KEY_SPACING_Y),
                        KEY_W, KEY_H, TFT_WHITE, keyColor[b], TFT_WHITE,
                        keyLabel[b], KEY_TEXTSIZE);
      key[b].drawButton();
    }
  }
}

void touch_calibrate() {
  uint16_t calData[5];
  uint8_t calDataOK = 0;

  // Check if calibration file exists and size is correct
  if (SPIFFS.begin()) {
    if (SPIFFS.exists("/TouchCalData")) {
      File f = SPIFFS.open("/TouchCalData", "r");
      if (f.readBytes((char *)calData, 14) == 14) {
        calDataOK = 1;
      }
      f.close();
    }
  }

  if (calDataOK) {
    // Set the calibration data
    tft.setTouch(calData);
    Serial.println("Touch screen calibrated");
  } else {
    Serial.println("Calibrating touch screen...");
    tft.calibrateTouch(calData, TFT_WHITE, TFT_RED, 15);
    Serial.println("Calibration complete");

    // Store calibration data
    if (SPIFFS.begin()) {
      File f = SPIFFS.open("/TouchCalData", "w");
      f.write((const unsigned char *)calData, 14);
      f.close();
    }
  }
}

void connectToWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());
}

// Function Definitions (Implementations)
bool sendToFirebaseFloat(const String &path, float value) {
  bool success = false;
  int retryCount = 3;

  while (retryCount > 0 && !success) {
    if (Firebase.RTDB.setFloat(&fbdo, path.c_str(), value)) {
      Serial.println(path + " sent successfully at " + timeString);
      success = true;
    } else {
      Serial.println("Failed to send " + path + "at " + timeString);
      Serial.println(fbdo.errorReason());
      retryCount--;
      delay(1000);  // Retry delay
    }
  }
  return success;
}

bool sendToFirebaseString(const String &path, const char* value) {
  bool success = false;
  int retryCount = 3;

  while (retryCount > 0 && !success) {
    if (Firebase.RTDB.setString(&fbdo, path.c_str(), value)) {
      Serial.println(path + " sent successfully at " + timeString);
      success = true;
    } else {
      Serial.println("Failed to send " + path + "at " + timeString);
      Serial.println(fbdo.errorReason());
      retryCount--;
      delay(1000);  // Retry delay
    }
  }
  return success;
}
