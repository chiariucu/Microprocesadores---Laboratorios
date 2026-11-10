
;
; Lab3.asm
;
; Created: 18/10/2026 11:09:48
; Author : chiar
;

.include "m328pdef.inc"

.org 0x0000
	rjmp start

; Vector de interrupción para desbordamiento de Timer 0
.org OVF0addr
	rjmp timer0_ovf_isr

start:
; Inicialización del Stack Pointer (Pila) necesaria para llamadas a subrutinas y uso de PUSH/POP
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

;configuro los puertos:
;	PB2 PB3 PB4 PB5	son los LEDs del shield
;	PB0 es SD (serial data) para el display 7seg
;	PD7 es SCLK, el reloj de los shift registers del display 7seg
;	PD4 es LCH, transfiere los datos que ya ingresaron en serie, a la salida del registro paralelo
;   PC son entradas para los botones (PC0, PC1, PC2)
	ldi		r16,	0b00111101
	out		DDRB,	r16			;4 LEDs del shield son salidas
	ldi		r16,	0b00111000
	out		PORTB,	r16			;apago los LEDs

	ldi		r16,	0b00000000
	out		DDRC,	r16			;3 botones del shield son entradas
	ldi		r16,	0b00001110
; En esta placa, S1 y S2 del shield se leen por PC1 y PC2
	out		PORTC,	r16			;Habilito pull-ups internas en PC0, PC1 y PC2

	ldi		r16,	0b10010000
	out		DDRD,	r16			;configuro PD.4 y PD.7 como salidas
	cbi		PORTD,	7			;PD.7 a 0, es el reloj serial, inicializo a 0
	cbi		PORTD,	4			;PD.4 a 0, es el reloj del latch, inicializo a 0

; Inicializar el estado de la posición del dígito en r19 (0..3)
	clr r19

; Inicializar el contador de ticks para 1 segundo en r20
	clr r20

; Inicializar variables del cronómetro (mm:ss)
	clr r21					; r21 = Unidades de segundos (0-9)
	clr r22					; r22 = Decenas de segundos (0-5)
	clr r23					; r23 = Unidades de minutos (0-9)
	clr r24					; r24 = Decenas de minutos (0-5)
	clr r25					; r25 = Estado del cronómetro (0: Stop, 1: Run)

; Guardar el estado inicial de los botones S1 (PC1) y S2 (PC2)
	ldi r26, 0b00000110

apagar:		; apaga todo el display de 7 segmentos
	ldi r16,0b11111111
	ldi r17,0b11110000
	call sacanum_raw

; Configuración del Timer 0 para interrupciones por desbordamiento
; Prescaler = 1024 (TCCR0B = 0b00000101) -> ~61 Hz de desbordamiento
	ldi r16, (1<<CS02) | (1<<CS00)
	out TCCR0B, r16

; Limpiar cualquier bandera de desbordamiento pendiente
	ldi r16, (1<<TOV0)
	out TIFR0, r16

; Habilitar la interrupción por desbordamiento de Timer 0
	ldi r16, (1<<TOIE0)
	sts TIMSK0, r16

; Habilitar interrupciones globales
	sei

;-------------------------------------------------------------------------------------
; Observar la rutina sacanum, utiliza r16 para los LEDs del número que quiero mostrar, r17 para indicar dónde lo quiero mostrar
; En main: cargo en r16 los leds del número que quiero mostrar, y en r17 indico es el primero de los 4 dígitos.
; Luego se llama la rutina de sacar la información serial.
;
; En el ejemplo para ver el número 0, r16 debe ser 0b00000011 (orden de segmentos es abcdefgh, h es el punto)
; y r17 debe ser 0b00010000 (dígito display de más a la derecha)

/*
;PARTE 1, i)
main:
	ldi r16, 0b10011111 ; Enciendo b y c, formando el número 1.
	ldi r17, 0b10000000 ; Se encenderá en el dígito 1 (el que está más a la izquierda).
	call sacanum
	rjmp main;
*/

