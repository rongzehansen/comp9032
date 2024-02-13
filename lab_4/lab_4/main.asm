;
; lab_4.asm
;
; Created: 2/11/2023 2:27:35 PM
; Author : rdcor
;


.include "m2560def.inc"

.def rots = r19										; 4 rotations = 1 revolution
.def revsl = r20									; low byte of revolutions
.def revsh = r21									; high bye of revolutions
.def temp1 = r22						
.def temp2 = r23	

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait

.endmacro

.macro do_lcd_data
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait

.endmacro

.macro lcd_set
	sbi PORTA, @0

.endmacro

.macro lcd_clr
	cbi PORTA, @0

.endmacro

.dseg
flag: .db 0

.cseg
.org 0x00
	jmp RESET

.org OC1Aaddr
	jmp Timer1_COMPA_ISR

RESET:
	ldi temp1, low(RAMEND)
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1

	; LED RELATED - PORTC
	ser temp1
	out DDRC, temp1	
	out PORTC, temp1

	; MOTOR RELATED - PORTB
	cbi DDRB, DDB1
	sbi DDRB, DDB0
	sbi PORTB, PORTB0								

	; LCD RELATED - PORTF
	ser temp1
	out DDRF, temp1
	out DDRA, temp1
	clr temp1
	out PORTF, temp1
	out PORTA, temp1
	sbi DDRE, 5
	sbi PORTE, 5

	do_lcd_command 0b00111000						; Function set: 8-bit interface, 2 lines, 5x7 dots
    do_lcd_command 0b00001100						; Display on, Cursor off
    do_lcd_command 0b00000110						; Entry Mode: Increment cursor position, No display shift
    do_lcd_command 0b00000001						; Clear display

	rjmp main	

Timer1_COMPA_ISR:
prologue:
	push ZH											; Save all conflict registers in the prologue.
	push ZL
	push YH											
	push YL 
	push XH
	push XL
	push temp2										
	push temp1
	;push revsh
	;push revsl
	push rots
	push r16										; in case the interrupt happens during the execution of do_lcd_data or do_lcd_command

chapter1:
	;ldi temp1, 1
	;ldi XL, low(flag)
	;ldi XH, high(flag)
    ;st X, temp1
	call output_revs
	out PORTC, revsh
	clr revsl
    clr revsh

epilogue:
	pop r16
	pop rots
	;pop revsl
	;pop revsh
	pop temp1
	pop temp2
	pop XL											
	pop XH
	pop YL
	pop YH
	pop ZL
	pop ZH

	reti		

main:
	; INTERRUPT RELATED
	; Set up Timer/Counter1 in CTC mode
	ldi temp1, (1 << WGM12)							; Set WGM12 bit for CTC mode
	sts TCCR1B, temp1

	; Load compare value for 1s interrupt @ 16MHz clock with 256 prescaler
	ldi temp1, high(62499)
	sts OCR1AH, temp1
	ldi temp1, low(62499)
	sts OCR1AL, temp1

	; Set prescaler to 256
	lds temp1, TCCR1B								; Load current value of TCCR1B
	ori temp1, (1 << CS12)							; Set CS12 bit for prescaler of 256
	andi temp1, ~((1 << CS11) | (1 << CS10))		; Clear CS11 and CS10 bits
	sts TCCR1B, temp1

	; Enable Timer1 Compare Match A interrupt
	ldi temp1, (1 << OCIE1A)
	sts TIMSK1, temp1

	sei

loop:
	call motor_main
	;ldi XL, low(flag)
	;ldi XH, high(flag)
	;ld temp1, X
	;cpi temp1, 1
	;breq output_revs
	rjmp loop

motor_main:
	sbic PINB, PINB1
	ret

motor_srecord:
	rcall motor_waitrot
	
	cpi rots, 4										; if rotations == 4
	breq motor_erecord
	
	inc rots										; rotations++

	ret

motor_erecord:
	clr rots										; reset rotations
;
	inc revsl
;	
	clr temp1
	cpse revsl, temp1
	ret
;	
	inc revsh
	ret
	

motor_waitrot:
	sbic PINB, PINB1								; Skip the next instruction if PB1 is low
	rjmp motor_donerot
	rjmp motor_waitrot

motor_donerot:
	ret

output_revs:
	
	; Clear LCD and reset flag
    do_lcd_command 0b00000001
    ;clr temp1
	;ldi XL, low(flag)
	;ldi XH, high(flag)
    ;st X, temp1

convert_to_ascii:
	ldi r16, '0'
	ldi temp1, 100									; Load 100 to a temp register
divide_hundreds:
    cp revsl, temp1									; Compare R3 with 100
    brmi handle_tens								; If less than 100, move to tens
    sub revsl, temp1								; Subtract 100 from R3
    inc r16											; Increment the hundreds place
    rjmp divide_hundreds

handle_tens:
	do_lcd_data r16
	ldi r16, '0'
    ldi temp1, 10									; Load 10 to a temp register

divide_tens:
    cp revsl, temp1									; Compare R3 with 10
    brmi handle_units								; If less than 10, move to units
    sub revsl, temp1								; Subtract 10 from R3
    inc r16											; Increment the tens place
    rjmp divide_tens

handle_units:
	do_lcd_data r16
	ldi r16, '0'
    add r16, revsl									; Convert to ASCII
	do_lcd_data r16
    
    ;rjmp main
	ret

;
; Send a command to the LCD (r16)
;

lcd_command:
	out PORTF, r16
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	nop
	nop
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	nop
	lcd_set LCD_E
	nop
	nop
    nop
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

sleep_30ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret