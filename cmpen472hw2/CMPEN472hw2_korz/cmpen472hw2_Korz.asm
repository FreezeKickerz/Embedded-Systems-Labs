************************************************************************
*
* Title:        LED Light Blinking
*
* Objective:    CMPEN472 Homework 2 in-class-room demonstration
*               program
*
*
* Revision:     V3.2 for Codellarrior 5.2 Debugger Simulation
*
* Date:         9/10/24
*
*
* Programmer:   Tyler Korz
*
* Company:      The Pennsylvania State University
*               Department of Computer Science and Engineering
*
* Algorithm:    Simple Parallel I/O use and time delay-loop demo
*
* Register use: A: LED Light on/off state and Switch 1 on/off state
*               X, Y: Delay l oop counters
*
* Memory use:   RAM Locations from $3000 for data,
*               RAM Locations from $3100 for program
*
* Input:        Parameters hard-coded in the program - PORTS
*               Switch 1 at PORTS bit 0
*               Switch 2 at PORTS bit 1
*               Switch 3 at PORTS bit 2
*               Switch 4 at PORTS bit 3
*
* Output:          LED 1 at PORTS bit 4
*                  LED 2 at PORTS bit 5
*                  LED 3 at PORTS bit 6
*                  LED 4 at PORTS bit 7
*
* Observation:  This is a program that blinks LEDs and blinking period can
*               be changed with the delay loop counter value.
*
* Note:         All Homework programs MUST have comments similar
*               to this Homework 2 program. So, please use those
*               comment format for all your subsequent CMPEN472
*               Homework programs.
*
*               Adding more explanations and comments help you and
*               others to understand your program later.
*
* Comments:     This program is developed and simulated using CodeWorrior
*               development software and targeted for Axion
*               Manufacturing's CSM-12C128 board running at 24MHz.
*
***********************************************************************
* Parameter Declearation Section
*
* Export Symbols
            XDEF        pstart        ; export 'pstart' symbol
            ABSENTRY    pstart        ; for assembly entry point

* Symbols and Macros
PORTA       EQU         $0000         ; i/o port A addresses
DDRA        EQU         $0002           
PORTB       EQU         $0001         ; i/o port B addresses
DDRB        EQU         $0003         

***********************************************************************
* Data Section: address used [ $3000 to $30FF ] RAM memory
*
            ORG         $3000         ; Reserved. RAM memory starting address
                                      ;   for Data for CMPEN 472 class
Counter1    DC.W        $004B         ; X register count number for time delay                
                                      ;   inner loop for msec
Counter2    DC.W        $0064         ; Y register count number for time delay
                                      ;   outer loop for sec
                                      
                                      ; Remaining data memory space for stack,
                                      ;   up to program memory start
*
***********************************************************************    
* Program Section: address used [ $3100 to $3FFF ] RAM memory    
*
            ORG         $3100         ; Program start address, in RAM
pstart      LDS         #$3100        ; initialize the stack pointer

            LDAA        #%11111111    ; LED 1,2,3,4 at PORTB bit 4,5,6,7 FOR Simulation only
            STAA        DDRB          ; set PORTB bit 4,5,6,7 as output
            
            LDAA        #%00000000
            STAA        PORTB         ; Turn off LED 1,2,3,4 (all bits in PORTB, for simulation

mainLoop            
            
           BSET         PORTB,%10000000    ; Turn ON LED 4 at PORTB bit 7
           BCLR         PORTB,%00010000    ; Turn OFF LED 1 at PORTB bit 4
           JSR          delay1sec          ; Wait for 1 second
            
           BCLR         PORTB,%10000000    ; Turn OFF LED 4 at PORTB bit 7
           BSET         PORTB,%00010000    ; Turn ONN LED 1 at PORTB bit 4
           JSR          delay1sec          ; Wait for 1 second
            
           LDAA         PORTB
           ANDA         #%00000001         ; read switch 1 at PORTB bit 0
           BNE          sw1pushed          ; check to see if it is pushed    

                                                 
sw1notpsh  BCLR         PORTB, %11110000   ; turn OFF LEDs
           BRA          mainLoop    
                                      
sw1pushed  BCLR         PORTB, %11110000   ; turn OFF LEDs
           BSET         PORTB,%10000000    ; Turn ON LED 4 at PORTB bit 7
           BCLR         PORTB,%01000000    ; Turn OFF LED 3 at PORTB bit 6
           BCLR         PORTB,%00100000    ; Turn OFF LED 2 at PORTB bit 5                        
           BCLR         PORTB,%00010000    ; Turn OFF LED 1 at PORTB bit 4
           JSR          delay1sec          ; Wait for 1 second
         
           BCLR         PORTB,%10000000    ; Turn OFF LED 4 at PORTB bit 7
           BSET         PORTB,%01000000    ; Turn ON LED 3 at PORTB bit 6
           BCLR         PORTB,%00100000    ; Turn OFF LED 2 at PORTB bit 5
           BCLR         PORTB,%00010000    ; Turn OFF LED 1 at PORTB bit 4
           JSR          delay1sec          ; Wait for 1 second
           
           BCLR         PORTB,%10000000    ; Turn OFF LED 4 at PORTB bit 7
           BCLR         PORTB,%01000000    ; Turn OFF LED 3 at PORTB bit 6
           BSET         PORTB,%00100000    ; Turn ON LED 2 at PORTB bit 5
           BCLR         PORTB,%00010000    ; Turn OFF LED 1 at PORTB bit 4
           JSR          delay1sec          ; Wait for 1 second
            
           BCLR         PORTB,%10000000    ; Turn OFF LED 4 at PORTB bit 7
           BCLR         PORTB,%01000000    ; Turn OFF LED 3 at PORTB bit 6
           BCLR         PORTB,%00100000    ; Turn OFF LED 2 at PORTB bit 5
           BSET         PORTB,%00010000    ; Turn ON LED 1 at PORTB bit 4
           JSR          delay1sec          ; Wait for 1 second
           
           LDAA         PORTB
           ANDA         #%00000001         ; read switch 1 at PORTB bit 0                                                                                                                                        
           BEQ          sw1notpsh          ; check to see if it is not pushed              
           
           JMP          sw1pushed          ;keep looping
***********************************************************************                
* Subroutine Section: address used [ $3100 to $3FFF ] RAM memory            
*

;**************************************************************            
; delaylsec subroutine
; 
; Please be sure to include your comments here !            
;  
          
delay1sec
           PSHY                   ; save Y
           LDY    Counter2        ; long delay by
           
dly1Loop   JSR    delayMS         ; total time delay = Y * delayMS
           DEY
           BNE    dly1Loop
           
           PULY                   ; restore Y
           RTS                    ; return   
                    
;**************************************************************
; delayMS subroutine
;
; This subroutine cause few msec. delay
;
; Input : a 16bit count number in 'Counter1'
; Output : time delay, cpu cycle wasted
; Registers in use : X register, as counter
; Memory locations in use : a 16bit input number at 'Counter1'
;
; Comments : one can add more NOP ins tructions to lengthen
;            the delay time.

delayMS
           PSHX                   ; save X
           LDX    Counter1        ; short delay

dlyMSLoop  NOP                    ; total time delay = X * NOP
           DEX
           BNE    dlyMSLoop
                                  
           PULX                   ; restore X
           RTS                    ; return

*            
* Add any subroutines here          
*           
            
           end                    ;last line of a file
           