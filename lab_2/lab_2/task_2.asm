;
; task_2.asm
;
; Created: 4/10/2023 9:26:15 PM
; Author : Rongze Han
;


.include "m2560def.inc"

.DSEG
len_s1: .db 0
len_s2: .db 0

prev_row: .db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
curr_row: .db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

.CSEG
.org 0x00
rjmp init

s1: .db "T18A has 1 student.", 0
s2: .db "Lab class T18A has no students at all.", 0

.def r_cost=r6
.def i_cost=r7
.def d_cost=r8
.def cost=r9

.def cmp_flag=r19

.macro length									; count the number of words
	ldi r16, 0
	ldi ZL, low(@0<<1)
	ldi ZH, high(@0<<1)

count_char:
	lpm r17, Z+
	cpi r17, 0									; check if it reaches the end of the sentence
	breq store_len								; if yes, store the number in DSEG
	cpi r17, ' '								; check if it reaches the empty space
	brne count_char								; if yes, counter goes up by 1
	inc r16
	rjmp count_char

store_len:
	inc r16
	ldi XL, low(@1)
    ldi XH, high(@1)
    st X, r16
	
.endmacro

.macro compare									; kinda same as the strcmp() function in C

cmp_char:
	mov ZL, @2
	mov ZH, @3
	lpm r25, Z+									; s2 char
	mov @2, ZL
	mov @3, ZH

	mov ZL, @0
	mov ZH, @1
	lpm r24, Z+									; s1 char
	mov @0, ZL
	mov @1, ZH

	cp r24, r25									; check if both chars are the same
	brne check_char								; if not, check if one is ' ' and the other one is '.'
	
	cpi r24, ' '								; check if both chars are ' '
	breq eq_str

	cpi r24, '.'								; check if both chars are '.'
	breq eq_str

	rjmp cmp_char

check_char:
	add r24, r25								; get the result of the sum of two ascii values
	cpi r24, 78									; ' ' + '.' == 78
	brne ne_str									; if this is not the case, compare set flag to 1
	rjmp eq_str

eq_str:
	ldi cmp_flag, 0								; mark flag as 0, meaning both strings are the same
	rjmp cmp_done

ne_str:
	ldi cmp_flag, 1								; mark flag as 1, meaning both strings are not the same

mov_ptr_s1:										; point current s1 pointer to the next word in s1
	lpm r24, Z+
	mov @0, ZL
	mov @1, ZH
	cpi r24, ' '
	breq cmp_done
	rjmp mov_ptr_s1

cmp_done:

.endmacro

.macro minimum									; get the minium number from three numbers
	cp @0, @1									; first compare the first number and the second one
	brcs min_2
	mov cost, @1								; copy the smallest @1
	rjmp min_3

min_2:
	mov cost, @0								; copy the smallest @0

min_3:
	cp cost, @2									; compare the result with the third number
	brcs min_done								; if @2 is the smallest, update the result
	mov cost, @2

min_done:

.endmacro

init:
	length s1, len_s1							; get the number of words from s1
	length s2, len_s2							; get the number of words from s2

	ldi r16, 0
	ldi XL, low(len_s1)							
	ldi XH, high(len_s1)
	ld r17, X									; store n_words of s1 in register
	inc r17										; increase it by 1 because the number of rows in the matrix is n_words + 1
	ldi XL, low(len_s2)
	ldi XH, high(len_s2)
	ld r18, X									; store n_words of s2 in register
	inc r18										; increase it by 1 because the number of columns in the matrix is n_words + 1

	ldi XL, low(prev_row)						; point X to the start of prev_row
	ldi XH, high(prev_row)

init_prev_row:									; fill prev_row with 0, 1, 2, 3, 4, 5... up to n_words
	st X+, r16
	inc r16
	cp r16, r17
	brne init_prev_row
	ldi r16, 1

main:
	ldi r20, low(s1<<1)							; store the address of the start of s1
	ldi r21, high(s1<<1)
	ldi r22, low(s2<<1)							; store the address of the start of s2
	ldi r23, high(s2<<1)
	
	inc r2										; row counter

outer_loop:
	cpse r2, r18
	rjmp init_1st_col
	rjmp halt
	
init_1st_col:
	ldi XL, low(curr_row)
	ldi XH, high(curr_row)
	ldi r20, low(s1<<1)
	ldi r21, high(s1<<1)
	ldi cmp_flag, 0								; cmp flag
	ldi r16, 0									; col counter

	st X+, r2									; row_counter | x | x | x | x | x |...
	inc r16
	mov r4, r22									; temp store the address of s2
	mov r5, r23
	mov d_cost, r2								; delete cost for the next col is the first col
	ldi YL, low(prev_row)
	ldi YH, high(prev_row)
	ld r_cost, Y+								; load replace cost, and ready for the next one
	ld i_cost, Y+								; load insert cost, and ready for the next one

inner_loop_p1:
	mov r22, r4									; restore the address of s2
	mov r23, r5

	compare r20, r21, r22, r23					; strcmp, it takes s1 ptr and s2 ptr, s2 will not move

	cpi cmp_flag, 0								; check the result
	breq get_cost_eq							; if it is equal
	brne get_cost_ne							; if it is not equal

inner_loop_p2:
	mov d_cost, cost							; update delete cost, the next col will use the current cost
	mov r_cost, i_cost							; update replace cost, the next col will use the current insert cost
	ld i_cost, Y+								; update insert cost

	inc r16
	cp r16, r17									; check if the calulation for the whole row is done
	brne inner_loop_p1

	mov r22, r4
	mov r23, r5

	inc r2										; increase row counter
	mov ZL, r22									; reset
	mov ZH, r23

	cp r2, r18									; check if the calulation for the whole table is done
	breq output_result

mov_ptr_s2:										; shift s2 pointer to the next word of s2
	lpm r25, Z+									
	mov r22, ZL
	mov r23, ZH
	cpi r25, ' '
	breq update_row
	rjmp mov_ptr_s2

get_cost_eq:									; calulate the cost when two strings are equal (take the replace cost)
	st X+, r_cost

	rjmp inner_loop_p2	

get_cost_ne:									; calulate the cost when two strings are not equal (take the minimum of those three, and add 1)
	minimum r_cost, i_cost, d_cost
	inc cost
	st X+, cost

	rjmp inner_loop_p2	

update_row:
	ldi XL, low(curr_row)						; reset s1 pointer to the beginning of s1
	ldi XH, high(curr_row)
	ldi YL, low(prev_row)
	ldi YH, high(prev_row)

	ldi r16, 0

update_col:										; the values inside prev_row is replaced by the value inside curr_row
	ld r10, X+
	
	st Y+, r10

	inc r16
	cp r16, r17
	brne update_col
	rjmp outer_loop

output_result:
	ld r11, -X

halt:
	rjmp halt	
