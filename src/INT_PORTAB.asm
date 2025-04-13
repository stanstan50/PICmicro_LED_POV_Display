; RA1..4 - bit0..3 Output LEDs
; RA0 - Tilt Switch In
; RB4..7 - bit4..7 Output LEDs
; RB0 - Interrupt (Sensors)
    
    
; Assume 0.5cm physcal space between columns (at 1 MHz instruction cycle)
; at 0.5 m/s -> 10 ms delay -> 10000 instruction delay
; at 0.25 m/s -> 20 ms delay -> 20000 instruction delay
; at 0.8 m/s -> 6.25 ms delay -> 6250 instruction delay

; delay range
; 6.25 ms -- 20 ms
    
    list	p=16F628A
    include "p16f628a.inc"
__CONFIG _INTOSC_OSC_NOCLKOUT & _WDTE_OFF & _PWRTE_OFF & _BOREN_OFF & _LVP_OFF & _CPD_ON & _CP_OFF
; [_INTOSC_OSC_NOCLKOUT] INTOSC oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN
 M_DELAY1s MACRO
    MOVLW   .250
    call    Delay_ms
    MOVLW   .250
    call    Delay_ms
    MOVLW   .250
    call    Delay_ms
    MOVLW   .250
    call    Delay_ms
ENDM

    
    cblock  0x20
TEMPDLY	; used in instruction delay (Delay_ms)
TMPDLY1 ; used in instruction delay (Delay_ms)
INDEXCTR
TEMP
DELAYVAL_MS
DELAYVAL_US
INTWBUFFER
    endc
    
    org 0x0
    goto    Init
    
    org 0x4	; Interrupt Vector
ISR
    BTFSS   INTCON, INTF
    goto    ISR_Exit
    
    MOVWF   INTWBUFFER
    call    SetDelay
    MOVFW   INTWBUFFER
    
    CLRF    TMR1H
    CLRF    TMR1L
    
    BCF	    INTCON, INTF     ; Clear interrupt flag
    
ISR_Exit
    retfie
    
    org 0x20
Init
    ;CLRF    PORTA
    ;CLRF    PORTB
    ; Disable Comparators (Bank 0)
    MOVLW   0X07
    MOVWF   CMCON
    
    ; Enable Timer1 (Bank 0)
    MOVLW   b'00100001'
    MOVWF   T1CON
    
    ; Clear Timer1 registers (Bank 0)
    CLRF    TMR1H
    CLRF    TMR1L
    
    
    ; ----- SELECT BANK [1] -----
    BSF	    STATUS, RP0	    
    
    ; Disable VREF (Bank 1)
    MOVLW   0x00
    MOVWF   VRCON	    
    
    ; Set I/O Direction (Bank 1)
    MOVLW   b'11100001'	    ; [OUT] RA1..4 (LEDs) - bit 0..3
    MOVWF   TRISA	    ; [IN] RA0 as Tilt Switch Input
    MOVLW   b'00001111'	    ; [OUT] RB4..7 (LEDs) - bit 4..7
    MOVWF   TRISB	    ; [IN] RB0 as Interrupt (Sensors)
    
    ; ----- SELECT BANK [0] -----
    BCF	    STATUS, RP0
    
    ; Interrupts Setup (Bank 0)
	; Clear interrupt flags
	BCF     INTCON, INTF	    ; Clear Ext. Interrupt Flag (RB0/INT)
	BCF     PIR1, TMR1IF	    ; Clear Timer1 Interrupt Flag

	; Configure INT interrupt (RB0 / INT)
	BCF     OPTION_REG, INTEDG   ; Interrupt on falling edge (either side hits the magnet -> low)

	; Enable interrupts
	BSF     INTCON, INTE         ; Enable external INT interrupt (RB0/INT)
	BSF     INTCON, GIE          ; Enable global interrupts

    ; Initialize DELAYVAL_MS (in ms)
    MOVLW   .10
    MOVWF   DELAYVAL_MS
    
    ; Initialize DELAYVAL_US (in us)
    MOVLW   .10
    MOVWF   DELAYVAL_US
    

    ;goto    MainProgram	    ; comment out to enter idle loop
    
