*-----------------------------------------------------------
* Title      : SpaceWavez Assembly Game
* Written by : Dylan Aron
* Date       : 10/12/2022
* Description: MAIN FILE -> Press Play on this file to run 
*
*   Play as an Astronaut in space dodging bad vibes in this 2 player game! Fight to be the last one standing!
*   arrow keys or wasd to move left, right, and jetpack up, you are always being pulled down by a black hole!
*
*   All variables that interact with other files are set at the top here. Below these equates we have our main menu loop, game loop, and end game loop
*   In this file we include our other files at the bottom for bitmapdraw, obstaclespawning, 7segmentled, and randomization
*
*   In the main game loop this file handles our player movement as well as checking collision
*
*   The end game loop and main menu loop show an image and the user can hit the 'Enter' Key to play again and move past the menu
*
*-----------------------------------------------------------

START   ORG     $1000

ALL_REG         REG     D0-D7/A0-A6

SET_PEN_COLOR_COMMAND   equ     80
SET_FILL_COLOR_COMMAND  equ     81
DRAW_CIRCLE_COMMAND     equ     88

CLEAR_SCREEN_COMMAND        equ     11
CLEAR_SCREEN_MAGIC_VAL      equ     $FF00
DRAWING_MODE_TRAP_CODE	    equ	92
DOUBLE_BUFFERED_MODE	    equ	17
SINGLE_BUFFERED_MODE	    equ	16
REPAINT_SCREEN_TRAP_CODE	equ	94

PlayerStartYpos     equ 100<<8
PlayerStartXpos     equ 100<<8
Player2StartYpos    equ 100<<8
Player2StartXpos    equ 400<<8
PlayerWidth         equ 25
PlayerHeight        equ 50
Player_Velocity		equ	1000
Gravity		        equ	1000


ObstacleStartVelocity           equ 30
ObstacleHeight                  equ 25
ObstacleWidth                   equ 25
ObstacleTopYPos                 equ 0

StartSecondsBetweenSpawn        equ 350 ;in hundreths of second this decreases over time
TotalObstacles                  equ 20 

RIGHT_SIDE_OF_SCREEN	equ	640 
BOTTOM_SCREEN           equ 480
RandomOffset            equ RIGHT_SIDE_OF_SCREEN/255

DistanceForHit          equ  (PlayerWidth>>1+ObstacleWidth>>1)*(PlayerWidth>>1+ObstacleWidth>>1)  

EnterKey                equ $D
GET_USER_INPUT_COMMAND  equ     19
KEY_UP_INPUT            equ     $26
KEY_LEFT_INPUT          equ     $25
KEY_RIGHT_INPUT         equ     $27
W_UP_INPUT              equ 87
A_LEFT_INPUT            equ 65
D_RIGHT_INPUT           equ 68

WHITE			equ	$00FFFFFF
GREEN           equ $0000FF00
RED             equ $000000FF

*----------------------------------------------------------------

    lea	music,a1    
	move.l      #0,d1
	move.l      #0,d2
	move.l      #73,d0
	TRAP        #15


PreMainMenu:
        *SCREEN No Double buffer for main menu cuz it looks cool
      	move.b	#DRAWING_MODE_TRAP_CODE,d0
      	move.b	#SINGLE_BUFFERED_MODE,d1
      	trap	#15
        
   
        sub.l #28, sp        ;prepare stack for 7 4byte args 
        lea titleScreen, a0       * Pointer to .bmp file
        move.l a0, (sp)
        move.l #0, 4(sp)     * Top, Left corner x bmp chunk
        move.l #0, 8(sp)     * Top, Left corner y bmp chunk
        move.l #RIGHT_SIDE_OF_SCREEN, 12(sp)  * Width  of bitmap chunk to display
        move.l #BOTTOM_SCREEN, 16(sp)  * Height of bitmap chunk to display
        move.l #0, 20(sp)    * Top, Left corner x to display on output screen
        move.l #0, 24(sp)    * Top, Left corner y to display on output screen
        jsr DrawBitmap
        add.l #28, sp        *fix stack


