***********************************************************************
*
* Title:          Signal Wave Generation and Digital Clock Program
*
* Objective:      CMPEN 472 Homework 10
*
* Revision:       V1.2  for CodeWarrior 5.2 Debugger Simulation
*
* Date:	          13 November 2024
*
* Programmer:     Tyler Korz
*
* Company:        Student at The Pennsylvania State University
*                 Department of Computer Science and Engineering
*
* Program:        RTI usage
*                 Typewriter program and 7-Segment display, at PORTB
*                 Terminal and Waveform generation
*                 
*
* Algorithm:      Simple Serial I/O use, typewriter, RTIs, OC6
*
* Register use:	  A, B, X, Y, CCR
*
* Memory use:     RAM Locations from $3000 for data, 
*                 RAM Locations from $3100 for program
*
*	Input:			    Parameters hard-coded in the program - PORTB, 
*                 Terminal connected over serial
* Output:         
*                 Terminal connected over serial
*                 PORTB bit 7 to bit 4, 7-segment MSB
*                 PORTB bit 3 to bit 0, 7-segment LSB
*
* Observation:    This is a menu-driven program that prints to and receives
*                 data from a terminal, and will do different things based 
*                 on user input. Change the clock time, display the time,
*                 and generate different waveforms.
*
***********************************************************************
* Parameter Declearation Section
*
* Export Symbols
            XDEF        Entry        ; export 'Entry' symbol
            ABSENTRY    Entry        ; for assembly entry point

; include derivative specific macros
PORTB       EQU         $0001
DDRB        EQU         $0003

SCIBDH      EQU         $00C8        ; Serial port (SCI) Baud Register H
SCIBDL      EQU         $00C9        ; Serial port (SCI) Baud Register L
SCICR2      EQU         $00CB        ; Serial port (SCI) Control Register 2
SCISR1      EQU         $00CC        ; Serial port (SCI) Status Register 1
SCIDRL      EQU         $00CF        ; Serial port (SCI) Data Register

TIOS        EQU         $0040   ; Timer Input Capture (IC) or Output Compare (OC) select
TIE         EQU         $004C   ; Timer interrupt enable register
TCNTH       EQU         $0044   ; Timer free runing main counter
TSCR1       EQU         $0046   ; Timer system control 1
TSCR2       EQU         $004D   ; Timer system control 2
TFLG1       EQU         $004E   ; Timer interrupt flag 1
TC6H        EQU         $005C   ; Timer channel 2 register

CRGFLG      EQU         $0037        ; Clock and Reset Generator Flags
CRGINT      EQU         $0038        ; Clock and Reset Generator Interrupts
RTICTL      EQU         $003B        ; Real Time Interrupt Control

CR          equ         $0d          ; carriage return, ASCII 'Return' key
LF          equ         $0a          ; line feed, ASCII 'next line' character

DATAmax     equ         2048    ; Data count maximum, 1024 constant

;*******************************************************
; variable/data section
            ORG    $3000             ; RAMStart defined as $3000
                                     ; in MC9S12C128 chip

timeh       DS.B   1
timem       DS.B   1
times       DS.B   1
ctr2p5m     DS.W   1                 ; interrupt counter for 2.5 mSec. of time

half        DS.B   1                 ; used for determining when a second has passed
dec         DS.B   1                 ; stores the decimal input as hex
hms         DS.B   1
opcode      DS.B   1

CCount      DS.B        $0001        ; Number of chars in buffer
CmdBuff     DS.B        $000B        ; The actual command buffer

DecBuff     DS.B        $0006        ; used for decimal conversions
HCount      DS.B        $0001        ; number of ASCII characters for Hex conversion
DCount      DS.B        $0001        ; number of ASCII characters for Decimal

ctr125u     DS.W   1            ; 16bit interrupt counter for 125 uSec. of time

BUF         DS.B   6            ; character buffer for a 16bit number in decimal ASCII
CTR         DS.B   1            ; character buffer fill count

gwcount     DS.B   2
gtcount     DS.B   1
gtcount2    DS.B   1

sqcount     DS.B   1
sqflag      DS.B   1
gtflag      DS.B   1

carry       DS.B   1



;*******************************************************
; interrupt vector section
            ORG    $FFF0             ; RTI interrupt vector setup for the simulator
;            ORG    $3FF0             ; RTI interrupt vector setup for the CSM-12C128 board
            DC.W   rtiisr
            
            ORG     $FFE2       ; Timer channel 6 interrupt vector setup, on simulator
            DC.W    oc6isr

;*******************************************************
; code section

           ORG    $3100           ; Set origin for the code
            
Entry
            LDS    #Entry         ; Initialize the stack pointer

            LDAA   #%11111111     ; Load accumulator A with value to set all PORTB bits
            STAA   DDRB           ; Set all bits of PORTB as output
            STAA   PORTB          ; Initialize PORTB by setting all bits to high

            LDAA   #$0C           ; Load value to enable SCI port Tx and Rx units
            STAA   SCICR2         ; Disable SCI interrupts for now

            LDD    #$0002         ; Load register D with value for SCI Baud Rate = 1M baud at 24MHz
            STD    SCIBDH         ; Set SCI port baud rate

            LDAA   #$00           ; Load accumulator A with 0
            STAA   PORTB          ; Display 00 on PORTB (clear display)

            STAA   timeh          ; Initialize high part of time variable to 0
            STAA   timem          ; Initialize middle part of time variable to 0
            STAA   times          ; Initialize low part of time variable to 0

            LDX    #msg1          ; Load X register with address of msg1 for welcome message
            JSR    printmsg       ; Call subroutine to print welcome message
            JSR    nextline       ; Call subroutine to move to the next line
            JSR    nextline       ; Move to the next line again

            LDX    #menu1         ; Load X with address of menu1 (cmd instructions)
            JSR    printmsg       ; Print menu1 instructions
            JSR    nextline       ; Move to next line
            
            LDX    #menu2         ; Load X with address of menu2
            JSR    printmsg       ; Print menu2 instructions
            JSR    nextline       ; Move to next line
            
            LDX    #menu3         ; Load X with address of menu3
            JSR    printmsg       ; Print menu3 instructions
            JSR    nextline       ; Move to next line
            
            LDX    #menu4         ; Load X with address of menu4
            JSR    printmsg       ; Print menu4 instructions
            JSR    nextline       ; Move to next line
            JSR    nextline       ; Additional line break

            LDX    #menu5         ; Load X with address of menu5
            JSR    printmsg       ; Print menu5 instructions
            JSR    nextline       ; Move to next line
            
            LDX    #menu6         ; Load X with address of menu6
            JSR    printmsg       ; Print menu6 instructions
            JSR    nextline       ; Move to next line
            
            LDX    #menu7         ; Load X with address of menu7
            JSR    printmsg       ; Print menu7 instructions
            JSR    nextline       ; Move to next line
            
            LDX    #menu8         ; Load X with address of menu8
            JSR    printmsg       ; Print menu8 instructions
            JSR    nextline       ; Move to next line
            
            LDX    #menu9         ; Load X with address of menu9
            JSR    printmsg       ; Print menu9 instructions
            JSR    nextline       ; Move to next line
            JSR    nextline       ; Additional line break

            LDX    #menu10        ; Load X with address of menu10
            JSR    printmsg       ; Print menu10 instructions
            JSR    nextline       ; Move to next line
            JSR    nextline       ; Additional line break
            JSR    nextline       ; Additional line break

            BSET   RTICTL,%00011001 ; Set RTI rate to 2.555ms
            BSET   CRGINT,%10000000 ; Enable RTI interrupt
            BSET   CRGFLG,%10000000 ; Clear RTI interrupt flag (RTI IF)


            LDX    #0                ; Load X register with 0
            STX    ctr2p5m           ; Initialize interrupt counter with 0
            CLI                      ; Enable global interrupts

            CLR    half              ; Clear the half counter
            CLR    times             ; Clear the seconds counter
            CLR    timem             ; Clear the minutes counter
            CLR    timeh             ; Clear the hours counter

            LDX    #prompt           ; Load X register with address of prompt message
            JSR    printmsg          ; Call subroutine to print the prompt message