Idle
    M_DELAY1s
    
    MOVLW   0xFF
    MOVWF   PORTB   ; Light up bit4..7 on RB4..7
    ANDLW   0xFF    ; Mask for bit0..3
    MOVWF   TEMP    ; Copy WREG to TEMP
    RLF	    TEMP, W ; shift for RA1..4
    MOVWF   PORTA   ; Light up bit0..3 on RA1..4
    

    M_DELAY1s
    
    MOVLW   0x00
    MOVWF   PORTB   ; Light up bit4..7 on RB4..7
    ANDLW   0x0F    ; Mask for bit0..3
    MOVWF   TEMP    ; Copy WREG to TEMP
    RLF	    TEMP, W ; shift for RA1..4
    MOVWF   PORTA   ; Light up bit0..3 on RA1..4
    
    BTFSC   PORTA, 0
    call    TiltSwitchSet
    
    goto    Idle    ; Temporary idle program

MainProgram
    CLRW
    CLRF    INDEXCTR
    
    
LoopMessage
    
    BTFSC   PORTA, 0
    call    TiltSwitchSet
    
    MOVFW   INDEXCTR
    call    MessageTable    ; Get LED pattern form MessageTable -> WREG
    ; Light up LEDs
    MOVWF   PORTB	; Light up bit4..7 on RB4..7
    ANDLW   0x0F	; Mask for bit0..3
    MOVWF   TEMP	; Copy WREG to TEMP
    RLF	    TEMP, W	; shift for RA1..4
    MOVWF   PORTA	; Light up bit0..3 on RA1..4

    
;    call    GetDelay_ms	; get the delay value (in ms)
;    ; Value returned in WREG
;    call    Delay_ms
    
    call    Delay_Call
    
    INCF    INDEXCTR	; increment index
    MOVLW   .160	; index 160 is overflow
    SUBWF   INDEXCTR, W	; Compare using subtraction
    BTFSC   STATUS, Z	; Check if equal or not
    CLRF    INDEXCTR	; Reset the index
    
    goto    LoopMessage

    
    
    goto    MainProgram
    
Delay_Call
    MOVFW   DELAYVAL_US
    call    Delay_4
    
    MOVFW   DELAYVAL_MS
    call    Delay_ms
    
    return
    
SetDelay
    MOVFW   TMR1L
    MOVWF   TEMP
    RRF	    TEMP, W
    MOVWF   TEMP
    RRF	    TEMP, W
    MOVWF   TEMP
    RRF	    TEMP, W
    MOVWF   DELAYVAL_US
    
    MOVFW   TMR1H
    MOVWF   TEMP
    RRF	    TEMP, W
    MOVWF   TEMP
    RRF	    TEMP, W
    MOVWF   TEMP
    RRF	    TEMP, W
    MOVWF   DELAYVAL_MS
    
    return
    
Delay_4
    nop			;1
    DECFSZ  W, W	;1 or 2
    goto    Delay_10us	;2
    
    return		;2

TiltSwitchSet
    CLRF    PORTA
    CLRF    PORTB
TiltSwitchSetLoop
    BTFSC   PORTA, 0
    goto    TiltSwitchSetLoop
    return

    
MessageTable	
    ; Program Memory (Instruction Word): 1 + 20(5) = 101 + 60 (char space) = 161
    ; Instructions Cycles: 1 (ADDWF) + 2 (RETLW) = 3
    ; Expected WREG Value: 0x00..0x63, or .0--.159
    
    ADDWF   PCL, F
    
