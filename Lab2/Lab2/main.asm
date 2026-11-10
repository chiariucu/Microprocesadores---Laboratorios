;
; Lab2.asm
;
; Created: 22/9/2026 08:32:43
; Author : chiar
;

; LABORATORIO 2 - PARTE 1: 
; VECTORES DE INTERRUPCIÓN
.ORG 0x0000
    jmp start           ; PARTE 1: Vector de Reset
.ORG 0x0008
    jmp _pcint1_int     ; PARTE 2 Y 3: Interrupción de botones (Puerto C - PCINT1)
.ORG 0x001C 
    jmp _tmr0_int       ; PARTE 1 Y 3: Interrupción Timer0 (OCIE0A). Vector de comparación A del Timer0.

; CONFIGURACIÓN INICIAL (start)
start:
    ; Configuración de puertos (PARTE 1)
    ldi r16, 0b00111100  ; PB2 (D4), PB3 (D3), PB4 y PB5 como SALIDAS
    out DDRB, r16        
    ldi r16, 0b00111100  ; Apagamos todos los LEDs (lógica invertida: 1 = Apagado)
    out PORTB, r16       

	;(PARTE 1 Y 2)
    ldi r16, 0b00000000  ; Puertos C como entradas (botones)
    out DDRC, r16
	ldi r16, 0b00001110  ; PARTE 2: Activa Pull-ups internas para PC1, PC2 y PC3
    out PORTC, r16        

    ; Configuración del Timer0 (PARTE 1)
    ldi r16, 0b00000010
    out TCCR0A, r16      ; Modo CTC (Clear Timer on Compare Match)
    ldi r16, 0b00000101
    out TCCR0B, r16      ; Prescaler = 1024
    ldi r16, 124
    out OCR0A, r16       ; Dispara la interrupción cada 125 cuentas (125 veces/segundo)
    ldi r16, 0b00000010
    sts TIMSK0, r16      ; Habilita la interrupción de comparación A (OCIE0A)

	; Configuración de Interrupción por Cambio de Pin - PCINT1 (PARTE 2)
    ldi r16, 0b00000010  ; Habilita el grupo PCIE1 (Puerto C)
    sts PCICR, r16
    ldi r16, 0b00001110  ; Máscara para habilitar PCINT9, PCINT10, PCINT11 (PC1, PC2, PC3)
    sts PCMSK1, r16

    ; Inicialización de registros de trabajo
    clr r24              ; (PARTE 1) r24: Contador de interrupciones (0 a 62)
    clr r25              ; (PARTE 1) r25: Contador de segundos transcurridos
	clr r17              ; (PARTE 3) r17: Bandera de Marcha/Pausa (0 = Pausado, 1 = Corriendo) (PARTE 3)

; PROGRAMA PRINCIPAL
comienzo:
    sei                  ; (PARTE 1) Habilita las interrupciones globales

loop1: ;(PARTE 1)
    ; Verificar si pasaron 30 segundos en r25 (PARTE 1)
    cpi r25, 30          ; ¿Llegamos a 30 segundos?
    brlo no_pasaron_30   ; Si r25 < 30, salta
    cbi PORTB, 3         ; Si pasaron 30s, enciende el LED D3 (PB3 en 0)
	rjmp fin_chk_30		 

/* (PARTE 1):
	no_pasaron_30:
    nop
    nop
    nop
    nop
    ori r16, 0xFF        ; Modifica banderas de SREG (probado en parte i)
    nop
    nop
    nop
    brne loop1           ; Si la interrupción guarda SREG, jamás sale de loop1


no_pasaron_30:
    sbi PORTB, 3         ; [PARTE 3] Apaga/Mantiene apagado el LED D3 (PB3 en 1) tras un Reset

loop2:
    nop
    nop
    nop
fin:
    rjmp loop2
*/

no_pasaron_30:
    sbi PORTB, 3         ; [PARTE 3] Apaga/Mantiene apagado el LED D3 (PB3 en 1) tras un Reset

fin_chk_30:
    nop
    nop
    rjmp loop1           ; Bucle infinito del programa principal


; RUTINA DE ATENCIÓN A LA INTERRUPCIÓN (PARTE 1 Y 3).
; DESCOMENTAR PARA HACER CORRER PARTE 1 Y 3.
_tmr0_int:
    ; SOLUCIÓN AL BUG DE SREG. (PARTE 1)
    push r16            ; Guardar r16 auxiliar
    in r16, SREG        ; Leer el registro de estado SREG
    push r16            ; Guardar SREG en la pila

	; VERIFICACIÓN DE MARCHA/PAUSA (PARTE 3)
	tst r17             ; Si r17 = 0 (Cronómetro pausado/detenido), sale sin contar
    breq _tmr0_out

	; (PARTES 1 Y 3):
    ; Lógica para contador e inversión del LED
    inc r24             ; Incrementa contador de interrupciones
    cpi r24, 62         ; ¿Llegó a ~62 interrupciones (aproximadamente 0.5 s)?
    brne _tmr0_out      ; Si no llegó a 62, salta al final de la ISR

    ; Si pasaron 62 interrupciones (~0.5 s):
    clr r24             ; Reiniciar el contador r24
    sbi PINB, 2         ; Toggle del LED D4 en PB2 (1 Hz: prende 0.5s / apaga 0.5s)
    inc r25             ; Incrementa el contador de medios segundos (o ajustar a segundos)

	;(PARTE 1):
_tmr0_out:
    ; Restauración segura del estado
    pop r16             ; Recuperar SREG de la pila
    out SREG, r16       ; Restaurar SREG
    pop r16             ; Restaurar r16
    reti                ; Retornar de la interrupción

; RUTINA BOTONES - PCINT1 (PARTE 2): Cambia el estado de un LED al presionar.
; DESCOMENTAR PARA HACER CORRER PARTE 2 Y 3.
_pcint1_int: ;(PARTE 2)
    push r16            ; Guardar r16
    in r16, SREG        ; Leer SREG
    push r16            ; Guardar SREG en la pila

	;(PARTE 2)
    in r16, PINC        ; Lectura obligatoria de PINC para limpiar/actualizar el cambio
	
	;(PARTE 3)
	sbic PINC, 1        ; Si PC1 está en 0 (presionado), salta 'rjmp _chk_s2'
    rjmp _chk_s2

    ldi r16, 1
    eor r17, r16        ; Alterna r17 entre 0 (Pausa) y 1 (Marcha)
    sbi PINB, 4         ; (PARTE 2)Toggle del LED D2 (PB4) al presionar/soltar cualquier botón

	_chk_s2:
    ;(PARTE 3) Botón S2 (PC2). Función Reset.
    sbic PINC, 2        ; Si PC2 está en 0 (presionado), salta 'rjmp _pcint1_exit'
    rjmp _pcint1_exit

    clr r17             ; Detiene el cronómetro (r17 = 0)
    clr r25             ; Reinicia el contador de segundos a 0
    clr r24             ; Reinicia el sub-contador a 0
    sbi PORTB, 3        ; Apaga el LED D3 (PB3 en 1)

	_pcint1_exit:
    ; (PARTE 2)
    pop r16             ; Restaurar SREG
    out SREG, r16
    pop r16             ; Restaurar r16
    reti                ; Retorno de la interrupción