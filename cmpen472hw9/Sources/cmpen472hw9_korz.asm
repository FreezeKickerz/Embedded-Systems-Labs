***********************************************************************
*
* Title:          24 Hour Clock With Calculator
*
* Objective:      CMPEN 472 Homework 9
*
* Revision:       V2.0  for CodeWarrior 5.2 Debugger Simulation
*
* Date:	      1 November 2024
*
* Programmer:     Tyler Korz
*
* Company:        Student at The Pennsylvania State University
*                 Department of Computer Science and Engineering
*
* Program:        RTI usage
*                 Typewriter program and 7-Segment display, at PORTB
*                 
*
* Algorithm:      Simple Serial I/O use, typewriter, RTIs
*
* Register use:	  A, B, X, CCR
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
*                 and perform calculator operations
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

CRGFLG      EQU         $0037        ; Clock and Reset Generator Flags
CRGINT      EQU         $0038        ; Clock and Reset Generator Interrupts
RTICTL      EQU         $003B        ; Real Time Interrupt Control

CR          equ         $0d          ; carriage return, ASCII 'Return' key
LF          equ         $0a          ; line feed, ASCII 'next line' character

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

CCount      DS.B        $0001        ; Number of chars in buffer
CmdBuff     DS.B        $000B        ; The actual command buffer

DecBuff     DS.B        $0006        ; used for decimal conversions
DecBuffC    DS.B        $0006        ; used for decimal conversions
HCount      DS.B        $0001        ; number of ASCII characters for Hex conversion

DCount      DS.B        $0001        ; number of ASCII characters for Decimal
DCount1     DS.B        $0001        ; number of digits in Num1
DCount2     DS.B        $0001        ; number of digits in Num2
Hex         DS.B        $0002        ; used to store number in hex

tempbuff1   DS.B        $0002        ; temp buffers for conversions
tempbuff2   DS.B        $0002

Num1        DS.B        $0002        ; stores first  inputed number
Num2        DS.B        $0002        ; stores second inputed number
Num1ASCII   DS.B        $0005        ; Num1 in ASCII
Num2ASCII   DS.B        $0005        ; Num2 in ASCII

Opcode      DS.B        $0001        ; stores the operation code                            
err         DS.B        $0001        ; error flag
negFlag     DS.B        $0001        ; negative answer flag


;*******************************************************
; interrupt vector section
            ORG    $FFF0             ; RTI interrupt vector setup for the simulator
;            ORG    $3FF0             ; RTI interrupt vector setup for the CSM-12C128 board
            DC.W   rtiisr

;*******************************************************
; code section

            ORG    $3100
Entry
            LDS    #Entry         ; initialize the stack pointer

            LDAA   #%11111111   ; Set PORTB bit 0,1,2,3,4,5,6,7
            STAA   DDRB         ; as output
            STAA   PORTB        ; set all bits of PORTB, initialize

            ldaa   #$0C         ; Enable SCI port Tx and Rx units
            staa   SCICR2       ; disable SCI interrupts

            ldd    #$0002       ; Set SCI Baud Register = $0002 => 1M baud at 24MHz

            std    SCIBDH       ; SCI port baud rate change

            ldaa    #$00
            staa    PORTB           ; show 00 on the clock
            
            staa   timeh
            staa   timem
            staa   times

            ldx    #msg1           ; print the welcome message
            jsr    printmsg
            jsr    nextline

            ldx    #menu1          ; print the first menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu6          ; print the 6 menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu2          ; print the 2nd menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu3          ; print the 3rd menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu4          ; print the 4th menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu5          ; print the 5th menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu7          ; print the 7th menu line
            jsr    printmsg
            jsr    nextline
            
            bset   RTICTL,%00011001 ; set RTI: dev=10*(2**10)=2.555msec for C128 board
                                    ;      4MHz quartz oscillator clock
            bset   CRGINT,%10000000 ; enable RTI interrupt
            bset   CRGFLG,%10000000 ; clear RTI IF (Interrupt Flag)


            ldx    #0
            stx    ctr2p5m          ; initialize interrupt counter with 0.
            cli                     ; enable interrupt, global

            clr    half             ; clear out the half counter
            clr    times
            clr    timem
            clr    timeh
            
            
main        
           
            ldx    #CmdBuff
            clr    CCount
            clr    HCount
            jsr    clrBuff
                        
            ldx    #CmdBuff
            ldaa   #$0000
            

looop       
            
            jsr    CountAndDisplay  ; if 0.5 second is up, toggle the LED

            jsr    getchar          ; type writer - check the key board
            tsta                    ;  if nothing typed, keep checking
            beq    looop               
            
            cmpa  #CR
            beq   noReturn
            jsr   putchar
            
noReturn    staa  1,X+               ; store char in buffer
            inc   CCount             ; 
            ldab  CCount
            cmpb  #$0B               ; max # chars in buffer is 11, including Enter
            lbhi   Error              ; user filled the buffer
            cmpa  #CR
            bne    looop            

            ldab  CCount
            cmpb  #$02               ; min # chars in buffer is 2, including Enter
            lblo   Error            
            
            

            ldx    #CmdBuff           
            ldaa   1,X+   
