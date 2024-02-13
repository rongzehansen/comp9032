;
; ass_1.asm
;
; Created: 30/10/2023 8:30:30 PM
; Author : Rongze Han
;


.include "m2560def.inc"

; PLEASE AVOID USING R16 (LCD RELATED)
.def temp1 = r22						
.def temp2 = r23						

.equ PORTLDIR = 0xF0								; use PortL for input/output from keypad: PF7-4, output, PF3-0, input
.equ INITCOLMASK = 0xEF								; scan from the leftmost column, the value to mask output
.equ INITROWMASK = 0x01								; scan from the top row
.equ ROWMASK = 0x0F									; high four bits are input from the keypad. This value mask the low 4

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4

.macro get_keystroke								; KEYPAD RELATED
	ldi ZL, low(key_table<<1)
	ldi ZH, high(key_table<<1)
													; calculate the index using: index = 4 * row + col
	ldi temp1, 4									; temp1 = 4
	ldi XL, low(row)					
	ldi XH, high(row)
	ld temp2, X										; temp2 = row
	
	mul temp1, temp2
	add ZL, r0
	adc ZH, r1
	ldi XL, low(col)					
	ldi XH, high(col)
	ld temp2, X										; temp2 = col
	
	add ZL, temp2
	brcc set_keystroke								; branch if carry is not set
	inc ZH

set_keystroke:
	lpm @0, Z										; load ASCII value of the keypad input into @0

.endmacro

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
; DRONE RELATED
state: .db 0										; 0 - F, 1 - H, 2 - R, 3 - C
position: .db 0, 0, 0								; x, y, z
speed: .db 0							
direction: .db 0									; N, E, S, W, U, D

; KEYPAD RELATED
row: .db 0
col: .db 0
rmask: .db 0
cmask: .db 0
maskb: .db 0

.cseg
.org 0x00
	jmp RESET

.org OC1Aaddr
	jmp Timer1_COMPA_ISR

key_table:											; W/A/S/D -> N/E/S/W, Q -> UP, E -> DOWN, X -> SWITCH, 0 -> NONE
.db '1', '2', '3', 'A'								; Q W E 0
.db '4', '5', '6', 'B'								; A S D 0
.db '7', '8', '9', 'C'								; 0 X 0 0
.db '*', '0', '#', 'D'								; 0 0 0 0

RESET:
	ldi temp1, low(RAMEND)
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1

	; KEYPAD RELATED - PORTL
	ldi temp1, PORTLDIR								; columns are outputs, rows are inputs
	sts DDRL, temp1
	ser temp1
	ldi temp1, ROWMASK
	sts PORTL, temp1								; Activate pull-ups for PF3-0

	; LED RELATED - PORTC
	ser temp1
	out DDRC, temp1	
	out PORTC, temp1

	; PUSH BUTTONS RELATED - PORT D
	clr temp1
	out DDRD, temp1
	ldi temp1, 0b00000011				
	out PORTD, temp1								; Activate pull-ups for PB1-0
	
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

Timer1_COMPA_ISR:									; interrupt subroutine
prologue:
	push ZH											; Save all conflict registers in the prologue.
	push ZL
	push YH											
	push YL 
	push XH
	push XL
	push temp2										
	push temp1
	push r16										; in case the interrupt happens during the execution of do_lcd_data or do_lcd_command
	push r1											; in case the interrupt happens during the execution of get_keystroke
	push r0											; in case the interrupt happens during the execution of get_keystroke

chapter1:
	call update_status

chapter2:
	call output_status
	cpi r17, 0
	breq test1
	brne test2

test1:
	ldi r17, 1
	ldi temp1, 0b01010101
	out PORTC, temp1
	jmp epilogue

test2:
	ldi r17, 0
	ldi temp1, 0b10101010
	out PORTC, temp1
	jmp epilogue

epilogue:
	pop r0											; Restore all conflict registers from the stack.
	pop r1	
	pop r16
	pop temp1
	pop temp2
	pop XL											
	pop XH
	pop YL
	pop YH
	pop ZL
	pop ZH

	reti											; return to where the interrupt happens

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

	sei												; Global interrupt enable