MainMenu:

        move.l  #EnterKey,d1 ; check for keypress 
        move.b  #GET_USER_INPUT_COMMAND,d0
        TRAP    #15
        andi.l  #$FF,d1
        cmp.b #$FF, d1 ;check enter
        beq MainGameStart
        bra MainMenu



MainGameStart:
        *RESET PARAMETERS
        lea SecondsBetweenSpawn, a1
        move.l #StartSecondsBetweenSpawn, (a1)
    
        lea ObstacleVelocity, a1
        move.l #ObstacleStartVelocity, (a1)

        lea PlayerX, a1
	    move.l	#PlayerStartXpos, (a1)
        lea PlayerY, a1       
        move.l	#PlayerStartYpos, (a1)
        
        lea Player2X, a1
	    move.l	#Player2StartXpos, (a1)
        lea Player2Y, a1       
        move.l	#Player2StartYpos, (a1)
                
        *set double buffered mode
      	move.b	#DRAWING_MODE_TRAP_CODE,d0
      	move.b	#DOUBLE_BUFFERED_MODE,d1
      	trap	#15
      	
      	movem.l ALL_REG,-(sp)
      	*Initial Background Draw
        sub.l #28, sp        ;prepare stack for 7 4byte args
    
        lea background, a0       * Pointer to .bmp file
        move.l a0, (sp)
    
        move.l #0, 4(sp)     * Top, Left corner x bmp chunk
        move.l #0, 8(sp)     * Top, Left corner y bmp chunk
    
        move.l #RIGHT_SIDE_OF_SCREEN, 12(sp)  * Width  of bitmap chunk to display
        move.l #BOTTOM_SCREEN, 16(sp)  * Height of bitmap chunk to display
    
        move.l #0, 20(sp)    * Top, Left corner x to display on output screen
        move.l #0, 24(sp)    * Top, Left corner y to display on output screen
    
        jsr DrawBitmap
        add.l #28, sp        *fix stack
        movem.l (sp)+,ALL_REG
        
        *Obstacles
        lea ObstaclesPointer,a5
        move.l  #8,d0		;trap code to get timer into D1
	    trap	#15			;timer is in hundredths of seconds since midnight
        move.l d1, d6
        add.l #StartSecondsBetweenSpawn, d6
        lea NextSpawnTime, a3
        move.l d6, (a3)
    
        
        
gameloop:
   
   movem.l ALL_REG,-(sp)
    jsr ObstacleSpawning
   movem.l (sp)+,ALL_REG

*-----------P1------------------------------
   *Set x position & ypos for player 1 to d7 & d5
    lea PlayerX, a1
	move.l	(a1),d7
    lea PlayerY, a1       
    move.l	(a1),d5
    move.l	#0,d6 ;no side velocity = not moving
    move.l  #Gravity, d4 ;grav = player always pulled down unless jetpacking up
    
    move.l  #A_LEFT_INPUT<<16+D_RIGHT_INPUT<<8+W_UP_INPUT,d1 ; check for keypress (left,right,up)
    move.b  #GET_USER_INPUT_COMMAND,d0
    TRAP    #15
    andi.l  #$FFFFFF,d1
    cmp.b #$FF, d1 ;check up
    beq UpKey
UpSet:   
    lsr.l #8, d1
    cmp.b #$FF, d1 ;check right
    beq RightKey
RightSet:
    lsr.l #8, d1
    cmp.b #$FF, d1 ;check left
    beq LeftKey
LeftSet: 
    lsr.l #8, d1    
       	
    jsr updatePlayer
    lea PlayerX, a1
	move.l	d7, (a1)
    lea PlayerY, a1       
    move.l	d5, (a1)
    
    jsr drawPlayer
    
   movem.l ALL_REG,-(sp)
    jsr CheckPlayerCollision
   movem.l (sp)+,ALL_REG
    
    *Player1Health
     movem.l ALL_REG,-(sp)
     sub.l #16, sp
     lea PlayerHealth, a2
     move.l (a2),(sp)          ;number to print on LED
     move.l #50, 4(sp)      ;xPos
     move.l #7, 8(sp)       ;yPos
     move.l #WHITE, 12(sp)
     jsr DrawSegmentLED
     add.l #12, sp           ;fix stack
     movem.l (sp)+,ALL_REG
