
;===============================================================================
; LABORATORIO 5 - Enlace serial USART entre dos microcontroladores
;
; DESCRIPCIÓN GENERAL:
; El programa permite transmitir y recibir un bloque de 512 bytes mediante
; comunicación USART. Al finalizar la transmisión se envía un checksum de
; 32 bits que permite comprobar si los datos llegaron correctamente.
;
; ORGANIZACIÓN DE LAS RUTINAS:
;
;   generar_...       Generación de datos pseudoaleatorios.
;   calcular_...      Cálculo del checksum del mensaje.
;   enviar_...        Transmisión de información por USART.
;   recibir_...       Recepción de información por USART.
;   verificar_...     Comprobación de los datos recibidos.
;   esperar_...       Esperas y control de los botones.
;   mostrar_...       Control del display de siete segmentos.
;   int_...           Rutinas asociadas a las interrupciones.
;
; RUTINAS DEL PROGRAMA:
;
; generar_aleatorios:
;   Completa el espacio mensaje_512 con 512 bytes generados mediante
;   el algoritmo XORSHIFT de 32 bits.
;
; calcular_checksum:
;   Suma todos los bytes almacenados en mensaje_512.
;   El resultado se guarda en r7:r6:r5:r4.
;   Los dos bytes inferiores (r5:r4) se utilizan para el display.
;
; enviar_mensaje:
;   Envía los 512 bytes del mensaje y posteriormente los cuatro bytes
;   correspondientes al checksum.
;
; recibir_mensaje:
;   Almacena los 512 bytes recibidos y luego guarda el checksum
;   enviado por la otra placa.
;
; verificar_checksum:
;   Compara el resultado local con el valor recibido y actualiza
;   los indicadores luminosos según el resultado.
;
; int_botones:
;   Detecta la pulsación de cualquiera de los tres botones.
;
; int_timer_display:
;   Actualiza periódicamente el display, mostrando los 16 bits
;   inferiores del checksum.
;
; mostrar_digito / enviar_byte_display / tabla_7segmentos:
;   Se encargan de controlar los registros de desplazamiento 74HC595
;   utilizados por el display.
;
;-------------------------------------------------------------------------------
; DISTRIBUCIÓN DE REGISTROS
;
; r7:r6:r5:r4     Resultado del checksum de 32 bits.
;                  r5:r4 se utilizan para actualizar el display.
;
; r25              Selección del dígito que se encuentra activo.
;
; r26              Bandera de pulsación de botones (bit 0).
;
; r11:r10:r9:r8    Estado del generador XORSHIFT entre transmisiones.
;
; r15:r14:r13:r12  Acumulador auxiliar para calcular el checksum.
;
; r19:r18:r17:r16  Registros de uso general durante la generación.
;
; r18              Indicadores de errores de recepción:
;                    bit 4: error de trama (FE0)
;                    bit 3: pérdida de datos (DOR0)
;                    bit 2: error de paridad (UPE0)
;                    bit 7: tiempo de espera agotado.
;
;-------------------------------------------------------------------------------
; INDICADORES DEL RECEPTOR
;
; PB5  Resultado correcto del checksum.
; PB4  Diferencia entre el checksum calculado y el recibido.
; PB3  Error detectado durante la recepción serial.
;
; Los LEDs funcionan con lógica activa en cero.
;
;-------------------------------------------------------------------------------
; CONFIGURACIÓN DE VELOCIDAD
;
; Frecuencia del microcontrolador: 16 MHz.
;
; 9600 baudios    UBRR = 103   U2X = 0
; 250000 baudios  UBRR = 3     U2X = 0
; 500000 baudios  UBRR = 1     U2X = 0
; 1 Mbaud         UBRR = 0     U2X = 0
; 2 Mbaud         UBRR = 0     U2X = 1
;
; Con paridad habilitada, cada trama contiene:
; 1 bit de inicio + 8 bits de datos + 1 bit de paridad + 1 bit de parada.
;===============================================================================


;===============================================================================
; PARÁMETROS GENERALES
;===============================================================================

.equ VALOR_UBRR = 103          ; Divisor para una velocidad de 9600 baudios.
.equ VALOR_U2X  = 0            ; Selección del modo normal de transmisión.

; Orden de transmisión de los bits hacia los registros 74HC595.
; Con valor 1 se transmite primero el bit menos significativo.
; Con valor 0 se transmite primero el bit más significativo.