main

            LDX    #CmdBuff          ; Load X register with address of command buffer
            CLR    CCount            ; Clear the character count
            CLR    HCount            ; Clear the half count
            JSR    clrBuff           ; Call subroutine to clear the command buffer

            LDX    #CmdBuff          ; Load X register with address of command buffer
            LDAA   #$0000            ; Load accumulator A with 0 (initialize value)

looop
            JSR    CountAndDisplay   ; Call subroutine to count and display time

            JSR    getchar           ; Call subroutine to check for keyboard input
            TSTA                     ; Test accumulator A (check if a key was pressed)
            BEQ    looop             ; If no key was pressed, continue looping

            CMPA   #CR               ; Compare typed character with Enter key (Carriage Return)
            BEQ    noReturn          ; If Enter key, skip storing character
            JSR    putchar           ; Call subroutine to display typed character

noReturn    
            STAA   1,X+              ; Store typed character in buffer at position 1 and increment X
            INC    CCount            ; Increment character count
            LDAB   CCount            ; Load character count into accumulator B
            CMPB   #$0B              ; Compare character count with 11 (max buffer size)
            LBHI   IError            ; If buffer is full, jump to error handling

            CMPA   #CR               ; Compare typed character with Enter key
            BNE    looop             ; If not Enter key, continue looping

            LDAB   CCount            ; Load character count into B
            CMPB   #$02              ; Compare with 2 (minimum required characters, including Enter)
            LBLO   IError            ; If less than 2 characters, jump to error handling

            LDX    #CmdBuff          ; Reload X register with address of command buffer
            LDAA   1,X+              ; Load the first character from buffer into A

CmdChk      
            CMPA   #$68              ; Compare with 'h' command
            LBEQ   h                 ; If 'h', jump to h command handler
            CMPA   #$6D              ; Compare with 'm' command
            LBEQ   m                 ; If 'm', jump to m command handler
            CMPA   #$74              ; Compare with 't' command
            LBEQ   t                 ; If 't', jump to t command handler
            CMPA   #$73              ; Compare with 's' command
            LBEQ   s                 ; If 's', jump to s command handler
            CMPA   #$71              ; Compare with 'q' command
            LBEQ   q                 ; If 'q', jump to quit command handler

            CMPA   #$67              ; Compare with 'g' command
            LBEQ   g                 ; If 'g', jump to g command handler
                       
            
IError                                ; Error handling: unrecognized command entered
            JSR   nextline            ; Move to the next line
            LDX   #errmsg1            ; Load X with address of error message
            JSR   printmsg            ; Print the error message
            JSR   nextline            ; Move to the next line
            JSR   nextline            ; Additional line break
            LDX   #prompt             ; Load X with address of prompt message
            JSR   printmsg            ; Print the prompt message

            LBRA  main                ; Loop back to beginning to await new command input

g           LDAA   1,X+               ; Load the next character from buffer into A

            CMPA   #$77               ; Check if character is 'w'
            LBEQ   g2                 ; If 'w', jump to g2 handler
            CMPA   #$74               ; Check if character is 't'
            LBEQ   g3                 ; If 't', jump to g3 handler
            CMPA   #$71               ; Check if character is 'q'
            LBEQ   g4                 ; If 'q', jump to g4 handler

            LBRA   IError             ; If character does not match, jump to error handler

g2          LDAA   1,X+               ; Load the next character from buffer into A
            CMPA   #$0D               ; Check if character is Carriage Return (CR)
            LBEQ   gw                 ; If CR, proceed to gw handler
            CMPA   #$32               ; Check if character is '2'
            LBEQ   g22                ; If '2', proceed to g22 handler

            LBRA   IError             ; If character does not match, jump to error handler

g22         LDAA   1,X+               ; Load the next character from buffer into A
            CMPA   #$0D               ; Check if character is Carriage Return (CR)
            LBEQ   gw2                ; If CR, proceed to gw2 handler

            LBRA   IError             ; If character does not match, jump to error handler

g3          LDAA   1,X+               ; Load the next character from buffer into A
            CMPA   #$0D               ; Check if character is Carriage Return (CR)
            LBEQ   gt                 ; If CR, proceed to gt handler

            LBRA   IError             ; If character does not match, jump to error handler

g4          LDAA   1,X+               ; Load the next character from buffer into A
            CMPA   #$0D               ; Check if character is Carriage Return (CR)
            LBEQ   gq                 ; If CR, proceed to gq handler
            CMPA   #$32               ; Check if character is '2'
            LBEQ   g44                ; If '2', proceed to g44 handler

            LBRA   IError             ; If character does not match, jump to error handler

g44         LDAA   1,X+               ; Load the next character from buffer into A
            CMPA   #$0D               ; Check if character is Carriage Return (CR)
            LBEQ   gq2                ; If CR, proceed to gq2 handler

            LBRA   IError             ; If character does not match, jump to error handler       

TError                                ; Error handling: unrecognized command entered
            JSR   nextline            ; Move to the next line
            LDX   #errmsg2            ; Load X with address of second error message
            JSR   printmsg            ; Print the error message
            JSR   nextline            ; Move to the next line
            LDX   #prompt             ; Load X with address of prompt message
            JSR   printmsg            ; Print the prompt message
            JSR   nextline            ; Move to the next line
            LDX   #prompt             ; Reload X with address of prompt message again
            JSR   printmsg            ; Print the prompt message again

            LBRA  main                ; Loop back to beginning to await new command input

t
            LDAA  1,X+                ; Load next character from buffer into A
            CMPA  #$20                ; Ensure the second character is a space
            BNE   TError              ; If not a space, jump to error handler
            CLR   dec                 ; Clear the decimal variable

            LDAA  1,X+                ; Load the next character (expected to be a number)
            CMPA  #$30                ; Ensure character is a number
            BLO   TError              ; If below '0', jump to error handler
            CMPA  #$32                ; Ensure character is '2' or less
            BHI   TError              ; If greater than '2', jump to error handler

            BEQ   t2                  ; If character is '0', jump to t2 handler

            SUBA  #$30                ; ASCII number offset to convert character to digit
            LDAB  #10                 ; Set weight of the most significant digit to 10
            MUL                       ; Multiply A by 10, result stored in D
            STAB  dec                 ; Store result in dec

            LDAA  1,X+                ; Load the next character (expected to be a number)
            CMPA  #$30                ; Ensure character is a number
            BLO   TError              ; If below '0', jump to error handler
            CMPA  #$39                ; Ensure character is '9' or less
            BHI   TError              ; If greater than '9', jump to error handler
            SUBA  #$30                ; ASCII number offset to convert character to digit
            LDAB  #1                  ; Set weight of the least significant digit to 1
            MUL                       ; Multiply A by 1, result stored in D
            LDAA  dec                 ; Load previously stored 10s place number
            ABA                       ; Add 10s place and 1s place numbers
            STAA  dec                 ; Store final decimal value in dec
            BRA   t3                  ; Jump to t3 handler

