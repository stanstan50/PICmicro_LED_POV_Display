; =====================================
; PIC16F628A - RB0 External Interrupt Test
; RB0 - Input (interrupt source)
; RB1 to RB7 - Output LEDs
; =====================================

    list      p=16F628A
    #include <p16f628a.inc>

    __CONFIG _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _BOREN_OFF & _LVP_OFF & _CP_OFF
    
    cblock 0x20
    TEMPDLY
TMPDLY1
    endc

; ========== RESET VECTOR ==========
    ORG 0x0000
    goto Init

; ========== INTERRUPT VECTOR ==========
    ORG 0x0004
ISR:
    ; Check if RB0 caused the interrupt
    btfss INTCON, INTF
    goto ISR_Exit

    ; Clear the interrupt flag
    bcf INTCON, INTF

    ; Turn on RB1 to RB7
    movlw b'11111110' ; RB7..RB1 = 1, RB0 remains input
    movwf PORTB

ISR_Exit:
    retfie

; ========== MAIN PROGRAM ==========
Init:
    ; --- Bank 1: Setup ---
    bsf STATUS, RP0

    ; Set PORTB directions
    movlw b'00000001' ; RB0 = input (interrupt source), RB1-RB7 = output
    movwf TRISB

    ; Optionally: Set PORTA all outputs
    clrf TRISA
;    clrf TRISAbits.TRISA
    
    ; Configure INT interrupt (RB0 / INT)
    bsf     OPTION_REG, INTEDG   ; Interrupt on rising edge

    ; --- Bank 0: Initialize ---
    bcf STATUS, RP0

    ; Clear PORTB (all outputs off)
    clrf PORTB
    
    

    ; Clear interrupt flag
    bcf INTCON, INTF

    ; Enable RB0/INT external interrupt
    bsf INTCON, INTE

    ; Enable global interrupts
    bsf INTCON, GIE

MainLoop:
    goto MainLoop

Delay_ms
    MOVWF   TEMPDLY
Delay_1	; delay 100 uS
    MOVLW   .99		;1
    MOVWF   TMPDLY1	;1
    goto    $+1		;2
    goto    $+1		;2
    nop			;1
Delay
    goto    $+1		;2
    goto    $+1		;2
    goto    $+1		;2
    nop			;1
    DECFSZ  TMPDLY1, F	;1 or 2
    goto    Delay	;2
    
    DECFSZ  TEMPDLY, F	;1 or 2
    goto    Delay_1	;2
    
    return		;2
     
    
    END
