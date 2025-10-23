***************************************************************************************************
*
* Title: SCI Serial Port I/O
*
* Objective: CMPEN472 Homework 6
*
* Date: 09 October 2024
*
* Programmer: Tyler Korz
*
* Student at The Pennsylvania State University
* Electrical Engineering and Computer Science
*
* Revision: v2.0
*
* Algorithm: Simple Serial I/O use, typewriter, ASCII and hex conversions
*
* Register use: A accumulator: Data from serial port
*               B accumulator: Misc. data
*               X register: Char Buffer
*               Y register: Buffer
*
* Memory use: RAM locations from $3000 for data
*             RAM locations from $3100 for program
*
* Input: Parameters hard coded in program (PORT B)
*        Terminal
* 
* Output:   PORTB bit 7 to bit 4, 7-segment MSB
*           PORTB bit 3 to bit 0, 7-segment LSB
*           Terminal
*
* Observation: This is a program for simple memory access. It can show the
*              value in memory with command 'S' and can write to a memory
*              location with command 'W'. The 'QUIT' command exits the
*              SMA and moves to typewriter mode.
*
* Comments: This program is developed and simulated using CodeWarrior IDE
*           and is targeted for a CSM-12C128 board
*
***********************************************************************
* Parameter Declearation Section
*
* Export Symbols
            XDEF        pstart       ; export 'pstart' symbol
            ABSENTRY    pstart       ; for assembly entry point
  
* Symbols and Macros
PORTB       EQU         $0001        ; i/o port B addresses
DDRB        EQU         $0003

SCIBDH      EQU         $00C8        ; Serial port (SCI) Baud Register H
SCIBDL      EQU         $00C9        ; Serial port (SCI) Baud Register L
SCICR2      EQU         $00CB        ; Serial port (SCI) Control Register 2
SCISR1      EQU         $00CC        ; Serial port (SCI) Status Register 1
SCIDRL      EQU         $00CF        ; Serial port (SCI) Data Register

CR          EQU         $0D          ; carriage return, ASCII 'Return' key
LF          EQU         $0A          ; line feed, ASCII 'next line' character
SPACE       EQU         $20          ; space character
PERCENT     EQU         $25          ; % character

***********************************************************************
* Data Section: address used [ $3000 to $30FF ] RAM memory
*
            ORG         $3000        ; Reserved RAM memory starting address 
                                     ;   for Data for CMPEN 472 class

CCount      DS.B        $0001        ; Number of chars in buffer
HCount      DS.B        $0001        ; number of ASCII characters to be converted to hex
DCount      DS.B        $0001        ; number of ASCII chars to be converted to decimal
mainBuff    DS.B        $000D        ; The actual command buffer
HexBuff     DS.B        $0004        ; used to store Hex -> ASCII conversion)
AddrBuff    DS.B        $0006        ; stores the address copied from the command buffer
DecBuff     DS.B        $0004        ; used to store Hex -> Decimal -> ASCII conversion
BinBuff     DS.B        $0004        ; used to store Hex -> Decimal -> Binary conversion
Hex         DS.B        $0004        ; stores a hex number
Temp        DS.B        $0001                                    

; Each message ends with $00 (NULL ASCII character) for your program.
msg1           DC.B    'Hello', $00
msg2           DC.B    'You may type below', $00
msg3           DC.B    'Enter your command below:', $00
msg4           DC.B    'Error: Invalid command', $00

; There are 256 bytes from $3000 to $3100.  If you need more bytes for
; your messages, you can put more messages 'msg3' and 'msg4' at the end of 
; the program - before the last "END" line.
                                     ; Remaining data memory space for stack,
                                     ;   up to program memory start

*
***********************************************************************
* Program Section: address used [ $3100 to $3FFF ] RAM memory
*
            org   $3100              ; Program start address, in RAM
