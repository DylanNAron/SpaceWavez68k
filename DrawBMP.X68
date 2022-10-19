*-----------------------------------------------------------
* Title      : Assignment 2 - Bitmap Subroutine
* Written by : Dylan Aron
* Date       : 9/26/22
* Description: Subroutine that reads a 32 bit bitmap and draws it to the output window based on parameters for x/y bmp chunking,
*    x/y output start, width/height to draw, and a pointer to bmp. These parameters are given via the stack. This program ignores alpha values
*    and prints bottom up and left to right through two loops (looping through rows and columns). At the start of the program we check edge cases
*    and then we calculate the start of the data from the given chunking values and by finding actual width and height so that we have:

*    A1 is the start of pixel data (after factoring in chunking/height), A2 is pixel data-1 row (so that we avoid issues with x chunking) 
*    D4 is x output & D5 is y output(d4,d5)
*    D6 is outerloop counter for rows decrementing
*    D7 is inner counter for columns decrementing
* 
*-----------------------------------------------------------
*    ORG    $1000
*START:                  
SET_PEN_COLOR           equ     80
DRAW_PIXEL              equ     82
DISPLAY_TXT             equ     14

*Call Subroutine here with args in stack: (to retrieve the arg it will be +4ofnumbered sp set)
*    sub.l #28, sp        ;prepare stack for 7 4byte args
*    
*    lea bitmap, a0       * Pointer to .bmp file
*    move.l a0, (sp)
*    
*    move.l #0, 4(sp)     * Top, Left corner x bmp chunk
*    move.l #0, 8(sp)     * Top, Left corner y bmp chunk
*    
*    move.l #200, 12(sp)  * Width  of bitmap chunk to display
*    move.l #130, 16(sp)  * Height of bitmap chunk to display
*    
*    move.l #0, 20(sp)    * Top, Left corner x to display on output screen
*    move.l #0, 24(sp)    * Top, Left corner y to display on output screen
*    
*    jsr DrawBitmap
*    add.l #28, sp        *fix stack
*    
*    SIMHALT
     

DrawBitmap:
;Check if valid inputs
*-----------------------------------------------------------
   *Width check
   move.l 8(sp), d1
   move.l 16(sp), d2
   sub.l d1,d2
   move.l 4(sp), a0
   add.l #$12, a0
   jsr GetBigEndian
   cmp.l d2,d1
   blt WidthError
   *Height check
   move.l 12(sp), d1
   move.l 20(sp), d2
   sub.l d1,d2
   move.l 4(sp), a0
   add.l #$16, a0
   jsr GetBigEndian
   cmp.l d2,d1
   blt HeightError
   *Invalid Bmp check
   move.l 4(sp), a0
   move.w (a0), d1
   move.l #$424D, d2
   cmp d1,d2
   bne InvalidBmp
   *Negative number check
   move.l #0, d1
   add.l 8(sp), d1
   bmi NegativeNumbers
   move.l #0, d1
   add.l 12(sp), d1
   bmi NegativeNumbers
   move.l #0, d1
   add.l 16(sp), d1
   bmi NegativeNumbers
   move.l #0, d1
   add.l 20(sp), d1
   bmi NegativeNumbers
   move.l #0, d1
   add.l 24(sp), d1
   bmi NegativeNumbers
   move.l #0, d1
   add.l 28(sp), d1
   bmi NegativeNumbers
   *Incorrect bmp check
   move.l 4(sp), a0
   add.l #$1C, a0
   clr.l d1
   clr.l d2
   move.b (a0), d1
   move.b #$20, d2   ;32 bit!
   cmp d1,d2
   bne IncorrectBmp
*-----------------------------------------------------------
   

;Get start address offset and then set a1 to starting point
   move.l 4(sp), a0
   add.l #$A, a0
   jsr GetBigEndian
   move.l 4(sp), a1          ;a1 is start point of data
   add.l d1, a1         
   

;set a1 to proper bottom layer by adding (actual height - height - top chunk y) * width
   move.l 4(sp), a0        
   add.l #$16, a0
   jsr GetBigEndian          ; true height in d1
   sub.l 20(sp), d1          ; aheight - hieght
   sub.l 12(sp),d1           ; hrightsum - topchunk y
   move.l d1,d2              ;put in d2
   
   move.l 4(sp), a0        
   add.l #$12, a0
   jsr GetBigEndian          ;width in d1 mulu both
   lsl.l #2,d1
   mulu d2, d1
   
   add.l d1, a1
   
   move.l a1, a2             ;a2 temp hold data -1 width
   move.l 4(sp), a0        
   add.l #$12, a0
   jsr GetBigEndian
   lsl.l #2, d1              ;shifting left 2 bits = *4
   sub.l d1, a2
   

