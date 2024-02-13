;
; task_2.asm
;
; Created: 13/09/2023 2:20:10 PM
; Author : Rongze Han
;


.include "m2560def.inc"

.def a=r16
.def l_a_cubed=r17
.def m_a_cubed=r18
.def h_a_cubed=r19
.def l_result=r20
.def h_result=r21

.def l_counter=r25
.def h_counter=r26


main:
	; Assuming input 'a' is in register a

	; Initialize 24-bit result to zero
	clr l_a_cubed								; Result 8-bit Low Byte
	clr m_a_cubed								; Result 16-bit Middle-Low Byte
	clr h_a_cubed								; Result 24-bit Middle-High Byte

	clr l_counter
	clr h_counter
	
	; Step 2: Compute a^2 and store in l_a_cubed-m_a_cubed (16-bit result)

	mul a, a ; Multiply a with itself. 
	mov l_a_cubed, r0							; l_a_cubed has low byte of a^2
	mov m_a_cubed, r1							; m_a_cubed has high byte of a^2

	; Step 3: Multiply a^2 by a. (a * a^2 = a^3)

	; Multiply l_a_cubed (low byte of a^2) by a
	mul l_a_cubed, a
	mov r22, r0									; Temporarily store in R22
	mov r23, r1									; Temporarily store in R23

	; Multiply m_a_cubed (high byte of a^2) by a
	mul m_a_cubed, a
	add r23, r0									; Add to the result of the previous multiplication
	adc h_a_cubed, r1							; Add with carry to next byte

	; Transfer back the results to l_a_cubed-R20
	mov l_a_cubed, r22
	mov m_a_cubed, r23

find_sqrt:
	clr r0
	clr r1
	clr r22
	clr r23
	clr r24

	mul l_counter, l_counter
	mov r22, r0
	mov r23, r1

	mul l_counter, h_counter
	add r23, r0
	adc r24, r1

	mul h_counter, l_counter
	add r23, r0
	adc r24, r1

	mul h_counter, h_counter
    add r24, r0

	cp r24, h_a_cubed							; compare r24 with the high byte of a^3
	brlo increment								; if r24 is less than the high byte of a^3, go to increase
	brne get_sqrt								; if r24 is not equal to the high byte of a^3, then it's greater

	cp r23, m_a_cubed							; compare r23 with middle byte of a^3
	brlo increment								; if r23 is less than the middle byte of a^3, go to increase
	brne get_sqrt								; if r23 is not equal to the middle byte of a^3, then it's greater

	cp r22, l_a_cubed							; compare r22 with the low byte of a^3
	brlo increment								; if r22 is less than the low byte of a^3, go to increase
	rjmp get_sqrt								; if r23 is not equal to the low byte of a^3, then it's greater

increment:
	inc l_counter								; Increment l_counter
	brne find_sqrt								; If there's no overflow, skip the increment of h_counter
	inc h_counter								; Increment h_counter to handle the carry from l_counter
	rjmp find_sqrt

decrement:
	dec l_counter								; Decrement the low byte
	brne found_sqrt								; If the result is not 0x00, then it didn't wrap around. Skip the next instruction.
	dec h_counter								; Decrement the high byte because the low byte wrapped around
	rjmp found_sqrt

get_sqrt:
	; The result is greater, check if it needs decrement
	cpse r24, h_a_cubed							
	rjmp decrement
	cpse r23, m_a_cubed
	rjmp decrement
	cpse r22, l_a_cubed
	rjmp decrement

found_sqrt:
	mov l_result, l_counter
	mov h_result, h_counter
    
halt:
	rjmp halt			