pstart      lds   #$3100             ; initialize the stack pointer

            ldaa  #%11111111         ; Set PORTB bit 0,1,2,3,4,5,6,7
            staa  DDRB               ; as output

            ldaa  #%00000000
            staa  PORTB              

            ldaa  #$0C               ; Enable SCI port Tx and Rx units
            staa  SCICR2             ; disable SCI interrupts

            ldd   #$0001             ; Set SCI Baud Register = $0001 => 2M baud at 24MHz (for simulation)
            std   SCIBDH             ; SCI port baud rate change

            ldx   #HexBuff
            ldaa  #$24
            staa  1,X+               ; initialize the HexBuff with $ in first byte

            ldx   #Hex
            clr   1,X+
            clr   1,X+
            
            ldx   #menu1             ; start printing the terminal menu
            jsr   printmsg          ; this entire section is for setting up the menu
            
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar
            
            ldx   #menu2             ; print the second menu
            jsr   printmsg
            
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar
            
            ldx   #menu3              ; print the next menu message
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            
            ldx   #msg8              ; print the next menu message
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar

            ldx   #msg9              ; print the next menu message
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            ldx   #prompt            ; print '>'
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            
            ldx   #msg10             ; print the next menu message
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            ldx   #msg11             ; print the next menu message
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            ldx   #prompt            ; print '>'
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            
            ldx   #msg12             ; print the next menu message
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            ldx   #msg13             ; print the next menu message
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar

            ldx   #prompt            ; print '>'
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            
            ldx   #msg14             ; print 'QUIT'
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            ldx   #msg15             ; print the next menu message
            jsr   printmsg
                                                                                                            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
main        ldx   #prompt            
            jsr   printmsg
            ldx   #mainBuff           
            clr   CCount
            clr   HCount
            LDAA  #$0000
            ldy   #Hex
            staa  Y
            
            
mainLoop    jsr   getchar            
            cmpa  #$00               
            beq   mainLoop
                                     
            jsr   putchar            

            staa  1,X+               ; store characters
            inc   CCount              
            ldab  CCount
            cmpb  #$0C               ; check if full
            beq   Error              
            cmpa  #CR
            bne   mainLoop            
            ldaa  #LF                
            jsr   putchar
                        
            ldx   #mainBuff           
            ldaa  1,X+   

CmdChk      cmpa  #$53               ; check for 'S'            
            lbeq  Show               ; branch to show function
            cmpa  #$57               ; check for 'W'            
            lbeq  Write              ; branch to write function
                                                 
            
QUITChk     cmpa  #$51               ; check for 'Q'
            bne   Error              
            ldaa  1,X+               
            cmpa  #$55               ; check for 'U'
            bne   Error
            ldaa  1,X+
            cmpa  #$49               ; check for 'I'
            bne   Error
            ldaa  1,X+
            cmpa  #$54               ; check for 'T'
            lbeq  tw                 ; start typewriter
            
Error                                ; used to print error messages
            ldaa  #CR                
            jsr   putchar                                
            ldaa  #LF                
            jsr   putchar

            ldx   #msg4              ; print the error message
            jsr   printmsg
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                                                 
            jsr   putchar
            lbra  main               ; branch to main


Show        ldab  CCount
            cmpb  #$07               ; S cmds are 6 chars long
            lbne  SAddrError         ; error for incorrect length
            inx                      
            ldaa  0,X   
            cmpa  #$33               
            
            pshx                     ; save X
            inx            


S4          ldaa  1,X+
            cmpa  #$46               ; check to third digit
            lbhi  SAddrError
            cmpa  #$41               
            bhs   S3
            cmpa  #$39               
            lbhi  SAddrError
            cmpa  #$30               
            lblo  SAddrError
            
            
S3          ldaa  1,X+               
            cmpa  #$46               ; check next digit
            lbhi  SAddrError
            cmpa  #$41               
            bhs   S2
            cmpa  #$39               
            lbhi  SAddrError
            cmpa  #$30               
            lblo  SAddrError
            
S2          ldaa  0,X                ; check last digit
            cmpa  #$46               
            lbhi  SAddrError
            cmpa  #$41               
            bhs   S1
            cmpa  #$39               
            lbhi  SAddrError
            cmpa  #$30               
            lblo  SAddrError
                       