.equ DISPLAY_BIT0_PRIMERO = 1


;===============================================================================
; VECTORES DE INTERRUPCIÓN
;===============================================================================

.ORG 0x0000
    jmp inicio

.ORG 0x0008
    jmp int_botones

.ORG 0x001C
    jmp int_timer_display


;===============================================================================
; RESERVA DE MEMORIA
;===============================================================================

.DSEG

mensaje_512:            .byte 512    ; Espacio reservado para los datos.
fin_del_mensaje:        .byte 1      ; Referencia al final del mensaje.
checksum_recibido:      .byte 4      ; Almacenamiento del checksum recibido.


;===============================================================================
; PROGRAMA PRINCIPAL
;===============================================================================

.CSEG

inicio:
    call configurar_placa

    ldi r26, 0x00
    mov r7, r26
    mov r6, r26
    mov r5, r26
    mov r4, r26

    sei                              ; Activación de las interrupciones.

    jmp modo_transmisor              ; Configuración para la placa transmisora.
;   jmp modo_receptor                ; Utilizar esta opción en la placa receptora.


;===============================================================================
; FUNCIONAMIENTO COMO TRANSMISOR
;===============================================================================

modo_transmisor:

    ; Estado inicial del generador de números pseudoaleatorios.
    ldi r16, 0xA3
    ldi r17, 0x82
    ldi r18, 0xF0
    ldi r19, 0x05

transmisor_repetir:

    rcall generar_aleatorios

    ; Conservar el estado del generador para la siguiente transmisión.
    movw r8, r16
    movw r10, r18

    rcall calcular_checksum

    ; Esperar una nueva pulsación.
    ldi r26, 0

transmisor_espera_boton:

    sbrs r26, 0
    rjmp transmisor_espera_boton

    rcall esperar_boton_suelto

    ; Durante el envío se suspenden las interrupciones.
    cli
    rcall enviar_mensaje
    sei

    ; Recuperar el estado del generador XORSHIFT.
    movw r16, r8
    movw r18, r10

    rjmp transmisor_repetir


;===============================================================================
; FUNCIONAMIENTO COMO RECEPTOR
;===============================================================================

modo_receptor:

    ldi r26, 0

receptor_espera_boton:

    sbrs r26, 0
    rjmp receptor_espera_boton

    rcall esperar_boton_suelto

    ; Recibir el mensaje completo y su checksum.
    cli
    rcall recibir_mensaje
    sei

    ; Obtener el checksum de los datos almacenados.
    rcall calcular_checksum

    ; Comparar ambos resultados y actualizar los LEDs.
    rcall verificar_checksum

    rjmp modo_receptor


;===============================================================================
; CONTROL DE BOTONES Y ANTIRREBOTE
;===============================================================================

; Espera inicial, liberación de los botones y espera final.
; Se utilizan r16, r17 y r18 como registros auxiliares.

esperar_boton_suelto:

    rcall pausa_25ms

soltar_esperando:

    in r16, PINC
    andi r16, 0b00001110

    cpi r16, 0b00001110
    brne soltar_esperando

    rcall pausa_25ms
    ret


; Generación de una demora aproximada de 25 ms.
; El cálculo está realizado para una frecuencia de 16 MHz.

pausa_25ms:

    ldi r18, 2

pausa_externo:

    ldi r17, 0

pausa_medio:

    ldi r16, 0

pausa_interno:

    dec r16
    brne pausa_interno

    dec r17
    brne pausa_medio

    dec r18
    brne pausa_externo

    ret


;===============================================================================
; CÁLCULO DEL CHECKSUM
;===============================================================================

; Recorre el bloque completo y acumula el valor de cada byte.
; El resultado se conserva en cuatro registros para evitar desbordamientos.
;
; r15:r14:r13:r12 = acumulador temporal.
; r7:r6:r5:r4     = resultado definitivo.

calcular_checksum:

    ; Dirección inicial del bloque de datos.
    ldi YL, low(mensaje_512)
    ldi YH, high(mensaje_512)

    ; Reiniciar el acumulador.
    clr r12
    clr r13
    clr r14
    clr r15
    clr r17

