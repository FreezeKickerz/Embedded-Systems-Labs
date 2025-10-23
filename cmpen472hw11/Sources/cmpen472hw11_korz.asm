***********************************************************************
*
* Title:          ADC, Signal Wave Generation, and Digital Clock Program
*
* Objective:      CMPEN 472 Homework 11
*
* Revision:       V2.0 for CodeWarrior 5.2 Debugger Simulation
*
* Date:	          20 November 2024
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
* Algorithm:      Simple Serial I/O use, typewriter, RTIs, OC6 interrupts
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
* Observation:    Menu-driven program that interacts with a terminal, 
*                 allowing users to manipulate the digital clock, 
*                 display time, and generate various waveforms. 
*                 Includes analog-to-digital conversion.
*
***********************************************************************
* Parameter Declaration Section
*
* Export Symbols
            XDEF        Entry        ; Export 'Entry' symbol for external use
            ABSENTRY    Entry        ; Specify assembly entry point

; Define hardware-specific constants
PORTB       EQU         $0001        ; Data Register for PORTB
DDRB        EQU         $0003        ; Data Direction Register for PORTB

; Serial Communication Interface (SCI) Registers
SCIBDH      EQU         $00C8        ; SCI Baud Rate Register High
SCIBDL      EQU         $00C9        ; SCI Baud Rate Register Low
SCICR2      EQU         $00CB        ; SCI Control Register 2
SCISR1      EQU         $00CC        ; SCI Status Register 1
SCIDRL      EQU         $00CF        ; SCI Data Register

; Timer Registers
TIOS        EQU         $0040        ; Timer Input Capture/Output Compare Select
TIE         EQU         $004C        ; Timer Interrupt Enable Register
TCNTH       EQU         $0044        ; Timer Main Counter High
TSCR1       EQU         $0046        ; Timer System Control Register 1
TSCR2       EQU         $004D        ; Timer System Control Register 2
TFLG1       EQU         $004E        ; Timer Interrupt Flag 1
TC6H        EQU         $005C        ; Timer Channel 6 High

; Clock and Reset Generator (CRG) Registers
CRGFLG      EQU         $0037        ; CRG Flags Register
CRGINT      EQU         $0038        ; CRG Interrupt Register
RTICTL      EQU         $003B        ; Real-Time Interrupt Control Register

; ASCII Control Characters
CR          EQU         $0D          ; Carriage Return (ASCII 13)
LF          EQU         $0A          ; Line Feed (ASCII 10)

; Data Limits
DATAmax     EQU         2048         ; Maximum Data Count for Buffer

; Analog-to-Digital Converter (ADC) Registers
ATDCTL2     EQU  $0082               ; ATD Control Register 2
ATDCTL3     EQU  $0083               ; ATD Control Register 3
ATDCTL4     EQU  $0084               ; ATD Control Register 4
ATDCTL5     EQU  $0085               ; ATD Control Register 5
ATDSTAT0    EQU  $0086               ; ATD Status Register 0
ATDDR0H     EQU  $0090               ; ATD Data Register 0 High Byte
ATDDR0L     EQU  $0091               ; ATD Data Register 0 Low Byte
ATDDR7H     EQU  $009E               ; ATD Data Register 7 High Byte
ATDDR7L     EQU  $009F               ; ATD Data Register 7 Low Byte

;*************************************************************
; Variable/Data Section
            ORG    $3000             ; Start of RAM for data storage
                                     ; MCU-specific RAM starts at $3000

timeh       DS.B   1                 ; Hours in digital clock
timem       DS.B   1                 ; Minutes in digital clock
times       DS.B   1                 ; Seconds in digital clock
ctr2p5m     DS.W   1                 ; Interrupt counter for 2.5ms intervals

half        DS.B   1                 ; Half-second tracker
dec         DS.B   1                 ; Temporary decimal storage
hms         DS.B   1                 ; Holds 'h', 'm', or 's' commands
opcode      DS.B   1                 ; Operation code for waveform generation

CCount      DS.B   $0001             ; Buffer character count
CmdBuff     DS.B   $000B             ; Command input buffer

DecBuff     DS.B   $0006             ; Buffer for decimal conversions
HCount      DS.B   $0001             ; Number of ASCII characters for Hex conversion
DCount      DS.B   $0001             ; Number of ASCII characters for Decimal

ctr125u     DS.W   1                 ; Interrupt counter for 125µs intervals

BUF         DS.B   6                 ; General character buffer
CTR         DS.B   1                 ; Character buffer fill count

gwcount     DS.B   2                 ; Sawtooth waveform generator counter
gtcount     DS.B   1                 ; Triangle waveform generator counter
gtcount2    DS.B   1                 ; Secondary triangle counter

sqcount     DS.B   1                 ; Square wave generator counter
sqflag      DS.B   1                 ; Square wave toggle flag
gtflag      DS.B   1                 ; Triangle wave toggle flag

carry       DS.B   1                 ; Carry flag for waveforms

ATDdone     DS.B   1                 ; ADC conversion complete flag (1 = complete)
;*******************************************************  ;******************************************************* ;*******************************************************





;*******************************************************
; Interrupt Vector Section
;*******************************************************
            ORG    $FFF0             ; Define Real-Time Interrupt (RTI) vector for simulator
;            ORG    $3FF0           ; (Alternate) RTI vector setup for CSM-12C128 board
            DC.W   rtiisr            ; Assign rtiisr as the RTI interrupt service routine
            
            ORG     $FFE2            ; Define Timer Channel 6 interrupt vector for simulator
            DC.W    oc6isr           ; Assign oc6isr as the Timer Channel 6 interrupt service routine

;*******************************************************
; Code Section
;*******************************************************
            ORG    $3100             ; Start of code section in program memory
Entry
            LDS    #Entry            ; Initialize stack pointer to program start address

            LDAA   #%11111111        ; Configure PORTB pins as outputs
            STAA   DDRB              ; Set data direction register for PORTB
            STAA   PORTB             ; Initialize PORTB output to all HIGH

            LDAA   #$0C              ; Enable SCI Tx and Rx units
            STAA   SCICR2            ; Disable SCI interrupts initially

            LDD    #$0002            ; Set SCI Baud Rate Registers for 1M baud at 24MHz clock
            STD    SCIBDH            ; Update SCI Baud Rate registers

            LDAA   #$00              ; Initialize PORTB to display "00" (clock reset)
            STAA   PORTB

            ; Initialize Analog-to-Digital Converter (ADC)
            LDAA   #%11000000        ; Enable ADC, clear flags, disable ATD interrupts
            STAA   ATDCTL2
            LDAA   #%00001000        ; Configure single conversion per sequence
            STAA   ATDCTL3
            LDAA   #%10000111        ; Configure ADC for 8-bit results, 1.5 MHz ADCLK
            STAA   ATDCTL4           ; (optimized for simulation)

            ; Reset digital clock variables
            STAA   timeh
            STAA   timem
            STAA   times

            ; Print welcome message and main menu
            LDX    #msg1             ; Load address of welcome message
            JSR    printmsg          ; Call printmsg subroutine to display the message
            JSR    nextline          ; Add newline
            JSR    nextline          ; Add another newline
            
            ; Display menu commands
            LDX    #menu11           
            JSR    printmsg          ; Print additional menu instructions
            JSR    nextline
            JSR    nextline

            ; Print individual menu options
            LDX    #menu5
            JSR    printmsg
            JSR    nextline

            LDX    #menu6
            JSR    printmsg
            JSR    nextline

            LDX    #menu7
            JSR    printmsg
            JSR    nextline

            LDX    #menu8
            JSR    printmsg
            JSR    nextline

            LDX    #menu9
            JSR    printmsg
            JSR    nextline
            JSR    nextline

            ; Print digital clock instructions
            LDX    #menu1
            JSR    printmsg
            JSR    nextline

            LDX    #menu2
            JSR    printmsg
            JSR    nextline

            LDX    #menu3
            JSR    printmsg
            JSR    nextline

            LDX    #menu4
            JSR    printmsg
            JSR    nextline
            JSR    nextline

            ; Print exit and conversion options
            LDX    #menu10
            JSR    printmsg
            JSR    nextline
            JSR    nextline
            JSR    nextline

            ; Configure RTI (Real-Time Interrupt)
            BSET   RTICTL,%00011001  ; Set RTI to trigger every 2.555ms (simulated timing)
            BSET   CRGINT,%10000000  ; Enable RTI interrupt globally
            BSET   CRGFLG,%10000000  ; Clear RTI Interrupt Flag to prepare for next interrupt

            ; Initialize variables and counters
            LDX    #0
            STX    ctr2p5m           ; Reset 2.5ms interrupt counter
            CLI                     ; Enable global interrupts
            CLR    half              ; Reset half-second flag
            CLR    times             ; Reset seconds counter
            CLR    timem             ; Reset minutes counter
            CLR    timeh             ; Reset hours counter

            ; Display the prompt for user input
            LDX    #prompt
            JSR    printmsg