CmdChk      

            cmpa   #$68              ; check for 'h'
            lbeq   h
            cmpa   #$6D              ; check for 'm'
            lbeq   m 
            cmpa   #$74              ; check for 't'
            lbeq   t
            cmpa   #$73               ; check for 's'            
            lbeq   s                  
            cmpa   #$71               ; check for 'q'            
            lbeq   q                  ; typewriter
            
            jsr   parse              ; parse input
            ldaa  err                ; check for error 
            cmpa  #$01               
            lbeq  Error
            
            ldx   #Hex
            clr   1,X+
            clr   1,X+
            
            ldy   #Num1
            ldx   #Num1ASCII
            ldaa  DCount1
            staa  DCount
            jsr   ad2h               ; convert Num1 into hex
            ldaa  err                
            cmpa  #$01               
            lbeq  Error
            sty   Num1
            
            ldx   #Hex
            clr   1,X+
            clr   1,X+
            
            ldy   #Num2
            ldx   #Num2ASCII
            ldaa  DCount2
            staa  DCount
            jsr   ad2h               ; convert Num2 into hex
            ldaa  err                
            cmpa  #$01               ; branch if error
            lbeq  Error
            sty   Num2
            
            
            ldaa  Opcode             ; decide which operation to perform
            cmpa  #$00
            beq   AddOp
            cmpa  #$01
            beq   SubOp
            cmpa  #$02
            beq   MulOp
            cmpa  #$03
            beq   DivOp
            bra   Error              ; error, invalid opcode
            
AddOp       ldd   Num1               ; add Num1 and Num2
            addd  Num2            
            std   Hex                
            bra   PrintAnswer        ; branch to answer

SubOp       ldd   Num1               ; subtract Num2 from Num1
            cpd   Num2               
            blt   Negate             ; check for negative answer
            subd  Num2
            std   Hex
            bra   PrintAnswer
            
Negate      ldd   Num2               ; subtract Num1 from Num2 instead 
            subd  Num1
            std   Hex
            ldaa  #$01
            staa  negFlag            ; set negative flag
            bra   PrintAnswer            

MulOp       ldd   Num1               ; multiply Num1 by Num2
            ldy   Num2
            emul
            bcs   OFError            ; check for overflow
            cpy   #$00               
            bne   OFError                  
            std   Hex
            bra   PrintAnswer

DivOp       ldd   Num1               ; divide Num1 by Num2
            ldx   Num2
            cpx   #$0000             ; check for division by zero
            beq   Error
            idiv                     
            stx   Hex
            
PrintAnswer                          ; print the answer to calculation          

            ldd   Hex
            jsr   h2adC               ; convert answer to ascii for printing on terminal
            
            
HandleCalcResult        
            jsr   CalcTerm            
            clr   negFlag            ; clear negative flag
            lbra  main            
            
            

Error                                ; no recognized command entered, print err msg
            

            ldx   #msg4              ; print the error message
            jsr   printmsg
            clr   err
            
            lbra  main               ; loop back to beginning, infinitely
            
OFError                             
                                   
            ldx   #errmsg2           ; prints overflow error message
            jsr   printmsg
            clr   err                ; reset error flag
            lbra  main               ; loop to main            
           

t           ldaa  1,X+
            cmpa  #$20              ; ensure second character in input is space
            bne   Error             ; must be a space there
            clr   dec               ; clear out decimal variable
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error
            cmpa  #$32              ; ensure digit is 2 or less
            bhi   Error
            
            beq   t2              
            
            suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error
            cmpa  #$39              ; ensure digit is smaller than ":" (9 or below)
            bhi   Error
            suba  #$30              ; ASCII number offset
            ldab  #1                ; weight of least sig digit
            mul                     ; A * #10, stored in D
            ldaa  dec
            aba                     ; add stored 10s place number with converted 1s place number
            staa  dec
            bra   t3
            
t2          suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error
            cmpa  #$33              ; ensure digit is 3 or less
            bhi   Error
            suba  #$30              ; ASCII number offset
            ldab  #1                ; weight of least sig digit
            mul                     ; A * #10, stored in D
            ldaa  dec
            aba                     ; add stored 10s place number with converted 1s place number
            staa  dec  
                    
            
            
t3          staa  timeh             ; save hours
            clr   dec               ; clear out decimal variable
            

            ldaa  1,X+
            cmpa  #$3A              ; ensure next character in input is ':'
            bne   Error1
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error1
            cmpa  #$35              ; ensure digit is 5 or less
            bhi   Error1
            suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error1
            cmpa  #$39              ; ensure digit is smaller than 9
            bhi   Error1
            suba  #$30              ; ASCII number offset
            ldab  #1                ; weight of least sig digit
            mul                     ; A * #10, stored in D
            ldaa  dec
            aba                     ; add stored 10s place number with converted 1s place number
            staa  dec
            
            staa  timem             ; save minutes
            clr   dec               ; clear out decimal variable
            
            
            ldaa  1,X+
            cmpa  #$3A              ; ensure next character in input is ':'
            bne   Error1
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error1
            cmpa  #$35              ; ensure digit is 5 or less
            bhi   Error1
            suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error1
            cmpa  #$39              ; ensure digit is smaller than 9
            bhi   Error1
            suba  #$30              ; ASCII number offset
            ldab  #1                ; weight of least sig digit
            mul                     ; A * #10, stored in D
            ldaa  dec
            aba                     ; add stored 10s place number with converted 1s place number
            staa  dec             
            
            staa  times             ; save seconds
            
            
            clr   half
            ldx   #$0000
            stx    ctr2p5m          ; initialize interrupt counter with 0.
            
            lbra   main
            
Error1                                ; no recognized command entered, print err msg
            ldx   #msg4              ; print the error message
            jsr   printmsg
            
            lbra  main               ; loop back to beginning, infinitely           
            
            


h           cmpb  #$02              ; check if command is max length.
            bne   Error1
            staa  hms
            lbra  main
 

m           cmpb  #$02              ; check if command is max length.
            bne   Error1
            staa  hms
            lbra  main
            
            
s           cmpb  #$02              ; check if command is max length.
            bne   Error1
            staa  hms
            lbra  main
            
q           cmpb  #$02              ; check if command is max length.
            bne   Error1
            bra   ttyStart                        
            
                
            
