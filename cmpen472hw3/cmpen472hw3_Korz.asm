***********************************************************************
*
* Title:          LED Light ON/OFF and Switch ON/ OFF
*
* Objective:      CMPEN 472 Homework 3
*
*
* Revision:       V3.1 for CodeWarrior 5.2 Debugger Simulation
*
* Date:           Sep. 7, 2020
*
* Programmer:     Tyler Korz
*
* Company:        The Pennslyvania State University
*                 Department of Computer Science and Engineering
*
* Program:        LED 4 Blink every 1 second
*                 ON for 0.2 second, OFF for 0.8 second when switch 1 is not pressed
*                 ON for 0.8 second, OFF for 0.2 second when switch 1 is pressed
*
* Note:       
*                 On CSM-12C128 board,
*                 Switch 1 i s at PORTB bit 0, and
*                 LED 4 is at PORTB bit 7.
*                 This program is developed and simulated using
*                 CodeWorrior 5.2 only, with switch simulation problem.
*                 So, one MUST set "switch 1" at PORTB bit 0 as an
*                 OUTPUT - not an INPUT.
*                 (If running on CSM-12C128 board, PORTB bit 0 must be set to INPUT).
*
* Algorithm:      Simple Parallel I/O use and time delay-loop demo
*
* Register use:   A: LED Light on/off state and Switch on/off state
*                 X,Y: Delay loop counters
*
* Memory Use:     RAM Locations from $3000 for data,
*                 RAM Locations from $3100 for program
*
* Input:          Parameters hard-coded in the program - PORTB
*                 Switch 1 at PORTB bit 0
*                   (set this bit as an output for simulation only - and add Switch)
*                 Switch 2 at PORTB bit 1
*                 Switch 3 at PORTB bit 2
*                 Switch 4 at PORTB bit 3
*
* Output:           LED 1 at PORTB bit 4
*                   LED 2 at PORTB bit 5
*                   LED 3 at PORTB bit 6
*                   LED 4 at PORTB bit 7
*
* Observation:    This is a program that blinks LEDs and blinking period can
*                 be changed with the delay loop counter value.
*
***********************************************************************
* Parameter Declearation Section
*
* Export Symbols
            XDEF        pstart        ; export 'pstart' symbol 
            ABSENTRY    pstart        ; for assembly entry point

* Symbols and Macros
PORTA       EQU         $0000         ; i/o port A addresses
PORTB       EQU         $0001         ; i/o port B addresses
DDRA        EQU         $0002         
DDRB        EQU         $0003

***********************************************************************
* Data Section: address used [ $3000 to $30FF ] RAM memory
*
            ORG         $3000         ; Reserved RAM memory starting address
                                      ;   for Data for CMPEN 472 class
Counter1    DC.W        $003B         ; X register count number for time delay                     
                                      ;   inner loop for msec
Counter2    DC.W        $000C         ; Y register count number for time delay
                                      ;   outer loop for sec
* Number $008F and $000C will result 1/10 second delay
* Number $003B and $000C will be 10 usec                                      
                                      ; Remaining data memory space for stack,
                                      ;   up to program memory start    
*                                      
***********************************************************************
* Program Section: address used [ $3100 to $3FFF ] RAM memory
*
            ORG         $3100         ; Program start address, in RAM
pstart      LDS         #$3100        ; initialize the stack pointer

            LDAA        #%11110001    ; LED 1,2,3,4 at PORTB bit 4,5,6,7
            STAA        DDRB          ; set PORTB bit 4,5,6,7 as output
                                      ; plus the bit 0 for switch 1
                                      
                                      
            LDAA        #%00000000
            STAA        PORTB         ; clear all bits of PORTB         

mainLoop                                      
          BSET        PORTB,%00010000   ; turn ON LED 1 at PORTB bit 4
          BCLR        PORTB,%00100000   ; turn OFF LED 2 at PORTB bit 5
          BCLR        PORTB,%10000000   ; turn OFF LED 4 at PORTB 7 bit 
          LDAA        PORTB             ; check bit 0 of PORTB, switch 1
          ANDA        #%00000001        ; if 0, run switch not pushed loop
          BNE         sw1pushed         ; if 1, run switch pushed loop

;Switch 1 not pushed, use 4 and 96

sw1notpsh BSET        PORTB,%01000000   ; turn ON LED 3 at PORTB bit 6
          LDAA        #$04              ; counter ONN to 4

          