S1          pulx                     ; restore X
            ldab  #$04
            stab  HCount
            jsr   asciiHex2Hex       ; jump to subroutine
            ldy   Hex
            ldaa  0,Y                
            jsr   hex2ascii
            ldy   Hex
            ldaa  0,Y                
            jsr   hex2asciiDec       ; convert the hex value into decimal then ascii
            ldy   Hex
            ldaa  0,Y                
            jsr   hex2asciiBin       ; convert the hex to binary            
            
            ldx   #mainBuff
            ldy   #AddrBuff
            inx                      ; skip 'S'
            ldaa  1,X+               ; load the '$' into A
            staa  1,Y+               ; store '$' into Buffer
            ldaa  1,X+               ; load '3' into A
            staa  1,Y+               ; store '3' into Buffer
            ldaa  1,X+
            staa  1,Y+
            ldaa  1,X+
            staa  1,Y+
            ldaa  1,X+
            staa  1,Y+
            ldaa  #$00               
            staa  1,Y+               ; store the string terminator into Buffer
            
            ldaa  #SPACE                
            jsr   putchar
            
            ldx   #AddrBuff          ; print the entered address
            jsr   printmsg
            
            ldx   #equals            ; print the '=' sign
            jsr   printmsg
            
            ldaa  #PERCENT
            jsr   putchar
            ldx   #BinBuff           ; print the binary version of the data at that address
            jsr   printmsg
            
            ldaa  #SPACE             ; print a space   
            jsr   putchar
            
            ldx   #HexBuff           ; print the hex data at that address
            jsr   printmsg
            
            ldaa  #SPACE             ; print a space   
            jsr   putchar
            
            ldx   #DecBuff           ; print the decimal version of the data at that address
            jsr   printmsg
            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            lbra  main


Write       ldy   #AddrBuff
            ldaa  0,X
            staa  1,Y+               ; store '$'
            cmpa  #$24               
            lbne  WAddrError
            inx                      
            
            pshx                     ; save X
            
            
            ldaa  0,X
            cmpa  #$46               ; check to make sure fourth digit
            lbhi  WAddrError
            ldab  #$01               ; should be at least 1 digit in valid address
            cmpa  #$41               ; hex?
            bhs   W4
            cmpa  #$39               ; number?
            lbhi  WAddrError
            cmpa  #$30               
            lblo  WAddrError            
            
W4          staa  1,Y+               ; check next digit in buffer
            inx
            ldaa  1,X+
            cmpa  #$46               
            lbhi  WAddrError
            cmpa  #$20               
            beq   W1
            incb                     
            cmpa  #$41               
            bhs   W3
            cmpa  #$39               
            lbhi  WAddrError
            cmpa  #$30               
            lblo  WAddrError
            
W3          staa  1,Y+               ; check next digit in buffer
            ldaa  1,X+               
            cmpa  #$46               
            lbhi  WAddrError
            cmpa  #$20               
            beq   W1
            incb                     
            cmpa  #$41               
            bhs   W2
            cmpa  #$39               
            lbhi  WAddrError
            cmpa  #$30               
            lblo  WAddrError            

W2          staa  1,Y+               ; check next digit in buffer
            ldaa  0,X               
            cmpa  #$46               
            lbhi  WAddrError
            cmpa  #$20               
            beq   W1
            incb                     
            cmpa  #$41               
            bhs   W1
            cmpa  #$39               
            lbhi  WAddrError
            cmpa  #$30               
            lblo  WAddrError
            
W1          staa  1,Y+               ; check next digit in buffer
            ldaa  #$00               ; also check for null term
            staa  1,Y+               
            pulx                                 
            stab  HCount             
            jsr   asciiHex2Hex       
            ldy   Hex
            inx                      
            pshx                     
            ldaa  1,X+               
            cmpa  #$24               
            lbne  W7                 
            pshx                     
            
            clr   HCount             ; clear hex count
            ldaa  1,X+
            cmpa  #$46               
            lbhi  DataError
            inc   HCount             
            cmpa  #$41               
            bhs   W5
            cmpa  #$39               
            cmpa  #$30               
            lblo  DataError
            
W5          ldaa  1,X+                ; keep checking next digits
            cmpa  #$46               
            lbhi  DataError
            cmpa  #CR                
            beq   W6
            inc   HCount             
            cmpa  #$41               
            bhs   W6
            cmpa  #$39               
            lbhi  DataError
            cmpa  #$30               
            lblo  DataError
                                  
                        
       
W6          ldx   #Hex               ; clear
            clr   1,X+
            clr   1,X+
            pulx                     ; restore X
            jsr   asciiHex2Hex  
                 
STORE       ldx   #Hex
            inx
            ldaa  0,X                ; load converted hex data stored in Hex
            staa  0,Y                
            
            
            ldx   #Hex
            inx
            ldaa  0,X                
            jsr   hex2asciiDec       ; convert the hex value from the address into decimal then to ascii
            
            pulx
            ldy   #HexBuff
            ldaa  1,X+               
            staa  1,Y+               ; store the first char
            ldaa  1,X+               ; load next char
            cmpa  #CR                ; check for Enter
            beq   term
            staa  1,Y+               ; store the character into buffer
            ldaa  1,X+               
            cmpa  #CR                ; check for Enter
            beq   term
            staa  1,Y+ 
            
                          
