;
; lab_0.asm
;
; Created: 12/09/2023 4:02:30 PM
; Author : rdcor
;


; Replace with your application code
.include "m2560def.inc"
.def a=r16				;define a to be register r16
.def b=r17				;define b to be register r17
.def c=r10				;define c to be register r10

main:					;main is a label
	ldi a, 10			;load  value 10 into a
	ldi b, -20			;load  value -20 into b  
	lsl a;				;2*a
	add a, b			;2*a+b
	mov c, a			;c=2*a+b

halt:
	rjmp halt			;halt the processor execution