checksum_sumar_byte:

    ; Leer el siguiente elemento.
    ld r16, Y+

    ; Incorporar el valor al acumulador de 32 bits.
    add r12, r16
    adc r13, r17
    adc r14, r17
    adc r15, r17

    ; Comprobar si se procesaron los 512 bytes.
    cpi YL, low(fin_del_mensaje)
    brne checksum_sumar_byte

    cpi YH, high(fin_del_mensaje)
    brne checksum_sumar_byte

    ; Copiar el resultado definitivo.
    movw r4, r12
    movw r6, r14

    ret


;===============================================================================
; TRANSMISIÓN MEDIANTE USART
;===============================================================================

; Envía primero el contenido del vector y después el checksum.
; El orden de los bytes del checksum es de menor a mayor significancia.

enviar_mensaje:

    ; Posicionar el puntero al comienzo del mensaje.
    ldi ZL, low(mensaje_512)
    ldi ZH, high(mensaje_512)

    ; Habilitar únicamente el transmisor.
    ldi r16, (1<<TXEN0)
    sts UCSR0B, r16

    ; Configurar velocidad y limpiar la bandera de transmisión.
    ldi r16, (1<<TXC0)|(VALOR_U2X<<U2X0)
    sts UCSR0A, r16

enviar_los_512_bytes:

    ; Obtener el siguiente byte y transmitirlo.
    ld r16, Z+
    rcall enviar_un_byte

    ; Comprobar si se alcanzó el final del vector.
    cpi ZL, low(fin_del_mensaje)
    brne enviar_los_512_bytes

    cpi ZH, high(fin_del_mensaje)
    brne enviar_los_512_bytes


; Envío de los cuatro bytes que forman el checksum.

enviar_los_4_del_checksum:

    mov r16, r4
    rcall enviar_un_byte

    mov r16, r5
    rcall enviar_un_byte

    mov r16, r6
    rcall enviar_un_byte

    mov r16, r7
    rcall enviar_un_byte


; Confirmar que el último byte terminó de salir por el puerto serial.

esperar_fin_envio:

    lds r17, UCSR0A
    sbrs r17, TXC0
    rjmp esperar_fin_envio

    ret


; Transmisión individual de un byte almacenado en r16.
; Antes de escribir UDR0 se comprueba que el registro esté disponible.

enviar_un_byte:

    lds r17, UCSR0A
    sbrs r17, UDRE0
    rjmp enviar_un_byte

    sts UDR0, r16

    ret


;===============================================================================
; RECEPCIÓN MEDIANTE USART
;===============================================================================

; Recibe los 512 bytes de información y los cuatro bytes del checksum.
; La recepción se realiza mediante consulta periódica de las banderas USART.

recibir_mensaje:

    ; Establecer el destino de los datos recibidos.
    ldi ZL, low(mensaje_512)
    ldi ZH, high(mensaje_512)

    ; Activar el receptor.
    ldi r16, (1<<RXEN0)
    sts UCSR0B, r16


; Descartar cualquier dato anterior que permanezca en el buffer.

vaciar_receptor:

    lds r17, UCSR0A
    sbrs r17, RXC0
    rjmp receptor_vacio

    lds r16, UDR0
    rjmp vaciar_receptor

receptor_vacio:

    clr r18                         ; Reiniciar indicadores de error.


; Esperar indefinidamente hasta detectar el primer byte de la transmisión.

esperar_primer_byte:

    lds r17, UCSR0A
    sbrs r17, RXC0
    rjmp esperar_primer_byte


; A partir del primer byte comienza la recepción con tiempo limitado.

recibir_los_512_bytes:

    rcall recibir_un_byte

    brcs recepcion_fallo_tiempo

    ; Guardar el dato en la posición correspondiente.
    st Z+, r16

    ; Verificar si se completó el bloque.
    cpi ZL, low(fin_del_mensaje)
    brne recibir_los_512_bytes

    cpi ZH, high(fin_del_mensaje)
    brne recibir_los_512_bytes


; Preparar el almacenamiento de los cuatro bytes adicionales.

    ldi ZL, low(checksum_recibido)
    ldi ZH, high(checksum_recibido)

    ldi r19, 4

recibir_los_4_del_checksum:

    rcall recibir_un_byte

    brcs recepcion_fallo_tiempo

    st Z+, r16

    dec r19
    brne recibir_los_4_del_checksum

    ret


; Si se agota el tiempo de espera, indicar que la recepción quedó incompleta.

