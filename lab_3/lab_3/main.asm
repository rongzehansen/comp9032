;
; lab_3.asm
;
; Created: 13/10/2023 3:18:15 PM
; Author : Rongze Han, Chenhao Wu
;


.include "m2560def.inc"

.dseg
append_flag:
.db 0

axby:
.db 0, 0, 0, 0

.cseg
.org 0x00
	rjmp RESET

key_table:
.db '1', '2', '3', 'A'
.db '4', '5', '6', 'B'
.db '7', '8', '9', 'C'
.db '*', '0', '#', 'D'

; row, col
.macro get_value
	ldi ZL, low(key_table<<1)
	ldi ZH, high(key_table<<1)
								; calculate the index using: index = 4*row + col
	ldi r22, 4
	mul r22, @0
	add ZL, r0
	adc ZH, r1
	add ZL, @1
	brcc set_value				; branch if carry is not set
	inc ZH
set_value:
	lpm r22, Z					; load ASCII value of the keypad input into uint8
.endmacro

.macro lin_func					; YOU MIGHT WANT TO ADD OTHER INSTRUCTIONS HERE TO HANDLE OVERFLOW
	ldi XL, low(axby)
	ldi XH, high(axby)
	ld r23, X+
	ld r20, X+
	mul r23, r20
	mov r23, r0
	ld r20, X+
	sub r23, r20
	st X, r23
.endmacro

.macro do_lcd_command
	ldi r20, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	mov r20, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro
.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

.def row=r16					; current row number
.def col=r17					; current column number
.def rmask=r18					; mask for current row
.def cmask=r19					; mask for current column
.def temp1=r20		
.def temp2=r21
.def input=r22
.def uint8=r23

.equ PORTLDIR=0xF0				; use PortL for input/output from keypad: PF7-4, output, PF3-0, input
.equ INITCOLMASK=0xEF			; scan from the leftmost column, the value to mask output
.equ INITROWMASK=0x01			; scan from the top row
.equ ROWMASK=0x0F				; high four bits are input from the keypad. This value mask the low 4 
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

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

;
; Send a command to the LCD (temp1)
;

lcd_command:
	out PORTF, temp1
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
	out PORTF, temp1
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
	push temp1
	clr temp1
	out DDRF, temp1
	out PORTF, temp1
	lcd_set LCD_RW
lcd_wait_loop:
	nop
	lcd_set LCD_E
	nop
	nop
    nop
	in temp1, PINF
	lcd_clr LCD_E
	sbrc temp1, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser temp1
	out DDRF, temp1
	pop temp1
	ret

RESET:
	; INIT STACK PTR
	ldi temp1, high(RAMEND)
	sts SPH, temp1
	ldi temp1, low(RAMEND)
	sts SPL, temp1

	; KEYPAD RELATED - PORTL
	ldi temp1, PORTLDIR			; columns are outputs, rows are inputs
	sts DDRL, temp1
	ser temp1
	out DDRC, temp1	
	out PORTC, temp1
	ldi temp1, ROWMASK
	sts PORTL, temp1			; Activate pull-ups for PF3-0

	ldi YL, low(axby)			; DO NOT MODIFIY Y POINTER BEFORE GETTING THE RESULT
	ldi YH, high(axby)

	; LCD RELATED - PORTF
	ser temp1
	out DDRF, temp1
	out DDRA, temp1
	clr temp1
	out PORTF, temp1
	out PORTA, temp1

	; Initialize backlight control (PE5) as output
	sbi DDRE, 5

	; Turn ON the backlight
	sbi PORTE, 5

	; Initialize LCD
    do_lcd_command 0b00111000	; Function set: 8-bit interface, 2 lines, 5x7 dots
    do_lcd_command 0b00001100	; Display on, Cursor off
    do_lcd_command 0b00000110	; Entry Mode: Increment cursor position, No display shift
    do_lcd_command 0b00000001	; Clear display

main:
	ldi cmask, INITCOLMASK		; initial column mask
	clr	col						; initial column
colloop:
	cpi col, 4
	breq main
	sts PORTL, cmask			; set column to mask value (one column off)
	ldi temp1, 0xFF
delay:
	rcall sleep_30ms

	lds temp1, PINL
	andi temp1, ROWMASK
	cpi temp1, 0x0F				; check if any rows are on
	breq nextcol
								; if yes, find which row is on
	ldi rmask, INITROWMASK		; initialise row check
	clr	row						; initial row
rowloop:
	cpi row, 4
	breq nextcol
	mov temp2, temp1
	and temp2, rmask			; check masked bit
	breq record 		
	inc row						; else move to the next row
	lsl rmask					; shift the mask to the next bit
	jmp rowloop
nextcol:
	lsl cmask					; else get new mask by shifting and 
	ori cmask, 0x01				; set the LSB to '1' after shifting, we don't want to disable pull-up
	inc col						; increment column value
	jmp colloop					; and check the next column
record:
	rcall wait_for_release	
	ldi XL, low(append_flag)
	ldi XH, high(append_flag)
	
	get_value row, col

	jmp record_end

record_end:
	cpi input, '*'				; case - '*'
	breq multiply
	cpi input, '#'				; case - '#'
	breq equal
	cpi input, 'A'				; case - 'A'
	breq ignore
	cpi input, 'B'				; case - 'B'
	breq ignore
	cpi input, 'C'				; case - 'C'
	breq convert
	cpi input, 'D'				; case - 'D'
	breq minus
	jmp digit

multiply:
	ldi temp2, 0				; reset append flag
	st X, temp2
	st Y+, uint8
	jmp main