term        ldaa  #$00               ; load null terminator into A
            staa  0,Y                
            
            ldaa  #SPACE                
            jsr   putchar
            
            ldx   #AddrBuff          ; print the entered address
            jsr   printmsg
            
            ldx   #equals            ; print the =
            jsr   printmsg
            
            ldaa  #PERCENT
            jsr   putchar
            ldx   #BinBuff           ; print the binary version of the data at that address
            jsr   printmsg           
            
            ldx   #HexBuff           ; print the hex data at that address
            jsr   printmsg
            
            ldaa  #SPACE             ; print a space   
            jsr   putchar
            
            ldx   #DecBuff           ; print the decimal version of the data at that address
            jsr   printmsg

            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
            
            lbra  main

W7          cmpa  #$39               ; check for numeric digits
            lbhi  DataError
            cmpa  #$30               
            lblo  DataError
            pshx                     
            
            clr   DCount             
            inc   DCount             
            ldaa  1,X+
            cmpa  #$39               
            lbhi  DataError
            cmpa  #CR                ; check for second digit
            beq   W8
            cmpa  #$30               
            lblo  DataError
            inc   DCount              
            
            ldaa  1,X+
            cmpa  #$39               
            lbhi  DataError
            cmpa  #CR                 ; check for third digit
            beq   W8
            cmpa  #$30               
            lblo  DataError
            inc   DCount 
            
            ldaa  1,X+
            cmpa  #$39               
            lbhi  DataError
            cmpa  #CR                 ; check for fourth digit
            beq   W8
            cmpa  #$30               
            lblo  DataError
            inc   DCount            
            
W8          ldx   #Hex               ; clear out the Hex storage
            clr   1,X+
            clr   1,X+
            pulx                     ; restore X to the beginning of the ASCII Argument representation
            pshx                     ;
            jsr   asciiDec2Hex       ; jump to subrt to convert ASCII argument text to an actual hex number            
            
            ldx   #Hex
            inx
            ldaa  0,X                ; load converted hex data stored in Hex
            staa  0,Y                ; store that data into the address input by the user
            
            ldx   #mainBuff
            inx
            ldaa  1,X+
            pshx
            inx
            lbra  S4
            

             

SAddrError                           ; for invalid addresses
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar

            ldx   #errormsg1         ; print the error message
            jsr   printmsg
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
                                     

            lbra  main               ; loop back to main
            
WAddrError                           
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar

            ldx   #errormsg1         ; print the error message
            jsr   printmsg
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar
                                     
            
            lbra  main               ; loop back to main            

DataError                            
            ldaa  #CR                
            jsr   putchar            
            ldaa  #LF                
            jsr   putchar

            ldx   #errormsg2         ; print the error message
            jsr   printmsg
            ldaa  #CR                
            jsr   putchar               
            ldaa  #LF                 
            jsr   putchar

            lbra  main               ; loop back to main
            
tw          ldx   #msg1              ; print the first message, 'Hello'
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
                 
twloop      jsr   getchar            ; type writer - check the key board
            cmpa  #$00               ;  if nothing typed, keep checking
            beq   twloop
                                     ;  otherwise - what is typed on key board
            jsr   putchar            ; is displayed on the terminal window - echo print

            staa  PORTB              ; show the character on PORTB

            cmpa  #CR
            bne   twloop             ; if Enter/Return key is pressed, move the
            ldaa  #LF                ; cursor to next line
            jsr   putchar
            bra   twloop


            
;subroutine section below

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
NULL           equ     $00
printmsg       psha                   ;Save registers
               pshx
printmsgloop   ldaa    1,X+           ;pick up an ASCII character from string
                                       ;   pointed by X register
                                       ;then update the X register to point to
                                       ;   the next byte
               cmpa    #NULL
               beq     printmsgdone   ;end of strint yet?
               jsr     putchar        ;if not, print character and do next
               bra     printmsgloop

printmsgdone   pulx 
               pula
               rts
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
putchar        brclr SCISR1,#%10000000,putchar   ; wait for transmit buffer empty
               staa  SCIDRL                      ; send a character
               rts
;***************end of putchar*****************