*-------P2-------------------------------- 
  *Set x position & ypos for player 1 to d7 & d5
    lea Player2X, a1
	move.l	(a1),d7
    lea Player2Y, a1       
    move.l	(a1),d5
    move.l	#0,d6 ;no side velocity = not moving
    move.l  #Gravity, d4 ;grav = player always pulled down unless jetpacking up

	move.l  #KEY_LEFT_INPUT<<16+KEY_RIGHT_INPUT<<8+KEY_UP_INPUT,d1   ; check for keypress (left,right,up)
    move.b  #GET_USER_INPUT_COMMAND,d0
    TRAP    #15
    andi.l  #$FFFFFF,d1
    cmp.b #$FF, d1 ;check up
    beq UpKey2
UpSet2:   
    lsr.l #8, d1
    cmp.b #$FF, d1 ;check right
    beq RightKey2
RightSet2:
    lsr.l #8, d1
    cmp.b #$FF, d1 ;check left
    beq LeftKey2
LeftSet2: 
    lsr.l #8, d1    
       	
    jsr updatePlayer
    lea Player2X, a1
	move.l	d7, (a1)
    lea Player2Y, a1       
    move.l	d5, (a1)
    

    jsr drawPlayer2
    
    movem.l ALL_REG,-(sp)
    jsr CheckPlayer2Collision
    movem.l (sp)+,ALL_REG
    
    *Player2Health
     movem.l ALL_REG,-(sp)
     sub.l #12, sp
     lea Player2Health, a2
     move.l (a2),(sp)          ;number to print on LED
     move.l #400, 4(sp)      ;xPos
     move.l #7, 8(sp)       ;yPos
     move.l #GREEN, 12(sp)
     jsr DrawSegmentLED
     add.l #12, sp           ;fix stack
     movem.l (sp)+,ALL_REG
	
	
*---Redraw&EndLoop---------------
	jsr	swapBuffers
	bra     gameloop

*-----------------------------------------------------------------------game loop

UpKey:
    move.l #-Gravity, d4
    bra UpSet
LeftKey:
    move.l	#-Player_Velocity,d6
    bra LeftSet
RightKey:
    move.l	#Player_Velocity,d6
    bra RightSet
    
    
UpKey2:
    move.l #-Gravity, d4
    bra UpSet2
LeftKey2:
    move.l	#-Player_Velocity,d6
    bra LeftSet2
RightKey2:
    move.l	#Player_Velocity,d6
    bra RightSet2

clearScreen
        move.b  #CLEAR_SCREEN_COMMAND,d0
       	move.l  #CLEAR_SCREEN_MAGIC_VAL,d1
       	TRAP    #15
	    rts
swapBuffers
	move.b  #REPAINT_SCREEN_TRAP_CODE,d0
    TRAP    #15
	rts        
	
	
	
updatePlayer:
    add.l	d6,d7 ;velocity x 
    
    add.l   d4,d5 ;grav y


	cmpi.l	#(RIGHT_SIDE_OF_SCREEN-PlayerWidth-5)<<8,d7 ;check rightwall
	bge WallHit
	
	cmpi.l #(5<<8), d7   ;check leftwall
	ble WallHit
	
	WallChecked:
	cmpi.l #(50<<8), d5   ;check topscreen
	ble VerticalHit
	
	cmpi.l #(BOTTOM_SCREEN-PlayerWidth)<<8,d5 ;check bottom screen
	bge VerticalHit
	
	rts
	
    WallHit:
    sub.l d6,d7
    ;rts
    bra WallChecked
    
    VerticalHit:
    sub.l d4,d5
    rts
	
	