t2
            SUBA  #$30                ; ASCII number offset to convert character to digit
            LDAB  #10                 ; Set weight of the most significant digit to 10
            MUL                       ; Multiply A by 10, result stored in D
            STAB  dec                 ; Store result in dec

            LDAA  1,X+                ; Load the next character (expected to be a number)
            CMPA  #$30                ; Ensure character is a number
            BLO   TError              ; If below '0', jump to error handler
            CMPA  #$33                ; Ensure character is '3' or less
            BHI   TError              ; If greater than '3', jump to error handler
            SUBA  #$30                ; ASCII number offset to convert character to digit
            LDAB  #1                  ; Set weight of the least significant digit to 1
            MUL                       ; Multiply A by 1, result stored in D
            LDAA  dec                 ; Load previously stored 10s place number
            ABA                       ; Add 10s place and 1s place numbers
            STAA  dec                 ; Store final decimal value in dec

t3          
            STAA  timeh             ; Save hours in timeh variable
            CLR   dec               ; Clear the decimal variable

            LDAA  1,X+              ; Load the next character from buffer into A
            CMPA  #$3A              ; Ensure next character is ':'
            BNE   TError            ; If not ':', jump to error handler

            LDAA  1,X+              ; Load the next character (expected to be a number)
            CMPA  #$30              ; Ensure character is a number
            BLO   TError1           ; If below '0', jump to specific error handler
            CMPA  #$35              ; Ensure character is '5' or less
            BHI   TError1           ; If greater than '5', jump to specific error handler
            SUBA  #$30              ; ASCII number offset to convert character to digit
            LDAB  #10               ; Set weight of the most significant digit to 10
            MUL                     ; Multiply A by 10, result stored in D
            STAB  dec               ; Store result in dec

            LDAA  1,X+              ; Load the next character (expected to be a number)
            CMPA  #$30              ; Ensure character is a number
            BLO   TError1           ; If below '0', jump to specific error handler
            CMPA  #$39              ; Ensure character is '9' or less
            BHI   TError1           ; If greater than '9', jump to specific error handler
            SUBA  #$30              ; ASCII number offset to convert character to digit
            LDAB  #1                ; Set weight of the least significant digit to 1
            MUL                     ; Multiply A by 1, result stored in D
            LDAA  dec               ; Load previously stored 10s place number
            ABA                     ; Add 10s place and 1s place numbers
            STAA  dec               ; Store result in dec

            STAA  timem             ; Save minutes in timem variable
            CLR   dec               ; Clear the decimal variable

            LDAA  1,X+              ; Load the next character from buffer into A
            CMPA  #$3A              ; Ensure next character is ':'
            BNE   TError1           ; If not ':', jump to specific error handler

            LDAA  1,X+              ; Load the next character (expected to be a number)
            CMPA  #$30              ; Ensure character is a number
            BLO   TError1           ; If below '0', jump to specific error handler
            CMPA  #$35              ; Ensure character is '5' or less
            BHI   TError1           ; If greater than '5', jump to specific error handler
            SUBA  #$30              ; ASCII number offset to convert character to digit
            LDAB  #10               ; Set weight of the most significant digit to 10
            MUL                     ; Multiply A by 10, result stored in D
            STAB  dec               ; Store result in dec

            LDAA  1,X+              ; Load the next character (expected to be a number)
            CMPA  #$30              ; Ensure character is a number
            BLO   TError1           ; If below '0', jump to specific error handler
            CMPA  #$39              ; Ensure character is '9' or less
            BHI   TError1           ; If greater than '9', jump to specific error handler
            SUBA  #$30              ; ASCII number offset to convert character to digit
            LDAB  #1                ; Set weight of the least significant digit to 1
            MUL                     ; Multiply A by 1, result stored in D
            LDAA  dec               ; Load previously stored 10s place number
            ABA                     ; Add 10s place and 1s place numbers
            STAA  dec               ; Store final seconds in dec

            STAA  times             ; Save seconds in times variable

            CLR   half              ; Clear the half variable
            LDX   #$0000            ; Load X with 0
            STX   ctr2p5m           ; Initialize interrupt counter to 0

            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message again
            JSR   printmsg          ; Print the prompt message again

            LBRA  main              ; Loop back to beginning to await new command input

TError1                             ; Specific error handler for invalid time format
            JSR   nextline          ; Move to the next line
            LDX   #errmsg2          ; Load X with address of second error message
            JSR   printmsg          ; Print the error message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Reload X with address of prompt message again
            JSR   printmsg          ; Print the prompt message again

            LBRA  main              ; Loop back to beginning to await new command input

h
            CMPB  #$02              ; Check if command length is 2
            BNE   HError            ; If not, jump to specific error handler
            STAA  hms               ; Store command in hms variable
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message again
            JSR   printmsg          ; Print the prompt message again
            LBRA  main              ; Loop back to beginning to await new command input

m
            CMPB  #$02              ; Check if command length is 2
            BNE   MError            ; If not, jump to specific error handler
            STAA  hms               ; Store command in hms variable
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message again
            JSR   printmsg          ; Print the prompt message again
            LBRA  main              ; Loop back to beginning to await new command input

s
            CMPB  #$02              ; Check if command length is 2
            BNE   SError            ; If not, jump to specific error handler
            STAA  hms               ; Store command in hms variable
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message again
            JSR   printmsg          ; Print the prompt message again
            LBRA  main              ; Loop back to beginning to await new command input
            
HError      
            JSR   nextline          ; Move to the next line
            LDX   #errmsg5          ; Load X with address of error message for 'H' command
            JSR   printmsg          ; Print the error message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Reload X with address of prompt message
            JSR   printmsg          ; Print the prompt message again

            LBRA  main              ; Loop back to beginning to await new command input

MError      
            JSR   nextline          ; Move to the next line
            LDX   #errmsg4          ; Load X with address of error message for 'M' command
            JSR   printmsg          ; Print the error message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Reload X with address of prompt message
            JSR   printmsg          ; Print the prompt message again

            LBRA  main              ; Loop back to beginning to await new command input

SError      
            JSR   nextline          ; Move to the next line
            LDX   #errmsg3          ; Load X with address of error message for 'S' command
            JSR   printmsg          ; Print the error message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message
            JSR   nextline          ; Move to the next line
            LDX   #prompt           ; Reload X with address of prompt message
            JSR   printmsg          ; Print the prompt message again

            LBRA  main              ; Loop back to beginning to await new command input

q
            CMPB  #$02              ; Check if command length is 2
            BNE   SError            ; If not, jump to error handler
            LBRA  ttyStart          ; Branch to ttyStart

gw
            LDAA  #$00              ; Set opcode to 0
            STAA  opcode            ; Store opcode for 'gw' command

            JSR   nextline          ; Move to the next line
            LDX   #gwmsg            ; Load X with address of sawtooth message
            JSR   printmsg          ; Print the sawtooth message
            JSR   nextline          ; Move to the next line
            JSR   nextline          ; Additional line break

            LBRA  TI                ; Branch to TI for further processing

