# Conexion Arduino — Arcade Timer 10s

Documento tecnico de hardware, wiring y protocolo serial para el kiosko.

---

## 1. Componentes necesarios

| Componente | Especificacion | Notas |
|---|---|---|
| Arduino | Uno, Nano, Micro o Leonardo | Uno/Nano son los mas simples; Micro/Leonardo usan USB CDC-ACM nativo |
| Boton arcade | Push-button momentaneo (big arcade style) | Los botones Sanwa OBSF-30 o similar son standard en kioskos |
| Cable USB | USB-A a USB-B (Uno) o micro-USB (Nano/Micro) | Conecta Arduino a la tablet |
| Cable USB OTG | Micro-USB OTG (host) → USB-A | Fire HD 8 no tiene USB-A; el OTG la habilita como host |
| Tablet | Amazon Fire HD 8 (gen 10+) | Target de produccion |
| Cinta/termosoldadura | Para conexiones permanentes | Soldar, NO usar Dupont en produccion |

---

## 2. Pin mapping del Arduino

```
Arduino Pin    Funcion              Conexion fisica
─────────────  ──────────────────   ─────────────────────────────
D2             Button input          Una pata del boton → D2
GND            Button ground         Otra pata del boton → GND
LED_BUILTIN    Debug indicator       LED onboard (no requiere wiring)
5V             No conectado          —
VIN            No conectado          — (el USB alimenta el Arduino)
```

**NO se necesita resistor externo** — el sketch usa `INPUT_PULLUP` (resistor interno ~20kΩ a VCC).

---

## 3. Circuito completo (wiring)

```
                    ARDUINO
                 ┌──────────┐
                 │          │
   Boton ────────│ D2       │
   arcade        │          │     USB ──── Cable USB ──── OTG ──── Tablet
   (pata 1)      │          │     port      (Arduino side)  (tablet side)
                 │          │
   Boton ────────│ GND      │
   arcade        │          │
   (pata 2)      │          │
                 │          │
                 │ LED  ●   │ ← LED builtin parpadea con cada pulse (debug)
                 │          │
                 └──────────┘

   Detalle del boton:
   ┌──────────────────────────────┐
   │   BOTON ARCADE               │
   │                              │
   │   Pata COM ──── Arduino D2   │
   │   Pata NO  ──── Arduino GND  │
   │                              │
   │   (Pata NC no se conecta)    │
   └──────────────────────────────┘
```

### Diagrama logico del circuito

```
        VCC (+5V)
         │
         │  R_PULLUP (~20kΩ interno)
         │
         ├─── Arduino D2 (INPUT_PULLUP) ──── Serial 0x01 → Tablet
         │
         │   Boton arcade
         │   (momentaneo NO)
         │
         └─── GND
```

**Logica**: D2 lee HIGH por defecto (pull-up a VCC). Al presionar el boton, D2 va a GND = LOW. El sketch detecta la transicion HIGH→LOW y envia `0x01` por Serial.

---

## 4. Protocolo serial

| Parametro | Valor | Detalle |
|---|---|---|
| Baud rate | 9600 | Standard Arduino bootloader rate |
| Data bits | 8 | — |
| Stop bits | 1 | — |
| Paridad | None | 8N1 |
| Flow control | None | Sin RTS/CTS |
| Byte de pulse | `0x01` | Un solo byte por presion |
| Formato | Raw binary, no ASCII | NO es 'P' (ASCII 80) — es byte 0x01 |
| Debounce hardware | 50 ms | Guard en el sketch (minimo) |
| Debounce software | 200 ms | En la app Flutter (StopwatchController) |

### Secuencia de comunicacion

```
Tiempo →
┌─────────────────────────────────────────────────────────┐
│  Arduino:  D2=HIGH (idle)                               │
│  Serial:   silencio                                     │
│                                                         │
│  ████████ Boton presionado ████████                      │
│  Arduino:  D2=LOW → Serial.write(0x01)                  │
│  Tablet:   recibe 0x01 → pulse → cambio de estado       │
│                                                         │
│  ████████ Boton liberado ████████                        │
│  Arduino:  D2=HIGH (idle)                               │
│  Serial:   silencio                                     │
│                                                         │
│  ████████ Boton presionado (2da vez) ████████            │
│  Arduino:  D2=LOW → Serial.write(0x01)                  │
│  Tablet:   recibe 0x01 → pulse → stop stopwatch         │
└─────────────────────────────────────────────────────────┘
```

---

## 5. Conexion fisica step-by-step

### 5.1 Preparar el Arduino

1. Instalar Arduino IDE 2.x (o Arduino CLI).
2. Abrir `arduino/arcade_button/arcade_button.ino` del repo.
3. Selecionar board: **Arduino Uno** (o el board que uses).
4. Compilar y subir el sketch.

### 5.2 Cablear el boton

1. Identificar las patas del boton arcade:
   - **COM** (common) → conectar a **D2** del Arduino.
   - **NO** (normally open) → conectar a **GND** del Arduino.
   - **NC** (normally closed) → NO conectar (ignorar).

2. Para produccion: **SOLDAR** las conexiones. No usar jumper Dupont — se aflojan con el uso repetido del kiosko.

3. Proteger con cinta termosoldable o heat shrink.

### 5.3 Conectar a la tablet

1. Conectar el cable USB del Arduino al **adaptador USB OTG**.
2. Conectar el OTG al puerto micro-USB de la **Fire HD 8**.
3. El Arduino se alimenta por USB — no necesita fuente externa.
4. Android debe ofrecer abrir **Arcade Timer 10s** para el Arduino Uno. Si
   aparece el diálogo, seleccionar la app y aceptar el acceso USB.

### 5.4 Verificar

