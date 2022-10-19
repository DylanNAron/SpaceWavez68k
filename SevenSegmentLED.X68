*-----------------------------------------------------------
* Title      : SevenSegmentLED
* Written by : Dylan Aron
* Date       : 9/28/22
* Description: Draw a seven segment led number from a given number and display it based on given x & y (font can be set as well)
*   3 parameters in stack number to print, x pos, y pos : this program takes these given values and displays the seven segments
*   based on a number bitmask and a letter bitmask 
*
*   use the given number as an offset for the number bitmask and then check each bit to determine which segments to print!
*-----------------------------------------------------------
*    ORG    $1000
*START:                  ; first instruction of program

RECTANGLE_COLOR                 equ     $00FFFFFF
RECTANGLE_FILL_COLOR            equ     $00FFFFFF
RECTANGLE_PEN_WIDTH             equ     5
FontSize                        equ     4

SET_PEN_COLOR_COMMAND           equ     80
SET_PEN_WIDTH_COMMAND           equ     93
SET_FILL_COLOR_COMMAND          equ     81
DRAW_RECTANGLE_COMMAND          equ     87



*    sub.l #16, sp
*    
*    move.l #0,(sp)          ;number to print on LED
*    move.l #600, 4(sp)      ;xPos
*    move.l #10, 8(sp)       ;yPos
*    move.l #$000000FF, 12(sp) color!
    
*    jsr DrawSegmentLED
*    
*    add.l #16, sp           ;fix stack
*    *
*
*    SIMHALT    
    
DrawSegmentLED:
    *move.l  #RECTANGLE_COLOR,d1
    move.l 16(sp), d1
    move.l  #SET_PEN_COLOR_COMMAND,d0
    TRAP    #15
        
    move.l  #RECTANGLE_PEN_WIDTH,d1
    move.l  #SET_PEN_WIDTH_COMMAND,d0
    TRAP    #15

    *move.l  #RECTANGLE_FILL_COLOR,d1   
    move.l 16(sp), d1
    move.l  #SET_FILL_COLOR_COMMAND,d0
    TRAP    #15



    move.l 4(sp), d0        ;number to check segments on in d0
    lea bitmask0, a0        ;load bitmaskNumbers in a0 and offset by d0
    add.l d0, a0
    
    move.b (a0), d5         ;d5 contains the correct bitmask
    move.b #8, d6           ;use d6 as counter for each bit
     
    ;check each bit if we should draw letter!
    ;use d7 for anding (check if set)
CheckBitsToDraw:
    cmp.b #0, d6
    blt LoopDone

    sub.b #1, d6            ;--
    move.b #1, d7
    and.b d5, d7            ;ANDing the last bit to check if it is turned on to draw
    lsr.b #1,d5
    cmp.b #1, d7
    bne CheckBitsToDraw
    
*---DrawSegment--use d6 to find Letter to print------------------------------------------------------
    
    lea bitmaska, a0       ;load bitmaskLetters in a0 and offset  by d6
    move.l d6, d7
    sub.l #1, d7
    lsl.l #2, d7
    add.l d7,a0
    move.l (a0), d7        ;d7 contains correct letter pos bitmask
    
    clr.l d1  ;x1
    clr.l d2  ;y1
    clr.l d3  ;x2
    clr.l d4  ;y2
    
    move.b d7, d4
    lsr.l #8, d7
    move.b d7, d3
    lsr.l #8, d7
    move.b d7, d2
    lsr.l #8, d7
    move.b d7, d1
    
    ;;FontSize Multiplier
    lsl.l #FontSize, d1
    lsl.l #FontSize, d2
    lsl.l #FontSize, d3
    lsl.l #FontSize, d4
    
    ;;ADD X AND Y Pos that is inputted
    add.l 8(sp), d1
    add.l 8(sp), d3
    add.l 12(sp), d2
    add.l 12(sp), d4
    
    
    move.b  #DRAW_RECTANGLE_COMMAND,d0  
    TRAP #15
*-------------------------------------------------------------------------------------------------    
    bra CheckBitsToDraw
  
LoopDone:
    rts

* Put variables and constants here
NumbersBitmaskStart ;-ABCDEFG (bits set for each segment of LED
bitmask0 dc.b %01111110
bitmask1 dc.b %00110000
bitmask2 dc.b %01101101
bitmask3 dc.b %01111001
bitmask4 dc.b %00110011
bitmask5 dc.b %01011011
bitmask6 dc.b %01011111
bitmask7 dc.b %01110000
bitmask8 dc.b %01111111
bitmask9 dc.b %01110011

LettersBitmaskStart ; Xstart, Ystart, Xend, Yend [ 00 ]
;bitmaska dc.b %00000100
bitmaska dc.l $00000100
bitmaskb dc.l $01000101
bitmaskc dc.l $01010102
bitmaskd dc.l $01020002
bitmaske dc.l $00020001
bitmaskf dc.l $00010000
bitmaskg dc.l $00010101


 *   END    START        ; last line of source










*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