gw2
            LDAA  #$01              ; Set opcode to 1
            STAA  opcode            ; Store opcode for 'gw2' command
            CLR   gwcount           ; Clear the gwcount variable
            CLR   carry             ; Clear the carry flag

            JSR   nextline          ; Move to the next line
            LDX   #gw2msg           ; Load X with address of 100Hz sawtooth message
            JSR   printmsg          ; Print the 100Hz sawtooth message
            JSR   nextline          ; Move to the next line
            JSR   nextline          ; Additional line break

            LBRA  TI                ; Branch to TI for further processing

gt
            LDAA  #$02              ; Set opcode to 2
            STAA  opcode            ; Store opcode for 'gt' command
            CLR   gtcount           ; Clear the gtcount variable
            CLR   gtflag            ; Clear the gtflag

            JSR   nextline          ; Move to the next line
            LDX   #gtmsg            ; Load X with address of triangle message
            JSR   printmsg          ; Print the triangle message
            JSR   nextline          ; Move to the next line
            JSR   nextline          ; Additional line break

            LBRA  TI                ; Branch to TI for further processing

gq
            LDAA  #$03              ; Set opcode to 3
            STAA  opcode            ; Store opcode for 'gq' command
            CLR   sqcount           ; Clear the sqcount variable
            CLR   sqflag            ; Clear the sqflag

            JSR   nextline          ; Move to the next line
            LDX   #gqmsg            ; Load X with address of square wave message
            JSR   printmsg          ; Print the square wave message
            JSR   nextline          ; Move to the next line
            JSR   nextline          ; Additional line break
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message

            LBRA  TI                ; Branch to TI for further processing
            
gq2
            LDAA  #$04              ; Set opcode to 4
            STAA  opcode            ; Store opcode for 'gq2' command (100Hz square wave)
            CLR   sqcount           ; Clear the square wave count variable
            CLR   sqflag            ; Clear the square wave flag

            JSR   nextline          ; Move to the next line
            LDX   #gq2msg           ; Load X with address of 100Hz square wave message
            JSR   printmsg          ; Print the 100Hz square wave message
            JSR   nextline          ; Move to the next line
            JSR   nextline          ; Additional line break
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message

            LBRA  TI                ; Branch to TI for further processing

TI          
            LDX   #msg5             ; Load X with address of terminal save file message
            JSR   printmsg          ; Print '> Set Terminal save file RxData3.txt'
            JSR   nextline          ; Move to the next line

            LDX   #msg6             ; Load X with address of enter key start message
            JSR   printmsg          ; Print '> Press Enter/Return key to start sawtooth wave'
            JSR   nextline          ; Move to the next line

            JSR   delay1ms          ; Flush out SCI serial port, wait to finish sending last characters

loop2
            JSR   CountAndDisplay   ; Call subroutine to count and display time
            JSR   getchar           ; Call subroutine to check for keyboard input
            CMPA  #0                ; Compare accumulator A with 0
            BEQ   loop2             ; If no key is pressed, continue looping
            CMPA  #CR               ; Compare with Enter/Return key
            BNE   loop2             ; If not Enter/Return, continue looping

            JSR   nextline          ; Move to the next line
            JSR   nextline          ; Additional line break

            JSR   delay1ms          ; Delay for stability before starting
            LDX   #0                ; Load X with 0 to indicate Enter/Return key pressed
            STX   ctr125u           ; Initialize 125us counter to 0
            JSR   StartTimer6oc     ; Start Timer OC6

            CLI                     ; Enable interrupts, start Timer OC6 interrupt

loop1024
            JSR   CountAndDisplay   ; Call subroutine to count and display time

            LDD   ctr125u           ; Load D with 125us counter value
            CPD   #DATAmax          ; Compare with DATAmax (2048 bytes)
            BHS   loopTxON          ; If 2048 bytes sent, jump to transmission off sequence
            BRA   loop1024          ; Otherwise, continue looping to transmit

loopTxON
            LDAA  #%00000000        ; Load accumulator A with 0
            STAA  TIE               ; Disable OC6 interrupt

            JSR   nextline          ; Move to the next line
            JSR   nextline          ; Additional line break

            LDX   #msg4             ; Load X with address of completion message
            JSR   printmsg          ; Print '> Done! Close Output file.'
            JSR   nextline          ; Move to the next line
            JSR   nextline          ; Additional line break
            LDX   #prompt           ; Load X with address of prompt message
            JSR   printmsg          ; Print the prompt message

            LBRA  main              ; Loop back to beginning to await new command input
            
;
; Typewriter Program
;
ttyStart    
            JSR   nextline          ; Move to the next line
            SEI                     ; Disable interrupts
            LDX   #msg3             ; Load X with address of first message, 'Hello'
            LDAA  #$DD              ; Load A with $DD
            STAA  CCount            ; Store in CCount
            JSR   printmsg          ; Print the message

            LDAA  #CR               ; Load A with Carriage Return (CR) to move cursor to start of line
            JSR   putchar           ; Output CR (Enter key effect)
            LDAA  #LF               ; Load A with Line Feed (LF) to move cursor to next line
            JSR   putchar           ; Output LF

            LDX   #msg2             ; Load X with address of third message
            JSR   printmsg          ; Print the message

            LDAA  #CR               ; Load A with Carriage Return to move cursor to start of line
            JSR   putchar           ; Output CR (Enter key effect)
            LDAA  #LF               ; Load A with Line Feed to move cursor to next line
            JSR   putchar           ; Output LF

tty         
            JSR   getchar           ; Call subroutine to check for keyboard input
            CMPA  #$00              ; Compare A with 0 to check if any key was pressed
            BEQ   tty               ; If no key was pressed, continue checking (loop)

                                     ; If a key was pressed:
            JSR   putchar           ; Output the typed character on terminal window (echo)

            STAA  PORTB             ; Display the character on PORTB

            CMPA  #CR               ; Check if the typed character is Enter (Carriage Return)
            BNE   tty               ; If not Enter, continue to check for input
            LDAA  #LF               ; If Enter, load A with Line Feed to move cursor to the next line
            JSR   putchar           ; Output LF
            BRA   tty               ; Continue to check for input in a loop
;subroutine section below

;***********RTI interrupt service routine***************
rtiisr      
            BSET   CRGFLG, %10000000 ; Clear the RTI Interrupt Flag to allow for the next interrupt
            LDX    ctr2p5m           ; Load X register with current value of 16-bit interrupt counter
            INX                      ; Increment the interrupt counter
            STX    ctr2p5m           ; Store the updated counter back in ctr2p5m

rtidone     
            RTI                      ; Return from interrupt
;***********end of RTI interrupt service routine********

;***********Timer OC6 interrupt service routine***************
oc6isr
            LDD   #3000              ; Load D with 3000 for 125usec delay (24MHz clock)
            ADDD  TC6H               ; Add to TC6H for the next interrupt
            STD   TC6H               ; Store result in TC6H
            BSET  TFLG1, %01000000   ; Clear timer channel 6 interrupt flag

            LDX   #opcode            ; Load X with address of opcode
            LDAA  1,X+               ; Load A with the opcode value

            CMPA  #$00               ; Check if opcode is '0'
            LBEQ  gwgen              ; If '0', branch to gwgen
            CMPA  #$01               ; Check if opcode is '1'
            LBEQ  gw2gen             ; If '1', branch to gw2gen
            CMPA  #$02               ; Check if opcode is '2'
            LBEQ  gtgen              ; If '2', branch to gtgen
            CMPA  #$03               ; Check if opcode is '3'
            LBEQ  gqgen              ; If '3', branch to gqgen
            CMPA  #$04               ; Check if opcode is '4'
            LBEQ  gq2gen             ; If '4', branch to gq2gen
            LBRA  oc2done            ; Otherwise, branch to oc2done