main
            ; Main execution loop
            LDX    #CmdBuff          ; Load address of command buffer
            CLR    CCount            ; Clear command count
            CLR    HCount            ; Clear hex character count
            JSR    clrBuff           ; Clear buffer contents
            
            LDX    #CmdBuff
            LDAA   #$0000

looop
            ; Main program operation
            JSR    CountAndDisplay   ; Update and display digital clock
            JSR    getchar           ; Check for user keyboard input
            TSTA                     ; If no input, continue checking
            BEQ    looop

            CMPA   #CR               ; Check if Enter key was pressed
            BEQ    noReturn
            JSR    putchar           ; Echo typed character to terminal
            
noReturn    STAA   1,X+              ; Store character in command buffer
            INC    CCount            ; Increment character count
            LDAB   CCount
            CMPB   #$0B              ; Check for max buffer size (11 chars including Enter)
            LBHI   IError            ; Go to error handling if buffer exceeds size
            CMPA   #CR
            BNE    looop             ; Continue accepting input if not Enter key

            ; Validate minimum command size
            LDAB   CCount
            CMPB   #$02              ; Minimum 2 characters needed (including Enter)
            LBLO   IError

            LDX    #CmdBuff          ; Load buffer for command checking
            LDAA   1,X+

CmdChk
            ; Check the first character for specific commands
            CMPA   #$68              ; Check for 'h' (hours)
            LBEQ   h
            CMPA   #$6D              ; Check for 'm' (minutes)
            LBEQ   m 
            CMPA   #$74              ; Check for 't' (time set)
            LBEQ   t
            CMPA   #$73              ; Check for 's' (seconds)
            LBEQ   s                  
            CMPA   #$71              ; Check for 'q' (quit to typewriter mode)
            LBEQ   q

            CMPA   #$67              ; Check for 'g' (wave generation)
            LBEQ   g

            CMPA   #$61              ; Check for 'a' (ADC conversion)
            LBEQ   achk

IError
            ; Handle unrecognized commands
            JSR    nextline
            LDX    #errmsg1          ; Print error message
            JSR    printmsg
            JSR    nextline
            JSR    nextline
            LDX    #prompt           ; Re-display the prompt
            JSR    printmsg
            LBRA   main              ; Return to main program loop
            
            
            
achk        ldaa   1,X+              ; Load next character in command buffer
                         
            cmpa   #$64              ; Check for 'd' (part of 'adc' command)
            lbeq   a2                ; If 'd', proceed to the next step
            
            lbra   IError            ; Otherwise, jump to error handling

a2          ldaa   1,X+              ; Load next character
                         
            cmpa   #$63              ; Check for 'c' (completing 'adc' command)
            lbeq   a3                ; If 'c', proceed to final step
            
            lbra   IError            ; Otherwise, jump to error handling

a3          ldaa   1,X+              ; Load next character
                         
            cmpa   #$0D              ; Check for 'CR' (Carriage Return)
            lbeq   adccmd            ; If Enter key, start ADC command execution
            
            lbra   IError            ; Otherwise, jump to error handling
            
; Handle 'g' command for wave generation
g           ldaa   1,X+              ; Load next character
                         
            cmpa   #$77              ; Check for 'w' (sawtooth wave)
            lbeq   g2                ; If 'w', proceed to the next step
            cmpa   #$74              ; Check for 't' (triangle wave)
            lbeq   g3                ; If 't', proceed to triangle wave
            cmpa   #$71              ; Check for 'q' (square wave)
            lbeq   g4                ; If 'q', proceed to square wave
            
            lbra   IError            ; Otherwise, jump to error handling
            
g2          ldaa   1,X+              ; Load next character
            cmpa   #$0D              ; Check for 'CR' (Carriage Return)
            lbeq   gw                ; If Enter key, start sawtooth wave
            cmpa   #$32              ; Check for '2' (100Hz sawtooth wave)
            lbeq   g22               ; If '2', proceed to 100Hz sawtooth wave
            
            lbra   IError            ; Otherwise, jump to error handling

g22         ldaa   1,X+              ; Load next character
            cmpa   #$0D              ; Check for 'CR' (Carriage Return)
            lbeq   gw2               ; If Enter key, start 100Hz sawtooth wave
            
            lbra   IError            ; Otherwise, jump to error handling

g3          ldaa   1,X+              ; Load next character
            cmpa   #$0D              ; Check for 'CR' (Carriage Return)
            lbeq   gt                ; If Enter key, start triangle wave
            
            lbra   IError            ; Otherwise, jump to error handling

g4          ldaa   1,X+              ; Load next character
            cmpa   #$0D              ; Check for 'CR' (Carriage Return)
            lbeq   gq                ; If Enter key, start square wave
            cmpa   #$32              ; Check for '2' (100Hz square wave)
            lbeq   g44               ; If '2', proceed to 100Hz square wave
            
            lbra   IError            ; Otherwise, jump to error handling

g44         ldaa   1,X+              ; Load next character
            cmpa   #$0D              ; Check for 'CR' (Carriage Return)
            lbeq   gq2               ; If Enter key, start 100Hz square wave
            
            lbra   IError            ; Otherwise, jump to error handling

; Error handler for invalid commands
TError                                
            jsr   nextline
            ldx   #errmsg2           ; Load error message for invalid time format
            jsr   printmsg           ; Print the error message
            jsr   nextline
            ldx   #prompt            ; Reload prompt message
            jsr   printmsg           ; Print the prompt
            jsr   nextline
            ldx   #prompt            ; Reload prompt message
            jsr   printmsg           ; Print the prompt again
            
            lbra  main               ; Return to main loop

; Handle 't' command to set time
t           
            ldaa  1,X+               ; Load next character
            cmpa  #$20               ; Ensure second character is a space
            bne   TError             ; If not a space, trigger error
            clr   dec                ; Clear decimal variable for processing
            
            ldaa  1,X+               ; Load next character
            cmpa  #$30               ; Ensure it's a number
            blo   TError             ; If below '0', trigger error
            cmpa  #$32               ; Ensure it's 2 or less
            bhi   TError             ; If above '2', trigger error
            
            beq   t2                 ; If '0', skip to next part
            
            suba  #$30               ; Convert ASCII to numerical value
            ldab  #10                ; Set weight for tens place
            mul                      ; Multiply for tens place
            stab  dec                ; Store result in dec
            
            ldaa  1,X+               ; Load next character
            cmpa  #$30               ; Ensure it's a number
            blo   TError             ; If below '0', trigger error
            cmpa  #$39               ; Ensure it's 9 or less
            bhi   TError             ; If above '9', trigger error
            suba  #$30               ; Convert ASCII to numerical value
            ldab  #1                 ; Set weight for ones place
            mul                      ; Multiply for ones place
            ldaa  dec
            aba                      ; Add tens and ones places
            staa  dec                ; Store combined result
            bra   t3                 ; Proceed to store hours
            
t2          suba  #$30              ; Convert ASCII to numerical value
            ldab  #10               ; Set weight for tens place
            mul                     ; Multiply to calculate tens value
            stab  dec               ; Store result in `dec` for hours tens place
            
            ldaa  1,X+              ; Load next character from buffer
            cmpa  #$30              ; Ensure character is a valid digit
            blo   TError            ; If below '0', trigger error
            cmpa  #$33              ; Ensure digit is 3 or less (hours cannot exceed 23)
            bhi   TError            ; If above '3', trigger error
            suba  #$30              ; Convert ASCII to numerical value
            ldab  #1                ; Set weight for ones place
            mul                     ; Multiply to calculate ones value
            ldaa  dec
            aba                     ; Add tens and ones place to get full hour value
            staa  dec               ; Store combined hours value
                    
