*-----------------------------------------------------------
* Title      : Obstacle Spawning For SpaceWavez Assembly
* Written by : Dylan Aron
* Date       : 10/18/22
* Description: Subroutine for random obstacle spawning above
*
*   Stores all obstacles in a list and handles updating and spawning in random positions based on given parameters in the main function
*   for timebetweenspawning, obstacle size, total obstacles to spawn, and their velocity. Each time they spawn, spawn time increases, and velocity increases.
*-----------------------------------------------------------
*START   ORG     $1000


SET_PEN_COLOR_COMMAND   equ     80
SET_FILL_COLOR_COMMAND  equ     81
DRAW_CIRCLE_COMMAND     equ     88

CLEAR_SCREEN_COMMAND    equ     11
CLEAR_SCREEN_MAGIC_VAL  equ     $FF00
DRAWING_MODE_TRAP_CODE	equ	    92
DOUBLE_BUFFERED_MODE	equ 	17
REPAINT_SCREEN_TRAP_CODE	equ	94




RED             equ $000000FF
WHITE			equ	$00FFFFFF

ALL_REG         REG     D0-D7/A0-A6




          
ObstacleSpawning:

    lea NextSpawnTime, a3
    lea ObstaclesPointer,a5
    
    move.l (a3), d6   
    
    move.l a5, a4 ; a5 always store the ref to start of obstacles
    move.l #(EndObstaclesPointer-ObstaclesPointer)/4, d0
  LoopThroughObstacles:
    ;;obstacle long stored as XXXXYYYY 
    move.l (a4), d1
    
    jsr MaybeInstantiate
    *if we do not decide to Instantiate then skip   
    cmp #$FFFFFFFF, d1
    beq Skip
    
    move.w d1, d5 ;y value
    lsr.l #8, d1
    lsr.l #8, d1
    move.w d1, d7 ;x value
    
    jsr updateObstacle

    ;movem.l ALL_REG, -(sp)
    move.l d0, -(sp)
    jsr drawObstacle
    move.l (sp)+,d0
    ;movem.l (sp)+, ALL_REG

    Skip:
    add.l #0, (a4)+ ;increment a4
    subi.b #1, d0 
    bne LoopThroughObstacles
	
	rts

;Time+Timebtwn set in d6 compare that with cur time got in d1
MaybeInstantiate:
    cmp #$FFFFFFFF, d1
    bne DontNeedInstantiate
    
    move.l d0, -(sp)
    move.l  #8,d0		;trap code to get timer into D1
    trap	#15			;timer is in hundredths of seconds since midnight
    move.l (sp)+,d0
    cmp.l d1, d6
    blt InitializeObstacle
    
    DontNeedInstantiate:
    rts 



InitializeObstacle
        *Make obstacles get faster
        lea ObstacleVelocity, a1
        add.l #1, (a1)



        lea SecondsBetweenSpawn, a1
        sub.l #1, (a1)
        add.l (a1), d1 ;update new time to check
        move.l d1,d6
        move.l d6, (a3)
	    *initialize x position and x velocity
	    
	    
	    *Random x position
	    move.l d6, -(sp)
	    jsr getRandomByteIntoD6 ;only goes up to 255 rn make it go throughout width of screen
	    
	    mulu #RandomOffset, d6
	    
	    move.l	d6,d7     
	    
	    move.l (sp)+,d6
        
        *set y position and height
        move.l	#ObstacleTopYPos,d2
	    move.l	d2,d4
        add.l	#ObstacleHeight,d4
        
      	
      	move.l  #ObstacleStartVelocity, d5  ;obstacle falling
      	
      	move.l d7, d1
	    lsl.l #8, d1
	    lsl.l #8, d1
	    move.w d5, d1
	    move.l d1, (a4)
        
        rts 
	
	