;
; Typewriter Program
;
ttyStart    jsr   nextline
            jsr   nextline
            sei                      ; disable interrupts
            ldx   #msg3              ; print the first message, 'Hello'
            ldaa  #$DD
            staa  CCount
            jsr   printmsg
            
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar

            ldx   #msg2              ; print the third message
            jsr   printmsg
                                                                                                            
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar
                 
tty         jsr   getchar            ; type writer - check the key board
            cmpa  #$00               ;  if nothing typed, keep checking
            beq   tty
                                     ;  otherwise - what is typed on key board
            jsr   putchar            ; is displayed on the terminal window - echo print

            staa  PORTB              ; show the character on PORTB

            cmpa  #CR
            bne   tty                ; if Enter/Return key is pressed, move the
            ldaa  #LF                ; cursor to next line
            jsr   putchar
            bra   tty


;subroutine section below

;***********RTI interrupt service routine***************
rtiisr      bset   CRGFLG,%10000000 ; clear RTI Interrupt Flag - for the next one
            ldx    ctr2p5m          ; every time the RTI occur, increase
            inx                     ;    the 16bit interrupt count
            stx    ctr2p5m            
rtidone     RTI
;***********end of RTI interrupt service routine********


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
CountAndDisplay   psha
                  pshx

            ldx    ctr2p5m          ; check for 0.5 sec
;            cpx    #200             ; 2.5msec * 200 = 0.5 sec
;            cpx    #40
            cpx    #94               ; approx 1 sec             
            blo    last          ; NOT yet
            
            bra    UpdateTimeCounters
            
            
last        pulx
            pula
            rts            

UpdateTimeCounters        ldx    #0               ; 0.5sec is up,
            stx    ctr2p5m          ;     clear counter to restart
            
            
            ldaa    half            ; check if it's already been a second
            cmpa    #$01            ; if it's already 1, then we've just gone a whole second
            beq     second
            inc     half            ; it has not been a second yet. set half=1 because it has been 1/2 second so far
            lbra    last
            
            
            
            
          
            
second      

            clr     half            ; reset half second counter
            inc     times           ; increment seconds counter                                   
            
            
            
next        ldaa    times           ; check if 60sec have passed
            cmpa    #$3C            ; $3C == 60
            bne     cmd

            clr     times           ; reset times to 0 if 60sec passed
            inc     timem
            
            ldaa    timem           ; check if 60min have passed
            cmpa    #$3C            ; $3C == 60
            bne     cmd
            
            clr     timem
            inc     timeh
            
            ldaa    timeh           ; check if 24 hours have passed
            cmpa    #$18            
            bne     cmd
            
            clr     timeh
            
cmd         jsr     Terminal
            ldx    #hms           
            ldaa   1,X+
                     
            cmpa   #$68              ; check for 'h'
            lbeq   nextH
            cmpa   #$6D              ; check for 'm'
            lbeq   nextM 
            cmpa   #$73               ; check for 's'            
            lbeq   nextS
            
nextS       ldaa    times
            cmpa    #$32            
            blo     SelseIf1
            adda    #$1E            ; if (times >= $32) print(times+$1E);
            bra     print           
            
SelseIf1     cmpa    #$28            
            blo     SelseIf2
            adda    #$18            ; else if (times >= $28) print(times+$18);
            bra     print
            
SelseIf2     cmpa    #$1E
            blo     SelseIf3
            adda    #$12            ; else if (times >= $1E) print(times+$12);
            bra     print
            
SelseIf3     cmpa    #$14
            blo     SelseIf4
            adda    #$0C            ; else if (times >= $14) print(times+$0C);
            bra     print            
            
SelseIf4     cmpa    #$0A
            blo     print           ; branch to else case
            adda    #$06            ; else if (times >= $0A) print(times+$06);
            bra     print                       
            
            
nextM       ldaa    timem
            cmpa    #$32            
            blo     MelseIf1
            adda    #$1E            ; if (timem >= $32) print(timem+$1E);
            bra     print           
            
MelseIf1     cmpa    #$28            
            blo     MelseIf2
            adda    #$18            ; else if (timem >= $28) print(timem+$18);
            bra     print
            
MelseIf2     cmpa    #$1E
            blo     MelseIf3
            adda    #$12            ; else if (timem >= $1E) print(timem+$12);
            bra     print
            
MelseIf3     cmpa    #$14
            blo     MelseIf4
            adda    #$0C            ; else if (timem >= $14) print(timem+$0C);
            bra     print            
            
MelseIf4     cmpa    #$0A
            blo     print           ; branch to else case
            adda    #$06            ; else if (timem >= $0A) print(timem+$06);
            bra     print



            
print       staa    PORTB           ; show the number on PORTB                                                       
   
            pulx
            pula
            rts
            
            
nextH       ldaa    timeh
            cmpa    #$14
            blo     HelseIf4
            adda    #$0C            ; if (times >= $14) print(timeh+$0C);
            lbra     print           
                          
            
HelseIf4     cmpa    #$0A
            blo     print           ; branch to else case
            adda    #$06            ; else (times >= $0A) print(timeh+$06);
            lbra     print            
            
;***************end of CountAndDisplay***************

;***************Terminal***************
;Displays propmpts on terminal
;**********************************************
Terminal    

            pshx
            jsr    nextline
            ldx    #prompt
            jsr    printmsg
            
            ldd    timeh
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   hterm
            ldx   #zero
            jsr   printmsg
            
            
hterm       ldx    #DecBuff
            jsr    printmsg
            
            ldx    #semi
            jsr    printmsg
            
            ldd    timem
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   mterm
            ldx   #zero
            jsr   printmsg
            
mterm       ldx    #DecBuff
            jsr    printmsg
                                  
            
            ldx    #semi
            jsr    printmsg
            
            ldd    times
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   sterm
            ldx   #zero
            jsr   printmsg
            
sterm       ldx    #DecBuff
            jsr    printmsg
            
            ldx    #cmdmsg
            jsr    printmsg
            
            ldx    #CmdBuff
            jsr    printmsg
            
            
            
            pulx
            rts
            
            