t3          staa  timeh             ; Save hours to `timeh`
            clr   dec               ; Clear `dec` for reuse
            
            ldaa  1,X+              ; Load next character
            cmpa  #$3A              ; Ensure the character is ':'
            bne   TError            ; If not ':', trigger error
            
            ldaa  1,X+              ; Load next character (minutes tens place)
            cmpa  #$30              ; Ensure character is a valid digit
            blo   TError1           ; If below '0', trigger error
            cmpa  #$35              ; Ensure digit is 5 or less (valid for tens place)
            bhi   TError1           ; If above '5', trigger error
            suba  #$30              ; Convert ASCII to numerical value
            ldab  #10               ; Set weight for tens place
            mul                     ; Multiply to calculate tens value
            stab  dec               ; Store result in `dec`
            
            ldaa  1,X+              ; Load next character (minutes ones place)
            cmpa  #$30              ; Ensure character is a valid digit
            blo   TError1           ; If below '0', trigger error
            cmpa  #$39              ; Ensure digit is 9 or less
            bhi   TError1           ; If above '9', trigger error
            suba  #$30              ; Convert ASCII to numerical value
            ldab  #1                ; Set weight for ones place
            mul                     ; Multiply to calculate ones value
            ldaa  dec
            aba                     ; Add tens and ones place to get full minute value
            staa  dec               ; Store combined minute value
            
            staa  timem             ; Save minutes to `timem`
            clr   dec               ; Clear `dec` for reuse
            
            ldaa  1,X+              ; Load next character
            cmpa  #$3A              ; Ensure the character is ':'
            bne   TError1           ; If not ':', trigger error
            
            ldaa  1,X+              ; Load next character (seconds tens place)
            cmpa  #$30              ; Ensure character is a valid digit
            blo   TError1           ; If below '0', trigger error
            cmpa  #$35              ; Ensure digit is 5 or less (valid for tens place)
            bhi   TError1           ; If above '5', trigger error
            suba  #$30              ; Convert ASCII to numerical value
            ldab  #10               ; Set weight for tens place
            mul                     ; Multiply to calculate tens value
            stab  dec               ; Store result in `dec`
            
            ldaa  1,X+              ; Load next character (seconds ones place)
            cmpa  #$30              ; Ensure character is a valid digit
            blo   TError1           ; If below '0', trigger error
            cmpa  #$39              ; Ensure digit is 9 or less
            bhi   TError1           ; If above '9', trigger error
            suba  #$30              ; Convert ASCII to numerical value
            ldab  #1                ; Set weight for ones place
            mul                     ; Multiply to calculate ones value
            ldaa  dec
            aba                     ; Add tens and ones place to get full seconds value
            staa  dec               ; Store combined seconds value
            
            staa  times             ; Save seconds to `times`
            
            clr   half              ; Reset half-second tracker
            ldx   #$0000            ; Initialize counter for 2.5ms intervals
            stx   ctr2p5m           ; Store counter value
            
            jsr    nextline         ; Print newline
            ldx    #prompt          ; Load address of prompt
            jsr    printmsg         ; Print the prompt
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Reload address of prompt
            jsr    printmsg         ; Print the prompt again
            
            lbra   main             ; Return to main loop
            
TError1                                ; Error handler for invalid time format
            jsr    nextline
            ldx    #errmsg2         ; Load error message for invalid time
            jsr    printmsg         ; Print the error message
            jsr    nextline
            ldx    #prompt          ; Reload prompt
            jsr    printmsg         ; Print the prompt
            jsr    nextline
            ldx    #prompt          ; Reload prompt again
            jsr    printmsg         ; Print the prompt again
            
            lbra   main             ; Return to main loop
            
h           cmpb  #$02              ; Check if command is 2 characters long
            bne   HError            ; If not, trigger error
            staa  hms               ; Store command ('h') in `hms`
            jsr    nextline         ; Print newline
            ldx    #prompt          ; Load address of prompt
            jsr    printmsg         ; Print the prompt
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Reload prompt address
            jsr    printmsg         ; Print the prompt again
            lbra   main             ; Return to main loop
 

m           cmpb  #$02              ; Check if the command length is 2 characters
            bne   MError            ; If not, jump to minute command error handler
            staa  hms               ; Store 'm' command in `hms`
            jsr    nextline         ; Print a newline
            ldx    #prompt          ; Load address of prompt
            jsr    printmsg         ; Print the prompt
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Reload prompt address
            jsr    printmsg         ; Print the prompt again
            lbra   main             ; Return to the main loop
            
s           cmpb  #$02              ; Check if the command length is 2 characters
            bne   SError            ; If not, jump to second command error handler
            staa  hms               ; Store 's' command in `hms`
            jsr    nextline         ; Print a newline
            ldx    #prompt          ; Load address of prompt
            jsr    printmsg         ; Print the prompt
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Reload prompt address
            jsr    printmsg         ; Print the prompt again
            lbra   main             ; Return to the main loop

HError                              ; Error handler for 'h' command (hours)
            jsr    nextline         ; Print a newline
            ldx   #errmsg5          ; Load address of error message for invalid 'h' command
            jsr   printmsg          ; Print the error message
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Load prompt address
            jsr    printmsg         ; Print the prompt
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Reload prompt address
            jsr    printmsg         ; Print the prompt again
            lbra   main             ; Return to the main loop
            
MError                              ; Error handler for 'm' command (minutes)
            jsr    nextline         ; Print a newline
            ldx   #errmsg4          ; Load address of error message for invalid 'm' command
            jsr   printmsg          ; Print the error message
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Load prompt address
            jsr    printmsg         ; Print the prompt
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Reload prompt address
            jsr    printmsg         ; Print the prompt again
            lbra   main             ; Return to the main loop

SError                              ; Error handler for 's' command (seconds)
            jsr    nextline         ; Print a newline
            ldx   #errmsg3          ; Load address of error message for invalid 's' command
            jsr   printmsg          ; Print the error message
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Load prompt address
            jsr    printmsg         ; Print the prompt
            jsr    nextline         ; Print another newline
            ldx    #prompt          ; Reload prompt address
            jsr    printmsg         ; Print the prompt again
            lbra   main             ; Return to the main loop

q           cmpb  #$02              ; Check if the command length is 2 characters
            bne   SError            ; If not, jump to 's' command error handler
            lbra   ttyStart         ; If valid, jump to typewriter start routine
            
gw                                  ; Handle 'gw' command (sawtooth wave)
            ldaa  #$00              ; Set opcode for sawtooth wave
            staa  opcode            ; Store opcode
            
            jsr   nextline          ; Print a newline
            ldx   #gwmsg            ; Load sawtooth wave message
            jsr   printmsg          ; Print the message
            jsr   nextline          ; Print another newline
            jsr   nextline          ; Print another newline
            
            lbra   TI               ; Jump to TI (Timer initialization) routine
            
gw2                                 ; Handle 'gw2' command (100Hz sawtooth wave)
            ldaa  #$01              ; Set opcode for 100Hz sawtooth wave
            staa  opcode            ; Store opcode
            clr   gwcount           ; Clear sawtooth wave counter
            clr   carry             ; Clear carry flag
            
            jsr   nextline          ; Print a newline
            ldx   #gw2msg           ; Load 100Hz sawtooth wave message
            jsr   printmsg          ; Print the message
            jsr   nextline          ; Print another newline
            jsr   nextline          ; Print another newline
            
            lbra   TI               ; Jump to TI (Timer initialization) routine
            
gt                                  ; Handle 'gt' command (triangle wave)
            ldaa  #$02              ; Set opcode for triangle wave
            staa  opcode            ; Store opcode
            clr   gtcount           ; Clear triangle wave counter
            clr   gtflag            ; Clear triangle wave toggle flag
            
            jsr   nextline          ; Print a newline
            ldx   #gtmsg            ; Load triangle wave message
            jsr   printmsg          ; Print the message
            jsr   nextline          ; Print another newline
            jsr   nextline          ; Print another newline
            
            lbra   TI               ; Jump to TI (Timer initialization) routine
            
            

gq                                  ; Handle 'gq' command (square wave generation)
            ldaa  #$03              ; Set opcode for square wave
            staa  opcode            ; Store opcode
            clr   sqcount           ; Clear square wave counter
            clr   sqflag            ; Clear square wave toggle flag
            
            jsr   nextline          ; Print a newline
            ldx   #gqmsg            ; Load square wave message
            jsr   printmsg          ; Print the message
            jsr   nextline          ; Print another newline
            jsr   nextline          ; Print another newline
            ldx   #prompt           ; Load prompt message
            jsr   printmsg          ; Print the prompt
            
            lbra   TI               ; Jump to Timer Initialization routine

gq2                                 ; Handle 'gq2' command (100Hz square wave generation)
            ldaa  #$04              ; Set opcode for 100Hz square wave
            staa  opcode            ; Store opcode
            clr   sqcount           ; Clear square wave counter
            clr   sqflag            ; Clear square wave toggle flag
            
            jsr   nextline          ; Print a newline
            ldx   #gq2msg           ; Load 100Hz square wave message
            jsr   printmsg          ; Print the message
            jsr   nextline          ; Print another newline
            jsr   nextline          ; Print another newline
            ldx   #prompt           ; Load prompt message
            jsr   printmsg          ; Print the prompt
            
            lbra   TI               ; Jump to Timer Initialization routine

adccmd                              ; Handle 'adc' command (start ADC conversion)
            ldaa  #$05              ; Set opcode for ADC
            staa  opcode            ; Store opcode
            
            jsr   nextline          ; Print a newline
            ldx   #adcmsg           ; Load ADC message
            jsr   printmsg          ; Print the message
            jsr   nextline          ; Print another newline
            jsr   nextline          ; Print another newline
            ldx   #prompt           ; Load prompt message
            jsr   printmsg          ; Print the prompt
            
            lbra   adc2             ; Jump to ADC processing routine