recepcion_fallo_tiempo:

    ori r18, 0x80
    ret


;===============================================================================
; RECEPCIÓN DE UN BYTE Y CONTROL DE ERRORES
;===============================================================================

; Espera la llegada de un dato durante un intervalo limitado.
;
; Resultado:
;   r16 = byte recibido.
;   C = 0 si la recepción fue exitosa.
;   C = 1 si se agotó el tiempo.
;
; Los indicadores FE0, DOR0 y UPE0 se leen antes de acceder a UDR0.

recibir_un_byte:

    clr r20
    clr r21

esperar_llegada_byte:

    lds r17, UCSR0A

    sbrc r17, RXC0
    rjmp byte_llego

    ; Actualizar el contador de espera.
    subi r20, 1
    sbci r21, 0

    brne esperar_llegada_byte

    sec
    ret


byte_llego:

    ; Acumular los posibles errores detectados por el hardware.
    andi r17, (1<<FE0)|(1<<DOR0)|(1<<UPE0)

    or r18, r17

    ; Recuperar el dato recibido.
    lds r16, UDR0

    clc
    ret


;===============================================================================
; COMPROBACIÓN DEL CHECKSUM Y CONTROL DE LEDs
;===============================================================================

; Compara byte a byte el checksum local con el recibido.
;
; PB5: coincidencia entre ambos valores.
; PB4: diferencia en el resultado.
; PB3: errores detectados durante la recepción.

; Se utiliza Y para recorrer el checksum recibido porque la rutina
; de actualización del display utiliza el registro Z.

verificar_checksum:

    ; Apagar inicialmente los tres indicadores.
    sbi PORTB, 5
    sbi PORTB, 4
    sbi PORTB, 3

    ; Comprobar si se produjo algún error de hardware.
    tst r18
    breq revisar_checksum

    cbi PORTB, 3

revisar_checksum:

    ldi YL, low(checksum_recibido)
    ldi YH, high(checksum_recibido)

    ; Comparación del byte menos significativo.
    ld r16, Y+
    cp r16, r4
    brne checksum_distinto

    ld r16, Y+
    cp r16, r5
    brne checksum_distinto

    ld r16, Y+
    cp r16, r6
    brne checksum_distinto

    ld r16, Y+
    cp r16, r7
    brne checksum_distinto

    ; Todos los bytes coinciden.
    cbi PORTB, 5

    ret


checksum_distinto:

    ; Señalizar que los valores no son iguales.
    cbi PORTB, 4

    ret


;===============================================================================
; CONFIGURACIÓN INICIAL DEL HARDWARE
;===============================================================================

configurar_placa:

    ;---------------------------------------------------------------------------
    ; Configuración de los puertos de entrada y salida.
    ;
    ; PORTB:
    ;   PB2-PB5: LEDs de indicación.
    ;   PB0: línea de datos del display.
    ;
    ; PORTC:
    ;   PC1-PC3: entradas correspondientes a los botones.
    ;
    ; PORTD:
    ;   PD0: recepción USART.
    ;   PD4: señal de latch del display.
    ;   PD7: reloj de los registros de desplazamiento.
    ;---------------------------------------------------------------------------

    ldi r16, 0b00111101
    out DDRB, r16
    out PORTB, r16

    ldi r16, 0b00000000
    out DDRC, r16

    ldi r16, 0b00001110
    out PORTC, r16

    ldi r16, 0b10010000
    out DDRD, r16

    ; Mantener la entrada RXD en estado de reposo.
    sbi PORTD, 0

    ; Estado inicial de las señales del display.
    cbi PORTD, 7
    cbi PORTD, 4


    ;---------------------------------------------------------------------------
    ; Habilitación de interrupciones por cambio de estado en los botones.
    ;---------------------------------------------------------------------------

    ldi r16, 0b00000010
    sts PCICR, r16

    ldi r16, 0b00001110
    sts PCMSK1, r16


    ;---------------------------------------------------------------------------
    ; Configuración del temporizador 0 para actualizar el display.
    ;---------------------------------------------------------------------------

    ldi r16, 0b00000010
    out TCCR0A, r16

    ldi r16, 0b00000100
    out TCCR0B, r16

    ldi r16, 249
    out OCR0A, r16

    ldi r16, 0b00000010
    sts TIMSK0, r16


    ;---------------------------------------------------------------------------
    ; Parámetros de comunicación serial.
    ; Transmisión asíncrona, ocho bits de datos, paridad par y un bit de parada.
    ;---------------------------------------------------------------------------

    ldi r16, 0b00001000
    sts UCSR0B, r16

    ldi r16, 0b00100110