;****************getchar***********************
;* Program: Input one character from SCI port (terminal/keyboard)
;*             if a character is received, otherwise return NULL
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
getchar        brclr SCISR1,#%00100000,getchar7
               ldaa  SCIDRL
               rts
getchar7       clra
               rts
;****************end of getchar**************** 


;*******************asciiHex2Hex*********************
;* Program: converts ascii hex to hex
;*             
;* Input: a number in hex represented by ASCII      
;* Output: a number in hex 
;*                  
;* Registers modified: X, A, B
;   
;****************************************************
asciiHex2Hex    ldd   Hex              ; load full Hex buffer into D
                lsld                   ; shift four times
                lsld
                lsld
                lsld        
                std   Hex
                ldaa  1,X+  
                cmpa  #$41             ; check for A - F
                bhs   L1
                
                suba  #$30             ; subtract ascii bias
                staa  Temp
                ldd   Hex   
                orab  Temp  
                std   Hex
                dec   HCount
                tst   HCount
                bne   asciiHex2Hex

                rts
                
L1              suba  #$37             ; subtract bias
                staa  Temp
                ldd   Hex              ; load full 16bit Hex buffer into D
                orab  Temp             
                std   Hex
                dec   HCount
                tst   HCount
                bne   asciiHex2Hex

                rts      

;***********************end of asciiHex2Hex********************* 


;*****************************asciiDec2Hex*********************
;* Program: converts ascii decimal to hex
;*             
;* Input:  ascii decimal      
;* Output: hex number 
;*          
;*          
;* Registers modified: X,A,B
;   
;*****************************************************************************
asciiDec2Hex    dex
                ldaa  0,X     
                ldab  DCount  
                cmpb  #$04        ; check for 4 digits
                bne   A1
                dec   DCount  
                suba  #$30        ; subtract bias
                ldab  #100      
                mul               
                std   Hex         ; store buffer
                inx               
                ldaa  0,X       
                ldab  DCount    
                
A1              cmpb  #$03        ; check for 3 digits
                bne   A2
                dec   DCount  
                suba  #$30    
                ldab  #10     
                mul           
                addd  Hex
                std   Hex         ; store result in buffer                
                inx
                ldaa  0,X     
                ldab  DCount  
                
                
A2              cmpb  #$02        ; check for 2 digits
                bne   A3
                dec   DCount  
                suba  #$30        ; bias
                ldab  #10     
                mul           
                addd  Hex
                std   Hex         ; store in buffer                
                inx
                ldaa  0,X     
                ldab  DCount                 
                
A3              cmpb  #$01    
                lbne  DataError
                dec   DCount  
                suba  #$30        ; subtract bias 
                ldab  #1      
                mul           
                addd  Hex
                std   Hex         ; store in buffer                
                inx                

               
                rts


;************************end of asciiDec2Hex************************* 


;***************************hex2ascii*****************************
;* Program: converts hex to ascii hex 
;*             
;* Input: HexBuff   
;* Output: hex number 
;*          
;*          
;* Registers modified: A,X
;   
;************************************************************
hex2ascii       ldx   #HexBuff  ; load buffer
                inx             
                staa  Temp      
                lsra            ; shift four times
                lsra
                lsra
                lsra
                cmpa  #$09      ; check for letter
                bhi   B2        
                adda  #$30      ; add bias
                
                
                staa  1,X+      ; store in buffer
                              
B1              ldaa  Temp      ; load from temp
                anda  #$0F      ; 
                cmpa  #$09      
                bhi   B3        
                adda  #$30      ; add bias
                staa  1,X+      
                ldaa  #$00      
                staa  1,X+      
                rts
                
B2              adda  #$37      
                staa  1,X+      
                              
                ldaa  Temp      
                anda  #$0F      
                cmpa  #$09      
                bls   B1        ; if number, branch
                adda  #$37      ; add bias
                staa  1,X+       
                ldaa  #$00       
                staa  1,X+       
                rts
                
B3              adda  #$37      ; add bias
                staa  1,X+      
                ldaa  #$00      
                staa  1,X+      
                rts                      

;**************************end of hex2ascii*******************************


