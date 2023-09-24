;------------------------
; Assembly Code
;------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global DHT11_sensor_LCD
;=================================================================
DHT11_sensor_LCD:
;------------
    LDI   R17, 0xFF 
;-----------------------------------------------------------------
agn:RCALL delay_2s      ;wait 2s for DHT11 to get ready
;-----------------------------------------------------------------
;start_signal
;------------
    SBI   DDRB, 2       ;pin PB2 as o/p
    CBI   PORTB, 2      ;send low pulse
    RCALL delay_20ms        
    SBI   PORTB, 2      ;send high pulse
;-----------------------------------------------------------------
;responce signal
;---------------
    CBI   DDRB, 2        ;pin PB2 as i/p
w1: SBIC  PINB, 2
    RJMP  w1            ;wait for DHT11 low pulse
w2: SBIS  PINB, 2
    RJMP  w2            ;wait for DHT11 high pulse
w3: SBIC  PINB, 2 
    RJMP  w3            ;wait for DHT11 low pulse
;-----------------------------------------------------------------
    RCALL DHT11_reading ;read humidity (1st byte of 40-bit data)
    MOV   R19, R18
    RCALL DHT11_reading
    RCALL DHT11_reading ;read temp (3rd byte of 40-bit data)
;-----------------------------------------------------------------
    RCALL LCD_write
    RJMP  agn
;=================================================================
LCD_write:
      LDI   R16, 0xFF
      OUT   DDRD, R16         ;set port D o/p for data
      OUT   DDRB, R16         ;set port B o/p for command
      CBI   PORTB, 0          ;EN = 0
      RCALL delay_ms          ;wait for LCD power on
      ;-----------------------------------------------------
      RCALL LCD_init          ;subroutine to initialize LCD
      ;-----------------------------------------------------
      RCALL disp_message      ;subroutine to display message
      ;-----------------------------------------------------
      LDI   R16, 0x01         ;clear LCD
      RCALL command_wrt       ;send command code
      RCALL delay_ms
      ;-----------------------------------------------------
      LDI   R17, 4            ;wait 1 second
l1:   RCALL delay_seconds
      DEC   R17
      BRNE  l1
      ;-----------------------------------------------------
                              ;jump to again for another run
;================================================================
DHT11_reading:
    LDI   R17, 8        ;set counter for receiving 8 bits
    CLR   R18           ;clear data register
    ;-------------------------------------------------------
w4: SBIS  PINB, 2
    RJMP  w4            ;detect data bit (high pulse)
    RCALL delay_timer0  ;
    ;-------------------------------------------------------
    SBIS  PINB, 2   ;if received bit=1, skip next inst
    RJMP  skp           ;else, received bit=0, jump to skp
    SEC                 ;set carry flag (C=1)
    ROL   R18           ;shift in 1 into data register
    RJMP  w5            ;jump & wait for low pulse
skp:LSL   R18           ;shift in 0 into data register
    ;-------------------------------------------------------
w5: SBIC  PINB, 2
    RJMP  w5            ;wait for DHT11 low pulse
    ;-------------------------------------------------------
    DEC   R17           ;decrement counter
    BRNE  w4            ;go back & detect next bit
    RET                 ;return to calling subroutine
;=================================================================
;delay subroutines
;=================================================================
delay_20ms:             ;delay 20ms
    LDI   R21, 255
l3: LDI   R22, 210
l4: LDI   R23, 2
l5: DEC   R23
    BRNE  l5
    DEC   R22
    BRNE  l4
    DEC   R21
    BRNE  l3
    RET
;-----------------------------------------------------------------
delay_2s:               ;delay 2s
    LDI   R21, 255
l6: LDI   R22, 255
l7: LDI   R23, 164
l8: DEC   R23
    BRNE  l8
    DEC   R22
    BRNE  l7
    DEC   R21
    BRNE  l6
    RET
;===============================================================
delay_timer0:             ;50 usec delay via Timer 0
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCNT0, R20      ;initialize timer0 with count=0
    LDI   R20, 100
    OUT   OCR0A, R20      ;OCR0 = 100
    LDI   R20, 0b00001010
    OUT   TCCR0B, R20     ;timer0: CTC mode, prescaler 8
    ;---------------------------------------------------------
l2: IN    R20, TIFR0      ;get TIFR0 byte & check
    SBRS  R20, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  l2              ;else, loop back & check OCF0 flag
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCCR0B, R20     ;stop timer0
    ;---------------------------------------------------------
    LDI   R20, (1<<OCF0A)
    OUT   TIFR0, R20      ;clear OCF0 flag
    RET