updateObstacle:
    move.l (a4), d1
    cmp #$FFFFFFFF, d1
    beq DontNeedInstantiate

    clr.l d5
    move.w d1, d5 ;y value
    lsr.l #8, d1
    lsr.l #8, d1
    move.w d1, d7 ;x value

    ;add.l	d6,d7 ;x not moving
    lea ObstacleVelocity, a1
    move.l  (a1), d4 ;obstacle always falling down
    add.l   d4,d5 ;Falling y
	
	cmpi.l #(BOTTOM_SCREEN-ObstacleHeight+50)<<2,d5 ;check bottom screen ;was 8?? lowered to 4 for fix pt math cuz overflow with 8
	bge VerticalBoundsObstacle
	
	;set obstacle properly
	
	move.l d7, d1
	lsl.l #8, d1
	lsl.l #8, d1
	move.w d5, d1
	move.l d1, (a4)
	
	rts
	;bra YesDraw
	
    VerticalBoundsObstacle: ;reset and set obstacle to 0
    move.l #$FFFFFFFF, (a4)
    rts
    ;bra NoDraw
	
	
	
*Draw obstacle sprite & small chunks of bg around sprite
drawObstacle
    *draw each sliver of background around obstacle------------------------------*
    *d7 is x pos & d5 is ypos
    move.l	d7,d1
    move.l d5, d2
    asr.l #2, d2 ;was 8??
    *---above---------
    
    movem.l ALL_REG,-(sp)
    sub.l #28, sp        ;prepare stack for 7 4byte args
    lea background, a0       * Pointer to .bmp file
    move.l a0, (sp)
    sub.l #5, d1
    bmi SkipAboveDraw2
    move.l d1, 4(sp)     * Top, Left corner x bmp chunk
    sub.l #30, d2
    bmi SkipAboveDraw2    *check if out of bounds
    move.l d2, 8(sp)     * Top, Left corner y bmp chunk
    move.l #ObstacleWidth+10, 12(sp)  * Width  of bitmap chunk to display
    move.l #30, 16(sp)  * Height of bitmap chunk to display
    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
    jsr DrawBitmap
    SkipAboveDraw2:
    add.l #28, sp        *fix stack
    movem.l (sp)+,ALL_REG    


	***DRAW Obstacle---------------------
	move.l	d7,d1
    move.l d5, d2
    asr.l #2, d2 ;2 fractional bits
    
    movem.l ALL_REG,-(sp)
*    sub.l #28, sp        ;prepare stack for 7 4byte args
*    lea obstacle, a0       * Pointer to .bmp file
*    move.l a0, (sp)
*    move.l #0, 4(sp)     * Top, Left corner x bmp chunk
*    move.l #0, 8(sp)     * Top, Left corner y bmp chunk
*    move.l #ObstacleWidth, 12(sp)  * Width  of bitmap chunk to display
*    move.l #ObstacleHeight, 16(sp)  * Height of bitmap chunk to display
*    move.l d1, 20(sp)    * Top, Left corner x to display on output screen
*    move.l d2, 24(sp)    * Top, Left corner y to display on output screen
    
*    jsr DrawBitmap
*    add.l #28, sp        *fix stack

* Draw Circle Instead because drawing obstacle sprite was too laggy
    move.l	#RED,d1
	move.b	#SET_PEN_COLOR_COMMAND,d0
	trap	#15
	move.b	#SET_FILL_COLOR_COMMAND,d0
	trap	#15
	
	move.b	#DRAW_CIRCLE_COMMAND,d0
	move.l	d7,d1
	move.l	d1,d3
	add.l	#ObstacleWidth,d3

    move.l d5, d2
    asr.l   #2, d2
    move.l d2, d4
    add.l #ObstacleHeight, d4 
		
	trap	#15

    

    movem.l (sp)+,ALL_REG


	rts
	*------------------------------------------------------------

	
*obstacle INCBIN "bad_notew.bmp"
*background INCBIN "spaceBG.bmp"
*draw INCLUDE "DrawBMP.x68"
	
*ObstaclesPointer: ds.l totalObstacles
*EndObstaclesPointer:

*random INCLUDE "RandomNumber.x68"

	
 *       END     START

























*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