*Draw player sprite & small chunks of bg around sprite
drawPlayer
    *draw each sliver of background around astro------------------------------*
    *d7 is x pos & d5 is ypos
    move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2

    *---above---------
    
    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    lea background, a0       * Pointer to .bmp file
    move.l a0, (sp)
    sub.l #5, d1
    bmi SkipAboveDraw
    move.l d1, 4(sp)     * Top, Left corner x bmp chunk
    sub.l #5, d2
    bmi SkipAboveDraw    *check if out of bounds
    move.l d2, 8(sp)     * Top, Left corner y bmp chunk
    move.l #PlayerWidth+5, 12(sp)  * Width  of bitmap chunk to display
    move.l #5, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    SkipAboveDraw:
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG
  
    *--left------------
    
    move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2

    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    lea background, a0       * Pointer to .bmp file
    move.l a0, (sp)
    sub.l #5, d1
    bmi SkipLeftDraw     *check if out of bounds
    move.l d1, 4(sp)     * Top, Left corner x bmp chunk
    move.l d2, 8(sp)     * Top, Left corner y bmp chunk
    move.l #5, 12(sp)    * Width  of bitmap chunk to display
    move.l #PlayerHeight+5, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    SkipLeftDraw:
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG
    
    *--right-----------
    
    move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2

    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    lea background, a0       * Pointer to .bmp file
    move.l a0, (sp)
    
    sub.l #9, d2
    bmi SkipRightDraw
    
    add.l #0, d1
    add.l #PlayerWidth, d1
    cmp RIGHT_SIDE_OF_SCREEN, d1
    blt SkipRightDraw    *check if out of bounds
    move.l d1, 4(sp)     * Top, Left corner x bmp chunk
    move.l d2, 8(sp)     * Top, Left corner y bmp chunk
    move.l #9, 12(sp)    * Width  of bitmap chunk to display
    move.l #PlayerHeight+15, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    SkipRightDraw:
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG

    
    
    *--below-----------
    
    move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2
    
    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    lea background, a0       * Pointer to .bmp file
    move.l a0, (sp)
    sub.l #5, d1
    bmi SkipBelowDraw
    move.l d1, 4(sp)     * Top, Left corner x bmp chunk
    add.l #5, d2
    add.l #PlayerHeight, d2
    bmi SkipBelowDraw  *check if out of bounds
    move.l d2, 8(sp)     * Top, Left corner y bmp chunk
    move.l #PlayerWidth+10, 12(sp)  * Width  of bitmap chunk to display
    move.l #5, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    SkipBelowDraw:
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG
    
    *chunk bg END-----------------------------------------****


	***DRAW PLAYER ASTRONAUT---------------------
	move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2
    
    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    *move a1,a0 *A1 set to correct sprite
    lea player, a0       * Pointer to .bmp file
    move.l a0, (sp)
    move.l #0, 4(sp)     * Top, Left corner x bmp chunk
    move.l #0, 8(sp)     * Top, Left corner y bmp chunk
    move.l #PlayerWidth, 12(sp)  * Width  of bitmap chunk to display
    move.l #PlayerHeight, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG


	rts
	*------------------------------------------------------------