/*
;PARTE 1, ii)
main:
	; --- Dígito 1 (más a la izquierda): Mostrar un '1' ---
	ldi r16, 0b10011111		; Máscara para '1'
	ldi r17, 0b10000000		; Dígito 1
	call sacanum

	; --- Dígito 2: Mostrar un '2' ---
	ldi r16, 0b00100101		; Máscara para '2'
	ldi r17, 0b01000000		; Dígito 2
	call sacanum

	; --- Dígito 3: Mostrar un '3' ---
	ldi r16, 0b00001101		; Máscara para '3'
	ldi r17, 0b00100000		; Dígito 3
	call sacanum

	; --- Dígito 4 (más a la derecha): Mostrar un '4' ---
	ldi r16, 0b10011001		; Máscara para '4'
	ldi r17, 0b00010000		; Dígito 4
	call sacanum

	rjmp main				; Repetir infinitamente
*/

/*
;PARTE 1, iii)
main:
	; --- Dígito 1 (más a la izquierda): Mostrar un '1' ---
	ldi r16, 1				; Número decimal '1'
	ldi r17, 0b10000000		; Dígito 1
	call sacanum

	; --- Dígito 2: Mostrar un '2' ---
	ldi r16, 2				; Número decimal '2'
	ldi r17, 0b01000000		; Dígito 2
	call sacanum

	; --- Dígito 3: Mostrar un '3' ---
	ldi r16, 3				; Número decimal '3'
	ldi r17, 0b00100000		; Dígito 3
	call sacanum

	; --- Dígito 4 (más a la derecha): Mostrar un '4' ---
	ldi r16, 4				; Número decimal '4'
	ldi r17, 0b00010000		; Dígito 4
	call sacanum

	rjmp main				; Repetir infinitamente
*/

/*
;PARTE 2, i)
main:
	nop						; La CPU no hace nada aquí, el refresco del display lo realiza el Timer 0 en segundo plano
	rjmp main
*/

/*
;PARTE 2, ii)
main:
	nop						; La CPU libre, el Timer atiende la rotación del display y el LED a 1 Hz
	rjmp main
*/

;PARTE 3 - Cronómetro con display mm:ss y botones Start/Stop/Reset
main:
	; --- Lectura de Botón S1 (PC1) - Start / Stop ---
	in r16, PINC

	; Detectar flanco de pulsación de S1 (antes liberado y ahora presionado)
	sbrc r16, 1
	rjmp chk_btn_reset
	sbrs r26, 1
	rjmp chk_btn_reset

	; Conmutar estado del cronómetro (r25 = r25 XOR 1)
	ldi r17, 1
	eor r25, r17

chk_btn_reset:
	; --- Lectura de Botón S2 (PC2) - Reset ---
	; Detectar flanco de pulsación de S2 (antes liberado y ahora presionado)
	sbrc r16, 2
	rjmp update_buttons
	sbrs r26, 2
	rjmp update_buttons

	; Resetear contadores y detener cronómetro
	clr r21                 ; u_seg = 0
	clr r22                 ; d_seg = 0
	clr r23                 ; u_min = 0
	clr r24                 ; d_min = 0
	clr r25                 ; Estado = Stop
	clr r20                 ; Reiniciar contador de ticks

update_buttons:
	; Guardar el estado actual de los botones
	mov r26, r16
	andi r26, 0b00000110

	rjmp main

;-------------------------------------------------------------------------------------
; Rutina de atención a la interrupción del Timer 0 (Parte 3)
timer0_ovf_isr:
	push r16				; Preservamos registros y SREG
	push r17
	push r18
	push r30
	push r31
	in r16, SREG
	push r16

	; --- Control del avance del tiempo (1 Segundo) ---
	inc r20
	cpi r20, 61
	brne continuar_display
	clr r20
	sbi PINB, 2             ; Titileo del LED PB2 a 1 Hz

	; Verificar si el cronómetro está en marcha (r25 == 1)
	cpi r25, 1
	brne continuar_display

	; Incrementar tiempo: Unidades de segundo
	inc r21
	cpi r21, 10
	brne continuar_display
	clr r21

	; Incrementar tiempo: Decenas de segundo
	inc r22
	cpi r22, 6
	brne continuar_display
	clr r22

	; Incrementar tiempo: Unidades de minuto
	inc r23
	cpi r23, 10
	brne continuar_display
	clr r23

	; Incrementar tiempo: Decenas de minuto
	inc r24
	cpi r24, 6
	brne continuar_display
	clr r24

continuar_display:
	; --- Control de la rotación de dígitos en el display (mm:ss) ---
	cpi r19, 0
	breq caso_dig1
	cpi r19, 1
	breq caso_dig2
	cpi r19, 2
	breq caso_dig3
	rjmp caso_dig4

