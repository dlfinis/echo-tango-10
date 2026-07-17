#include <Arduino.h>

constexpr uint8_t BUTTON_PIN = 2;
constexpr uint8_t STATUS_LED_PIN = LED_BUILTIN;
constexpr uint8_t BUTTON_EVENT = 0x01;

constexpr unsigned long DEBOUNCE_MS = 35;

// true: muestra logs para probar en Arduino IDE.
// false: envía únicamente el protocolo limpio hacia Flutter.
constexpr bool DEBUG_MODE = false;

bool lastRawState = HIGH;
bool stableState = HIGH;

unsigned long lastChangeTime = 0;
unsigned long pressCount = 0;

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, LOW);

  Serial.begin(9600);

  if (DEBUG_MODE) {
    delay(300);
    Serial.println();
    Serial.println("[BOOT] Echo Tango iniciado");
    Serial.println("[READY] Esperando pulsaciones");
  }
}

void loop() {
  const bool rawState = digitalRead(BUTTON_PIN);
  const unsigned long now = millis();

  if (rawState != lastRawState) {
    lastRawState = rawState;
    lastChangeTime = now;

    if (DEBUG_MODE) {
      Serial.print("[RAW] Cambio detectado: ");
      Serial.println(rawState == LOW ? "LOW" : "HIGH");
    }
  }

  if (now - lastChangeTime < DEBOUNCE_MS) {
    return;
  }

  if (rawState == stableState) {
    return;
  }

  stableState = rawState;

  if (stableState == LOW) {
    pressCount++;

    digitalWrite(STATUS_LED_PIN, HIGH);

    if (DEBUG_MODE) {
      Serial.print("[BOTON] Pulsacion valida numero ");
      Serial.println(pressCount);
      Serial.println("[LED] Encendido");
      Serial.println("[TX] Evento 0x01 enviado");
    }

    // Señal binaria que Flutter espera.
    Serial.write(BUTTON_EVENT);

  } else {
    digitalWrite(STATUS_LED_PIN, LOW);

    if (DEBUG_MODE) {
      Serial.println("[BOTON] Liberado");
      Serial.println("[LED] Apagado");
    }
  }
}