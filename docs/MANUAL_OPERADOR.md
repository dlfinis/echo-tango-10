# Manual del Operador — Arcade Timer 10s

Guía rápida para la persona que opera el kiosko en la feria. **No es documentación técnica.** Si necesitás la documentación para desarrolladores, mirá el `README.md` del repositorio.

---

## 0. Temas visuales disponibles

El kiosko tiene dos temas visuales que cambian colores, copy y gráficos. Podés cambiar entre ellos desde el admin (sección "Tema activo", ver abajo).

- **Selección Colombia** (default). Paleta azul / amarillo / rojo bandera. Copy en español colombiano con jerga de fútbol: "¡GOOOOL!", "¡AL PALO!", "¡AFUERA!", "¡SE PITÓ FINAL!". Marcha de pelotas en la pantalla de espera.
- **Arcade Clásico**. La apariencia original con invasores pixelados, paleta verde neón y copy "¡GANASTE!" / "¡CASI, CASI!" / etc.

Ambos temas funcionan con la misma mecánica: el cronómetro de 10 segundos, los 4 veredictos, el leaderboard, el botón físico. Solo cambia lo visual y el texto.

---

## 1. Cómo encender la tablet

1. Conectá la tablet (Fire HD 8) al cable de alimentación.
2. Mantené presionado el botón de encendido (arriba a la derecha) hasta que aparezca el logo de Amazon.
3. Esperá 10-15 segundos. La pantalla muestra "ARCADE TIMER 10s" con un círculo girando. En pocos segundos aparece la pantalla de espera con el mensaje "¡Presioná el botón para jugar!".
4. Si ves una pantalla negra con un mensaje de error, anotalo y contactá al soporte técnico.

## 2. Cómo entrar al modo administrador

En la pantalla de espera (cuando nadie está jugando) hay un **icono de engranaje** chico en la esquina inferior derecha.

1. Tocá y **mantené presionado** el engranaje durante **3 segundos**.
2. Aparece un círculo verde que se llena alrededor del engranaje — esperá a que se complete.
3. Se abre la pantalla de administración con todas las opciones de configuración.

Para salir: tocá el botón rojo **"Salir"** al final de la pantalla.

## 3. Qué hace cada sección del admin

Las secciones están en orden de arriba hacia abajo. Cada una tiene un título claro.

### 3.0 Tema activo (la primera sección)

Un dropdown arriba de todo permite elegir el tema visual del kiosko. Las opciones son:

- **Selección Colombia** — fútbol, paleta Selección, copy es-CO (default desde v0.2.0).
- **Arcade Clásico** — Space Invaders, paleta neón, copy es-AR.

Tocá el dropdown y elegí. El cambio se aplica al instante (sin reiniciar el kiosko). La selección queda guardada aunque se apague la tablet.

**Cuándo cambiar de tema**: si el evento ya no es futbolero y querés volver al look original, pasá a "Arcade Clásico". Si volvés al mundial o a otro evento deportivo, dejá "Selección Colombia" o creá un tema nuevo (ver `docs/THEMES.md`).

### 3.1 Mensajes de invitación

Los mensajes grandes que aparecen en la pantalla de espera rotando. Por defecto hay 3 mensajes:
- "¡Presioná el botón para jugar!"
- "¿Te animás a los 10 segundos exactos?"
- "¡El que pega en 10.000s gana!"

Podés agregar más mensajes tocando **"+ Agregar mensaje"** abajo de la lista. Para borrar uno, tocá el ícono de tacho de basura a la derecha del mensaje.

**Recomendado**: 3-5 mensajes. Más de 5 hace que el ciclo se sienta lento.

### 3.2 Sub-frases (call to action)

Las frases chicas que aparecen DEBAJO del mensaje principal, en mayúsculas. Por defecto:
- "¡JUGÁ Y GANÁ EL PREMIO!"
- "¿PODÉS ROMPER EL RÉCORD?"
- "¿TENÉS HABILIDAD?"
- "¿SOS CAPAZ DEL RÉCORD?"
- "¡APUNTÁ AL 10 EXACTO!"

Misma mecánica que los mensajes: agregar/borrar. Las sub-frases rotan más rápido que los mensajes.

**Recomendado**: 3-5 sub-frases.

### 3.3 Intervalos de rotación

Tres campos numéricos:

- **Rotación de mensajes**: cada cuántos segundos cambia el mensaje principal. Default: 30 segundos. Recomendado: 20-45.
- **Rotación de sub-frases**: cada cuántos segundos cambia la sub-frase. Default: 6 segundos. Recomendado: 4-10.
- **Rotación del ranking**: cada cuántos segundos se muestra la pantalla de "Últimos ganadores" antes de volver a los mensajes. Default: 15 segundos. **Máximo: 15 segundos.** Rango permitido: 3-15.

### 3.4 Pantalla de resultado

Cuántos segundos queda en pantalla el resultado antes de volver automáticamente a la pantalla de espera. Default: 5 segundos. Rango permitido: 1-60.

### 3.5 Rango de victoria

El rango de tiempo (en segundos) que cuenta como victoria. Por defecto: 9.9990 a 10.0010 (cualquier tiempo entre esos dos valores gana).

**Para probar el juego sin clavar los 10 segundos exactos**, podés cambiar el rango a algo más fácil, por ejemplo:
- **Victoria desde**: 0.4
- **Victoria hasta**: 0.6

Así, soltar el botón a los 0.5 segundos cuenta como victoria. Útil para probar todo el flujo (victoria → nombre → leaderboard → espera).

**Recomendado para el público en general**: dejar el rango default.

### 3.6 Colores

Tres colores personalizables:
- **Fondo**: color de fondo de todas las pantallas.
- **Texto**: color de los textos generales.
- **Acento**: color destacado (botones, bordes, el círculo del long-press del admin).

Cada color tiene un botón "Siguiente color" que cicla por una paleta predefinida. Si necesitás un color específico que no está en la paleta, contactá al soporte técnico.

### 3.7 Conectar Arduino (solo Android)

Este botón conecta la tablet al Arduino que tiene el botón físico del kiosko. Tocá **"Conectar Arduino"** la primera vez que encendés el kiosko.

Si todo sale bien, aparece un mensaje verde "USB conectado". Si falla (cable mal conectado, Arduino sin alimentar), aparece un mensaje rojo con el error.

**Una vez conectado, el Arduino queda conectado hasta que apagues la tablet** — no necesitás volver a tocar este botón.

## 4. Cómo conectar el botón Arduino (primera vez)

1. Conectá el Arduino al puerto USB de la tablet (con un cable USB OTG si la tablet no tiene USB-A).
2. Asegurate de que el Arduino esté alimentado (LED de power encendido).
3. En la tablet, andá al admin (ver sección 2).
4. Tocá **"Conectar Arduino"**.
5. Si aparece "USB conectado", probá apretar el botón físico. La pantalla de espera debería cambiar a la pantalla de juego.

**Si no se conecta**:
- Verificá que el cable esté bien enchufado en ambos extremos.
- Probá con otro cable USB.
- Verificá que el Arduino esté alimentado (LED encendido).
- Si sigue sin funcionar, contactá al soporte técnico.

## 5. Cómo limpiar el ranking

Si querés borrar todos los ganadores (por ejemplo, al inicio del día o después de un evento):

1. Entrá al admin.
2. Tocá el botón rojo **"Borrar base de datos"** al final.
3. Confirmá tocando **"Borrar todo"** en el diálogo.
4. El ranking queda vacío. La próxima victoria lo empieza de nuevo.

**Cuidado**: esta acción NO se puede deshacer.

## 6. Qué hacer si la tablet se queda colgada

1. Mantené presionado el botón de encendido durante **10 segundos** hasta que la tablet se apague.
2. Esperá 5 segundos.
3. Volvé a encender.
4. La tablet debería arrancar normalmente.

Si el problema persiste, contactá al soporte técnico.

## 7. Valores recomendados (resumen rápido)

| Sección | Recomendado | Mínimo | Máximo |
|---|---|---|---|
| Cantidad de mensajes | 3-5 | 1 | sin límite |
| Cantidad de sub-frases | 3-5 | 1 | sin límite |
| Rotación de mensajes | 30s | 1 | 3600 |
| Rotación de sub-frases | 6s | 1 | 3600 |
| Rotación del ranking | 15s | 3 | **15** |
| Pantalla de resultado | 5s | 1 | 60 |
| Rango de victoria (default) | 9.9990 — 10.0010 | — | — |

---

¿Dudas? Contactá al equipo técnico.