;***************end of Terminal***************

;***************CalcTerm****************************
;Displays propmpts on terminal when calc is in use
;***************************************************
CalcTerm    

            pshx
            jsr    nextline
            ldx    #prompt
            jsr    printmsg
            
            ldd    timeh
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   hterm1
            ldx   #zero
            jsr   printmsg
            
            
hterm1      ldx    #DecBuff
            jsr    printmsg
            
            ldx    #semi
            jsr    printmsg
            
            ldd    timem
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   mterm1
            ldx   #zero
            jsr   printmsg
            
mterm1              ldx    #DecBuff
                    jsr    printmsg
                                  
            
                    ldx    #semi
                    jsr    printmsg
            
                    ldd    times
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    jsr    h2ad
                    ldx    #DecBuff
            
                    inx
                    ldaa  1,X+
                    cmpa  #$00              ; check for NULL
                    bne   sterm1
                    ldx   #zero
                    jsr   printmsg
            
sterm1              ldx    #DecBuff
                    jsr    printmsg
            
                    ldx    #sspace
                    jsr    printmsg
            
                    ldx    #Num1ASCII
                    jsr    printmsg
            
                    ldaa  Opcode             ; decide which operation to perform
                    cmpa  #$00
                    beq   addsign
                    cmpa  #$01
                    beq   subsign
                    cmpa  #$02
                    beq   mulsign
                    cmpa  #$03
                    beq   divsign
            
                        
addsign             ldx    #add
                    jsr    printmsg       
                    bra    Num22
            
subsign             ldx    #minus
                    jsr    printmsg
                    bra    Num22

divsign             ldx    #divide
                    jsr    printmsg
                    bra    Num22

mulsign             ldx    #multiply
                    jsr    printmsg
            

            
Num22               ldx    #Num2ASCII
                    jsr    printmsg
            
                    ldx    #equal
                    jsr    printmsg
            
                    ldaa  negFlag
                    cmpa  #$01               ; check if answer should be negative
                    bne   ShowResult               
                    ldx   #minus
                    jsr   printmsg      
            
ShowResult          ldx    #DecBuffC
                    jsr    printmsg            
            
                    pulx
                    rts
            
            
;***************end of CalcTerm***************