;   ldi r16, 0b00000110           ; Alternativa de configuración sin paridad.
    sts UCSR0C, r16

    ldi r16, (VALOR_U2X<<U2X0)
    sts UCSR0A, r16

    ldi r16, high(VALOR_UBRR)
    sts UBRR0H, r16

    ldi r16, low(VALOR_UBRR)
    sts UBRR0L, r16


    ;---------------------------------------------------------------------------
    ; Valor inicial para la selección de los dígitos del display.
    ;---------------------------------------------------------------------------

    ldi r25, 0x10

    ret


;===============================================================================
; GENERACIÓN DE DATOS PSEUDOALEATORIOS
;===============================================================================

; Llena el vector mensaje_512 con 512 bytes.
; Cada iteración genera un nuevo número de 32 bits mediante XORSHIFT.

generar_aleatorios:

    ; Ubicar el puntero Y al principio de la memoria reservada.
    ldi r28, low(mensaje_512)
    ldi r29, high(mensaje_512)

aleatorios_nuevo_numero:

    ; Aplicar las tres transformaciones del algoritmo XORSHIFT.
    ldi r20, 13
    call desplazar_izquierda_xor

    ldi r20, 17
    call desplazar_derecha_xor

    ldi r20, 5
    call desplazar_izquierda_xor

    ; Guardar los cuatro bytes generados.
    st Y+, r16
    st Y+, r17
    st Y+, r18
    st Y+, r19

    ; Continuar mientras queden posiciones disponibles.
    cpi YL, low(fin_del_mensaje)
    brne aleatorios_nuevo_numero

    cpi YH, high(fin_del_mensaje)
    brne aleatorios_nuevo_numero

    ret


; Desplazamiento hacia la izquierda seguido de una operación XOR.
; x = x XOR (x << desplazamiento)

desplazar_izquierda_xor:

    ; Copiar el estado actual para realizar la transformación.
    mov r0, r16
    mov r1, r17
    mov r2, r18
    mov r3, r19

izquierda_un_bit:

    clc

    rol r0
    rol r1
    rol r2
    rol r3

    dec r20
    brne izquierda_un_bit

    rjmp mezclar_xor


; Desplazamiento hacia la derecha seguido de una operación XOR.
; x = x XOR (x >> desplazamiento)

desplazar_derecha_xor:

    mov r0, r16
    mov r1, r17
    mov r2, r18
    mov r3, r19

derecha_un_bit:

    clc

    ror r3
    ror r2
    ror r1
    ror r0

    dec r20
    brne derecha_un_bit


; Combinar el valor original con la copia desplazada.

mezclar_xor:

    eor r16, r0
    eor r17, r1
    eor r18, r2
    eor r19, r3

    ret


;===============================================================================
; CONTROL DEL DISPLAY DE SIETE SEGMENTOS
;===============================================================================

; Recibe en r16 la información que se desea representar:
;
;   Nibble superior: posición del dígito que se activa.
;   Nibble inferior: valor hexadecimal que se muestra.
;
; Ejemplo:
;   r16 = 0x47 representa el número 7 en el segundo dígito.

mostrar_digito:

    ; Conservar el valor original para enviarlo posteriormente.
    push r16

    ; Obtener la dirección de la tabla de conversión.
    ldi zh, high(tabla_7segmentos<<1)
    ldi zl, low(tabla_7segmentos<<1)

    ; Seleccionar el patrón correspondiente al número.
    andi r16, 0x0F

    add zl, r16

    clr r16
    adc zh, r16

    ; Leer el patrón desde la memoria de programa.
    lpm r16, Z

    call enviar_byte_display

    ; Enviar la selección del dígito.
    pop r16

    call enviar_byte_display

    ; Actualizar las salidas de los registros 74HC595.
    sbi PORTD, 4
    cbi PORTD, 4

    ret


;===============================================================================
; ENVÍO DE DATOS AL DISPLAY
;===============================================================================

; Envía los ocho bits de r16 por PB0.
; Cada bit transmitido genera un pulso de reloj en PD7.
; El registro r17 se conserva durante la ejecución.