*Draw player sprite & small chunks of bg around sprite
drawPlayer2
    *draw each sliver of background around astro------------------------------*
    *d7 is x pos & d5 is ypos
    move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2

    *---above---------
    
    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    lea background, a0       * Pointer to .bmp file
    move.l a0, (sp)
    sub.l #5, d1
    bmi SkipAboveDraw22
    move.l d1, 4(sp)     * Top, Left corner x bmp chunk
    sub.l #5, d2
    bmi SkipAboveDraw22    *check if out of bounds
    move.l d2, 8(sp)     * Top, Left corner y bmp chunk
    move.l #PlayerWidth+5, 12(sp)  * Width  of bitmap chunk to display
    move.l #5, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    SkipAboveDraw22:
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG
  
    *--left------------
    
    move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2

    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    lea background, a0       * Pointer to .bmp file
    move.l a0, (sp)
    sub.l #5, d1
    bmi SkipLeftDraw22     *check if out of bounds
    move.l d1, 4(sp)     * Top, Left corner x bmp chunk
    move.l d2, 8(sp)     * Top, Left corner y bmp chunk
    move.l #5, 12(sp)    * Width  of bitmap chunk to display
    move.l #PlayerHeight+5, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    SkipLeftDraw22:
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG
    
    *--right-----------
    
    move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2

    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    lea background, a0       * Pointer to .bmp file
    move.l a0, (sp)
    
    sub.l #9, d2
    bmi SkipRightDraw22
    
    add.l #0, d1
    add.l #PlayerWidth, d1
    cmp RIGHT_SIDE_OF_SCREEN, d1
    blt SkipRightDraw22    *check if out of bounds
    move.l d1, 4(sp)     * Top, Left corner x bmp chunk
    move.l d2, 8(sp)     * Top, Left corner y bmp chunk
    move.l #9, 12(sp)    * Width  of bitmap chunk to display
    move.l #PlayerHeight+15, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    SkipRightDraw22:
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG

    
    
    *--below-----------
    
    move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2
    
    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    lea background, a0       * Pointer to .bmp file
    move.l a0, (sp)
    sub.l #5, d1
    bmi SkipBelowDraw22
    move.l d1, 4(sp)     * Top, Left corner x bmp chunk
    add.l #5, d2
    add.l #PlayerHeight, d2
    bmi SkipBelowDraw22  *check if out of bounds
    move.l d2, 8(sp)     * Top, Left corner y bmp chunk
    move.l #PlayerWidth+10, 12(sp)  * Width  of bitmap chunk to display
    move.l #5, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    SkipBelowDraw22:
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG
    
    *chunk bg END-----------------------------------------****


	***DRAW PLAYER ASTRONAUT---------------------
	move.l d7,d1 ;x
    asr.l	#8,d1
    move.l d5, d2 ;y
    asr.l #8, d2
    
    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    *move a1,a0 *A1 set to correct sprite
    lea player2, a0       * Pointer to .bmp file
    move.l a0, (sp)
    move.l #0, 4(sp)     * Top, Left corner x bmp chunk
    move.l #0, 8(sp)     * Top, Left corner y bmp chunk
    move.l #PlayerWidth, 12(sp)  * Width  of bitmap chunk to display
    move.l #PlayerHeight, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG


	rts
	*------------------------------------------------------------