equal:							; YOU CAN USE uint8 DIRECTLY OR USE THE LAST DATA OF axby INSIDE DSEG BEFORE IT'S BEING RESET
	ldi temp2, 0				; reset append flag
	st X, temp2
	st Y+, uint8
	lin_func
	ldi YL, low(axby)			; reset axby pointer for next input sequence, better reset axby if possible
	ldi YH, high(axby)
	;jmp output_led				; YOU CAN JMP TO OTHER LABELS THAT HANDLE LCD, this label is only for debugging
	jmp output_lcd_decimal
ignore:
	jmp main					; ignore invalid input
convert:
	ldi temp2, 0				; reset append flag
	st X, temp2

	jmp output_lcd_hexadecimal
minus:
	ldi temp2, 0				; reset append flag
	st X, temp2
	st Y+, uint8
	jmp main
digit:
	subi input, '0'				; the input is the ascii value of the digit, so sub '0' to get the actual value
	ld temp2, X					
	cpi temp2, 0				; check append flag
	brne append_digit			; if it's not the first digit entered, then append digit to the previous one
	mov uint8, input
	ldi temp2, 1				; indicate that the next digit entered will be appended to the current one
	st X, temp2					; update flag value in dseg
	jmp output_led				
append_digit:
	ldi temp1, 10
	mul uint8, temp1
	mov uint8, r0
	add uint8, input
	jmp output_led
output_led:						; debugging output
	out PORTC, uint8
	jmp main

output_lcd_decimal:
	do_lcd_command 0b00000001
	mov r3, uint8

	out PORTC, uint8			; debugging output
	tst uint8
	brpl convert_to_ascii		; If positive or zero, skip to conversion
	ldi temp2, '-'
	do_lcd_data temp2
	neg uint8					; two's complement
convert_to_ascii:
	ldi temp1, 100				; Load 100 to a temp register
	ldi temp2, '0'
divide_hundreds:
    cp uint8, temp1				; Compare uint8 with 100
    brmi handle_tens			; If less than 100, move to tens
    sub uint8, temp1			; Subtract 100 from uint8
    inc temp2					; Increment the hundreds place
    rjmp divide_hundreds
handle_tens:
	do_lcd_data temp2
    ldi temp1, 10				; Load 10 to a temp register
	ldi temp2, '0'
divide_tens:
    cp uint8, temp1				; Compare uint8 with 10
    brmi handle_units			; If less than 10, move to units
    sub uint8, temp1			; Subtract 10 from uint8
    inc temp2					; Increment the tens place
    rjmp divide_tens
handle_units:
	do_lcd_data temp2
	ldi temp2, '0'
    add temp2, uint8			; Convert to ASCII
	do_lcd_data temp2

	mov uint8, r3				; restore uint8
	jmp main

output_lcd_binary:
	do_lcd_command 0b00000001	; Clear display
    
	out PORTC, uint8			; debugging output
	ldi temp1, 8				; Count of bits to process
display_loop:
    lsl uint8					; Shift left, bringing the leftmost bit to the carry
    brcc bit_is_0				; If carry is not set, jump to bit_is_0

    ; Bit is 1
    ldi temp2, '1'				; Load ASCII '1' into temp2
    rjmp send_to_lcd
bit_is_0:
    ldi temp2, '0'				; Load ASCII '0' into temp2
send_to_lcd:
	mov r3, temp1				; the next instruction will mod temp1, therefore we need to create a restore point
    do_lcd_data temp2
	mov temp1, r3				; restore temp1
    dec temp1					; Decrement bit count
    brne display_loop			; If not done, continue loop
	jmp main

output_lcd_hexadecimal:
	do_lcd_command 0b00000001	; Clear display

	mov r3, uint8

	out PORTC, uint8			; debugging output
	tst uint8
	brpl convert_to_ascii_x		; If positive or zero, skip to conversion
	ldi temp2, '-'
	do_lcd_data temp2
	neg uint8					; two's complement

convert_to_ascii_x:
	ldi temp2, '0'
	do_lcd_data temp2
	ldi temp2, 'x'
	do_lcd_data temp2
	clr temp2

	swap uint8					; Swap nibbles, upper -> lower, lower -> upper
	ldi temp1, 0x0F				; Mask for the upper 4 bits
	and temp1, uint8			; Get the upper 4 bits
	rcall convert_to_hex
	do_lcd_data temp2		
	
	swap uint8					; Get the original uint8
	ldi temp1, 0x0F				; Mask for the upper 4 bits
	and temp1, uint8			; Get the lower 4 bits
	rcall convert_to_hex
    do_lcd_data temp2			; Display on LCD

	mov uint8, r3				; restore uint8

	jmp main

convert_to_hex:
    cpi temp1, 10				; Check if the value is 10 or above
    brlo is_digit				; If lower, it's a digit

    ; It's A-F
    subi temp1, -55				; Convert to ASCII ('A' is 65, 'B' is 66, etc.)
    mov temp2, temp1
    ret

is_digit:
    ; It's 0-9
    subi temp1, -48				; Convert to ASCII ('0' is 48, '1' is 49, etc.)
    mov temp2, temp1
    ret

wait_for_release:				; core logic for debouncing mechanism
    lds temp1, PINL				; read the button state
    and temp1, rmask			; mask the current row
    brne wait_done				; if button is not pressed, exit the loop
    rjmp wait_for_release		; otherwise, keep checking
wait_done:
	rcall sleep_30ms			; This will ensure that it won't immediately start scanning for another button press 
    ret							; and will further debounce the release action of the button
halt:
	rjmp halt