gwgen
            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value
            INX                      ; Increment the counter
            STX   ctr125u            ; Store updated counter back in ctr125u
            CLRA                     ; Clear A to prepare for printing
            JSR   pnum10             ; Print the last byte of ctr125u for exactly 1024 data points

            LBRA  oc2done            ; Branch to oc2done

gw2gen
            LDX   #gwcount           ; Load X with address of gwcount
            LDAA  1,X+               ; Load A with current gwcount
            INCA                     ; Increment gwcount
            STAA  gwcount            ; Store updated gwcount
            CMPA  #5                 ; Check if gwcount equals 5
            LBEQ  gwnext             ; If yes, branch to gwnext

            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value
            INX                      ; Increment the counter
            STX   ctr125u            ; Store updated counter back in ctr125u
            CLRA                     ; Clear A to prepare for printing
            JSR   pnum100hz          ; Print for 100Hz frequency, ensuring 1024 data points

            LBRA  oc2done            ; Branch to oc2done

gwnext
            CLR   gwcount            ; Reset gwcount

            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value
            INX                      ; Increment the counter
            STX   ctr125u            ; Store updated counter back in ctr125u
            CLRA                     ; Clear A to prepare for printing
            JSR   pnum100hz2         ; Print at 100Hz, alternate timing for exactly 1024 data points
            INC   carry              ; Increment carry flag

            LBRA  oc2done            ; Branch to oc2done

gtgen
            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value
            INX                      ; Increment the counter
            STX   ctr125u            ; Store updated counter back in ctr125u
            CLRA                     ; Clear A to prepare for printing

            JSR   pnumtriangle       ; Print triangle waveform value for exactly 1024 data points

            LDX   #gtcount           ; Load X with address of gtcount
            LDAA  1,X+               ; Load A with current gtcount
            INCA                     ; Increment gtcount
            STAA  gtcount            ; Store updated gtcount
            CMPA  #0                 ; Check if gtcount equals 0
            LBEQ  gtext              ; If yes, branch to gtext

            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value

            LBRA  oc2done            ; Branch to oc2done

gtext
            LDX   #gtflag            ; Load X with address of gtflag
            LDAA  1,X+               ; Load A with gtflag value
            CMPA  #01                ; Check if gtflag is 1
            LBEQ  gtzero             ; If yes, branch to gtzero

            LDAB  #01                ; Set B to 1
            STAB  gtflag             ; Update gtflag to 1

            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value

            LBRA  oc2done            ; Branch to oc2done

gtzero
            LDAB  #00                ; Set B to 0
            STAB  gtflag             ; Update gtflag to 0

            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value

            LBRA  oc2done            ; Branch to oc2done

gqgen
            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value
            INX                      ; Increment the counter
            STX   ctr125u            ; Store updated counter back in ctr125u
            CLRA                     ; Clear A to prepare for printing

            JSR   pnum10sq           ; Print square waveform value for exactly 1024 data points

            LDX   #sqcount           ; Load X with address of sqcount
            LDAA  1,X+               ; Load A with current sqcount
            INCA                     ; Increment sqcount
            STAA  sqcount            ; Store updated sqcount
            CMPA  #0                 ; Check if sqcount equals 0
            LBEQ  gqext              ; If yes, branch to gqext

            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value

            LBRA  oc2done            ; Branch to oc2done

gqext
            LDX   #sqflag            ; Load X with address of sqflag
            LDAA  1,X+               ; Load A with sqflag value
            CMPA  #01                ; Check if sqflag is 1
            LBEQ  gqzero             ; If yes, branch to gqzero

            LDAB  #01                ; Set B to 1
            STAB  sqflag             ; Update sqflag to 1

            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value

            LBRA  oc2done            ; Branch to oc2done

gqzero
            LDAB  #00                ; Set B to 0
            STAB  sqflag             ; Update sqflag to 0

            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value

            LBRA  oc2done            ; Branch to oc2done  
                 
gq2gen
            LDD   ctr125u            ; Load D with current 125us counter value
            LDX   ctr125u            ; Load X with current 125us counter value
            INX                      ; Increment the counter
                                     
            STX   ctr125u            ; Store updated counter back in ctr125u
            CLRA                     ; Clear A to prepare for printing

                                     
            JSR   pnum10sq           ; Print square wave data to create RxData3.txt with exactly 1024 entries

            LDX   #sqcount           ; Load X with address of sqcount
            LDAA  1,X+               ; Load A with current sqcount
            INCA                     ; Increment sqcount
            STAA  sqcount            ; Store updated sqcount
            CMPA  #40                ; Check if sqcount equals 40
            LBEQ  gqext2             ; If it does, branch to gqext2

            LDD   ctr125u            ; Reload D with current 125us counter value
            LDX   ctr125u            ; Reload X with current 125us counter value

            LBRA  oc2done            ; Branch to oc2done

gqext2
            CLR   sqcount            ; Reset sqcount
            LDX   #sqflag            ; Load X with address of sqflag
            LDAA  1,X+               ; Load A with sqflag value
            CMPA  #01                ; Check if sqflag is 1
            LBEQ  gqzero2            ; If it is, branch to gqzero2

            LDAB  #01                ; Set B to 1
            STAB  sqflag             ; Update sqflag to 1

            LDD   ctr125u            ; Reload D with current 125us counter value
            LDX   ctr125u            ; Reload X with current 125us counter value

            LBRA  oc2done            ; Branch to oc2done

gqzero2     
            LDAB  #00                ; Set B to 0
            STAB  sqflag             ; Update sqflag to 0

            LDD   ctr125u            ; Reload D with current 125us counter value
            LDX   ctr125u            ; Reload X with current 125us counter value

            LBRA  oc2done            ; Branch to oc2done

oc2done     
            RTI                      ; Return from interrupt
            
;***********end of Timer OC6 interrupt service routine********

;***************StartTimer6oc************************
;* Program: Start the timer interrupt, timer channel 6 output compare
;* Input:   Constants - channel 6 output compare, 125usec at 24MHz
;* Output:  None, only the timer interrupt
;* Registers modified: D used and CCR modified
;* Algorithm:
;             initialize TIOS, TIE, TSCR1, TSCR2, TC2H, and TFLG1
;**********************************************
StartTimer6oc
            PSHD                    ; Push D register onto the stack to save its value
            LDAA   #%01000000       ; Load A with bitmask to configure CH6 for Output Compare
            STAA   TIOS             ; Set CH6 as Output Compare
            STAA   TIE              ; Enable CH6 interrupt

            LDAA   #%10000000       ; Load A to enable the timer (Fast Flag Clear not set)
            STAA   TSCR1            ; Enable the timer system

            LDAA   #%00000000       ; Load A with settings to disable TOI and TCRE, set TCLK = BCLK/1
            STAA   TSCR2            ; Configure timer settings (not needed if starting from reset)

            LDD    #3000            ; Load D with 3000 for 125us delay at 24MHz clock
            ADDD   TCNTH            ; Add to current timer count for the first interrupt
            STD    TC6H             ; Store the result in TC6H for channel 6 interrupt timing

            BSET   TFLG1, %01000000 ; Clear initial Timer CH6 interrupt flag (if fast clear is not set)
            LDAA   #%01000000       ; Load A with bitmask to enable CH6 interrupt
            STAA   TIE              ; Enable CH6 interrupt

            PULD                    ; Pull the original D register value from the stack
            RTS                     ; Return from subroutine