enviar_byte_display:

    push r17

    ldi r17, 8

display_bit_siguiente:

.if DISPLAY_BIT0_PRIMERO

    ; Desplazar el bit menos significativo hacia el carry.
    ror r16

.else

    ; Desplazar el bit más significativo hacia el carry.
    rol r16

.endif

    brcs display_bit_uno

    ; Colocar un cero en la línea de datos.
    cbi PORTB, 0

    rjmp display_pulso_reloj


display_bit_uno:

    ; Colocar un uno en la línea de datos.
    sbi PORTB, 0


display_pulso_reloj:

    ; Pulso de desplazamiento para almacenar el siguiente bit.
    sbi PORTD, 7
    cbi PORTD, 7

    dec r17
    brne display_bit_siguiente

    pop r17

    ret


;===============================================================================
; TABLA DE CONVERSIÓN HEXADECIMAL A SIETE SEGMENTOS
;===============================================================================

; Patrones correspondientes a los valores 0-F.
; La configuración corresponde a un display de ánodo común.
; El segmento se enciende cuando su salida se encuentra en cero.

tabla_7segmentos:

.if DISPLAY_BIT0_PRIMERO

    .db 0x03, 0x9F, 0x25, 0x0D, 0x99, 0x49, 0x41, 0x1F
    .db 0x01, 0x09, 0x11, 0xC1, 0x63, 0x85, 0x61, 0x71

.else

    .db 0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8
    .db 0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E

.endif


;===============================================================================
; INTERRUPCIÓN ASOCIADA A LOS BOTONES
;===============================================================================

; Se ejecuta cuando cambia el estado de alguno de los pines PC1-PC3.
; La bandera se activa únicamente cuando se detecta un botón presionado.

int_botones:

    push r16

    ; Guardar el estado actual de los indicadores del procesador.
    in r16, SREG
    push r16

    ; Consultar el estado de las entradas.
    in r16, PINC
    andi r16, 0b00001110

    ; Si todos están en uno, no hay botones presionados.
    cpi r16, 0b00001110
    breq int_botones_fin

    ; Informar al programa principal que hubo una pulsación.
    ori r26, 0x01


int_botones_fin:

    ; Recuperar los registros y el estado del procesador.
    pop r16
    out SREG, r16

    pop r16

    reti


;===============================================================================
; INTERRUPCIÓN DEL TEMPORIZADOR: ACTUALIZACIÓN DEL DISPLAY
;===============================================================================

; Esta rutina se ejecuta periódicamente mediante el Timer0.
; En cada llamada se actualiza uno de los cuatro dígitos del display.
;
; Secuencia controlada por r25:
;
;   0x10 -> Nibble superior de r5.
;   0x20 -> Nibble inferior de r5.
;   0x40 -> Nibble superior de r4.
;   0x80 -> Nibble inferior de r4.
;
; Al finalizar la secuencia se vuelve al primer dígito.

int_timer_display:

    ; Guardar los registros utilizados durante la interrupción.
    push r16

    in r16, SREG
    push r16

    push r30
    push r31


    ;---------------------------------------------------------------------------
    ; Seleccionar el byte y el nibble que corresponde mostrar.
    ;---------------------------------------------------------------------------

    cpi r25, 0x10
    brne timer_probar_digito_2

    mov r30, r5
    swap r30

    rjmp timer_dibujar


timer_probar_digito_2:

    cpi r25, 0x20
    brne timer_probar_digito_3

    mov r30, r5

    rjmp timer_dibujar


timer_probar_digito_3:

    cpi r25, 0x40
    brne timer_digito_4

    mov r30, r4
    swap r30

    rjmp timer_dibujar


timer_digito_4:

    mov r30, r4


    ;---------------------------------------------------------------------------
    ; Preparar el valor y enviarlo al display.
    ;---------------------------------------------------------------------------

timer_dibujar:

    andi r30, 0x0F

    mov r16, r25
    or r16, r30

    call mostrar_digito


    ;---------------------------------------------------------------------------
    ; Avanzar a la siguiente posición del display.
    ;---------------------------------------------------------------------------

    lsl r25

    brne timer_fin

    ldi r25, 0x10


timer_fin:

    ; Restaurar todos los registros antes de salir.
    pop r31
    pop r30

    pop r16
    out SREG, r16

    pop r16

    reti
