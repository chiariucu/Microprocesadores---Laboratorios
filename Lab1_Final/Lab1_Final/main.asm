;
; Lab1_Final.asm
;
; Created: 31/8/2026 15:51:55
; Author : chiar
;

/*
; PARTE 1: PRENDIENDO UN LED.
; Assembler 2: Modificación de Led1.asm para encender otro LED (PB5) y alternar su estado (encender y apagar).


.include "./m328Pdef.inc"
.org 0x00                 ; Coloco la dirección de inicio del programa.

setup:
    ldi r16, 0b00111100   ; Configuro los pines PB2 a PB5 como salidas.
    out DDRB, r16

start:
    ; Enciendo LED en PB5.
    ; Se coloca un '0' lógico en el bit 5.
    ldi r16, 0b11011111   ; Pin PB5 en 0 (encendido).
    out PORTB, r16
    rcall retardo

    ; Apago LED en PB5.
    ; Se coloca un '1' lógico en todos los pines.
    ldi r16, 0b11111111   ; Pin PB5 en 1 (apagado).
    out PORTB, r16
    rcall retardo

    rjmp start            ; Repite el bucle sin cesar.

; Para que no se vea estático, se agrega SUBRUTINA DE RETARDO (básicamente bucles anidados).
retardo:
    ldi r17, 80
loop1:
    ldi r18, 250
loop2:
    ldi r19, 250
loop3:
    dec r19
    brne loop3
    dec r18
    brne loop2
    dec r17
    brne loop1
    ret
*/

/*
; PARTE 2: MANEJO DEL PUERTO.
; Assembler 3: Prender uno a uno los 4 leds disponibles (PB2 a PB5) y luego apagarlos.

.include "./m328Pdef.inc"
.org 0x00                 ; Coloco la dirección de inicio del programa.

setup:
    ldi r16, 0b00111100   ; Configuro los pines PB2 a PB5 como salidas.
    out DDRB, r16
    ldi r16, 0xFF         ; Inicializo el puerto con todos los LEDs apagados.
    out PORTB, r16

start:
    ; Prendo el LED 1 (PB2 en 0 lógico).
    ldi r16, 0b11111011   ; Pin PB2 en 0 (encendido).
    out PORTB, r16
    rcall retardo

    ; Prendo el LED 2 (PB3 en 0 lógico).
    ldi r16, 0b11110111   ; Pin PB3 en 0 (encendido).
    out PORTB, r16
    rcall retardo

    ; Prendo el LED 3 (PB4 en 0 lógico).
    ldi r16, 0b11101111   ; Pin PB4 en 0 (encendido).
    out PORTB, r16
    rcall retardo

    ; Prendo el LED 4 (PB5 en 0 lógico).
    ldi r16, 0b11011111   ; Pin PB5 en 0 (encendido).
    out PORTB, r16
    rcall retardo

    ; Apago todos los LEDs.
    ldi r16, 0b11111111   ; Todos los pines en 1 (apagados).
    out PORTB, r16
    rcall retardo

    rjmp start            ; Repite el bucle sin cesar.

; SUBRUTINA DE RETARDO (bucles anidados para pausa visible).
retardo:
    ldi r17, 80
loop1:
    ldi r18, 250
loop2:
    ldi r19, 250
loop3:
    dec r19
    brne loop3
    dec r18
    brne loop2
    dec r17
    brne loop1
    ret
*/

/*
; PARTE 3: BLINKING LED.
; Assembler 5:

.include "./m328Pdef.inc"
.org 0x00

setup:
    ldi r16, 0b00111100   ; PB2 a PB5 como salidas.
    out DDRB, r16.
    ldi r16, 0b11111011   ; Arranca con PB2 encendido (0 lógico)
    out PORTB, r16

start:
    rcall retardo_500ms   ; Pausa de 0.5 segundos.

test:
    in r16, PORTB
    sbrc r16, 2           ; Evalúa el estado del bit 2 (PB2).
    rjmp prendo
    rjmp apago

prendo:
    ldi r16, 0b11111011   ; Enciende PB2.
    out PORTB, r16
    rjmp start

apago:
    ldi r16, 0b11111111   ; Apaga PB2.
    out PORTB, r16
    rjmp start

; Subrutina de retardo de 8.000.000 ciclos (0.5 s a 16 MHz)
retardo_500ms:
    ldi r17, 41           
loop1:
    ldi r18, 253          
loop2:
    ldi r19, 0            
loop3:
    dec r19               
    brne loop3            
    dec r18              
    brne loop2            
    dec r17              
    brne loop1            

    ; Se coloca más precisión (+ ciclos). Cargan el valor 568 repartido en r24 y r25.
    ldi r24, low(568)     
    ldi r25, high(568)    
loop_fino:
    sbiw r24, 1           ; Resta un valor inmediato, consumiendo 2 ciclos.
    brne loop_fino        ; Evalúa si se llegó a cero, sino salta consumiendo 2 ciclos.

    nop                   
    nop                   
    ret      
*/


;Assembler 6: Juego de Luces "El Auto Increíble"

.include "m328pdef.inc"

setup:
    ; Configura los pines PB2, PB3, PB4 y PB5 como salidas
    ldi r16, 0b00111100
    out DDRB, r16

start:
    ; Ida, de PB2 a PB5.
    
    ; Paso 1: Encender PB2 (0b11111011)
    ldi r16, 0b11111011
    out PORTB, r16
    rcall retardo_rapido

    ; Paso 2: Encender PB3 (0b11110111)
    ldi r16, 0b11110111
    out PORTB, r16
    rcall retardo_rapido

    ; Paso 3: Encender PB4 (0b11101111)
    ldi r16, 0b11101111
    out PORTB, r16
    rcall retardo_rapido

    ; Paso 4: Encender PB5 (0b11011111)
    ldi r16, 0b11011111
    out PORTB, r16
    rcall retardo_rapido

    ; De PB4 a PB3, da la vuelta.
    
    ; Paso 5: Encender PB4 (0b11101111)
    ldi r16, 0b11101111
    out PORTB, r16
    rcall retardo_rapido

    ; Paso 6: Encender PB3 (0b11110111)
    ldi r16, 0b11110111
    out PORTB, r16
    rcall retardo_rapido

    ; Repetir infinitamente
    rjmp start

; Subrutina de retardo corto para movimiento fluido del LED.
retardo_rapido:
    ldi r17, 10
loop1:
    ldi r18, 200
loop2:
    ldi r19, 0
loop3:
    dec r19
    brne loop3
    dec r18
    brne loop2
    dec r17
    brne loop1
    ret            