CheckPlayerCollision:
    *for all x&y positions need to add width/2 or height/2 to make them in middle
    move.l d7,d1 ;x player 
    asr.l	#8,d1
    add.l #PlayerWidth>>1, d1
    move.l d5, d2 ;y player
    asr.l #8, d2
    add.l #PlayerHeight>>1, d2
    lea ObstaclesPointer,a5
    move.l #(EndObstaclesPointer-ObstaclesPointer)/4, d0
   LoopThroughObstaclesCheck:
    move.l (a5), d5
    cmp.l #$FFFFFFFF, d5
    beq SkipObstacleCheck
    
    clr.l d4
    move.w d5, d4 ;y obstacle
    asr.l #2, d4
    add.l #ObstacleHeight>>1, d4
    lsr.l #8, d5
    lsr.l #8, d5
    clr.l d3
    move.w d5, d3 ;x obstacle
    add.l #ObstacleWidth>>1, d3
    
    *d1&d3 are x1x2 and d2&d4 are y1y2 so check (d3-d1)^2 + (d4-d2)^2 with precalculated distancesquared to obstacle
    *NEED TO CHECK IF OVERFLOW IE SUBTRACK HIGHER VS LOWER
    cmp d3, d1
    bgt d1Greater
    blt d3Greater
    d1Greater:
    move.l d1, d5
    sub.l d3, d5
    mulu d5,d5
    bra Yvaluesubtract
    d3Greater:
    move.l d3, d5
    sub.l d1, d5
    mulu d5,d5
    *Old x subtract
    *move.l d3, d5
    *sub.l d1, d5
    *mulu d5,d5
    
    Yvaluesubtract:
    cmp d4, d2
    bgt d2Greater
    blt d4Greater
    d2Greater:
    move.l d2, d6
    sub.l d4, d6
    mulu d6,d6
    bra addYandX
    d4Greater:
    move.l d4, d6
    sub.l d2, d6
    mulu d6, d6
    *old y subtract
    *move.l d4, d6
    *sub.l d2,d6
    *mulu d6,d6
    
    addYandX:
    add.l d6,d5
    
    cmp.l #DistanceForHit, d5
    blt HitPlayer
   
    SkipObstacleCheck:
    add.l #0, (a5)+ ;increment a5
    subi.b #1, d0 
    bne LoopThroughObstaclesCheck
	
	rts
    
    *delete obstacle and subtract health from player also check if lost also clear bg for score
   HitPlayer:
   *Clear Obstacle
    move.l (a5), d5
    move.w d5, d4 ;y obstacle
    asr.l #2, d4
    lsr.l #8, d5
    lsr.l #8, d5
    clr.l d3
    move.w d5, d3 ;x obstacle
    
    ***DRAW BG TODODODODODOD
     sub.l #28, sp        ;prepare stack for 7 4byte args
     lea background, a0       * Pointer to .bmp file
     move.l a0, (sp)
     move.l d3, 4(sp)     * Top, Left corner x bmp chunk
     move.l d4, 8(sp)     * Top, Left corner y bmp chunk
     move.l #ObstacleWidth, 12(sp)  * Width  of bitmap chunk to display
     move.l #ObstacleHeight, 16(sp)  * Height of bitmap chunk to display
     move.l d3, 20(sp)    * Top, Left corner x to display on output screen
     move.l d4, 24(sp)    * Top, Left corner y to display on output screen
     jsr DrawBitmap
     add.l #28, sp        *fix stack

    
   
   *Delete Obstacle
    move.l #$FFFFFFFF, (a5)
    
    *Clear BG Health counter
     sub.l #28, sp        ;prepare stack for 7 4byte args
     lea background, a0       * Pointer to .bmp file
     move.l a0, (sp)
     move.l #0, 4(sp)     * Top, Left corner x bmp chunk
     move.l #0, 8(sp)     * Top, Left corner y bmp chunk
     move.l #100, 12(sp)  * Width  of bitmap chunk to display
     move.l #50, 16(sp)  * Height of bitmap chunk to display
     move.l #0, 20(sp)    * Top, Left corner x to display on output screen
     move.l #0, 24(sp)    * Top, Left corner y to display on output screen
     jsr DrawBitmap
     add.l #28, sp        *fix stack
    
    lea PlayerHealth, a6
    move.l (a6), d6
    subi.l #1, d6
    beq PlayerOneLose
    move.l d6, (a6)
    rts

PlayerOneLose:
*Print player one lost and allow reset !!! todo
*DrawPlayer1 Health
     jsr	swapBuffers
     move.l d6, (a6)
     movem.l ALL_REG,-(sp)
     sub.l #12, sp
     lea PlayerHealth, a2
     move.l (a2),(sp)          ;number to print on LED
     move.l #50, 4(sp)      ;xPos
     move.l #7, 8(sp)       ;yPos
     move.l #WHITE, 12(sp)
     jsr DrawSegmentLED
     add.l #12, sp           ;fix stack
     movem.l (sp)+,ALL_REG

*End Screen
        sub.l #28, sp        ;prepare stack for 7 4byte args
    
        lea player2Win, a0       * Pointer to .bmp file
        move.l a0, (sp)
    
        move.l #0, 4(sp)     * Top, Left corner x bmp chunk
        move.l #0, 8(sp)     * Top, Left corner y bmp chunk
    
        move.l #RIGHT_SIDE_OF_SCREEN, 12(sp)  * Width  of bitmap chunk to display
        move.l #BOTTOM_SCREEN, 16(sp)  * Height of bitmap chunk to display
    
        move.l #0, 20(sp)    * Top, Left corner x to display on output screen
        move.l #0, 24(sp)    * Top, Left corner y to display on output screen
    
        jsr DrawBitmap
        add.l #28, sp        *fix stack

        jsr	swapBuffers
 play1endloop:
 **Hit enter to restart**
    lea PlayerHealth, a6
    move.l #3, (a6) 
 
    move.l  #EnterKey,d1 ; check for keypress 
    move.b  #GET_USER_INPUT_COMMAND,d0
    TRAP    #15
    andi.l  #$FF,d1
    cmp.b #$FF, d1 ;check enter
    beq PreMainMenu
    
    bra play1endloop