TI                                  ; Timer Initialization Routine
            ldx     #msg5           ; Load message: 'Set Terminal save file RxData3.txt'
            jsr     printmsg        ; Print the message
            jsr     nextline        ; Print a newline

            ldx     #msg6           ; Load message: 'Press Enter/Return key to start wave generation'
            jsr     printmsg        ; Print the message
            jsr     nextline        ; Print another newline

            jsr     delay1ms        ; Delay to flush out SCI serial port 
                                     ; Ensure transmission of last characters

loop2                               ; Wait for Enter/Return key to start
            jsr    CountAndDisplay  ; Update and display clock
            jsr     getchar         ; Check for keyboard input
            cmpa    #0              ; If no input, continue checking
            beq     loop2
            cmpa    #CR             ; Check for Enter/Return key
            bne     loop2           ; If not Enter, continue checking

            jsr     nextline        ; Print a newline
            jsr     nextline        ; Print another newline
            
            jsr     delay1ms        ; Delay for serial port flush
            ldx     #0              ; Reset data counter
            stx     ctr125u         ; Store counter value
            jsr     StartTimer6oc   ; Start Timer Channel 6 output compare

            CLI                     ; Enable global interrupts for Timer OC6 start

loop1024                           ; Loop for 1024 data points
            jsr    CountAndDisplay  ; Update and display clock
            
            ldd     ctr125u         ; Load current data count
            cpd     #DATAmax        ; Check if data count reached maximum (2048)
            bhs     loopTxON        ; If yes, move to next stage
            bra     loop1024        ; Otherwise, continue loop

loopTxON                           ; Transmission complete handler
            LDAA    #%00000000
            STAA    TIE             ; Disable Timer Channel 6 interrupts

            jsr     nextline        ; Print a newline
            jsr     nextline        ; Print another newline

            ldx     #msg4           ; Load message: 'Done! Close Output file.'
            jsr     printmsg        ; Print the message
            jsr     nextline        ; Print a newline
            jsr     nextline        ; Print another newline
            ldx     #prompt         ; Load prompt message
            jsr     printmsg        ; Print the prompt
             
            lbra  main              ; Return to main loop
;*******************************************************************
;ADC Conversion            
adc2                                ; Start ADC processing routine
            ldx     #msg5           ; Load message: '> Set Terminal save file RxData3.txt'
            jsr     printmsg        ; Print the message
            jsr     nextline        ; Print a newline

            ldx     #msg7           ; Load message: '> Press Enter/Return key to start ADC conversion'
            jsr     printmsg        ; Print the message
            jsr     nextline        ; Print a newline

            jsr     delay1ms        ; Delay to flush out SCI serial port
            
loopa                               ; Wait for Enter/Return key
            jsr    CountAndDisplay  ; Update and display clock
            jsr     getchar         ; Check for keyboard input
            cmpa    #0              ; If no input, continue checking
            beq     loopa
            cmpa    #CR             ; Check if Enter/Return key is pressed
            bne     loopa           ; If not, continue loop

            jsr     nextline        ; Print a newline
            jsr     nextline        ; Print another newline
            
            jsr     delay1ms        ; Delay for serial port flush
            ldx     #0              ; Reset data counter
            stx     ctr125u         ; Store counter value
            jsr     StartTimer6oc   ; Start Timer Channel 6 output compare

            CLI                     ; Enable global interrupts for Timer OC6 start
            
numLoopadc                          ; Loop to collect ADC data
      			jsr    CountAndDisplay  ; Update and display clock
      			ldx		ctr125u         ; Load current data counter
      			cpx		#DATAmax        ; Check if data collection is complete (1024 numbers)
      			bge		adcdone          ; If complete, proceed to finish

adcwait                             ; Wait for ADC conversion to finish
            ldaa  ATDSTAT0         ; Load ADC status register
            anda  #%10000000       ; Check SCF bit (Sequence Complete Flag)
            beq   adcwait          ; If not set, keep waiting
            
      			clra                  ; Clear high byte of result
      			ldab  ATDDR0L         ; Load ADC result (lower 8 bits) for SIMULATOR
      			jsr		h2ad            ; Convert hex result to ASCII decimal
      			ldx   #DecBuff        ; Load address of converted decimal buffer
            jsr   printmsg         ; Print the converted number
            jsr   nextline         ; Print a newline

      			ldx		ctr125u         ; Load current data counter
      			inx                  ; Increment counter for collected numbers
      			stx		ctr125u         ; Store updated counter value
      			bra		numLoopadc       ; Continue collecting data

adcdone                             ; ADC data collection complete
      			LDAA    #%00000000    ; Clear Timer Interrupt Enable register
            STAA    TIE            ; Disable OC6 interrupts
            
      			jsr		nextline        ; Print a newline
      			jsr		nextline        ; Print another newline

            ldx     #msg4           ; Load message: '> Done! Close Output file.'
            jsr     printmsg        ; Print the message
            jsr     nextline        ; Print a newline
            jsr     nextline        ; Print another newline
            ldx     #prompt         ; Load prompt message
            jsr     printmsg        ; Print the prompt
            
            lbra    main            ; Return to main loop
;************************************************************************
; Typewriter Program
;
ttyStart                              ; Start the typewriter program
            jsr   nextline           ; Print a newline
            sei                      ; Disable interrupts
            ldx   #msg3              ; Load the address of the first message ('Hello')
            ldaa  #$DD               ; Set a placeholder value in CCount
            staa  CCount             ; Store the placeholder in CCount
            jsr   printmsg           ; Print the message
            
            ldaa  #CR                ; Load carriage return character
            jsr   putchar            ; Move the cursor to the beginning of the line
            ldaa  #LF                ; Load line feed character
            jsr   putchar            ; Move the cursor to the next line

            ldx   #msg2              ; Load the address of the second message
            jsr   printmsg           ; Print the message
                                                                                                            
            ldaa  #CR                ; Load carriage return character
            jsr   putchar            ; Move the cursor to the beginning of the line
            ldaa  #LF                ; Load line feed character
            jsr   putchar            ; Move the cursor to the next line
                 
tty                                   ; Typewriter main loop
            jsr   getchar            ; Check for keyboard input
            cmpa  #$00               ; If nothing is typed, keep checking
            beq   tty

            jsr   putchar            ; Echo typed character on the terminal window
            staa  PORTB              ; Display the character on PORTB for debugging/output

            cmpa  #CR                ; Check if Enter/Return key is pressed
            bne   tty                ; If not, continue checking for input
            ldaa  #LF                ; Load line feed character
            jsr   putchar            ; Move the cursor to the next line
            bra   tty                ; Return to the main loop for more input
;subroutine section below

;***********RTI interrupt service routine***************
rtiisr                              ; Real-Time Interrupt Service Routine (RTISR)
            bset   CRGFLG,%10000000 ; Clear the RTI interrupt flag
                                     ; Ensures the system is ready for the next RTI
            ldx    ctr2p5m          ; Load the current 16-bit interrupt counter
            inx                     ; Increment the counter (adds 2.5 ms for each RTI)
            stx    ctr2p5m          ; Store the updated counter value back
            
rtidone                             ; End of RTI Service Routine
            RTI                     ; Return from the interrupt
;***********end of RTI interrupt service routine********

;***********Timer OC6 interrupt service routine***************
oc6isr                              ; Timer Channel 6 Output Compare Interrupt Service Routine
            ldd   #3000             ; Load value for 125 µs interval with 24MHz clock
            addd  TC6H              ; Add to the current Timer Channel 6 value
            std   TC6H              ; Store updated value for next interrupt
            
            LDAA  #%10000111        ; Configure ADC for:
                                     ; - Right-justified, unsigned data
                                     ; - Single conversion mode
                                     ; - Start conversion on Channel 7
            STAA  ATDCTL5           ; Start ADC conversion
            
            bset  TFLG1,%01000000   ; Clear Timer Channel 6 interrupt flag

            ldx    #opcode          ; Load the address of the opcode
            ldaa   1,X+             ; Load the opcode value
                     
            cmpa   #$00             ; Check if opcode is '0'
            lbeq   gwgen            ; Branch to sawtooth wave generator
            cmpa   #$01             ; Check if opcode is '1'
            lbeq   gw2gen           ; Branch to 100Hz sawtooth wave generator
            cmpa   #$02             ; Check if opcode is '2'
            lbeq   gtgen            ; Branch to triangle wave generator
            cmpa   #$03             ; Check if opcode is '3'
            lbeq   gqgen            ; Branch to square wave generator
            cmpa   #$04             ; Check if opcode is '4'
            lbeq   gq2gen           ; Branch to 100Hz square wave generator
            
            lbra   oc2done          ; Skip to end of ISR if no matching opcode

