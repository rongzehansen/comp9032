;
; exam.asm
;
; Created: 5/12/2023 2:25:30 PM
; Author : Rongze Han
;


.include "m2560def.inc"
.org 0x00             ; Origin, start at address 0
.set PARITYTYPE = 0   ; Set parity type, 0 for even, 1 for odd
.def temp = r16       ; Temporary register for function use
.def par_result = r20 ; Register for storing parity result
.def input_low = r18  ; Lower byte of input
.def input_high = r19 ; Higher byte of input
.def parity_type = r22 ; Parity type input for function P

; Initialize stack pointer (required for function calls that use the stack)
ldi temp, LOW(RAMEND) ; Load low byte of RAMEND into temp
out SPL, temp         ; Set stack pointer low byte to RAMEND
ldi temp, HIGH(RAMEND) ; Load high byte of RAMEND into temp
out SPH, temp         ; Set stack pointer high byte to RAMEND

; Clear registers
clr r0                ; Clear register R0, used for function output
clr r1                ; Clear register R1, commonly used as a constant zero
clr par_result        ; Clear register R20, will store our parity result

; Load parity type into register for function use
ldi parity_type, PARITYTYPE

; Load Z pointer with the start of the string in program memory
ldi ZL, low(STRING_START*2)
ldi ZH, high(STRING_START*2)

; Main program loop
main_loop:
    lpm input_low, Z+ ; Load a byte from program memory into lower byte of input
    lpm input_high, Z+ ; Load next byte from program memory into higher byte of input
    cpse input_low, r1 ; Compare input_low with 0 (assuming r1 is cleared to 0)
    rjmp end_of_string ; If end of string, jump to end

    ; Call the parity function
    mov r18, input_low  ; Move lower byte of input to r18
    mov r19, input_high ; Move higher byte of input to r19
    mov r20, parity_type ; Copy the parity type into r20 for the function
    rcall P ; Call the parity function

    ; Store the parity result in bit 0 of par_result
    bst r0, 0 ; Store bit 0 of r0 (parity result) to T
    bld par_result, 0 ; Load T to bit 0 of par_result
    rjmp main_loop ; Repeat the loop for next character

end_of_string:
    ; Here you can handle the end of the string case
    ; For this example, we will just halt
    rjmp end_of_string ; Infinite loop

; Function P (parity calculation)
P:
    push r0 ; Save r0
    push r1 ; Save r1
    clr r0  ; Clear r0 for parity calculation
    mov r1, r18 ; Copy low byte of input to r1 for processing
    mov r0, r19 ; Copy high byte of input to r0 for processing

    ; Initialize loop counter for 16-bit parity calculation
    ldi r18, 0x00
    ldi r19, 0x10 ; 16 loops for 16 bits

parity_loop:
    ; Shift and rotate through all 16 bits
    lsr r1     ; Shift right through carry, lower byte
    ror r0     ; Rotate right through carry, upper byte

    ; Decrement the loop counter
    sbiw r18, 0x01 ; Subtract immediate from word
    brne parity_loop ; Continue loop if not yet zero

    ; At this point, the LSB of r0 contains the even parity.
    ; If t is 1 (odd parity), we need to invert the LSB of r0.
    tst r20 ; Test if t (in r20) is zero
    breq even_parity ; If zero, branch to even_parity

odd_parity:
    com r0 ; Complement r0 if odd parity is requested
    rjmp parity_done ; Skip to end

even_parity:
    ; For even parity, r0 is already correct

parity_done:
    ; Store the parity result back in r0 and restore the registers
    andi r0, 0x01    ; Isolate the parity bit
    pop r1          ; Restore r1 from the stack
    pop r0          ; Restore r0 from the stack
    ret             ; Return from subroutine

STRING_START:
    .db 'H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd', 0