; -- Comments shows the value of WREG (**Outdated) --
; P (0)*5
    retlw b'11111110' ; 0 <-(0*5 + 0)
    retlw b'00001001' ; 1 <-(0*5 + 1)
    retlw b'00001001' ; 2 <-(0*5 + 2)
    retlw b'00001001' ; 3 <-(0*5 + 3)
    retlw b'00000110' ; 4 <-(0*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; L (1)*5
    retlw b'11111111' ; 5 <-(1*5 + 0)
    retlw b'10000000' ; 6 <-(1*5 + 1)
    retlw b'10000000' ; 7 <-(1*5 + 2)
    retlw b'10000000' ; 8 <-(1*5 + 3)
    retlw b'10000000' ; 9 <-(1*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; E (2)*5
    retlw b'11111111' ; 10 <-(2*5 + 0)
    retlw b'10001001' ; 11 <-(2*5 + 1)
    retlw b'10001001' ; 12 <-(2*5 + 2)
    retlw b'10001001' ; 13 <-(2*5 + 3)
    retlw b'10000001' ; 14 <-(2*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; A (3)*5
    retlw b'11111110' ; 15 <-(3*5 + 0)
    retlw b'00001001' ; 16 <-(3*5 + 1)
    retlw b'00001001' ; 17 <-(3*5 + 2)
    retlw b'00001001' ; 18 <-(3*5 + 3)
    retlw b'11111110' ; 19 <-(3*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; S (4)*5
    retlw b'10000110' ; 20 <-(4*5 + 0)
    retlw b'10001001' ; 21 <-(4*5 + 1)
    retlw b'10001001' ; 22 <-(4*5 + 2)
    retlw b'10001001' ; 23 <-(4*5 + 3)
    retlw b'01110001' ; 24 <-(4*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; E (5)*5
    retlw b'11111111' ; 25 <-(5*5 + 0)
    retlw b'10001001' ; 26 <-(5*5 + 1)
    retlw b'10001001' ; 27 <-(5*5 + 2)
    retlw b'10001001' ; 28 <-(5*5 + 3)
    retlw b'10000001' ; 29 <-(5*5 + 4)

    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'
    
; SPACE (6)*5
    retlw b'00000000' ; 30 <-(6*5 + 0)
    retlw b'00000000' ; 31 <-(6*5 + 1)
    retlw b'00000000' ; 32 <-(6*5 + 2)
    retlw b'00000000' ; 33 <-(6*5 + 3)
    retlw b'00000000' ; 34 <-(6*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; M (7)*5
    retlw b'11111111' ; 35 <-(7*5 + 0)
    retlw b'00000100' ; 36 <-(7*5 + 1)
    retlw b'00011000' ; 37 <-(7*5 + 2)
    retlw b'00000100' ; 38 <-(7*5 + 3)
    retlw b'11111111' ; 39 <-(7*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; A (8)*5
    retlw b'11111110' ; 40 <-(8*5 + 0)
    retlw b'00001001' ; 41 <-(8*5 + 1)
    retlw b'00001001' ; 42 <-(8*5 + 2)
    retlw b'00001001' ; 43 <-(8*5 + 3)
    retlw b'11111110' ; 44 <-(8*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; K (9)*5
    retlw b'11111111' ; 45 <-(9*5 + 0)
    retlw b'00001000' ; 46 <-(9*5 + 1)
    retlw b'00010100' ; 47 <-(9*5 + 2)
    retlw b'00100010' ; 48 <-(9*5 + 3)
    retlw b'11000001' ; 49 <-(9*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; E (10)*5
    retlw b'11111111' ; 50 <-(10*5 + 0)
    retlw b'10001001' ; 51 <-(10*5 + 1)
    retlw b'10001001' ; 52 <-(10*5 + 2)
    retlw b'10001001' ; 53 <-(10*5 + 3)
    retlw b'10000001' ; 54 <-(10*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; SPACE (11)*5
    retlw b'00000000' ; 55 <-(11*5 + 0)
    retlw b'00000000' ; 56 <-(11*5 + 1)
    retlw b'00000000' ; 57 <-(11*5 + 2)
    retlw b'00000000' ; 58 <-(11*5 + 3)
    retlw b'00000000' ; 59 <-(11*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; U (12)*5
    retlw b'01111111' ; 60 <-(12*5 + 0)
    retlw b'10000000' ; 61 <-(12*5 + 1)
    retlw b'10000000' ; 62 <-(12*5 + 2)
    retlw b'10000000' ; 63 <-(12*5 + 3)
    retlw b'01111111' ; 64 <-(12*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; S (13)*5
    retlw b'10000110' ; 65 <-(13*5 + 0)
    retlw b'10001001' ; 66 <-(13*5 + 1)
    retlw b'10001001' ; 67 <-(13*5 + 2)
    retlw b'10001001' ; 68 <-(13*5 + 3)
    retlw b'01110001' ; 69 <-(13*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; SPACE (14)*5
    retlw b'00000000' ; 70 <-(14*5 + 0)
    retlw b'00000000' ; 71 <-(14*5 + 1)
    retlw b'00000000' ; 72 <-(14*5 + 2)
    retlw b'00000000' ; 73 <-(14*5 + 3)
    retlw b'00000000' ; 74 <-(14*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; P (15)*5
    retlw b'11111110' ; 75 <-(15*5 + 0)
    retlw b'00001001' ; 76 <-(15*5 + 1)
    retlw b'00001001' ; 77 <-(15*5 + 2)
    retlw b'00001001' ; 78 <-(15*5 + 3)
    retlw b'00000110' ; 79 <-(15*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; A (16)*5
    retlw b'11111110' ; 80 <-(16*5 + 0)
    retlw b'00001001' ; 81 <-(16*5 + 1)
    retlw b'00001001' ; 82 <-(16*5 + 2)
    retlw b'00001001' ; 83 <-(16*5 + 3)
    retlw b'11111110' ; 84 <-(16*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; S (17)*5
    retlw b'10000110' ; 85 <-(17*5 + 0)
    retlw b'10001001' ; 86 <-(17*5 + 1)
    retlw b'10001001' ; 87 <-(17*5 + 2)
    retlw b'10001001' ; 88 <-(17*5 + 3)
    retlw b'01110001' ; 89 <-(17*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; S (18)*5
    retlw b'10000110' ; 90 <-(18*5 + 0)
    retlw b'10001001' ; 91 <-(18*5 + 1)
    retlw b'10001001' ; 92 <-(18*5 + 2)
    retlw b'10001001' ; 93 <-(18*5 + 3)
    retlw b'01110001' ; 94 <-(18*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'

; ! (19)*5
    retlw b'00000000' ; 95 <-(19*5 + 0)
    retlw b'00000000' ; 96 <-(19*5 + 1)
    retlw b'10111111' ; 97 <-(19*5 + 2)
    retlw b'00000000' ; 98 <-(19*5 + 3)
    retlw b'00000000' ; 99 <-(19*5 + 4)
    
    retlw b'00000000'
    retlw b'00000000'
    retlw b'00000000'
    
Delay_ms
    ; PROGRAM MEMORY = 15
    
    MOVWF   TEMPDLY
Delay_100	; delay 1000 uS
    MOVLW   .99		;1
    MOVWF   TMPDLY1	;1
    goto    $+1		;2
    goto    $+1		;2
    nop			;1
Delay_10
    goto    $+1		;2
    goto    $+1		;2
    goto    $+1		;2
    nop			;1
    DECFSZ  TMPDLY1, F	;1 or 2
    goto    Delay_10	;2
    
    DECFSZ  TEMPDLY, F	;1 or 2
    goto    Delay_100	;2
    
    return		;2
    
Delay_10us
    ; Delays [WREG] * 10us or [WREG] * 10 instruction delays
    ; + 1 (+3 more including the call and movlw)
    goto    $+1		;2
    goto    $+1		;2
    goto    $+1		;2
    nop			;1
    DECFSZ  W, W	;1 or 2
    goto    Delay_10us	;2
    
    return		;2

    end