gwgen                               ; Generate a standard sawtooth wave
            ldd   ctr125u           ; Load the current counter value
            ldx   ctr125u           ; Copy counter value
            inx                     ; Increment counter for 125 µs interval
            stx   ctr125u           ; Store updated counter value
            clra                    ; Clear upper byte for printing
            jsr   pnum10            ; Print the counter value as part of the sawtooth wave
            lbra   oc2done          ; End of ISR

gw2gen                              ; Generate a 100Hz sawtooth wave
            ldx   #gwcount          ; Load the sawtooth wave count
            ldaa  1,X+              ; Increment the count
            inca                    
            staa  gwcount           ; Store updated count
            cmpa  #5                ; Check if count reached 5
            lbeq  gwnext            ; Branch to next stage if count is 5

            ldd   ctr125u           ; Load current counter
            ldx   ctr125u
            inx                     ; Increment counter
            stx   ctr125u           ; Store updated counter
            clra                    ; Clear upper byte for printing
            jsr   pnum100hz         ; Print the value for 100Hz sawtooth wave
            lbra   oc2done          ; End of ISR

gwnext                              ; Reset 100Hz sawtooth wave count
            clr   gwcount           ; Clear count
            ldd   ctr125u           ; Load current counter
            ldx   ctr125u
            inx                     ; Increment counter
            stx   ctr125u           ; Store updated counter
            clra                    ; Clear upper byte for printing
            jsr   pnum100hz2        ; Print updated value for sawtooth wave
            inc   carry             ; Increment carry flag for next cycle
            lbra   oc2done          ; End of ISR

gtgen                               ; Generate a triangle wave
            ldd   ctr125u           ; Load current counter
            ldx   ctr125u
            inx                     ; Increment counter
            stx   ctr125u           ; Store updated counter
            clra                    ; Clear upper byte for printing
            jsr   pnumtriangle      ; Print counter value for triangle wave

            ldx   #gtcount          ; Load triangle wave count
            ldaa  1,X+              ; Increment count
            inca
            staa  gtcount           ; Store updated count
            cmpa  #0                ; Check if count is 0
            lbeq  gtext             ; Branch to handle toggle if count is 0

            ldd   ctr125u           ; Reload counter value
            ldx   ctr125u
            lbra   oc2done          ; End of ISR

gtext                               ; Handle triangle wave toggle
            ldx   #gtflag           ; Load triangle wave toggle flag
            ldaa  1,X+              ; Check current flag state
            cmpa  #01               ; If flag is set, invert the wave
            lbeq  gtzero

            ldab   #01              ; Set triangle wave flag
            stab   gtflag
            ldd   ctr125u           ; Reload counter value
            ldx   ctr125u
            lbra   oc2done          ; End of ISR

gtzero                              ; Clear triangle wave toggle flag
            ldab   #00              ; Clear the flag
            stab   gtflag
            ldd   ctr125u           ; Reload counter value
            ldx   ctr125u
            lbra   oc2done          ; End of ISR                 

gqgen                               ; Generate and output square wave data for 125us intervals
                                     ; Uses a counter to toggle between high and low states
            ldd     ctr125u         ; Load the current 125us interrupt counter into D
            ldx     ctr125u         ; Load the same value into X
            inx                     ; Increment the interrupt counter
            stx     ctr125u         ; Store the updated counter value back to memory
            clra                    ; Clear register A to prepare for printing

            jsr     pnum10sq        ; Print the current square wave value (0 or 255)
                                     ; Output the data to the terminal or file

            ldx     #sqcount        ; Load the address of the square wave count variable
            ldaa    1,X+            ; Load the square wave count value
            inca                    ; Increment the square wave count
            staa    sqcount         ; Store the updated count back to memory
            cmpa    #0              ; Check if the count has wrapped around to zero
            lbeq    gqext           ; If it has, handle the flag toggling

            ldd     ctr125u         ; Reload the current interrupt counter
            ldx     ctr125u         ; Reload into X as well (preparation for return)

            lbra    oc2done         ; Exit the routine and return to OC6 ISR

gqext                              ; Handle square wave flag toggling when count wraps
            ldx     #sqflag        ; Load the address of the square wave flag
            ldaa    1,X+           ; Load the flag's current value
            cmpa    #01            ; Check if the flag is set (high state)
            lbeq    gqzero         ; If high, toggle to low

            ldab    #01            ; Set the flag to indicate high state
            stab    sqflag         ; Store the updated flag value
            ldd     ctr125u        ; Reload the interrupt counter for return
            ldx     ctr125u        ; Load into X

            lbra    oc2done        ; Exit the routine

gqzero                           ; Toggle square wave flag to low state
            ldab    #00            ; Set the flag to indicate low state
            stab    sqflag         ; Store the updated flag value
            ldd     ctr125u        ; Reload the interrupt counter for return
            ldx     ctr125u        ; Load into X

            lbra    oc2done        ; Exit the routine


gq2gen                              ; Generate a 100Hz square wave
            ldd   ctr125u           ; Load the current counter value
            ldx   ctr125u           ; Copy the counter value
            inx                     ; Increment the counter for the 125 µs interval
            stx   ctr125u           ; Store the updated counter value
            clra                    ; Clear the upper byte for printing
            
            jsr   pnum10sq          ; Print the current counter value for square wave generation
                                     ; This output contributes to the RxData3.txt file
            
            ldx   #sqcount          ; Load the address of the square wave counter
            ldaa  1,X+              ; Increment the square wave counter
            inca                    
            staa  sqcount           ; Store the updated count
            cmpa  #40               ; Check if the counter has reached 40
            lbeq  gqext2            ; If yes, branch to the next square wave phase
            
            ldd   ctr125u           ; Reload the current counter value
            ldx   ctr125u           ; Copy the counter value
            lbra   oc2done          ; End of ISR

gqext2                              ; Handle the completion of a square wave cycle
            clr   sqcount           ; Reset the square wave counter
            ldx   #sqflag           ; Load the address of the square wave flag
            ldaa  1,X+              ; Check the flag value
            cmpa  #01               ; If the flag is set, invert the square wave
            lbeq  gqzero2           ; If the flag is already 1, branch to reset it

            ldab   #01              ; Set the square wave flag
            stab   sqflag           ; Store the updated flag value
            
            ldd   ctr125u           ; Reload the current counter value
            ldx   ctr125u           ; Copy the counter value
            lbra   oc2done          ; End of ISR

gqzero2                             ; Reset the square wave flag
            ldab   #00              ; Clear the square wave flag
            stab   sqflag           ; Store the updated flag value
            
            ldd   ctr125u           ; Reload the current counter value
            ldx   ctr125u           ; Copy the counter value
            lbra   oc2done          ; End of ISR
               
oc2done                             ; End of Timer Channel 6 ISR
            RTI                     ; Return from interrupt

;***********end of Timer OC6 interrupt service routine********

;***************StartTimer6oc************************
;* Program: Start the timer interrupt, timer channel 6 output compare
;* Input:   Constants - channel 6 output compare, 125usec at 24MHz
;* Output:  None, only the timer interrupt
;* Registers modified: D used and CCR modified
;* Algorithm:
;             initialize TIOS, TIE, TSCR1, TSCR2, TC2H, and TFLG1
;**********************************************
StartTimer6oc                        ; Initialize and start Timer Channel 6 Output Compare
            PSHD                    ; Push register D onto the stack to save its value

            LDAA   #%01000000       ; Configure Timer Channel 6 as Output Compare
            STAA   TIOS             ; Set Channel 6 for Output Compare mode
            STAA   TIE              ; Enable Channel 6 interrupt

            LDAA   #%10000000       ; Enable the timer system
                                     ; Fast Flag Clear not enabled
            STAA   TSCR1            ; Write configuration to Timer System Control Register 1

            LDAA   #%00000000       ; Timer Control Register 2 settings:
                                     ; - TOI (Timer Overflow Interrupt) Off
                                     ; - TCRE (Timer Counter Reset Enable) Off
                                     ; - TCLK (Timer Clock) set to BCLK/1
            STAA   TSCR2            ; Write settings to Timer System Control Register 2
                                     ; This may be redundant if the timer is in its reset state

            LDD    #3000            ; Load value for a 125 µs interval
            ADDD   TCNTH            ; Add to the current timer counter value
            STD    TC6H             ; Store the updated value to Timer Channel 6 Compare Register

            BSET   TFLG1,%01000000  ; Clear Timer Channel 6 interrupt flag
                                     ; This step may not be necessary if fast flag clear is enabled

            LDAA   #%01000000       ; Ensure Channel 6 interrupt is enabled
            STAA   TIE              ; Write to Timer Interrupt Enable Register

            PULD                    ; Restore the original value of register D from the stack
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
pnum10                              ; Convert a 16-bit number in register D to decimal ASCII
                                    ; and print it to the terminal
                pshd                ; Save register D onto the stack
                pshx                ; Save register X onto the stack
                pshy                ; Save register Y onto the stack
                clr     CTR         ; Clear the character count (CTR)

                ldy     #BUF        ; Load the address of the buffer to store digits