;**************************hex2asciiDec****************************
;* Program: converts a hex number to ascii decimal
;*             
;* Input:  a hex number     
;* Output: the number in ascii decimal 
;*          
;*          
;* Registers modified: X, A, B,
;   
;*****************************************************************
hex2asciiDec                    
                staa  Temp      
                clr   HCount    
                ldaa  #$00
                ldab  Temp      
                
                ldx   #10          ; division by 10
                idiv               
                ldy   #DecBuff  
                stab  1,Y+      
                inc   HCount    
                tfr   X,D       
                tstb               ; check 0 remainder
                beq  C   
                
                ldx   #10          
                idiv               ; Hex / 10   
                  
                stab  1,Y+      
                inc   HCount    
                tfr   X,D          ; copy to D
                tstb               ; check 0 remainder
                beq   C   
                
                ldx   #10          ; keep dividing
                idiv               
                  
                stab  1,Y+      
                inc   HCount    
                tfr   X,D       

                
C               ldaa  HCount    
                cmpa  #$03      
                beq   C4
                cmpa  #$02
                beq   C3
                                
                ldx   #DecBuff  
                ldaa  0,X       
                adda  #$30      
                staa  1,X+      
                ldaa  #$00      
                staa  1,X+      
                rts


C4              ldx   #DecBuff
                ldaa  1,X+         ; load first remainder
                inx
                ldab  0,X          ; load second remainder
                staa  0,X       
                ldx   #DecBuff
                stab  0,X       
                
                ldaa  0,X       
                adda  #$30         ; add bias
                staa  1,X+         ; store converted
                ldaa  0,X       
                adda  #$30
                staa  1,X+      
                ldaa  0,X       
                adda  #$30      
                staa  1,X+      
                ldaa  #$00         ; load NULL
                staa  1,X+         ; store NULL
                rts
                

C3              ldx   #DecBuff     ; same algo
                ldaa  1,X+      
                ldab  0,X       
                staa  0,X       
                ldx   #DecBuff  
                stab  0,X       
                
                ldaa  0,X       
                adda  #$30         ; add biaas
                staa  1,X+      
                ldaa  0,X       
                adda  #$30
                staa  1,X+      
                ldaa  #$00      
                staa  1,X+      
                rts


;******************end of hex2asciiDec*********************


;**************************hex2asciiBin****************************
;* Program: Converts a hex number to ASCII binary
;*             
;* Input:  A hex number in accumulator A    
;* Output: The number in ASCII binary stored in BinBuff
;*          
;* Registers modified: X, A, Y
;   
;*****************************************************************

hex2asciiBin                    
                    staa   Temp         ; Store input hex number
                    ldy    #BinBuff     ; Point Y to the binary buffer
                    ldx    #8           ; Initialize bit counter (8 bits)
                    
NextBit:            ldab   Temp         ; Load Temp into B
                    andb   #$80         ; Mask to get the MSB (bit 7)
                    beq    StoreZero    ; If zero, the bit is '0'
                    ldaa   #'1'         ; ASCII '1'
                    bra    StoreBit
                    
StoreZero:          ldaa   #'0'         ; ASCII '0'

StoreBit:           staa   0,Y          ; Store ASCII bit in buffer
                    iny                 ; Increment buffer pointer
                    asl    Temp         ; Shift Temp left by 1 bit
                    dex                 ; Decrement bit counter
                    bne    NextBit      ; Repeat until all bits are processed
                    
                    ldaa   #$00         ; NULL terminator
                    staa   0,Y          ; Store NULL at end of buffer
                    rts                 ; Return from subroutine

;******************end of hex2asciiBin*********************



;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip


menu1         DC.B    'Welcome to the Simple Memory Access Program!', $00
menu2         DC.B    'Enter one of the following commands (examples shown below)', $00
menu3         DC.B    'and hit Enter.', $00
msg8          DC.B    '>S$3000                   to see the memory content at $3000 and $3001', $00
msg9          DC.B    '> $3000 => %0001001001101010    $126A    4714', $00
msg10         DC.B    '>W$3003 $126A             to write $126A to memory locations $3003 and $3004', $00
msg11         DC.B    '$3003 => %0001001001101010    $126A    4714', $00
msg12         DC.B    '>W$3003 4714              to write $126A to memory location $3003 and $3004', $00
msg13         DC.B    '> $3003 => %0001001001101010    $126A    4714', $00
msg14         DC.B    'QUIT                      quit the Simple Memory Access Program', $00
msg15         DC.B    'Type-writing now, hit any keys:', $00   

errormsg1     DC.B    '> invalid input, address', $00
errormsg2     DC.B    '> invalid input, data', $00

prompt        DC.B    '>', $00
equals        DC.B    ' = ', $00

               END               ; last line of file