loop4     JSR         delay10usec       ; delay our 10usec loop
          DECA                          ; updates counter above
          BGT         loop4             ; loop until 4
          BCLR        PORTB,%01000000   ; turn OFF LED 3 at PORTB bit 6
          LDAA        #$60              ; counter OFF to 96
          
loop96    JSR         delay10usec       ; delay our 10usec loop
          DECA                          ; updates counter above
          BGT         loop96            ; loop until 96   
          BRA         mainLoop          ; loop forever!
          
          
          

;Switch 1 pushed, use 24 and 76
          
sw1pushed BSET        PORTB,%01000000   ; turn ON LED 3 at PORTB bit 6
          LDAA        #$18              ; counter ONN to 24
          
loop24    JSR         delay10usec       ; delay our 10usec loop
          DECA                          ; updates counter above
          BGT         loop24            ; loop until 24
          BCLR        PORTB,%01000000   ; turn OFF LED 3 at PORTB bit 6
          LDAA        #$4C              ; counter OFF to 76
          
loop76    JSR         delay10usec       ; delay our 10usec loop
          DECA                          ; updates counter above
          BGT         loop76            ; loop until 76 
          
          BRA         mainLoop          ; loop forever!          


;Sample HW3
;p20LED4    
;            JSR         LED4on        ; 20% light level (duty cycle)
;            JSR         LED4on
;            JSR         LED4off
;            JSR         LED4off
;            JSR         LED4off
;            JSR         LED4off
;            JSR         LED4off
;            JSR         LED4off
;            JSR         LED4off
;            JSR         LED4off
;            BRA         mainLoop      ; check switch, loop forever!
;
;p80LED4            
;            JSR         LED4on        ; 80% light level (duty cycle)
;            JSR         LED4on
;            JSR         LED4on
;            JSR         LED4on
;            JSR         LED4on
;            JSR         LED4on
;            JSR         LED4on
;            JSR         LED4on
;            JSR         LED4off
;            JSR         LED4off
;            BRA         mainLoop      ; check switch, loop forever!


***********************************************************************
* Subroutine Section: address used [ $3100 to $3FFF ] RAM memory
;
;
;**********************************************************************
; LED4 turn-on and turn-off subroutines
;
;LED4off
;            PSHA                      ; save A register
;            LDAA        #%01111111    ; Turn off LED 4 at PORTB bit 7
;            ANDA        PORTB         
;            STAA        PORTB
;            JSR         delay1sec     ; Wait for 1 second
;            PULA                      ; restore A register
;            RTS
;
;
;LED4on
;            PSHA                      ; save A register
;            LDAA        #%10000000    ; Turn on LED 4 at PORTB bit 7
;            ORAA        PORTB         
;            STAA        PORTB
;            JSR         delay1sec     ; Wait for 1 second
;            PULA                      ; restore A register
;            RTS
;
;
;
;**********************************************************************
; delay1sec subroutine
;
;
;

;delay1sec
;            PSHY                      ; save Y
;            LDY         Counter2      ; long delay by
;            
;dly1Loop    JSR         delayMS       ; total time delay = Y * delayMS
;            DEY
;            BNE         dly1Loop
;            
;            PULY                      ; restore Y
;            RTS                       ; return
;
;**********************************************************************
; delayMS subroutine
;
; This subroutine cause few msec. delay
;
; Input: a 16bit count number in 'Counter1'
; Output: time delay, cpu cycle wasted
; Registers in use: X register, as counter
; Memory locations in use: a 16bit input number at 'Counter1'
;
; Comments: one can add more NOP instructions to lengthen
;           the delay time.
;
;delayMS
;            PSHX                      ; save X
;            LDX         Counter1      ; short delay
;            
;dlyMSLoop   NOP                       ; total time delay = X * NOP
;            DEX         
;            BNE         dlyMSLoop
;            
;            PULX                      ; restore X
;            RTS                       ; return
     
;**********************************************************************
; delay10us subroutine
;
; This subroutine will cause a 10 usec. delay
;
; Input: a 16 bit count number in 'Counter3'
; Output: time delay, CPU cycle waisted
; Register in use: X register, as counter
; Memory Locations in use: a 16 bit input number at 'Counter3'

delay10usec 
          PSHX                        ; save X
          LDX         Counter1        ; long delay by
          
dlyUSLoop 
          DEX
          BNE         dlyUSLoop
          
          PULX                        ; restore X
          RTS                         ; return    



          
          end                         ;last line of a file