pnum10p1                            ; Loop to extract digits
                ldx     #10         ; Load the divisor (10 for decimal conversion)
                idiv                ; Divide register D by 10, result in X, remainder in B
                beq     pnum10p2    ; If quotient is zero, all digits have been extracted
                stab    1,y+        ; Store the remainder (next least significant digit) in the buffer
                inc     CTR         ; Increment the character count
                tfr     x,d         ; Transfer quotient from X to D for the next division
                bra     pnum10p1    ; Repeat until all digits are extracted

pnum10p2                            ; Store the final digit
                stab    1,y+        ; Store the last remainder in the buffer
                inc     CTR         ; Increment the character count

pnum10p3                            ; Loop to print digits in reverse order
                ldaa    #$30        ; Load ASCII bias for converting a digit to ASCII
                adda    1,-y        ; Retrieve a digit from the buffer and add ASCII bias
                jsr     putchar     ; Print the ASCII character to the terminal
                dec     CTR         ; Decrement the character count
                bne     pnum10p3    ; If more characters remain, repeat

                jsr     nextline    ; Print a newline after printing the number
                puly                ; Restore register Y from the stack
                pulx                ; Restore register X from the stack
                puld                ; Restore register D from the stack
                rts                 ; Return from the subroutine
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
pnumtriangle                        ; Convert and print a triangle wave value in decimal ASCII
                                     ; Handles toggling based on the triangle wave flag
                pshd                ; Save register D onto the stack
                pshx                ; Save register X onto the stack
                pshy                ; Save register Y onto the stack
                
                clr     CTR         ; Clear the character count (CTR)

                ldx     #gtflag     ; Load the address of the triangle wave flag
                ldaa    1,X+        ; Load the flag value
                cmpa    #01         ; Check if the flag is set
                lbeq    gtpnum2     ; If set, take the complement of the value
                
                bra     pnumnxt     ; Otherwise, proceed to number conversion
                
gtpnum2                             ; Take the two's complement of the number
                comb                ; Complement the lower byte of the value
                clra                ; Clear the upper byte for signed adjustment
                
pnumnxt                             ; Begin converting the value to ASCII
                ldy     #BUF        ; Load the address of the buffer to store digits

pnum10p1t                           ; Extract digits in reverse order
                ldx     #10         ; Load the divisor (10 for decimal conversion)
                idiv                ; Divide register D by 10, result in X, remainder in B
                beq     pnum10p2t   ; If quotient is zero, all digits have been extracted
                stab    1,y+        ; Store the remainder (next least significant digit) in the buffer
                inc     CTR         ; Increment the character count
                tfr     x,d         ; Transfer quotient from X to D for the next division
                bra     pnum10p1t   ; Repeat until all digits are extracted

pnum10p2t                           ; Store the final digit
                stab    1,y+        ; Store the last remainder in the buffer
                inc     CTR         ; Increment the character count
                
pnum10p3t                           ; Print digits in reverse order
                ldaa    #$30        ; Load ASCII bias for converting a digit to ASCII
                adda    1,-y        ; Retrieve a digit from the buffer and add ASCII bias
                jsr     putchar     ; Print the ASCII character to the terminal
                dec     CTR         ; Decrement the character count
                bne     pnum10p3t   ; If more characters remain, repeat

                jsr     nextline    ; Print a newline after printing the number
                puly                ; Restore register Y from the stack
                pulx                ; Restore register X from the stack
                puld                ; Restore register D from the stack
                rts                 ; Return from the subroutine
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
pnum100hz                           ; Convert and print a 100Hz signal value in decimal ASCII
                                     ; Includes a multiplier adjustment for specific scaling
                pshd                ; Save register D onto the stack
                pshx                ; Save register X onto the stack
                pshy                ; Save register Y onto the stack
                
                clr     CTR         ; Clear the character count (CTR) for digit storage

                ldy     #3          ; Load a scaling factor (3) into Y
                emul                ; Multiply the value in register D by the scaling factor
                                     ; Result: 32-bit product (D:B:A), upper byte in A
                addb    carry       ; Add the carry value to the result to account for adjustments
                clra                ; Clear the upper byte of register A to ensure proper formatting

                ldy     #BUF        ; Load the address of the buffer to store digits

pnum10p1x                           ; Extract digits in reverse order
                ldx     #10         ; Load the divisor (10 for decimal conversion)
                idiv                ; Divide register D by 10, result in X, remainder in B
                beq     pnum10p2x   ; If quotient is zero, all digits have been extracted
                stab    1,y+        ; Store the remainder (next least significant digit) in the buffer
                inc     CTR         ; Increment the character count
                tfr     x,d         ; Transfer quotient from X to D for the next division
                bra     pnum10p1x   ; Repeat until all digits are extracted

pnum10p2x                           ; Store the final digit
                stab    1,y+        ; Store the last remainder in the buffer
                inc     CTR         ; Increment the character count
                
pnum10p3x                           ; Print digits in reverse order
                ldaa    #$30        ; Load ASCII bias for converting a digit to ASCII
                adda    1,-y        ; Retrieve a digit from the buffer and add ASCII bias
                jsr     putchar     ; Print the ASCII character to the terminal
                dec     CTR         ; Decrement the character count
                bne     pnum10p3x   ; If more characters remain, repeat

                jsr     nextline    ; Print a newline after printing the number
                puly                ; Restore register Y from the stack
                pulx                ; Restore register X from the stack
                puld                ; Restore register D from the stack
                rts                 ; Return from the subroutine
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
pnum100hz2                          ; Convert and print a scaled 100Hz signal value in decimal ASCII
                                     ; Includes an additional offset adjustment
                pshd                ; Save register D onto the stack
                pshx                ; Save register X onto the stack
                pshy                ; Save register Y onto the stack
                
                clr     CTR         ; Clear the character count (CTR) for digit storage

                ldy     #3          ; Load a scaling factor (3) into Y
                emul                ; Multiply the value in register D by the scaling factor
                                     ; Result: 32-bit product (D:B:A), upper byte in A
                addb    carry       ; Add the carry value to the result to account for scaling adjustments
                clra                ; Clear the upper byte of register A
                addb    #1          ; Add a constant offset (1) to the result for further adjustment

                ldy     #BUF        ; Load the address of the buffer to store digits

pnum10p1x2                          ; Extract digits in reverse order
                ldx     #10         ; Load the divisor (10 for decimal conversion)
                idiv                ; Divide register D by 10, result in X, remainder in B
                beq     pnum10p2x2  ; If quotient is zero, all digits have been extracted
                stab    1,y+        ; Store the remainder (next least significant digit) in the buffer
                inc     CTR         ; Increment the character count
                tfr     x,d         ; Transfer quotient from X to D for the next division
                bra     pnum10p1x2  ; Repeat until all digits are extracted

pnum10p2x2                          ; Store the final digit
                stab    1,y+        ; Store the last remainder in the buffer
                inc     CTR         ; Increment the character count

pnum10p3x2                          ; Print digits in reverse order
                ldaa    #$30        ; Load ASCII bias for converting a digit to ASCII
                adda    1,-y        ; Retrieve a digit from the buffer and add ASCII bias
                jsr     putchar     ; Print the ASCII character to the terminal
                dec     CTR         ; Decrement the character count
                bne     pnum10p3x2  ; If more characters remain, repeat

                jsr     nextline    ; Print a newline after printing the number
                puly                ; Restore register Y from the stack
                pulx                ; Restore register X from the stack
                puld                ; Restore register D from the stack
                rts                 ; Return from the subroutine
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
pnum10sq                           ; Output a square wave value (either 0 or 255) as ASCII
                                    ; Based on the state of the square wave flag
                pshd               ; Save register D onto the stack
                pshx               ; Save register X onto the stack
                pshy               ; Save register Y onto the stack
 
                ldx     #sqflag    ; Load the address of the square wave flag
                ldaa    1,X+       ; Load the value of the square wave flag
                cmpa    #01        ; Check if the flag is set (square wave high)
                lbeq    sqpnum2    ; If set, branch to output "255"
                
                ldaa    #$30       ; ASCII for '0' (square wave low)
                jsr     putchar    ; Print the character '0'
                jsr     nextline   ; Move to the next line
                puly               ; Restore register Y from the stack
                pulx               ; Restore register X from the stack
                puld               ; Restore register D from the stack
                rts                ; Return from the subroutine
                
sqpnum2                            ; Output "255" for square wave high
                ldaa    #$32       ; ASCII for '2'
                jsr     putchar    ; Print the character '2'
                ldaa    #$35       ; ASCII for '5'
                jsr     putchar    ; Print the character '5'
                ldaa    #$35       ; ASCII for '5'
                jsr     putchar    ; Print the character '5'
                jsr     nextline   ; Move to the next line
                puly               ; Restore register Y from the stack
                pulx               ; Restore register X from the stack
                puld               ; Restore register D from the stack
                rts                ; Return from the subroutine
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
CountAndDisplay   psha                 ; Save accumulator A onto the stack
                  pshx                 ; Save index register X onto the stack

            ldx    ctr2p5m            ; Load the 2.5ms interrupt counter
            cpx    #94                ; Check if approximately 1 second has passed (94 * 2.5ms ˜ 235ms)
            blo    done               ; If less than 1 second, exit the routine

            bra    Fin               ; If 1 second has passed, process further
            