;===============================================================
LCD_init:
      LDI   R16, 0x33         ;init LCD for 4-bit data
      RCALL command_wrt       ;send to command register
      RCALL delay_ms
      LDI   R16, 0x32         ;init LCD for 4-bit data
      RCALL command_wrt
      RCALL delay_ms
      LDI   R16, 0x28         ;LCD 2 lines, 5x7 matrix
      RCALL command_wrt
      RCALL delay_ms
      LDI   R16, 0x0C         ;disp ON, cursor OFF
      RCALL command_wrt
      LDI   R16, 0x01         ;clear LCD
      RCALL command_wrt
      RCALL delay_ms
      LDI   R16, 0x06         ;shift cursor right
      RCALL command_wrt
      RET  
;================================================================
command_wrt:
      MOV   R27, R16
      ANDI  R27, 0xF0         ;mask low nibble & keep high nibble
      OUT   PORTD, R27        ;o/p high nibble to port D
      CBI   PORTB, 1      ;RS = 0 for command
      SBI   PORTB, 0      ;EN = 1
      RCALL delay_short       ;widen EN pulse
      CBI   PORTB, 0      ;EN = 0 for H-to-L pulse
      RCALL delay_us          ;delay in micro seconds
      ;----------------------------------------------------
      MOV   R27, R16
      SWAP  R27               ;swap nibbles
      ANDI  R27, 0xF0         ;mask low nibble & keep high nibble
      OUT   PORTD, R27        ;o/p high nibble to port D
      SBI   PORTB, 0      ;EN = 1
      RCALL delay_short       ;widen EN pulse
      CBI   PORTB, 0      ;EN = 0 for H-to-L pulse
      RCALL delay_us          ;delay in micro seconds
      RET
;================================================================
data_wrt:
      MOV   R27, R16
      ANDI  R27, 0xF0         ;mask low nibble & keep high nibble
      OUT   PORTD, R27        ;o/p high nibble to port D
      SBI   PORTB, 1      ;RS = 1 for data
      SBI   PORTB, 0      ;EN = 1
      RCALL delay_short       ;make wide EN pulse
      CBI   PORTB, 0      ;EN = 0 for H-to-L pulse
      RCALL delay_us          ;delay in micro seconds
      ;----------------------------------------------------
      MOV   R27, R16
      SWAP  R27               ;swap nibbles
      ANDI  R27, 0xF0         ;mask low nibble & keep high nibble
      OUT   PORTD, R27        ;o/p high nibble to port D
      SBI   PORTB, 0      ;EN = 1
      RCALL delay_short       ;widen EN pulse
      CBI   PORTB, 0      ;EN = 0 for H-to-L pulse
      RCALL delay_us          ;delay in micro seconds
      RET
;================================================================
disp_message:
      LDI   R16, 'T'          ;display characters
      RCALL data_wrt          ;via data register
                              ;delay 0.25s
      LDI   R16, 'E'
      RCALL data_wrt
      
      LDI   R16, 'M'
      RCALL data_wrt
      
      LDI   R16, 'P'
      RCALL data_wrt
      
      LDI   R16, '='
      RCALL data_wrt
      
      RCALL convert_temp

      LDI   R16, ' '
      RCALL data_wrt 

      LDI   R16, 'd'
      RCALL data_wrt

      LDI   R16, 'e'
      RCALL data_wrt

      LDI   R16, 'g'
      RCALL data_wrt 
    
      LDI   R16, '.'
      RCALL data_wrt

      LDI   R16, 'C'
      RCALL data_wrt
      ;----------------
      LDI   R16, 0xC0         ;cursor beginning of 2nd line
      RCALL command_wrt
      RCALL delay_ms
      ;----------------
      LDI   R16, 'H'
      RCALL data_wrt
      
      LDI   R16, 'U'
      RCALL data_wrt
      
      LDI   R16, 'M'
      RCALL data_wrt
      
      LDI   R16, 'I'
      RCALL data_wrt
      
      LDI   R16, 'D'
      RCALL data_wrt
      
      LDI   R16, 'I'
      RCALL data_wrt
      
      LDI   R16, 'T'
      RCALL data_wrt
      
      LDI   R16, 'Y'
      RCALL data_wrt
      
      LDI   R16, '='
      RCALL data_wrt
      
      RCALL convert_humidity
      

      LDI   R16, '%'
      RCALL data_wrt
      
      ;----------------
      LDI   R17, 4           ;wait 3 seconds
      RJMP  agn