1. LED de power del Arduino debe estar encendido (rojo/verde fijo).
2. LED builtin (pin 13) debe parpadearse brevemente al presionar el boton.
3. En la tablet: abrir admin → "Conectar Arduino". Debe indicar
   **Conectado · 9600 8N1** y mostrar el nombre/VID:PID del dispositivo.
4. Presionar el botón. El panel debe cambiar **Último byte** a `0x01` y
   aumentar **Pulsos Arduino aceptados**. Esto prueba el recorrido completo:
   botón → Arduino → USB OTG → Android → app.
5. Presionar el botón desde waiting: la pantalla debe pasar a playing.

Si el panel dice "Solicitando permiso USB", aceptar el diálogo Android. Si
indica "No se detectó ningún dispositivo USB", el problema es el OTG/cable o
la alimentación, no el sketch.

---

## 6. Consideraciones criticas

### 6.1 Alimentacion

- El Arduino se alimenta **exclusivamente por USB** desde la tablet. No conectar VIN ni 5V a fuentes externas — esto puede crear conflictos de ground.
- Si la tablet entra en sleep, el USB puede cortar alimentacion. La app usa `WakelockPlus` para evitar sleep.

### 6.2 Debounce doble

El sistema tiene **dos niveles de debounce**:
- **Hardware (50 ms)** en el sketch: evita flooding del buffer serial.
- **Software (200 ms)** en la app: la ventana final de supresion de bounce.

No eliminar ninguno. Si el boton tiene bounce extremo (>200 ms), considerar agregar un capacitor de 100 nF entre D2 y GND como filtro hardware adicional.

### 6.3 Pull-up interno vs externo

- El sketch usa `INPUT_PULLUP` (resistor ~20kΩ interno). Esto es suficiente para botones arcade con cable corto (<1m).
- Si el cable del boton es largo (>2m) o hay interferencia electromagnetica (feria), agregar un **resistor pull-up externo de 10kΩ** entre D2 y VCC y cambiar a `INPUT` en el sketch.

### 6.4 Board selection

| Board | Pros | Contras |
|---|---|---|
| **Uno** | Simple, robusto, USB-B (conector firme) | Grande, necesita cable USB-B |
| **Nano** | Compacto, micro-USB | Micro-USB se afloja con vibracion |
| **Micro/Leonardo** | USB CDC-ACM nativo, tiny | Mas caro, `while(!Serial)` blocking en setup |

**Recomendacion para kiosko**: **Uno** — el conector USB-B es el mas firme para un entorno de feria con vibracion y uso intensivo.

### 6.5 Cable USB OTG

- La Fire HD 8 **no tiene USB-A**. Necesita un adaptador **micro-USB OTG** (host mode).
- El adaptador OTG tiene un pin ID que shorta a GND — esto indica a la tablet que debe actuar como USB host.
- **Verificar**: algunos cables OTG cheap no conectan el pin ID correctamente. Usar uno de calidad.

### 6.6 Ruido electromagnetico

En un kiosko de feria hay motores, luces, speakers. Consideraciones:
- Usar cable **twisted pair** o **shielded** para el boton si el cable es >1m.
- No pasar el cable del boton paralelo a cables de alimentacion de alto consumo.
- Si hay falsos triggers: agregar capacitor 100 nF (0.1 µF) entre D2 y GND, cerca del Arduino.

---

## 7. Troubleshooting

| Problema | Diagnostico | Solucion |
|---|---|---|
| "No hay dispositivos seriales" | Arduino no enumerado por USB | Verificar cable USB, probar otro cable, verificar que la tablet soporta OTG |
| "No se pudo abrir el puerto serial" | Driver CDC-ACM no disponible | Usar Arduino Uno (driver universal); algunos clones CH340 necesitan driver |
| Boton no triggera la app | Byte incorrecto | Verificar que el sketch envie 0x01 (no 'P' ni ASCII 80) — comprobar con Serial Monitor |
| Falsos triggers (pulse sin presionar) | EMI o bounce extremo | Agregar capacitor 100 nF D2-GND; aumentar DEBOUNCE_MS a 100 en sketch |
| LED builtin no parpadea | Sketch no subido o pin incorrecto | Re-subir sketch; verificar PIN_BUTTON = 2 |
| Arduino no recibe power | USB host no alimenta | Algunas tablets no alimentan por OTG — usar hub USB con alimentacion externa |
| Conexion se pierde intermitentemente | Cable flojo | Soldar o usar conector USB-B (Uno); verificar OTG |

---

## 8. Test con Serial Monitor

Antes de conectar a la tablet, probar el Arduino standalone:

1. Conectar Arduino al PC por USB.
2. Abrir Arduino IDE → Serial Monitor (9600 baud).
3. Presionar el boton.
4. Debe aparecer un caracter `☺` (que es 0x01 en ASCII printable) o un byte `01` en modo hex.
5. Si aparece 'P' (ASCII 80): **el sketch es viejo — usar el nuevo que envia 0x01**.

---

## 9. Diagrama de bloques completo

```
┌──────────────┐      USB CDC-ACM      ┌──────────────┐      USB OTG      ┌──────────────┐
│   ARDUINO    │  9600 8N1, byte 0x01  │  Cable USB   │  micro-USB host   │   FIRE HD 8  │
│              │ ──────────────────────►│  + adaptador │◄──────────────────│   (Android)  │
│  D2 ← Boton │                        │  OTG         │                   │              │
│  GND ← Boton│                        └──────────────┘                   │  Flutter app │
│  USB → Host │                                                           │  200ms debounce│
└──────────────┘                                                           └──────────────┘
```

---

## 10. Sketch location

El sketch esta en: `arduino/arcade_button/arcade_button.ino` dentro del repo.