;*********************ad2h*****************************
;* Program: converts ascii-formatted decimal (up to 4 digits) to hex
;*             
;* Input: decimal in ascii form, number of digits      
;* Output: hex number in buffer (#Hex) and Y          
;*          
;* Registers modified: X,Y,A,B   
;******************************************************
ad2h    

D4                  ldaa    0,X          ; load first digit into A
                    ldab    DCount       ; load number of digits into B
                    cmpb    #$04         ; check for 4 digits
                    bne     D3           ; branch if 3 or less
                    dec     DCount  
                             
                
                    suba    #$30         ; subtract ascii bias
                    lsla                 ; shift left 3 times, multiply by 8
                    lsla
                    lsla
                    staa    tempbuff1    ; store in tempbuff
                
                    ldaa    0,X          ; reload into A
                    suba    #$30
                    lsla                 ; shift left 4 time, multiply by 16
                    lsla
                    lsla
                    lsla
                    adda    tempbuff1    ; add to tempbuff
                    staa    tempbuff1    ; now has digit multiplied by 24
                             
                
                    ldd     0,X          ; load digit into D
                    lsrd                 ; shift right 8 times, gives leading zeros
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    subd    #$30         ; subtract ascii bias
                
                    lsld                 ; shift left 10 times, multiply by 1024
                    lsld
                    lsld
                    lsld
                    lsld
                    lsld
                    lsld
                    lsld
                    lsld
                    lsld
                    std     tempbuff2    ; store in second buffer
                
                    ldd     tempbuff1    ; load first buffer into D
                    lsrd                 ; shift right to ensure leading zeros
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    lsrd
                    std     tempbuff1    ; store back into first buffer
                
                    ldd     tempbuff2    ; load second buffer into D
                    subd    tempbuff1    ; subtracts digit multiplied by 1024 
                                     ; by digit multiplied by 24
                
                
                
                    std     Hex          ; store digit multiplied by #1000 into Hex
                    ldd     #$0          ; reset D
                                                
                    inx                  
                    ldaa    0,X          ; load next digit into A
                    ldab    DCount       
                

D3                  cmpb    #$03         ; check for 3 digits left
                    bne     D2
                    dec     DCount  
                    suba    #$30         ; ascii bias
                    ldab    #100         
                    mul                  ; multiply A by #100, store in D
                    addd    Hex          ; add D and Hex buffer
                    std     Hex          ; store in Hex                
                    inx
                    ldaa    0,X         
                    ldab    DCount  

D2                  cmpb    #$02         ; check for 2 digits
                    bne     D1
                    dec     DCount  
                    suba    #$30         
                    ldab    #10     
                    mul                  ; multiply A by #10
                    addd    Hex
                    std     Hex                     
                    inx
                    ldaa    0,X     
                    ldab    DCount  
                
D1                  cmpb    #$01         ; last digit
                    bne     hconverror   ; branch to error, more than 4 digits
                    dec     DCount  
                    suba    #$30    
                    ldab    #1       
                    mul           
                    addd    Hex
                    std     Hex                     
                    inx                
                    ldy     Hex          ; load hex buffer into Y
               
                    rts

hconverror          ldaa    #$01         ; error occured, set A to #1
                    staa    err
                    rts

;*********************end of ad2h*********************            

;*********************h2adC****************************
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
h2adC            
                    clr   HCount    
                    cpd   #$00      ; check for $0
                    lbeq  H0C
                    ldy   #DecBuffC
                
HLoopC              ldx   #10       ; will be dividing by #10 using x reg
                    idiv               
                  
                    stab  1,Y+      ; get first digit
                    inc   HCount    ; first divison
                    tfr   X,D       
                    tstb            ; check remainder for zero
                    bne   HLoopC      
                
                
reverseC            ldaa  HCount    
                    cmpa  #$05      ; check number of remainders
                    beq   H4C
                    cmpa  #$04
                    beq   H3C        ; branch
                    cmpa  #$03
                    lbeq  H2C
                    cmpa  #$02
                    lbeq  H1C
                                ; if there is only one, convert and return
                    ldx   #DecBuffC  
                    ldaa  0,X       
                    adda  #$30      
                    staa  1,X+      ; store conversion
                    ldaa  #$00      ; load/store NULL
                    staa  1,X+      
                    rts


H4C                 ldx   #DecBuffC  ; H3,H2,H1 follow the same algorithm, just one less place
                    ldaa  1,X+      ; load the 1s place remainder
                    inx
                    inx
                    inx
                    ldab  0,X       ; load the 10000s place remainder
                    staa  0,X       
                    ldx   #DecBuffC
                    stab  0,X       
                
                    inx             ; move to 1000s place
                    ldaa  1,X+      ; load current 1000s place
                    inx             ; skip current 100s place
                    ldab  0,X       
                    staa  0,X       
                    ldx   #DecBuffC  ; reload buff
                    inx             ; move to 1000s place
                    stab  0,X       
                
                    ldx   #DecBuffC  
                    ldaa  0,X       ; load 10000s place
                    adda  #$30      ; add ascii bias
                    staa  1,X+      ; store converted 10000s place
                    ldaa  0,X       ; load 1000s place
                    adda  #$30      ; add ascii
                    staa  1,X+      ; store converted 1000s place
                    ldaa  0,X       ; load 100s place
                    adda  #$30      ; add ascii bias
                    staa  1,X+      ; store converted 100s place
                    ldaa  0,X       ; load 10s place
                    adda  #$30
                    staa  1,X+      ; store converted 10s place
                    ldaa  0,X       ; load 1s place
                    adda  #$30      
                    staa  1,X+      ; store converted 1s place
                    ldaa  #$00      ; load NULL
                    staa  1,X+      
                    rts


H3C                 ldx   #DecBuffC
                    ldaa  1,X+      ; load the 1s place remainder
                    inx
                    inx
                    ldab  0,X       ; load the 1000s place remainder
                    staa  0,X       
                    ldx   #DecBuffC
                    stab  0,X       ; put the 1000s place into the 1000s place
                
                    inx             ; move to 100s place
                    ldaa  1,X+      ; load current 100s place
                    ldab  0,X       ; load current 10s place
                    staa  0,X       
                    ldx   #DecBuffC  
                    inx             
                    stab  0,X       
                
                    ldx   #DecBuffC  
                    ldaa  0,X       ; load 1000s place
                    adda  #$30      ; add ascii bias
                    staa  1,X+      ; store converted 1000s place
                    ldaa  0,X       ; load 100s place
                    adda  #$30      ; add ascii bias
                    staa  1,X+      ; store converted 100s place
                    ldaa  0,X       ; load 10s place
                    adda  #$30
                    staa  1,X+      ; store converted 10s place
                    ldaa  0,X       ; load 1s place
                    adda  #$30      
                    staa  1,X+      ; store converted 1s place
                    ldaa  #$00      
                    staa  1,X+      
                    rts


H2C                 ldx   #DecBuffC
                    ldaa  1,X+      ; load the 1s place remainder
                    inx
                    ldab  0,X       ; load the 100s place remainder
                    staa  0,X       
                    ldx   #DecBuffC
                    stab  0,X       
                
                    ldaa  0,X       ; load 100s place
                    adda  #$30      ; add ascii bias
                    staa  1,X+      ; store converted 100s place
                    ldaa  0,X       ; load 10s placeA
                    adda  #$30
                    staa  1,X+      ; store converted 10s place
                    ldaa  0,X       ; load 1s place
                    adda  #$30      
                    staa  1,X+      ; store converted 1s place
                    ldaa  #$00      
                    staa  1,X+      
                    rts
                

H1C                 ldx   #DecBuffC
                    ldaa  1,X+      ; load the 1s place remainder
                    ldab  0,X       ; load the 10s place remainder
                    staa  0,X       
                    ldx   #DecBuffC  
                    stab  0,X       
                
                    ldaa  0,X       ; load 10s place
                    adda  #$30      ; add ascii bias
                    staa  1,X+      ; store converted 10s place
                    ldaa  0,X       ; load 1s place
                    adda  #$30
                    staa  1,X+      ; store converted 1s place
                    ldaa  #$00      
                    staa  1,X+      
                    rts

               
H0C                 ldx   #DecBuffC  
                    ldaa  #$30      
                    staa  1,X+      
                    ldaa  #$00      
                    staa  1,X+               
                    rts

;******************end of h2adC************************

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
h2ad                ; Entry point for converting a binary number to ASCII decimal representation
                    clr   HCount          ; Clear the HCount register to start counting digits
                    cpd   #$00            ; Compare the input value with zero
                    lbeq  H0              ; If the input is zero, branch to handler H0
                    ldy   #DecBuff         ; Load the address of the decimal buffer into Y register

HLoop               ; Loop to divide the number by 10 and extract each digit
                    ldx   #10             ; Load X with 10 to perform division by 10
                    idiv                  ; Divide D by X; quotient in D and remainder in B
                    stab  1,Y+            ; Store the remainder (current digit) into the buffer and increment Y
                    inc   HCount          ; Increment HCount to keep track of the number of digits
                    tfr   X,D             ; Transfer the quotient from X to D for the next division
                    tstb                  ; Test if the remainder is zero
                    bne   HLoop           ; If remainder is not zero, continue looping

reverse             ; Reverse the digits and convert them to ASCII
                    ldaa  HCount          ; Load the number of digits counted
                    cmpa  #$05            ; Compare with 5 to determine the number of digits
                    beq   H4              ; If equal to 5, branch to handler H4
                    cmpa  #$04            ; Compare with 4 digits
                    beq   H3              ; If equal to 4, branch to handler H3
                    cmpa  #$03            ; Compare with 3 digits
                    lbeq  H2              ; If equal to 3, branch to handler H2
                    cmpa  #$02            ; Compare with 2 digits
                    lbeq  H1              ; If equal to 2, branch to handler H1
                                        ; If there is only one digit, convert it to ASCII and return
                    ldx   #DecBuff         ; Load the address of the decimal buffer
                    ldaa  0,X              ; Load the single digit from the buffer
                    adda  #$30             ; Add ASCII offset to convert to ASCII character
                    staa  1,X+             ; Store the ASCII character back into the buffer and increment Y
                    ldaa  #$00             ; Load NULL terminator
                    staa  1,X+             ; Store NULL terminator in the buffer
                    rts                     ; Return from subroutine

H4                  ; Handler for 5-digit numbers
                    ldx   #DecBuff         ; Load the address of the decimal buffer
                    ldaa  1,X+             ; Load the 1's place digit
                    inx                     ; Increment X to skip to the next digit
                    inx
                    inx
                    ldab  0,X              ; Load the 10,000's place digit
                    staa  0,X              ; Store it back (possibly for rearrangement)
                    ldx   #DecBuff         ; Reload the decimal buffer address
                    stab  0,X              ; Store the digit in the buffer

                    inx                     ; Move to the 1,000's place
                    ldaa  1,X+             ; Load the current 1,000's place digit
                    inx                     ; Increment X to skip the 100's place
                    ldab  0,X              ; Load the 100's place digit
                    staa  0,X              ; Store it back
                    ldx   #DecBuff         ; Reload the decimal buffer address
                    inx                     ; Move to the 1,000's place
                    stab  0,X              ; Store the digit in the buffer

                    ldx   #DecBuff         ; Load the decimal buffer address
                    ldaa  0,X              ; Load the 10,000's place digit
                    adda  #$30             ; Convert to ASCII by adding ASCII offset
                    staa  1,X+             ; Store the ASCII character and increment Y
                    ldaa  0,X              ; Load the 1,000's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  0,X              ; Load the 100's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  0,X              ; Load the 10's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  0,X              ; Load the 1's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  #$00             ; Load NULL terminator
                    staa  1,X+             ; Store NULL terminator
                    rts                     ; Return from subroutine

H3                  ; Handler for 4-digit numbers
                    ldx   #DecBuff         ; Load the decimal buffer address
                    ldaa  1,X+             ; Load the 1's place digit
                    inx                     ; Increment X to the next digit
                    inx
                    ldab  0,X              ; Load the 1,000's place digit
                    staa  0,X              ; Store it back
                    ldx   #DecBuff         ; Reload the decimal buffer address
                    stab  0,X              ; Store the 1,000's place digit

                    inx                     ; Move to the 100's place
                    ldaa  1,X+             ; Load the current 100's place digit
                    ldab  0,X              ; Load the 10's place digit
                    staa  0,X              ; Store it back
                    ldx   #DecBuff         ; Reload the decimal buffer address
                    inx                     ; Increment X
                    stab  0,X              ; Store the 100's place digit

                    ldx   #DecBuff         ; Load the decimal buffer address
                    ldaa  0,X              ; Load the 1,000's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  0,X              ; Load the 100's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  0,X              ; Load the 10's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  0,X              ; Load the 1's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  #$00             ; Load NULL terminator
                    staa  1,X+             ; Store NULL terminator
                    rts                     ; Return from subroutine

H2                  ; Handler for 3-digit numbers
                    ldx   #DecBuff         ; Load the decimal buffer address
                    ldaa  1,X+             ; Load the 1's place digit
                    inx                     ; Increment X to the next digit
                    ldab  0,X              ; Load the 100's place digit
                    staa  0,X              ; Store it back
                    ldx   #DecBuff         ; Reload the decimal buffer address
                    stab  0,X              ; Store the 100's place digit

                    ldaa  0,X              ; Load the 100's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  0,X              ; Load the 10's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  0,X              ; Load the 1's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  #$00             ; Load NULL terminator
                    staa  1,X+             ; Store NULL terminator
                    rts                     ; Return from subroutine

H1                  ; Handler for 2-digit numbers
                    ldx   #DecBuff         ; Load the decimal buffer address
                    ldaa  1,X+             ; Load the 1's place digit
                    ldab  0,X              ; Load the 10's place digit
                    staa  0,X              ; Store it back
                    ldx   #DecBuff         ; Reload the decimal buffer address
                    stab  0,X              ; Store the 10's place digit

                    ldaa  0,X              ; Load the 10's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  0,X              ; Load the 1's place digit
                    adda  #$30             ; Convert to ASCII
                    staa  1,X+             ; Store the ASCII character
                    ldaa  #$00             ; Load NULL terminator
                    staa  1,X+             ; Store NULL terminator
                    rts                     ; Return from subroutine

H0                  ; Handler for zero input
                    ldx   #DecBuff         ; Load the decimal buffer address
                    ldaa  #$30             ; Load ASCII character '0'
                    staa  1,X+             ; Store '0' in the buffer and increment Y
                    ldaa  #$00             ; Load NULL terminator
                    staa  1,X+             ; Store NULL terminator in the buffer
                    rts                     ; Return from subroutine
;******************end of h2ad************************



;********************parse****************************
;* Program: parse input into Num1 and Num2
;* Input: 2 ASCII numbers with opcode in between 
;* 
;* Output: Num1 and Num2  
;* 
;* Registers modified: X,Y,A,B,CCR
;*****************************************************
parse            ; Entry point for parsing the command input
                    ldx     #indent          ; Load the address of the indentation message
                    jsr     printmsg         ; Call subroutine to print the indentation message
                    ldx     #CmdBuff         ; Load the address of the command buffer (input from terminal)
                    ldy     #Num1ASCII       ; Load the address of the first number's ASCII buffer
                    clrb                     ; Clear register B to initialize digit count
                
Num1Loop        ; Loop to parse the first number (Num1) from the input
                    ldaa    1,X+             ; Load the next character from the command buffer
                
                    cmpa    #$39             ; Compare with ASCII '9' to check for valid digit
                    bhi     parseErr         ; If above '9', branch to parse error
                
                    cmpa    #$30             ; Compare with ASCII '0' to check if it's an operator
                    blo     OpChk            ; If below '0', branch to operator check
                
                    cmpb    #$04             ; Check if the digit count exceeds 4
                    bhi     parseErr         ; If more than 4 digits, branch to parse error
                
                    staa    1,Y+             ; Store the valid digit in the Num1 buffer and increment Y
                    incb                     ; Increment digit counter in register B
                    bra     Num1Loop         ; Branch always to continue parsing Num1
                
OpChk           ; Operator check after parsing Num1
                    cmpb    #$04             ; Ensure Num1 does not exceed four digits
                    bhi     parseErr         ; If more than 4 digits, branch to parse error
                    tstb                     ; Test if at least one digit was parsed
                    beq     parseErr         ; If no digits, branch to parse error
                
                    stab    DCount1          ; Store the count of digits in DCount1
                    clrb                     ; Clear register B for next digit count
                    stab    0,Y              ; Initialize the next buffer position to zero
                
AddChk          ; Check if the operator is addition
                    cmpa    #$2B             ; Compare with ASCII '+' for addition
                    bne     SubChk           ; If not '+', branch to subtraction check
                    ldaa    #$00             ; Load opcode for addition
                    staa    Opcode            ; Store the addition opcode
                    bra     Numb2            ; Branch to parse the second number
                
SubChk          ; Check if the operator is subtraction
                    cmpa    #$2D             ; Compare with ASCII '-' for subtraction
                    bne     MulChk           ; If not '-', branch to multiplication check
                    ldaa    #$01             ; Load opcode for subtraction
                    staa    Opcode            ; Store the subtraction opcode
                    bra     Numb2            ; Branch to parse the second number
                
MulChk          ; Check if the operator is multiplication
                    cmpa    #$2A             ; Compare with ASCII '*' for multiplication
                    bne     DivChk           ; If not '*', branch to division check
                    ldaa    #$02             ; Load opcode for multiplication
                    staa    Opcode            ; Store the multiplication opcode
                    bra     Numb2            ; Branch to parse the second number
                
DivChk          ; Check if the operator is division
                    cmpa    #$2F             ; Compare with ASCII '/' for division
                    bne     parseErr         ; If not '/', branch to parse error
                    ldaa    #$03             ; Load opcode for division
                    staa    Opcode            ; Store the division opcode
                                
Numb2           ; Initialize parsing of the second number (Num2)
                    ldy     #Num2ASCII       ; Load the address of the second number's ASCII buffer
                
Num2Loop        ; Loop to parse the second number (Num2) from the input
                    ldaa    1,X+             ; Load the next character from the command buffer
                
                    cmpa    #CR              ; Compare with Carriage Return to detect end of input
                    beq     Return           ; If CR is detected, branch to return
                
                    cmpa    #$39             ; Compare with ASCII '9' to check for valid digit
                    bhi     parseErr         ; If above '9', branch to parse error
                    cmpa    #$30             ; Compare with ASCII '0' to ensure it's a digit
                    blo     parseErr         ; If below '0', branch to parse error
                
                    cmpb    #$04             ; Check if the digit count exceeds 4 for Num2
                    bhi     parseErr         ; If more than 4 digits, branch to parse error
                
                    staa    1,Y+             ; Store the valid digit in the Num2 buffer and increment Y
                    incb                     ; Increment digit counter in register B
                    bra     Num2Loop         ; Branch always to continue parsing Num2
                
Return          ; Finalize parsing after successfully reading both numbers
                    cmpb    #$04             ; Ensure Num2 does not exceed four digits
                    bhi     parseErr         ; If more than 4 digits, branch to parse error
                    tstb                     ; Test if at least one digit was parsed for Num2
                    beq     parseErr         ; If no digits, branch to parse error
                
                    stab    DCount2          ; Store the count of digits in DCount2
                    clrb                     ; Clear register B
                    stab    0,Y              ; Initialize the next buffer position to zero
    
                    rts                      ; Return from subroutine
                
parseErr        ; Error handling routine for parsing errors
                    ldaa    #$01             ; Load error code
                    staa    err              ; Store the error code in the error variable
                    rts                      ; Return from subroutine
;***************end of parse*****************************


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
NULL                equ     $00                ; Define NULL as hexadecimal 00

printmsg            psha                       ; Push Accumulator A onto stack to save its state
                    pshx                       ; Push Index Register X onto stack to save its state

printmsgloop        ldaa    1,X+               ; Load the next ASCII character from the string pointed by X and increment X
                                           ; X now points to the next character in the string
                    cmpa    #NULL              ; Compare the loaded character with NULL to check for end of string
                    beq     printmsgdone       ; If NULL is encountered, branch to printmsgdone to finish
                    bsr     putchar            ; If not NULL, call putchar subroutine to print the character
                    bra     printmsgloop       ; Branch always back to printmsgloop to process the next character

printmsgdone        pulx                       ; Pull the original value of Index Register X from the stack to restore it
                    pula                       ; Pull the original value of Accumulator A from the stack to restore it
                    rts                        ; Return from subroutine
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
putchar         ; Subroutine to send a single character via the serial interface
                    brclr SCISR1,#%10000000,putchar   ; Check if the Transmit Buffer Empty flag (bit 7) is clear
                                                      ; If not empty, branch back to 'putchar' to wait
                    staa  SCIDRL                      ; Store the character in the Serial Data Register Low (SCIDRL) to initiate transmission
                    rts                               ; Return from subroutine
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
getchar         ; Subroutine to receive a single character via the serial interface
                    brclr SCISR1,#%00100000,getchar7   ; Check if Receive Buffer Full flag (bit 5) is clear
                                                    ; If not full, branch to 'getchar7' to handle no input
                    ldaa  SCIDRL                      ; Load the received character from the Serial Data Register Low (SCIDRL) into Accumulator A
                    rts                               ; Return from subroutine

getchar7            clra                              ; Clear Accumulator A (set to 0) if no character was received
                    rts                               ; Return from subroutine
;****************end of getchar**************** 

;****************nextline**********************
nextline        ; Subroutine to move the cursor to the beginning of the next line
                    psha                    ; Push Accumulator A onto the stack to save its state

                    ldaa  #CR                ; Load Accumulator A with Carriage Return (CR) character
                    jsr   putchar            ; Call 'putchar' subroutine to send CR, moving cursor to the beginning of the line

                    ldaa  #LF                ; Load Accumulator A with Line Feed (LF) character
                    jsr   putchar            ; Call 'putchar' subroutine to send LF, moving cursor to the next line

                    pula                    ; Pull Accumulator A from the stack to restore its original state
                    rts                     ; Return from subroutine
;****************end of nextline***************


;***************echoPrint**********************
;* Program: makes calls to putchar but ends when CR is passed to it
;* Input:   ASCII char in A
;* Output:  1 char is displayed on the terminal window - echo print
;* Registers modified: CCR
;* Algorithm: if(A==CR) return; else print(A);
;**********************************************
echoPrint        ; Subroutine to echo characters until a Carriage Return (CR) is encountered
                    cmpa       #CR           ; Compare Accumulator A with Carriage Return (CR) character
                    beq        retEcho      ; If Accumulator A equals CR, branch to retEcho to end echoing
                    
                    jsr        putchar      ; If not CR, call 'putchar' subroutine to echo the character
                    
retEcho             rts                       ; Return from subroutine
;***************end of echoPrint***************


;***********clrBuff****************************
;* Program: Clear out command buff
;* Input:   
;* Output:  buffer is filled with zeros
;* 
;* Registers modified: X,A,B,CCR
;* Algorithm: set each byte (11 total) in CmdBuff to NULL
;************************************************
clrBuff         ; Subroutine to clear a buffer by setting allocated bytes to zero
                ldab    #$0B        ; Load register B with the number of bytes to clear (11 bytes)

clrLoop         ; Start of the buffer clearing loop
                cmpb    #$00        ; Compare register B with zero to check if all bytes have been cleared
                beq     clrReturn    ; If B is zero, all bytes are cleared; branch to clrReturn
                
                ldaa    #$00        ; Load Accumulator A with zero to clear the current byte
                staa    1,X+        ; Store zero to the memory location pointed by (X + 1) and increment X
                decb                ; Decrement register B by one to track remaining bytes
                bra     clrLoop      ; Branch always to clrLoop to continue clearing the next byte

clrReturn       rts                 ; Return from subroutine after buffer is cleared
;***********end of clrBuff*****************************

;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip
msg1        DC.B    'Welcome to the 24 hour clock and Calculator!', $00  ; Welcome message displayed at program start
msg3        DC.B    'Clock and Calculator stopped and Typewrite program started.', $00  ; Message displayed when the Clock and Calculator are stopped and TypeWriter program starts
msg2        DC.B    'You may type below:', $00                        ; Prompt indicating the user can begin typing input
msg4        DC.B    '        Error> Invalid input', $00              ; Error message for invalid input
errmsg2     DC.B    '        Error> Overflow', $00                    ; Error message for arithmetic overflow

prompt      DC.B    'Tcalc> ', $00                                   ; Prompt displayed to indicate readiness for calculator input
semi        DC.B    ':', $00                                         ; Colon character, possibly used as a separator in inputs
cmdmsg      DC.B    '                      CMD> ', $00               ; Command prompt message with indentation
zero        DC.B    '0', $00                                         ; Character representing zero
sspace      DC.B    '    ', $00                                       ; String of four spaces for indentation or formatting

indent      DC.B    '        ', $00                                   ; String of eight spaces for indentation
equal       DC.B    '=', $00                                         ; Equals sign character used in expressions
minus       DC.B    '-', $00                                         ; Minus sign character used for subtraction
multiply    DC.B    '*', $00                                         ; Asterisk character used for multiplication
divide      DC.B    '/', $00                                         ; Forward slash character used for division
add         DC.B    '+', $00                                         ; Plus sign character used for addition

menu1       DC.B    'Input the letter t followed by a time in the format [hh:mm:ss] to set the time.', $00  ; Instruction for setting the time
menu2       DC.B    'Input the letter s to display seconds.', $00 ; Instruction for displaying seconds
menu3       DC.B    'Input the letter m to display minutes.', $00 ; Instruction for displaying minutes
menu4       DC.B    'Input the letter h to display hours.', $00   ; Instruction for displaying hours
menu5       DC.B    'Quit to the typewriter program by pressing the letter q.', $00 ; Instruction for quitting to the typewriter program
menu6       DC.B    'For example: t 16:34:43', $00                   ; Example input format for setting the time
menu7       DC.B    'The Calculator can perform +,-,*,/ operations.', $00 ; Description of calculator capabilities

                END               ; Marks the end of the assembly source file
                                  ; Lines below are ignored - not assembled/compiled