;d4 output x pos  
;d5 output y pos 
    move.l 24(sp), d4       ;x output 
    
    move.l 20(sp), d5       ;y output (height - top y chunk + top y output)
    *???sub.l 12(sp), d5 
    add.l 28(sp), d5

;bitmap loop is drawing bottom up -> left to right
;d6 is outerloop counter for rows decrementing
    ;GetRows = height - y start
    move.l 20(sp), d6
    sub.l 12(sp), d6 
    
    add.l #1,d6             ;accounts for initial -- inloop
    add.l #1,d5
*-----------------------------------------------------------
OuterLoop:
    subi.l #1, d6           ;decrement outerloop #rows
    subi.l #1, d5           ;decrement y pos
   
    ;reset innerloop getCols = width - xstart
    move.l 16(sp), d7
    sub.l 8(sp), d7


    ******
    ;reset innerloop getCols = width
    move.l 16(sp), d7
    
    move.l 4(sp), a0        ;x true width in d1
    add.l #$12, a0
    jsr GetBigEndian
    lsl.l #2, d1              
    add.l d1, a2            ;a2 set to next row
    
    move.l 8(sp), d4        ;x chunk start in d2
    move.l #4,d2
    mulu d4,d2
    
    move.l a2,a1
    add.l d2,a1             ;set a1 to proper x chunk start resetting a1
    
    move.l 24(sp), d4       ;reset x output val
    subi.l #1, d4
    
    ;branch to end if d5 is equal to top corner y
    cmp.l 28(sp), d5
    beq End

*-----------------------------------------------------------

;d7 is inner counter for columns decrementing
;innerloop goes through each column in the row
InnerLoop:
    add.l #1, d4
    move.l (a1)+, d3 
    
    ;Print Pixel!
    lsr.l #8, d3            ;32bitmap is BBGGRRAA so bitshift to 00BBGGRR
    
    ;check if white FFFFFF to skip for transparency!
    *cmpi.l #$EFEFEF, d3
    *bgt SkipPixel
    cmpi.l #$FFFFFF, d3
    beq SkipPixel
    
    move.l  d3,d1
    move.l #SET_PEN_COLOR, d0
    trap #15
    move.l d4, d1 ;x pos
    move.l d5, d2 ;y pos
    move.l #DRAW_PIXEL, d0
    trap #15

    SkipPixel:
    subi.l #1,d7            ; decrement col counter
    ;branch to outerloop if d7 is equal to top corner x
    *cmp.l 8(sp), d7
    cmp.l #0, d7
    beq Outerloop
    bra InnerLoop

*-----------------------------------------------------------
    
;take a0 as start of long and resulting d1 will contain the bigEndian value
GetBigEndian: 
    clr.l d0
    clr.l d1

    move.w (a0)+,d0
    move.w (a0)+,d1
    
    rol.w #8,d0     ;swap byte d0
    swap   d0
    rol.w #8,d0
    
    rol.w #8,d1     ;swap byte d1
    swap   d1
    rol.w #8,d1
    
    add.l d0,d1     ;swap word now d1 contains big endian value of size ! 
    swap d1
    
    rts

WidthError:
    move    #DISPLAY_TXT,D0 
    lea     widthErrorTxt,A1
    trap    #15
    rts
HeightError: 
    move    #DISPLAY_TXT,D0 
    lea     heightErrorTxt,A1
    trap    #15
    rts
InvalidBmp:
    move    #DISPLAY_TXT,D0 
    lea     bmpErrorTxt,A1
    trap    #15
    rts
NegativeNumbers:
    move    #DISPLAY_TXT,D0 
    lea     negativeErrorTxt,A1
    trap    #15
    rts
IncorrectBmp:
    move    #DISPLAY_TXT,D0 
    lea     incorrectBmpTxt,A1
    trap    #15
    rts

    
End:
    rts

*    SIMHALT             ; halt simulator
    
*bitmap    INCBIN "32bitmap.bmp"
widthErrorTxt dc.b 'Width out of range for bitmap',0
heightErrorTxt dc.b 'Height out of range for bitmap',0
bmpErrorTxt dc.b 'Invalid bitmap',0
negativeErrorTxt dc.b 'Negative numbers inputted, remember the origin of the output screen is top left so only +x for right and +y for down!',0
incorrectBmpTxt dc.b '32 bitmaps only, Sorry!',0


*    END    START        ; last line of source






















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
