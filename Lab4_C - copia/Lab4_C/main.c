
/*
 * Lab4_C.c
 *
 * Created: 29/10/2026 10:01:35
 * Author : chiar
 */

#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <stdint.h>


/*
 * Lab4_C.c
 *
 * Created: 29/10/2026 10:01:35
 * Author : chiar
 */

#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <stdint.h>

// =====================================================
// PARTE 1, i) - Inicialización del conversor ADC
// =====================================================

void ADC_init(void) {

    // Configurar AVCC como referencia y seleccionar ADC0.
    ADMUX = (1 << REFS0);

    // Configurar PC0 como entrada.
    DDRC &= ~(1 << DDC0);

    // Deshabilitar el pull-up de PC0.
    PORTC &= ~(1 << PORTC0);

    // Habilitar ADC y configurar prescaler en 128.
    ADCSRA = (1 << ADEN) |
             (1 << ADPS2) |
             (1 << ADPS1) |
             (1 << ADPS0);
}


// =====================================================
// PARTE 1, i) - Lectura individual del ADC
// =====================================================

unsigned int ADC_leer(void) {

    // Iniciar conversión.
    ADCSRA |= (1 << ADSC);

    // Esperar a que finalice.
    while (ADCSRA & (1 << ADSC));

    // Retornar resultado de 10 bits.
    return ADC;
}


// =====================================================
// PARTE 1, ii) - Promedio de 100 conversiones
// =====================================================

unsigned int ADC_promedio(void) {

    // Acumulador de 32 bits para evitar desbordamiento.
    uint32_t suma = 0;

    // Realizar 100 conversiones.
    for (uint8_t i = 0; i < 100; i++) {

        suma += ADC_leer();
    }

    // Calcular y retornar el promedio.
    return (unsigned int)(suma / 100);
}


// =====================================================
// PARTE 1, iii) - Conversión de ADC a tensión (voltios)
// =====================================================

float ADC_a_voltios(unsigned int lectura) {

    // Convertir el valor digital a tensión.
    // VREF = 5V y resolución = 1024 niveles.
    float voltaje = (lectura * 5.0) / 1024.0;

    return voltaje;
}


// =====================================================
// PROGRAMA PRINCIPAL
// =====================================================

int main(void) {

    // Inicializar conversor ADC.
    ADC_init();

    // Variables para almacenar los resultados.
    volatile unsigned int promedio_adc = 0;
    volatile float voltaje_adc = 0;

    while (1) {

        // PARTE 1, ii): Obtener promedio de 100 conversiones.
        promedio_adc = ADC_promedio();

        // PARTE 1, iii): Convertir el promedio a voltios.
        voltaje_adc = ADC_a_voltios(promedio_adc);

        _delay_ms(100);
    }
}