;***************end of StartTimer2oc*****************


;***********pnum10***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnum10
                PSHD                    ; Save D register on the stack
                PSHX                    ; Save X register on the stack
                PSHY                    ; Save Y register on the stack
                CLR     CTR             ; Clear the character count (CTR) for the 8-bit number

                LDY     #BUF            ; Load Y with address of buffer (BUF) for storing digits
pnum10p1        
                LDX     #10             ; Load X with 10 for division
                IDIV                    ; Divide D by X (result in X, remainder in B)
                BEQ     pnum10p2        ; If quotient is 0, go to next step (pnum10p2)
                STAB    1,Y+            ; Store remainder in buffer, increment Y
                INC     CTR             ; Increment character count
                TFR     X,D             ; Transfer quotient to D for next division
                BRA     pnum10p1        ; Repeat the loop

pnum10p2        
                STAB    1,Y+            ; Store final remainder in buffer
                INC     CTR             ; Increment character count

pnum10p3        
                LDAA    #$30            ; Load A with ASCII offset for '0'
                ADDA    1,-Y            ; Add the buffer value to A (converting to ASCII)
                JSR     putchar         ; Print the character
                DEC     CTR             ; Decrement character count
                BNE     pnum10p3        ; If more digits remain, repeat

                JSR     nextline        ; Move to the next line after printing
                PULY                    ; Restore Y register from stack
                PULX                    ; Restore X register from stack
                PULD                    ; Restore D register from stack
                RTS                     ; Return from subroutine
;***********end of pnum10********************

;***********pnumtriangle***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnumtriangle
                PSHD                    ; Save D register on the stack
                PSHX                    ; Save X register on the stack
                PSHY                    ; Save Y register on the stack

                CLR     CTR             ; Clear the character count (CTR) for the 8-bit number

                LDX     #gtflag         ; Load X with address of gtflag
                LDAA    1,X+            ; Load A with gtflag value
                CMPA    #01             ; Check if gtflag is set to 1
                LBEQ    gtpnum2         ; If gtflag is 1, branch to gtpnum2

                BRA     pnumnxt         ; Otherwise, continue to pnumnxt

gtpnum2
                COMB                    ; Take the complement of register B
                CLRA                    ; Clear A to prepare for printing negative values if necessary

pnumnxt
                LDY     #BUF            ; Load Y with address of buffer (BUF) for storing digits

pnum10p1t
                LDX     #10             ; Load X with 10 for division
                IDIV                    ; Divide D by X (result in X, remainder in B)
                BEQ     pnum10p2t       ; If quotient is 0, go to next step (pnum10p2t)
                STAB    1,Y+            ; Store remainder in buffer, increment Y
                INC     CTR             ; Increment character count
                TFR     X,D             ; Transfer quotient to D for next division
                BRA     pnum10p1t       ; Repeat the loop

pnum10p2t
                STAB    1,Y+            ; Store final remainder in buffer
                INC     CTR             ; Increment character count

pnum10p3t
                LDAA    #$30            ; Load A with ASCII offset for '0'
                ADDA    1,-Y            ; Add the buffer value to A (converting to ASCII)
                JSR     putchar         ; Print the character
                DEC     CTR             ; Decrement character count
                BNE     pnum10p3t       ; If more digits remain, repeat

                JSR     nextline        ; Move to the next line after printing
                PULY                    ; Restore Y register from stack
                PULX                    ; Restore X register from stack
                PULD                    ; Restore D register from stack
                RTS                     ; Return from subroutine
;***********end of pnumtriangle********************




;***********pnum100hz***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnum100hz
                PSHD                    ; Save D register on the stack
                PSHX                    ; Save X register on the stack
                PSHY                    ; Save Y register on the stack

                CLR     CTR             ; Clear the character count (CTR) for the 8-bit number

                LDY     #3              ; Load Y with 3 for multiplication
                EMUL                    ; Multiply D by Y (extended multiply)
                ADDB    carry           ; Add the carry value to B
                CLRA                    ; Clear A to prepare for printing

                LDY     #BUF            ; Load Y with address of buffer (BUF) for storing digits

pnum10p1x
                LDX     #10             ; Load X with 10 for division
                IDIV                    ; Divide D by X (result in X, remainder in B)
                BEQ     pnum10p2x       ; If quotient is 0, go to next step (pnum10p2x)
                STAB    1,Y+            ; Store remainder in buffer, increment Y
                INC     CTR             ; Increment character count
                TFR     X,D             ; Transfer quotient to D for next division
                BRA     pnum10p1x       ; Repeat the loop

pnum10p2x
                STAB    1,Y+            ; Store final remainder in buffer
                INC     CTR             ; Increment character count

pnum10p3x
                LDAA    #$30            ; Load A with ASCII offset for '0'
                ADDA    1,-Y            ; Add the buffer value to A (converting to ASCII)
                JSR     putchar         ; Print the character
                DEC     CTR             ; Decrement character count
                BNE     pnum10p3x       ; If more digits remain, repeat

                JSR     nextline        ; Move to the next line after printing
                PULY                    ; Restore Y register from stack
                PULX                    ; Restore X register from stack
                PULD                    ; Restore D register from stack
                RTS                     ; Return from subroutine
;***********end of pnum100hz********************

;***********pnum100hz2***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnum100hz2
                PSHD                    ; Save D register on the stack
                PSHX                    ; Save X register on the stack
                PSHY                    ; Save Y register on the stack

                CLR     CTR             ; Clear the character count (CTR) for the 8-bit number

                LDY     #3              ; Load Y with 3 for multiplication
                EMUL                    ; Multiply D by Y (extended multiply)
                ADDB    carry           ; Add the carry value to B
                CLRA                    ; Clear A to prepare for further operations
                ADDB    #1              ; Add 1 to the result in B

                LDY     #BUF            ; Load Y with address of buffer (BUF) for storing digits

pnum10p1x2
                LDX     #10             ; Load X with 10 for division
                IDIV                    ; Divide D by X (result in X, remainder in B)
                BEQ     pnum10p2x2      ; If quotient is 0, go to next step (pnum10p2x2)
                STAB    1,Y+            ; Store remainder in buffer, increment Y
                INC     CTR             ; Increment character count
                TFR     X,D             ; Transfer quotient to D for next division
                BRA     pnum10p1x2      ; Repeat the loop

pnum10p2x2
                STAB    1,Y+            ; Store final remainder in buffer
                INC     CTR             ; Increment character count
;--------------------------------------

pnum10p3x2
                LDAA    #$30            ; Load A with ASCII offset for '0'
                ADDA    1,-Y            ; Add the buffer value to A (converting to ASCII)
                JSR     putchar         ; Print the character
                DEC     CTR             ; Decrement character count
                BNE     pnum10p3x2      ; If more digits remain, repeat

                JSR     nextline        ; Move to the next line after printing
                PULY                    ; Restore Y register from stack
                PULX                    ; Restore X register from stack
                PULD                    ; Restore D register from stack
                RTS                     ; Return from subroutine