loop:
	call keypad_main								; keypad scanning subroutine
	call inputs_main								; push buttons scanning subroutine - 2 nested subroutines
	rjmp loop

keypad_return:
	ret												; return to main

keypad_main:
	ldi temp1, INITCOLMASK				
	ldi XL, low(cmask)
	ldi XH, high(cmask)
	st X, temp1										; initial column mask

	ldi temp1, 0
	ldi XL, low(col)
	ldi XH, high(col)
	st X, temp1										; initial column

keypad_colloop:
	ldi XL, low(col)
	ldi XH, high(col)
	ld temp1, X										; temp1 = col
	cpi temp1, 4
	breq keypad_return

	ldi XL, low(cmask)
	ldi XH, high(cmask)
	ld temp1, X										; temp1 = cmask
	sts PORTL, temp1

keypad_readinput:		
	rcall sleep_30ms
					
	lds temp1, PINL
	andi temp1, ROWMASK
	ldi XL, low(maskb)					
	ldi XH, high(maskb)
	st X, temp1
	cpi temp1, 0x0F									; check if any rows are on
	breq keypad_nextcol
													; if yes, find which row is on
	ldi temp1, INITROWMASK				
	ldi XL, low(rmask)					
	ldi XH, high(rmask)
	st X, temp1										; initialise row check
	
	ldi temp1, 0
	ldi XL, low(row)
	ldi XH, high(row)
	st X, temp1										; initial row

keypad_rowloop:
	ldi XL, low(row)
	ldi XH, high(row)
	ld temp1, X										; temp1 = row
	cpi temp1, 4
	breq keypad_nextcol
	
	ldi XL, low(maskb)					
	ldi XH, high(maskb)
	ld temp1, X
	mov temp2, temp1

	ldi XL, low(rmask)					
	ldi XH, high(rmask)
	ld temp1, X
	and temp2, temp1								; check masked bit
	breq keypad_srecord

	ldi XL, low(row)					
	ldi XH, high(row)
	ld temp1, X										; temp1 = row
	inc temp1
	st X, temp1

	ldi XL, low(rmask)					
	ldi XH, high(rmask)
	ld temp1, X										; temp1 = rmask
	lsl temp1
	st X, temp1

	rjmp keypad_rowloop

keypad_nextcol:
	ldi XL, low(cmask)					
	ldi XH, high(cmask)
	ld temp1, X										; temp1 = cmask
	lsl temp1
	ori temp1, 0x01									; set the LSB to '1' after shifting, we don't want to disable pull-up
	st X, temp1

	ldi XL, low(col)					
	ldi XH, high(col)
	ld temp1, X										; temp1 = col
	inc temp1
	st X, temp1

	jmp keypad_colloop

keypad_srecord:										; start recording
	rcall keypad_waitrelease
	get_keystroke temp1

keypad_erecord:										; end recording
	;mov temp2, temp1
	;subi temp2, '0'
	;out PORTC, temp2
	cpi temp1, '2'									; fly forward
	breq keypad_north

	cpi temp1, '6'									; fly rightward
	breq keypad_east

	cpi temp1, '5'									; fly backward
	breq keypad_south

	cpi temp1, '4'									; fly leftward
	breq keypad_west

	cpi temp1, '1'									; fly upward
	breq keypad_up

	cpi temp1, '3'									; fly downward
	breq keypad_down

	cpi temp1, '8'
	breq keypad_switch								; switch between flight and hover mode

	jmp keypad_return								; ignore input

keypad_north:
	ldi XL, low(direction)
	ldi XH, high(direction)
	ldi temp1, 'N'
	st X, temp1
	jmp keypad_return

keypad_east:
	ldi XL, low(direction)
	ldi XH, high(direction)
	ldi temp1, 'E'
	st X, temp1
	jmp keypad_return

keypad_south:
	ldi XL, low(direction)
	ldi XH, high(direction)
	ldi temp1, 'S'
	st X, temp1
	jmp keypad_return

keypad_west:
	ldi XL, low(direction)
	ldi XH, high(direction)
	ldi temp1, 'W'
	st X, temp1
	jmp keypad_return

