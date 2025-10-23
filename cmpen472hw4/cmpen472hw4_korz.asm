************************************************************************
* Title:          Dimming the LED
*
* Objective:      CMPEN 472 Homework 4
*
*
* Revision:       V3.1 for CodeWarrior 5.2 Debugger Simulation
*
* Date:           Sep. 20, 2024
*
* Programmer:     Tyler Korz
*
* Company:        The Pennslyvania State University
*                 Department of Computer Science and Engineering
*
*
*
* Algorithm:      Simple Parallel I/O use and time delay-loop demo
*
* Register use: A accumulator
*               B accumulator
*               X register
*               Y register  
*
*
* Memory Use:     RAM Locations from $3000 for data,
*                 RAM Locations from $3100 for program
*
* Input:          Parameters hard-coded in the program - PORTB
*
*
* Output:           LED 1 at PORTB bit 4
*                   LED 2 at PORTB bit 5
*                   LED 3 at PORTB bit 6
*                   LED 4 at PORTB bit 7
*
* Observation:    This is a program that raises LED3 to 100% and back to 0% and loops
*                 
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
* Data Section: address used [ $3000 to $30FF ] RAM Memory
*
          ORG         $3000           ; Reserved RAM memory for starting address
                                      ;   for data for CMPEN 472 class
Counter1  DC.W        $0003           ; X Register count number for the time delay

*
*
***********************************************************************
* Program Section: address used [ $3100 to $3FFF ] RAM Memory
*
            ORG         $3100         ; Program start address, in RAM
pstart      LDS         #$3100        ; initialize the stack pointer

            LDAA        #%11111111    ; LED 1,2,3,4 at PORTB bit 4,5,6,7
            STAA        DDRB          ; set PORTB bit 4,5,6,7 as output
                                                                
            LDAA        #%00010000    ; turn OFF LED 2,3,4; Turn on LED 1
            STAA        PORTB               

              
mainLoop  

          JSR         dimUp             ; run dimUp
          JSR         dimDown           ; run dimDown
          BRA         mainLoop          ; loop 

          
*
***********************************************************************
* Subroutine Section: address used [ $3100 to $3FFF ] RAM Memory
*  
***********************************************************************
dimUp
          LDAA        #100                ; load 100 into A
          
dimUploop 
          BCLR        PORTB,%01000000   ; turn OFF LED 3 at PORTB bit 6
          JSR         delay10usec
          BSET        PORTB,%01000000   ; turn ON LED 3 at PORTB 6 bit
          JSR         delay10usec
          DECA                          ; A - 1
          CMPA        #00              ; Compare to 0
          BEQ         dimDown          ; if equal -> mainloop
               
          BRA         dimUploop         ; else dimUp




***********************************************************************
dimDown
          LDAA        #100              ; load 100 into A
                  
          
dimDownloop
          BCLR        PORTB,%01000000   ; turn OFF LED 3 at PORTB bit 6 
          JSR         delay10usec
          BSET        PORTB,%01000000   ; turn ON LED 3 at PORTB bit 6
          JSR         delay10usec                          ;
          DECA                          ; A - 1
          CMPA        #00               ; Compare to 0
          BEQ         dimUp          ; if equal -> mainloop
         
          BRA         dimDownloop       ; else dimDown
          
**********************************************************************
; delay10us subroutine
;
; This subroutine will cause a 10 usec. delay
;
; Input: a 16 bit count number in 'Counter1'
; Output: time delay, CPU cycle waisted
; Register in use: A register, as counter
; Memory Locations in use: a 16 bit input number at 'Counter1'

delay10usec 
          
          PSHA                          ; save A
          LDAA         Counter1         ; long delay by
          
dlyUSLoop 
          
          DECA
          BNE         dlyUSLoop
          
          PULA                          ; restore A
          RTS                           ; return    



          
          end                           ;last line of a file          