;***********end of pnum100hz2********************


;***********pnum10sq***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnum10sq
                PSHD                    ; Save D register on the stack
                PSHX                    ; Save X register on the stack
                PSHY                    ; Save Y register on the stack

                LDX   #sqflag           ; Load X with address of sqflag
                LDAA  1,X+              ; Load A with the value of sqflag
                CMPA  #01               ; Check if sqflag is set to 1
                LBEQ  sqpnum2           ; If sqflag is 1, branch to sqpnum2

                LDAA  #$30              ; Load A with ASCII code for '0'
                JSR   putchar           ; Print '0' character
                JSR   nextline          ; Move to the next line
                PULY                    ; Restore Y register from stack
                PULX                    ; Restore X register from stack
                PULD                    ; Restore D register from stack
                RTS                     ; Return from subroutine

sqpnum2
                LDAA  #$32              ; Load A with ASCII code for '2'
                JSR   putchar           ; Print '2' character
                LDAA  #$35              ; Load A with ASCII code for '5'
                JSR   putchar           ; Print '5' character
                LDAA  #$35              ; Load A with ASCII code for '5'
                JSR   putchar           ; Print '5' character
                JSR   nextline          ; Move to the next line
                PULY                    ; Restore Y register from stack
                PULX                    ; Restore X register from stack
                PULD                    ; Restore D register from stack
                RTS                     ; Return from subroutine
;***********end of pnum10sq********************


;***************CountAndDisplay***************
;* Program: increment half-second ctr if 0.5 second is up, handle seconds counting and display
;* Input:   ctr2p5m & times variables
;* Output:  ctr2p5m variable, times variable, 7Segment Displays
;* Registers modified: CCR, A, X
;* Algorithm:
;    Check for 0.5 second passed
;      if not 0.5 second yet, just pass
;      if 0.5 second has reached, then increment half and reset ctr2p5m 
;      if 1 second has been reached, then reset half and increment times and display times on 7seg displays
;**********************************************
CountAndDisplay
                  PSHA                   ; Save A register on the stack
                  PSHX                   ; Save X register on the stack

            LDX    ctr2p5m               ; Load X with the 0.5-second interrupt counter
            CPX    #94                   ; Compare with 94 (approx 1 second)
            BLO    done                  ; If less than 1 second, branch to done

            BRA    last                  ; If 1 second has passed, branch to last

done        PULX                         ; Restore X register from stack
            PULA                         ; Restore A register from stack
            RTS                          ; Return from subroutine

last        LDX    #0                    ; Reset the counter as 0.5 seconds have passed
            STX    ctr2p5m               ; Store 0 in the 0.5-second counter

            LDAA   half                  ; Load A with half-second counter
            CMPA   #$01                  ; Check if it's already been 1 second
            BEQ    second                ; If 1 second has passed, branch to 'second'
            INC    half                  ; Otherwise, increment half to indicate 0.5 seconds
            LBRA   done                  ; Branch to done

second      
            CLR     half                 ; Reset half-second counter
            INC     times                ; Increment seconds counter

next        LDAA    times                ; Check if 60 seconds have passed
            CMPA    #$3C                 ; $3C == 60 in hex
            BNE     cmd                  ; If less than 60 seconds, branch to cmd

            CLR     times                ; Reset seconds counter if 60 seconds passed
            INC     timem                ; Increment minutes counter

            LDAA    timem                ; Check if 60 minutes have passed
            CMPA    #$3C                 ; $3C == 60
            BNE     cmd                  ; If less than 60 minutes, branch to cmd

            CLR     timem                ; Reset minutes counter if 60 minutes passed
            INC     timeh                ; Increment hours counter

            LDAA    timeh                ; Check if 24 hours have passed
            CMPA    #$18                 ; $18 == 24
            BNE     cmd                  ; If less than 24 hours, branch to cmd

            CLR     timeh                ; Reset hours counter if 24 hours passed

cmd         
            LDX    #hms                  ; Load X with address of hms
            LDAA   1,X+                  ; Load A with hms command

            CMPA   #$68                  ; Check if command is 'h' (hours)
            LBEQ   nextH                 ; If yes, branch to nextH
            CMPA   #$6D                  ; Check if command is 'm' (minutes)
            LBEQ   nextM                 ; If yes, branch to nextM
            CMPA   #$73                  ; Check if command is 's' (seconds)
            LBEQ   nextS                 ; If yes, branch to nextS

nextS       
            LDAA    times                ; Load A with seconds count
            CMPA    #$32                 ; Compare with $32
            BLO     SelseIf1             ; If less than $32, branch to SelseIf1
            ADDA    #$1E                 ; If >= $32, add $1E
            BRA     print

SelseIf1    
            CMPA    #$28                 ; Compare with $28
            BLO     SelseIf2             ; If less than $28, branch to SelseIf2
            ADDA    #$18                 ; If >= $28, add $18
            BRA     print

SelseIf2    
            CMPA    #$1E                 ; Compare with $1E
            BLO     SelseIf3             ; If less than $1E, branch to SelseIf3
            ADDA    #$12                 ; If >= $1E, add $12
            BRA     print

SelseIf3    
            CMPA    #$14                 ; Compare with $14
            BLO     SelseIf4             ; If less than $14, branch to SelseIf4
            ADDA    #$0C                 ; If >= $14, add $0C
            BRA     print

SelseIf4    
            CMPA    #$0A                 ; Compare with $0A
            BLO     print                ; If less than $0A, go to print
            ADDA    #$06                 ; If >= $0A, add $06
            BRA     print

nextM       
            LDAA    timem                ; Load A with minutes count
            CMPA    #$32                 ; Compare with $32
            BLO     MelseIf1             ; If less than $32, branch to MelseIf1
            ADDA    #$1E                 ; If >= $32, add $1E
            BRA     print

MelseIf1    
            CMPA    #$28                 ; Compare with $28
            BLO     MelseIf2             ; If less than $28, branch to MelseIf2
            ADDA    #$18                 ; If >= $28, add $18
            BRA     print

MelseIf2    
            CMPA    #$1E                 ; Compare with $1E
            BLO     MelseIf3             ; If less than $1E, branch to MelseIf3
            ADDA    #$12                 ; If >= $1E, add $12
            BRA     print

MelseIf3    
            CMPA    #$14                 ; Compare with $14
            BLO     MelseIf4             ; If less than $14, branch to MelseIf4
            ADDA    #$0C                 ; If >= $14, add $0C
            BRA     print

MelseIf4    
            CMPA    #$0A                 ; Compare with $0A
            BLO     print                ; If less than $0A, go to print
            ADDA    #$06                 ; If >= $0A, add $06
            BRA     print

print       
            STAA    PORTB                ; Display the result on PORTB

            PULX                         ; Restore X register from stack
            PULA                         ; Restore A register from stack
            RTS                          ; Return from subroutine
            
nextH       
            LDAA    timeh            ; Load A with hours count
            CMPA    #$14             ; Compare with $14 (20 in decimal)
            BLO     HelseIf4         ; If less than $14, branch to HelseIf4
            ADDA    #$0C             ; If >= $14, add $0C (12) to hours count
            LBRA    print            ; Branch to print to display the result