done        pulx                      ; Restore index register X from the stack
            pula                      ; Restore accumulator A from the stack
            rts                       ; Return from the subroutine

Fin        ldx    #0                ; Reset the 2.5ms interrupt counter
            stx    ctr2p5m           ; Store the reset value back in memory

            ldaa    half             ; Load the half-second tracker
            cmpa    #$01             ; Check if a full second has passed (half == 1)
            beq     second           ; If so, process it as a full second
            inc     half             ; If not, increment half (indicating 0.5 seconds passed)
            lbra     done            ; Exit after updating the half-second tracker
            
second      clr     half             ; Reset the half-second tracker
            inc     times            ; Increment the seconds counter
            
next        ldaa    times            ; Load the current seconds value
            cmpa    #$3C             ; Check if 60 seconds (1 minute) have passed
            bne     cmd              ; If not, skip to the next command

            clr     times            ; Reset the seconds counter
            inc     timem            ; Increment the minutes counter
            
            ldaa    timem            ; Load the current minutes value
            cmpa    #$3C             ; Check if 60 minutes (1 hour) have passed
            bne     cmd              ; If not, skip to the next command

            clr     timem            ; Reset the minutes counter
            inc     timeh            ; Increment the hours counter
            
            ldaa    timeh            ; Load the current hours value
            cmpa    #$18             ; Check if 24 hours (end of a day) have passed
            bne     cmd              ; If not, skip to the next command

            clr     timeh            ; Reset the hours counter
            
cmd         ldx     #hms             ; Load the address of the 'hms' variable
            ldaa    1,X+             ; Load the value pointed by 'hms'
            
            cmpa    #$68             ; Check if the user requested hours ('h')
            lbeq    nextH            ; If so, branch to handle hours
            cmpa    #$6D             ; Check if the user requested minutes ('m')
            lbeq    nextM            ; If so, branch to handle minutes
            cmpa    #$73             ; Check if the user requested seconds ('s')
            lbeq    nextS            ; If so, branch to handle seconds
            
nextS       ldaa    times           ; Load the current seconds value into accumulator A
            cmpa    #$32            ; Compare with $32 (50 in decimal)
            blo     SelseIf1        ; If times < $32, branch to SelseIf1
            adda    #$1E            ; If times >= $32, add $1E (30 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value
            
SelseIf1    cmpa    #$28            ; Compare with $28 (40 in decimal)
            blo     SelseIf2        ; If times < $28, branch to SelseIf2
            adda    #$18            ; If times >= $28, add $18 (24 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value
            
SelseIf2    cmpa    #$1E            ; Compare with $1E (30 in decimal)
            blo     SelseIf3        ; If times < $1E, branch to SelseIf3
            adda    #$12            ; If times >= $1E, add $12 (18 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value
            
SelseIf3    cmpa    #$14            ; Compare with $14 (20 in decimal)
            blo     SelseIf4        ; If times < $14, branch to SelseIf4
            adda    #$0C            ; If times >= $14, add $0C (12 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value
            
SelseIf4    cmpa    #$0A            ; Compare with $0A (10 in decimal)
            blo     print           ; If times < $0A, directly branch to print
            adda    #$06            ; If times >= $0A, add $06 (6 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value

nextM       ldaa    timem           ; Load the current minutes value into accumulator A
            cmpa    #$32            ; Compare with $32 (50 in decimal)
            blo     MelseIf1        ; If timem < $32, branch to MelseIf1
            adda    #$1E            ; If timem >= $32, add $1E (30 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value
            
MelseIf1    cmpa    #$28            ; Compare with $28 (40 in decimal)
            blo     MelseIf2        ; If timem < $28, branch to MelseIf2
            adda    #$18            ; If timem >= $28, add $18 (24 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value
            
MelseIf2    cmpa    #$1E            ; Compare with $1E (30 in decimal)
            blo     MelseIf3        ; If timem < $1E, branch to MelseIf3
            adda    #$12            ; If timem >= $1E, add $12 (18 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value
            
MelseIf3    cmpa    #$14            ; Compare with $14 (20 in decimal)
            blo     MelseIf4        ; If timem < $14, branch to MelseIf4
            adda    #$0C            ; If timem >= $14, add $0C (12 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value
            
MelseIf4    cmpa    #$0A            ; Compare with $0A (10 in decimal)
            blo     print           ; If timem < $0A, directly branch to print
            adda    #$06            ; If timem >= $0A, add $06 (6 in decimal) to adjust for display
            bra     print           ; Jump to print to display the adjusted value

print       staa    PORTB           ; Store the adjusted value in PORTB to display it
            pulx                    ; Restore index register X from the stack
            pula                    ; Restore accumulator A from the stack
            rts                     ; Return from the subroutine

nextH       ldaa    timeh           ; Load the current hours value into accumulator A
            cmpa    #$14            ; Compare with $14 (20 in decimal)
            blo     HelseIf4        ; If timeh < $14, branch to HelseIf4
            adda    #$0C            ; If timeh >= $14, add $0C (12 in decimal) to adjust for display
            lbra    print           ; Jump to print to display the adjusted value
                          
HelseIf4    cmpa    #$0A            ; Compare with $0A (10 in decimal)
            blo     print           ; If timeh < $0A, directly branch to print
            adda    #$06            ; If timeh >= $0A, add $06 (6 in decimal) to adjust for display
            lbra    print           ; Jump to print to display the adjusted value
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
NULL            equ     $00            ; Define NULL as the value $00, representing the end of a string

printmsg        psha                   ; Save the accumulator A on the stack
                pshx                   ; Save the index register X on the stack
                
printmsgloop    ldaa    1,X+           ; Load the next byte from the memory address pointed to by X
                                       ; Increment X to point to the next byte
                cmpa    #NULL          ; Compare the loaded byte with NULL ($00)
                beq     printmsgdone   ; If the byte is NULL, branch to printmsgdone (end of string)
                bsr     putchar        ; Otherwise, call the putchar subroutine to print the character
                bra     printmsgloop   ; Repeat the loop for the next character
                