*------------------------------------------------------------

CheckPlayer2Collision:
    *for all x&y positions need to add width/2 or height/2 to make them in middle
    move.l d7,d1 ;x player 
    asr.l	#8,d1
    add.l #PlayerWidth>>1, d1
    move.l d5, d2 ;y player
    asr.l #8, d2
    add.l #PlayerHeight>>1, d2
    lea ObstaclesPointer,a5
    move.l #(EndObstaclesPointer-ObstaclesPointer)/4, d0
   LoopThroughObstaclesCheck2:
    move.l (a5), d5
    cmp.l #$FFFFFFFF, d5
    beq SkipObstacleCheck2
    
    clr.l d4
    move.w d5, d4 ;y obstacle
    asr.l #2, d4
    add.l #ObstacleHeight>>1, d4
    lsr.l #8, d5
    lsr.l #8, d5
    clr.l d3
    move.w d5, d3 ;x obstacle
    add.l #ObstacleWidth>>1, d3
    
    *d1&d3 are x1x2 and d2&d4 are y1y2 so check (d3-d1)^2 + (d4-d2)^2 with precalculated distancesquared to obstacle
    *NEED TO CHECK IF OVERFLOW IE SUBTRACK HIGHER VS LOWER
    cmp d3, d1
    bgt d1Greater2
    blt d3Greater2
    d1Greater2:
    move.l d1, d5
    sub.l d3, d5
    mulu d5,d5
    bra Yvaluesubtract2
    d3Greater2:
    move.l d3, d5
    sub.l d1, d5
    mulu d5,d5
    *Old x subtract
    *move.l d3, d5
    *sub.l d1, d5
    *mulu d5,d5
    
    Yvaluesubtract2:
    cmp d4, d2
    bgt d2Greater2
    blt d4Greater2
    d2Greater2:
    move.l d2, d6
    sub.l d4, d6
    mulu d6,d6
    bra addYandX2
    d4Greater2:
    move.l d4, d6
    sub.l d2, d6
    mulu d6, d6
    *old y subtract
    *move.l d4, d6
    *sub.l d2,d6
    *mulu d6,d6
    
    addYandX2:
    add.l d6,d5
    
    cmp.l #DistanceForHit, d5
    blt HitPlayer2
   
    SkipObstacleCheck2:
    add.l #0, (a5)+ ;increment a5
    subi.b #1, d0 
    bne LoopThroughObstaclesCheck2
	
	rts
    
    *delete obstacle and subtract health from player also check if lost also clear bg for score
   HitPlayer2:
   *Clear Obstacle
    move.l (a5), d5
    move.w d5, d4 ;y obstacle
    asr.l #2, d4
    lsr.l #8, d5
    lsr.l #8, d5
    clr.l d3
    move.w d5, d3 ;x obstacle
    
    ***DRAW BG TODODODODODOD
     sub.l #28, sp        ;prepare stack for 7 4byte args
     lea background, a0       * Pointer to .bmp file
     move.l a0, (sp)
     move.l d3, 4(sp)     * Top, Left corner x bmp chunk
     move.l d4, 8(sp)     * Top, Left corner y bmp chunk
     move.l #ObstacleWidth, 12(sp)  * Width  of bitmap chunk to display
     move.l #ObstacleHeight, 16(sp)  * Height of bitmap chunk to display
     move.l d3, 20(sp)    * Top, Left corner x to display on output screen
     move.l d4, 24(sp)    * Top, Left corner y to display on output screen
     jsr DrawBitmap
     add.l #28, sp        *fix stack

    
   
   *Delete Obstacle
    move.l #$FFFFFFFF, (a5)
    
    *Clear BG Health counter
     sub.l #28, sp        ;prepare stack for 7 4byte args
     lea background, a0       * Pointer to .bmp file
     move.l a0, (sp)
     move.l #350, 4(sp)     * Top, Left corner x bmp chunk
     move.l #0, 8(sp)     * Top, Left corner y bmp chunk
     move.l #100, 12(sp)  * Width  of bitmap chunk to display
     move.l #50, 16(sp)  * Height of bitmap chunk to display
     move.l #350, 20(sp)    * Top, Left corner x to display on output screen
     move.l #0, 24(sp)    * Top, Left corner y to display on output screen
     jsr DrawBitmap
     add.l #28, sp        *fix stack
    
    lea Player2Health, a6
    move.l (a6), d6
    subi.l #1, d6
    beq PlayerTwoLose
    move.l d6, (a6)
    rts