HelseIf4    
            CMPA    #$0A             ; Compare with $0A (10 in decimal)
            BLO     print            ; If less than $0A, go to print to display as is
            ADDA    #$06             ; If >= $0A, add $06 (6) to hours count
            LBRA    print            ; Branch to print to display the result            
;***************end of CountAndDisplay***************         



;***********printmsg***************************
;* Program: Output character string to SCI port, print message
;* Input:   Register X points to ASCII characters in memory
;* Output:  message printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Pick up 1 byte from memory where X register is pointing
;     Send it out to SCI port
;     Update X register to point to the next byte
;     Repeat until the byte data $00 is encountered
;       (String is terminated with NULL=$00)
;**********************************************
NULL            EQU     $00            ; Define NULL as $00

printmsg        
                PSHA                   ; Save A register on the stack
                PSHX                   ; Save X register on the stack

printmsgloop    
                LDAA    1,X+           ; Load A with an ASCII character from the string
                                       ; pointed to by X, then increment X to point to
                                       ; the next character
                CMPA    #NULL          ; Check if the character is NULL (end of string)
                BEQ     printmsgdone   ; If NULL, branch to printmsgdone

                BSR     putchar        ; Print the character
                BRA     printmsgloop   ; Loop back to continue printing the next character

printmsgdone    
                PULX                   ; Restore X register from the stack
                PULA                   ; Restore A register from the stack
                RTS                    ; Return from subroutine
;***********end of printmsg********************

;***************putchar************************
;* Program: Send one character to SCI port, terminal
;* Input:   Accumulator A contains an ASCII character, 8bit
;* Output:  Send one character to SCI port, terminal
;* Registers modified: CCR
;* Algorithm:
;    Wait for transmit buffer become empty
;      Transmit buffer empty is indicated by TDRE bit
;      TDRE = 1 : empty - Transmit Data Register Empty, ready to transmit
;      TDRE = 0 : not empty, transmission in progress
;**********************************************
putchar     
            BRCLR SCISR1, #%10000000, putchar ; Check the transmit buffer empty flag in SCISR1
                                             ; Loop here until the transmit buffer is empty

            STAA  SCIDRL                      ; Load the character in A to the SCIDRL register to send it
            RTS                               ; Return from subroutine
;***************end of putchar*****************

;****************getchar***********************
;* Program: Input one character from SCI port (terminal/keyboard)
;*             if a character is received, other wise return NULL
;* Input:   none    
;* Output:  Accumulator A containing the received ASCII character
;*          if a character is received.
;*          Otherwise Accumulator A will contain a NULL character, $00.
;* Registers modified: CCR
;* Algorithm:
;    Check for receive buffer become full
;      Receive buffer full is indicated by RDRF bit
;      RDRF = 1 : full - Receive Data Register Full, 1 byte received
;      RDRF = 0 : not full, 0 byte received
;**********************************************
getchar     
            BRCLR SCISR1, #%00100000, getchar7 ; Wait until the receive data register full flag is set in SCISR1
                                              ; Loop here until a character is received

            LDAA  SCIDRL                      ; Load the received character from SCIDRL into A
            RTS                               ; Return with the received character in A

getchar7    
            CLRA                              ; Clear A (no character received)
            RTS                               ; Return with A cleared
;****************end of getchar**************** 

;****************nextline**********************
nextline    
            PSHA                   ; Save A register on the stack

            LDAA  #CR              ; Load A with Carriage Return (CR) to move the cursor to the beginning of the line
            JSR   putchar          ; Send the Carriage Return (Enter key effect)
            
            LDAA  #LF              ; Load A with Line Feed (LF) to move the cursor to the next line
            JSR   putchar          ; Send the Line Feed

            PULA                   ; Restore A register from the stack
            RTS                    ; Return from subroutine
;****************end of nextline***************


;***********clrBuff****************************
;* Program: Clear out command buff
;* Input:   
;* Output:  buffer is filled with zeros
;* 
;* Registers modified: X,A,B,CCR
;* Algorithm: set each byte (11 total) in CmdBuff to NULL
;************************************************
clrBuff     
            LDAB    #$0B            ; Load B with the number of bytes to clear (11 bytes)

clrLoop     
            CMPB    #$00            ; Check if B is 0 (end of loop)
            BEQ     clrReturn       ; If B is 0, branch to clrReturn

            LDAA    #$00            ; Load A with 0
            STAA    1,X+            ; Store 0 in the current byte and increment X
            DECB                    ; Decrement B (B = B - 1)
            BRA     clrLoop         ; Repeat the loop until all bytes are cleared

clrReturn   
            RTS                     ; Return from subroutine 
;***********end of clrBuff*****************************

;****************delay1ms**********************
delay1ms:   
            PSHX                   ; Save X register on the stack

            LDX   #$1000           ; Load X with $1000 for a 1ms delay (adjustable for timing)

d1msloop    
            NOP                    ; No operation (used to introduce a small delay)
            DEX                    ; Decrement X by 1
            BNE   d1msloop         ; If X is not zero, repeat the loop

            PULX                   ; Restore X register from the stack
            RTS                    ; Return from subroutine
;****************end of delay1ms***************

;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip

msg1        DC.B    'Welcome to the Wave Generation and 24 hour clock Program!', $00
msg2        DC.B    '     You may type below:', $00
msg3        DC.B    '     Wave Generator and Clock stopped and Typewrite program started.', $00

msg4        DC.B    '> Done!  Close Output file.', $00
msg5        DC.B    '> Set Terminal save file RxData3.txt', $00
msg6        DC.B    '> Press Enter/Return key to start wave generation', $00

menu1       DC.B    'Input the letter t followed by a time in the format [hh:mm:ss] to set the time.', $00
menu2       DC.B    'Input the letter s to display  seconds.', $00
menu3       DC.B    'Input the letter m to display  minutes.', $00
menu4       DC.B    'Input the letter h to display    hours.', $00

menu5       DC.B    'Input command gw  to start  sawtooth        wave generation.', $00
menu6       DC.B    'Input command gw2 to start  100Hz sawtooth  wave generation.', $00
menu7       DC.B    'Input command gt  to start  triangle        wave generation.', $00
menu8       DC.B    'Input command gq  to start  square          wave generation.', $00
menu9       DC.B    'Input command gq2 to start  100Hz square    wave generation.', $00

menu10      DC.B    'Input the letter q to quit the program and boot typewriter.', $00

prompt      DC.B    '> ', $00


errmsg1     DC.B    '     Invalid input format', $00
errmsg2     DC.B    'Error> Invalid time format. Correct example => 00:00:00 to 23:59:59', $00
errmsg3     DC.B    'Error> Invalid command. ("s" for second display and "q" for quit)', $00
errmsg4     DC.B    'Error> Invalid command. ("m" for second display and "q" for quit)', $00
errmsg5     DC.B    'Error> Invalid command. ("h" for second display and "q" for quit)', $00

gwmsg       DC.B    '     sawtooth wave generation ....', $00
gw2msg      DC.B    '     sawtooth wave 100Hz generation ....', $00
gtmsg       DC.B    '     triangle wave generation ....', $00
gqmsg       DC.B    '     square wave generation ....', $00
gq2msg      DC.B    '     square wave 100Hz generation ....', $00


            END               ; this is end of assembly source file
                              ; lines below are ignored - not assembled/compiled