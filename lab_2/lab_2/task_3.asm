;
; task_3.asm
;
; Created: 8/10/2023 12:26:15 PM
; Author : Group D
;


.include "m2560def.inc"

    ;   - The button is connected to PINB.0
    ;   - The second button is connected to PINB.1
    ;   - The LED bar is connected to PORTC (using middle 6 LEDs)

    ; Initialize registers
    ldi r20, 0x00       ; State counter
    ldi r16, 0b11111100 ; Mask for middle 6 LEDs

	ldi r17, 0xAA
	ldi r18, 0x55
	ldi r19, 0xFF
	mov r12, r17
	mov r13, r18
	mov r14, r19

main_loop:
    sbic PINB, 0        ; Check if button is pressed
    rjmp button_pressed ; If yes, jump to button_pressed label

    sbic PINB, 1        ; Check if second button is pressed
    rjmp reset_display  ; If yes, reset display

    rjmp main_loop      ; If no button is pressed, keep polling

button_pressed:
    inc r20             ; Increment state counter
    cpi r20, 4          ; Check if state is 4
    brne update_display ; If not, update display

auto_cycle:
    out PORTC, r12      ; Display first pattern
    rcall delay_500ms
    out PORTC, r13      ; Display second pattern
    rcall delay_500ms
    out PORTC, r14      ; Display third pattern
    rcall delay_500ms

    sbic PINB, 1        ; Check if second button is pressed during auto cycle
    rjmp reset_display  ; If yes, reset display

    rjmp auto_cycle     ; Continue cycling

update_display:
    cpi r20, 1
    breq display_pattern1
    cpi r20, 2
    breq display_pattern2
    cpi r20, 3
    breq display_pattern3

display_pattern1:
    and r12, r16        ; Apply mask to use only middle 6 LEDs
    out PORTC, r12      ; Output pattern 1 to LED bar
    rjmp main_loop

display_pattern2:
    and r13, r16        ; Apply mask to use only middle 6 LEDs
    out PORTC, r13      ; Output pattern 2 to LED bar
    rjmp main_loop

display_pattern3:
    and r14, r16        ; Apply mask to use only middle 6 LEDs
    out PORTC, r14      ; Output pattern 3 to LED bar
    rjmp main_loop

reset_display:
    ldi r20, 0x00       ; Reset state counter
    clr r21             ; Clear any previous pattern
    out PORTC, r21      ; Clear LED bar
    rjmp main_loop

delay_500ms:
    ; Nested loop for delay
    ldi r24, 250        ; Outer loop counter
outer_loop:
    ldi r25, 64         ; Middle loop counter
middle_loop:
    ldi r26, 128        ; Inner loop counter
inner_loop:
    dec r26
    brne inner_loop

    dec r25
    brne middle_loop

    dec r24
    brne outer_loop
    ret