;================================================================
;================================================================
disp_message2:
      LDI   R16, 'T'          ;display characters
      RCALL data_wrt          ;via data register
                              ;delay 0.25s
      LDI   R16, 'E'
      RCALL data_wrt
      
      LDI   R16, 'M'
      RCALL data_wrt
      
      LDI   R16, 'P'
      RCALL data_wrt
      
      LDI   R16, '='
      RCALL data_wrt
      
      RCALL convert_temp

      LDI   R16, 'd'
      RCALL data_wrt

      LDI   R16, 'e'
      RCALL data_wrt

      LDI   R16, 'g'
      RCALL data_wrt      

      LDI   R16, '.'
      RCALL data_wrt

      LDI   R16, 'C'
      RCALL data_wrt
      ;----------------
      LDI   R16, 0xC0         ;cursor beginning of 2nd line
      RCALL command_wrt
      RCALL delay_ms
      ;----------------
      LDI   R16, 'H'
      RCALL data_wrt
      
      LDI   R16, 'U'
      RCALL data_wrt
      
      LDI   R16, 'M'
      RCALL data_wrt
      
      LDI   R16, 'I'
      RCALL data_wrt
      
      LDI   R16, 'D'
      RCALL data_wrt
      
      LDI   R16, 'I'
      RCALL data_wrt
      
      LDI   R16, 'T'
      RCALL data_wrt
      
      LDI   R16, 'Y'
      RCALL data_wrt
      
      LDI   R16, '='
      RCALL data_wrt
      
      RCALL convert_humidity
      

      LDI   R16, '%'
      RCALL data_wrt
      
      ;----------------
      LDI   R17, 4           ;wait 3 seconds
      RJMP  agn

;================================================================
delay_short:
      NOP
      NOP
      RET
;------------------------
delay_us:
      LDI   R20, 90
x2:   RCALL delay_short
      DEC   R20
      BRNE  x2
      RET
;-----------------------
delay_ms:
      LDI   R21, 40
x3:   RCALL delay_us
      DEC   R21
      BRNE  x3
      RET
;================================================================
delay_seconds:        ;nested loop subroutine (max delay 3.11s)
    LDI   R20, 255    ;outer loop counter 
x6: LDI   R21, 255    ;mid loop counter
x5: LDI   R22, 20     ;inner loop counter to give 0.25s delay
x4: DEC   R22         ;decrement inner loop
    BRNE  x4          ;loop if not zero
    DEC   R21         ;decrement mid loop
    BRNE  x5          ;loop if not zero
    DEC   R20         ;decrement outer loop
    BRNE  x6          ;loop if not zero
    RET               ;return to caller
;----------------------------------------------------------------
;==============================================================
binary2decimal:
;--------------
      CLR   R26             ;set counter1, initial value 0
      CLR   R27             ;set counter2, initial value 0
      ;--------------------------------------------------------
l70:  CPI   R28, 100        ;compare R28 with 100
Ret:  BRMI  l80             ;jump when R28 < 100
      INC   R26             ;increment counter1 by 1
      SUBI  R28, 100        ;R28 = R28 - 100
      RJMP  l70
      ;--------------------------------------------------------
l80:  CPI   R28, 10         ;compare R28 with 10
      BRMI  dsp             ;jump when R28 < 10
      INC   R27             ;increment counter2 by 1
      SUBI  R28, 10         ;R28 = R28 - 10
      RJMP  l80
      ;--------------------------------------------------------  
dsp:  MOV   R18, R27
      RCALL send_bytes     
      ;--------------------------------------------------------
      MOV   R18, R28
      RCALL send_bytes       
      ;--------------------------------------------------------
      RET
;-----------------------------------------------------------------
;convert temp & humidity bytes to decimal & display on MAX7219
;-------------------------------------------------------------
convert_temp:
    MOV   R28, R18
    ;-------------------
    RCALL binary2decimal  ;temp in decimal
    ;-------------------
    RET
convert_humidity:
    MOV   R28, R19
    ;-------------------
    RCALL binary2decimal  ;humidity in decimal
    ;-------------------
    RET                   ;go back & get another sensor reading
;=================================================================
;==============================================================
send_bytes:
      LDI R21, 48
      ADD R18, R21
      MOV R16, R18
      RCALL data_wrt
      RET
;==============================================================
