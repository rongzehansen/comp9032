;
; task_1.asm
;
; Created: 12/09/2023 4:20:10 PM
; Author : Rongze Han
;


.include "m2560def.inc"

.def signed_binary=r3
.def s_ascii_value=r4
.def trd_ascii_dig=r5
.def snd_ascii_dig=r6
.def fst_ascii_dig=r7

main:
	ldi r16, '+'							; load ascii value of '+' into r16 register
	mov s_ascii_value, r16					; copy register

	ldi r16, '0'							; load ascii value of '0' into r16 register
	mov trd_ascii_dig, r16					; Initialize the units place with '0'
	mov snd_ascii_dig, r16					; Initialize the tens place with '0'
	mov fst_ascii_dig, r16					; Initialize the hundreds place with '0'

	tst signed_binary
	brpl convert_to_ascii					; If positive or zero, skip to conversion
	ldi r16, '-'							; load ascii value of '-' into r16 register
	mov s_ascii_value, r16					; copy register
	neg signed_binary						; two's complement

convert_to_ascii:
	ldi   r24, 100							; Load 100 to a temp register
divide_hundreds:
    cp signed_binary, r24					; Compare R3 with 100
    brmi handle_tens						; If less than 100, move to tens
    sub signed_binary, r24					; Subtract 100 from R3
    inc fst_ascii_dig						; Increment the hundreds place
    rjmp divide_hundreds

handle_tens:
    ldi r24, 10								; Load 10 to a temp register
divide_tens:
    cp signed_binary, r24					; Compare R3 with 10
    brmi handle_units						; If less than 10, move to units
    sub signed_binary, r24					; Subtract 10 from R3
    inc snd_ascii_dig						; Increment the tens place
    rjmp divide_tens

handle_units:
    add   trd_ascii_dig, signed_binary      ; Convert to ASCII

halt:
	rjmp halt			
