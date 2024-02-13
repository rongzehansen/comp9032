;
; task_3.asm
;
; Created: 23/09/2023 2:20:10 PM
; Author : Rongze Han
;


.include "m2560def.inc"

.def a=r16
.def b=r17
.def counter=r18

; Macro to compute the Greatest Common Divisor (GCD) of two numbers
.macro gcd
	mov a, @0							; Load the first argument into 'a'
	mov b, @1							; Load the second argument into 'b'

loop:
	cp a, b								; Compare 'a' and 'b'
	breq done							; If 'a' is equal to 'b', jump to 'done'
	brlo else							; If 'a' is less than 'b', jump to 'else'
	sub a, b							; Subtract 'b' from 'a'
	rjmp loop							; Jump back to start of loop

else:									; 'a' is greater than 'b'
	sub b, a							; Subtract 'a' from 'b'
	rjmp loop							; Jump back to start of loop

done:	
	
.endmacro

main:
	ldi r26, 0x01						; Load the address of r1 to r26

process_array:	
	cp counter, r0						; Compare 'counter' with the array length
	brsh halt							; If 'counter' >= r0, jump to 'halt' (end of processing)

	ld r19, X+							; Load the next array element into r19 and increment the X pointer
	inc counter

	gcd r1, r19							; Call the 'gcd' macro with r1 and r19 as arguments

	mov r1, a

	rjmp process_array					; Jump back to process the next element of the array
	
halt:
	rjmp halt			