PlayerTwoLose:
*Print player Two lost and allow reset !!! todo
*DrawPlayer1 Health
     jsr	swapBuffers
     move.l d6, (a6)
     movem.l ALL_REG,-(sp)
     sub.l #12, sp
     lea Player2Health, a2
     move.l (a2),(sp)          ;number to print on LED
     move.l #400, 4(sp)      ;xPos
     move.l #7, 8(sp)       ;yPos
     move.l #GREEN, 12(sp)
     jsr DrawSegmentLED
     add.l #12, sp           ;fix stack
     movem.l (sp)+,ALL_REG

*End Screen
        sub.l #28, sp        ;prepare stack for 7 4byte args
    
        lea player1Win, a0       * Pointer to .bmp file
        move.l a0, (sp)
    
        move.l #0, 4(sp)     * Top, Left corner x bmp chunk
        move.l #0, 8(sp)     * Top, Left corner y bmp chunk
    
        move.l #RIGHT_SIDE_OF_SCREEN, 12(sp)  * Width  of bitmap chunk to display
        move.l #BOTTOM_SCREEN, 16(sp)  * Height of bitmap chunk to display
    
        move.l #0, 20(sp)    * Top, Left corner x to display on output screen
        move.l #0, 24(sp)    * Top, Left corner y to display on output screen
    
        jsr DrawBitmap
        add.l #28, sp        *fix stack

        jsr	swapBuffers
 play2endloop:
 **Hit enter to restart**
    lea Player2Health, a6
    move.l #3, (a6) 
 
    move.l  #EnterKey,d1 ; check for keypress 
    move.b  #GET_USER_INPUT_COMMAND,d0
    TRAP    #15
    andi.l  #$FF,d1
    cmp.b #$FF, d1 ;check enter
    beq PreMainMenu
    
    bra play2endloop


*-------------------------------------------------------------------------------------

background INCBIN "spaceBG.bmp"
player INCBIN "astrop1.bmp"
player2 INCBIN "astrop2.bmp"
obstacle INCBIN "bad_notew.bmp"
player1Win INCBIN "Player1Wins.bmp"
player2Win INCBIN "Player2Wins.bmp"
titleScreen INCBIN "TitleScreen.bmp"
music dc.b 'lofimusic.wav',0

random INCLUDE "RandomNumber.x68"	
draw INCLUDE "DrawBMP.x68"
score INCLUDE "SevenSegmentLED.x68"

obstacles INCLUDE "ObstaclesSpawningOptimized.x68"

ObstaclesPointer ds.l totalObstacles
EndObstaclesPointer
NextSpawnTime ds.l 1
SecondsBetweenSpawn ds.l 1

ObstacleVelocity ds.l 1

PlayerHealth dc.l 3
PlayerX ds.l 1
PlayerY ds.l 1

Player2Health dc.l 3
Player2X ds.l 1
Player2Y ds.l 1
	
	
        END     START







































*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