caso_dig1:
	mov r16, r24            ; Muestra Decenas de Minutos
	ldi r17, 0b10000000     ; En posición 1 (más a la izquierda)
	ldi r19, 1              ; Siguiente posición: 2
	rjmp fin_isr

caso_dig2:
	mov r16, r23            ; Muestra Unidades de Minutos
	ldi r17, 0b01000000     ; En posición 2
	ldi r19, 2              ; Siguiente posición: 3
	rjmp fin_isr

caso_dig3:
	mov r16, r22            ; Muestra Decenas de Segundos
	ldi r17, 0b00100000     ; En posición 3
	ldi r19, 3              ; Siguiente posición: 4
	rjmp fin_isr

caso_dig4:
	mov r16, r21            ; Muestra Unidades de Segundos
	ldi r17, 0b00010000     ; En posición 4 (más a la derecha)
	clr r19                 ; Volver a la posición 1

fin_isr:
	call sacanum            ; Refrescar el dígito correspondiente

	pop r16
	out SREG, r16
	pop r31
	pop r30
	pop r18
	pop r17
	pop r16
	reti

;-------------------------------------------------------------------------------------
; Nueva rutina sacanum (Parte 1.iii)
; r16 - Recibe un número del 0 al 9 (número decimal normal)
; r17 - Recibe la posición del dígito.
sacanum:
	push r30				; Guardamos ZL temporalmente
	push r31				; Guardamos ZH temporalmente
	push r17				; Guardamos el dígito temporalmente

	; Apuntamos el puntero Z al inicio de la tabla en Flash
	ldi ZL, low(tabla_7seg * 2)
	ldi ZH, high(tabla_7seg * 2)

	; Sumamos el número recibido en r16 al puntero Z
	add ZL, r16
	clr r16	; Ponemos r16 en 0 para sumar el acarreo a ZH.
	adc ZH, r16

	; Leemos el patrón traducido de leds desde la Flash y lo dejamos en r16
	lpm r16, Z

	; Enviamos el patrón de leds (r16) y luego la posición del dígito (r17)
	call dato_serie
	pop r17	; Recuperamos el valor del dígito en r17
	push r16 ; Guardamos el patrón de leds
	mov r16, r17
	call dato_serie
	pop r16

	; Damos el pulso de Latch para reflejar en el display
	sbi PORTD, 4
	cbi PORTD, 4

	pop r31					; Restauramos ZH
	pop r30					; Restauramos ZL
	ret

; Rutina para enviar bytes sin traducir (usada únicamente para la etiqueta apagar al inicio)
sacanum_raw:
	call dato_serie
	mov r16, r17
	call dato_serie
	sbi PORTD, 4
	cbi PORTD, 4
	ret

/*
; La rutina sacanum original, envía lo que hay en r16 y r17 al display de 7 segmentos
; r16 - contiene los LEDs a prender/apagar 0 - prende, 1 - apaga
; r17 - contiene el dígito: r17 = 1000xxxx 0100xxxx 0010xxxx 0001xxxx del dígito menos al más significativo.
sacanum:
	call	dato_serie
	mov		r16, r17
	call	dato_serie
	sbi		PORTD, 4		;PD.4 a 1, es LCH el reloj del latch
	cbi		PORTD, 4		;PD.4 a 0,
	ret
*/

; Voy a sacar un byte por el 7seg
dato_serie:
	ldi		r18, 0x08 ; lo utilizo para contar 8 (8 bits)
loop_dato1:
	cbi		PORTD, 7		;SCLK = 0 reloj en 0
	lsr		r16				;roto a la derecha r16 y el bit 0 se pone en el C
	brcs	loop_dato2		;salta si C=1
	cbi		PORTB, 0		;SD = 0 escribo un 0
	rjmp	loop_dato3
loop_dato2:
	sbi		PORTB, 0		;SD = 1 escribo un 1
loop_dato3:
	sbi		PORTD, 7		;SCLK = 1 reloj en 1
	dec		r18
	brne	loop_dato1; cuando r17 llega a 0 corta y vuelve
	ret

.ALIGN 2
tabla_7seg:
	.DB 0b00000011, 0b10011111  ; 0, 1
	.DB 0b00100101, 0b00001101  ; 2, 3
	.DB 0b10011001, 0b01001001  ; 4, 5
	.DB 0b01000001, 0b00011111  ; 6, 7
	.DB 0b00000001, 0b00001001  ; 8, 9