printmsgdone    pulx                   ; Restore the index register X from the stack
                pula                   ; Restore the accumulator A from the stack
                rts                    ; Return from the subroutine
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
putchar     brclr SCISR1,#%10000000,putchar   ; Wait until the SCI transmit buffer is empty.
                                              ; SCISR1 is the Serial Communication Interface Status Register 1.
                                              ; Bit 7 (#%10000000) is the TDRE (Transmit Data Register Empty) flag.
                                              ; The `brclr` instruction checks if this bit is clear (buffer not ready),
                                              ; and loops back to `putchar` until the buffer is ready.
                                              
            staa  SCIDRL                      ; Store the character from Accumulator A into SCIDRL (SCI Data Register Low).
                                              ; This sends the character to the SCI port for transmission.
                                              
            rts                               ; Return from the subroutine.
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
getchar     brclr SCISR1,#%00100000,getchar7   ; Check if a character has been received.
                                               ; SCISR1 is the Serial Communication Interface Status Register 1.
                                               ; Bit 5 (#%00100000) is the RDRF (Receive Data Register Full) flag.
                                               ; The `brclr` instruction checks if this bit is clear (no character received).
                                               ; If clear, branch to `getchar7`.

            ldaa  SCIDRL                        ; Load the received character from the SCI Data Register Low (SCIDRL) into Accumulator A.
                                               ; This clears the RDRF flag automatically and retrieves the received byte.

            rts                                ; Return with the received character in Accumulator A.

getchar7    clra                               ; If no character was received, clear Accumulator A (return NULL, $00).
            rts                                ; Return with NULL in Accumulator A.
;****************end of getchar**************** 

;****************nextline**********************
nextline    psha                   ; Save the current value of Accumulator A onto the stack.
            ldaa  #CR              ; Load the ASCII value for Carriage Return (CR) into Accumulator A.
                                    ; CR moves the cursor to the beginning of the current line.
            jsr   putchar          ; Call the `putchar` subroutine to send the CR character to the terminal.

            ldaa  #LF              ; Load the ASCII value for Line Feed (LF) into Accumulator A.
                                    ; LF moves the cursor to the next line on the terminal.
            jsr   putchar          ; Call the `putchar` subroutine to send the LF character to the terminal.

            pula                   ; Restore the original value of Accumulator A from the stack.
            rts                    ; Return from the subroutine.
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
            ldab    #$0B        ; Load B with the total number of bytes to clear (11 bytes in this case).
clrLoop
            cmpb    #$00        ; Compare B with 0 to check if all bytes are cleared.
            beq     clrReturn   ; If B equals 0, all bytes are cleared; branch to clrReturn.

            ldaa    #$00        ; Load A with 0 (null value).
            staa    1,X+        ; Store 0 into the current buffer location and increment X to the next byte.

            decb                ; Decrement B (reduce the remaining byte count by 1).
            bra     clrLoop     ; Branch back to clrLoop to continue clearing the next byte.

clrReturn   rts                 ; Return from the subroutine.;***********end of clrBuff*****************************

;****************delay1ms**********************
delay1ms:   pshx                   ; Push the X register onto the stack to save its current value.
            ldx   #$1000           ; Load X with the value $1000 (4096 in decimal) for the countdown.
d1msloop    nop                    ; No operation (used to delay and consume a small amount of time).
            dex                    ; Decrement X by 1.
            bne   d1msloop         ; Branch to d1msloop if X is not zero, continuing the countdown.
            pulx                   ; Restore the original value of X from the stack.
            rts                    ; Return from the subroutine.
;****************end of delay1ms***************

;*********************h2ad****************************
;* Program: converts a hex number to ascii decimal
;*             
;* Input:   hex number
;*     
;* Output:  number in ascii decimal 
;*          
;*          
;* Registers modified: A, B, X, CCR
;*   
;*****************************************************
h2ad            clr   HCount         ; Clear the count of digits (HCount).
                cpd   #$00          ; Check if the input value is zero.
                lbeq  H0            ; If input is zero, branch to H0 to handle it.
                ldy   #DecBuff      ; Load the address of DecBuff (buffer for decimal digits).

HLoop           ldx   #10           ; Load divisor (10) into X.
                idiv                ; Divide D by X, quotient in X, remainder in B.
                stab  1,Y+          ; Store remainder (digit) in DecBuff and increment Y.
                inc   HCount        ; Increment digit count (HCount).
                tfr   X,D           ; Transfer quotient back into D.
                tstb                ; Check if there’s any remainder left.
                bne   HLoop         ; If there’s more to divide, repeat the loop.

reverse         ldaa  HCount        ; Load the digit count.
                cmpa  #$05          ; Check if the number has 5 digits.
                beq   H4            ; If so, branch to H4 to process 5 digits.
                cmpa  #$04          ; Check if the number has 4 digits.
                beq   H3            ; If so, branch to H3 to process 4 digits.
                cmpa  #$03          ; Check if the number has 3 digits.
                lbeq  H2            ; If so, branch to H2 to process 3 digits.
                cmpa  #$02          ; Check if the number has 2 digits.
                lbeq  H1            ; If so, branch to H1 to process 2 digits.

                ; If there is only 1 digit, convert it and return.
                ldx   #DecBuff      ; Load the address of DecBuff.
                ldaa  0,X           ; Load the single digit.
                adda  #$30          ; Convert to ASCII.
                staa  1,X+          ; Store the ASCII digit.
                ldaa  #$00          ; Load NULL character.
                staa  1,X+          ; Store NULL.
                rts                 ; Return.

H4              ldx   #DecBuff  ; Load buffer base
                ldaa  1,X+      ; Load 1's place remainder
                inx
                inx
                inx
                ldab  0,X       ; Load 10000's place remainder
                staa  0,X       ; Swap positions
                ldx   #DecBuff
                stab  0,X       
                
                inx             ; Move to 1000's place
                ldaa  1,X+      ; Load current 1000's place
                inx             ; Skip 100's place
                ldab  0,X       
                staa  0,X       
                ldx   #DecBuff  ; Reload buffer
                inx             ; Move to 1000's place
                stab  0,X       
                
                ldx   #DecBuff  
                ldaa  0,X       ; Load 10000's place
                adda  #$30      ; Add ASCII bias
                staa  1,X+      ; Store converted 10000's place
                ldaa  0,X       ; Load 1000's place
                adda  #$30      ; Add ASCII bias
                staa  1,X+      ; Store converted 1000's place
                ldaa  0,X       ; Load 100's place
                adda  #$30      ; Add ASCII bias
                staa  1,X+      ; Store converted 100's place
                ldaa  0,X       ; Load 10's place
                adda  #$30
                staa  1,X+      ; Store converted 10's place
                ldaa  0,X       ; Load 1's place
                adda  #$30      
                staa  1,X+      ; Store converted 1's place
                ldaa  #$00      ; Load NULL terminator
                staa  1,X+      
                rts
                
H3              ldx   #DecBuff
                ldaa  1,X+      ; Load 1's place remainder
                inx
                inx
                ldab  0,X       ; Load 1000's place remainder
                staa  0,X       
                ldx   #DecBuff
                stab  0,X       ; Put 1000's place into position
                
                inx             ; Move to 100's place
                ldaa  1,X+      ; Load current 100's place
                ldab  0,X       ; Load current 10's place
                staa  0,X       
                ldx   #DecBuff  
                inx             
                stab  0,X       
                
                ldx   #DecBuff  
                ldaa  0,X       ; Load 1000's place
                adda  #$30      ; Add ASCII bias
                staa  1,X+      ; Store converted 1000's place
                ldaa  0,X       ; Load 100's place
                adda  #$30      ; Add ASCII bias
                staa  1,X+      ; Store converted 100's place
                ldaa  0,X       ; Load 10's place
                adda  #$30
                staa  1,X+      ; Store converted 10's place
                ldaa  0,X       ; Load 1's place
                adda  #$30      
                staa  1,X+      ; Store converted 1's place
                ldaa  #$00      ; Load NULL terminator
                staa  1,X+      
                rts 
                
H2              ldx   #DecBuff
                ldaa  1,X+      ; Load 1's place remainder
                inx
                ldab  0,X       ; Load 100's place remainder
                staa  0,X       
                ldx   #DecBuff
                stab  0,X       
                
                ldaa  0,X       ; Load 100's place
                adda  #$30      ; Add ASCII bias
                staa  1,X+      ; Store converted 100's place
                ldaa  0,X       ; Load 10's place
                adda  #$30
                staa  1,X+      ; Store converted 10's place
                ldaa  0,X       ; Load 1's place
                adda  #$30      
                staa  1,X+      ; Store converted 1's place
                ldaa  #$00      ; Load NULL terminator
                staa  1,X+      
                rts  
                
H1              ldx   #DecBuff
                ldaa  1,X+      ; Load 1's place remainder
                ldab  0,X       ; Load 10's place remainder
                staa  0,X       
                ldx   #DecBuff  
                stab  0,X       
                
                ldaa  0,X       ; Load 10's place
                adda  #$30      ; Add ASCII bias
                staa  1,X+      ; Store converted 10's place
                ldaa  0,X       ; Load 1's place
                adda  #$30
                staa  1,X+      ; Store converted 1's place
                ldaa  #$00      ; Load NULL terminator
                staa  1,X+      
                rts     
                
H0              ldx   #DecBuff  
                ldaa  #$30      ; Load ASCII '0'
                staa  1,X+      ; Store converted digit
                ldaa  #$00      ; Load NULL terminator
                staa  1,X+               
                rts                                                        
;******************end of h2ad************************


;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip

msg1        DC.B    'Welcome to the ADC, Wave Generation, and 24 hour clock Program!', $00
msg2        DC.B    '      Typewriter program started. You may type below:', $00
msg3        DC.B    '      ADC, Wave Generator, and Clock stopped.', $00

msg4        DC.B    '> Done!  Close Output file.', $00
msg5        DC.B    '> Set Terminal save file RxData3.txt', $00
msg6        DC.B    '> Press Enter/Return key to start wave generation', $00
msg7        DC.B    '> Press Enter/Return key to start analog digital conversion', $00

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
menu11      DC.B    'Input command adc to start  analog digital conversion.', $00

prompt      DC.B    'HW11> ', $00


errmsg1     DC.B    '      Invalid input format', $00
errmsg2     DC.B    '      Error> Invalid time format. Correct example => 00:00:00 to 23:59:59', $00
errmsg3     DC.B    '      Error> Invalid command. ("s" for second display and "q" for quit)', $00
errmsg4     DC.B    '      Error> Invalid command. ("m" for second display and "q" for quit)', $00
errmsg5     DC.B    '      Error> Invalid command. ("h" for second display and "q" for quit)', $00

gwmsg       DC.B    '      sawtooth wave generation ....', $00
gw2msg      DC.B    '      sawtooth wave 100Hz generation ....', $00
gtmsg       DC.B    '      triangle wave generation ....', $00
gqmsg       DC.B    '      square wave generation ....', $00
gq2msg      DC.B    '      square wave 100Hz generation ....', $00
adcmsg      DC.B    '      analog signal acquisition ....', $00


            END               ; this is end of assembly source file
                              ; lines below are ignored - not assembled/compiled