keypad_up:
	ldi XL, low(direction)
	ldi XH, high(direction)
	ldi temp1, 'U'
	st X, temp1
	jmp keypad_return

keypad_down:
	ldi XL, low(direction)
	ldi XH, high(direction)
	ldi temp1, 'D'
	st X, temp1
	jmp keypad_return

keypad_switch:
	ldi XL, low(state)
	ldi XH, high(state)
	ld temp1, X
	cpi temp1, 0									; current state is F
	breq keypad_hover								; switch to H
	cpi temp1, 1									; current state is H
	breq keypad_flight								; switch to F
	jmp keypad_return								; do nothing

keypad_hover:
	ldi temp1, 1
	st X, temp1
	jmp keypad_return

keypad_flight:
	ldi temp1, 0
	st X, temp1
	jmp keypad_return

keypad_waitrelease:
	lds temp1, PINL									; read the button state
	ldi XL, low(rmask)					
	ldi XH, high(rmask)
	ld temp2, X										; temp2 = rmask
	and temp1, temp2								; mask the current row
	brne keypad_donerelease
	rjmp keypad_waitrelease

keypad_donerelease:
	rcall sleep_30ms								; This will ensure that it won't immediately start scanning for another button press 
    ret												; and will further debounce the release action of the button

inputs_return:
	ret												; return to main

inputs_main:
	sbis PIND, 0									; Skip the next instruction if PB0 is high (pin will read as low (0) when the button is pressed due to the pull-up resistor)
	rcall input0_srecord							; return from input0_erecord
	sbis PIND, 1									; Skip the next instruction if PB1 is high (pin will read as low (0) when the button is pressed due to the pull-up resistor)
	rcall input1_srecord							; return from input1_erecord

	;in temp1, PIND
	;out PORTC, temp1

	jmp inputs_return
						
input0_srecord:
	rcall input0_waitrelease

input0_erecord:
	ldi XL, low(speed)
	ldi XH, high(speed)
	ld temp1, X
	dec temp1
	sbrc temp1, 7									; make sure speed is not negative, if true change it back to 0
	ldi temp1, 0						
	st X, temp1
	;out PORTC, temp1

	ret												; return to inputs_main

input0_waitrelease:
	sbic PIND, 0									; Skip the next instruction if PB0 is low
	rjmp input0_donerelease
	rjmp input0_waitrelease

input0_donerelease:
	rcall sleep_30ms								; This will ensure that it won't immediately start scanning for another button press 
    ret												; and will further debounce the release action of the button

input1_srecord:
	rcall input1_waitrelease

input1_erecord:
	ldi XL, low(speed)
	ldi XH, high(speed)
	ld temp1, X
	inc temp1
	sbrc temp1, 7									; make sure speed is not exceeding 127, if true change it back to 127
	ldi temp1, 127
	st X, temp1
	;out PORTC, temp1

	ret												; return to inputs_main

input1_waitrelease:
	sbic PIND, 1									; Skip the next instruction if PB1 is low
	rjmp input1_donerelease
	rjmp input1_waitrelease

input1_donerelease:
	rcall sleep_30ms								; This will ensure that it won't immediately start scanning for another button press 
    ret												; and will further debounce the release action of the button

update_status:
	; TODO - YOU CAN OUTPUT DIFFERENT DRONE STATUS TO PORT C FOR DEBUGGING
	; DRONE STATUS
	; state: .db 0									; 0 - F, 1 - H, 2 - R, 3 - C
	; position: .db 0, 0, 0							; x, y, z
	; speed: .db 0							
	; direction: .db 0								; 0 - N, 1 - E, 2 - S, 3 - W, 4 - UP, 5 - DOWN

	ret

output_status:
	; TODO
	do_lcd_command 0b00000001						; Clear display

	do_lcd_command 0b11001111
	ldi XL, low(direction)
	ldi XH, high(direction)
	ld temp1, X
	do_lcd_data temp1

	do_lcd_command 0b11001110
	ldi temp1, '/'
	do_lcd_data temp1

	do_lcd_command 0b11001101
	ldi XL, low(speed)
	ldi XH, high(speed)
	ld temp1, X
	subi temp1, -'0'
	do_lcd_data temp1

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