**
**	$VER: TrappedBat.s v1.0 release (February 2026)
**	Platform: Apollo Vampire (SAGA Graphics)
**	Assemble command:
**				Programs:Developer/VASM/vasmm68k_mot TrappedBat.s -Fhunkexe
**	
**	Author: Tomas Jacobsen - Bedroomcoders.com
**	Description: 
**
**			This code build on previous examples and animates an image.
**			- Hardware is set up and closed just like previous examples
**			- The loop now syncronize with the Vertical Blank. This means 50 times per second on our 50hz screenmode
**			- The _AnimateBat function calculates the image movement.
**			- We clear the area before drawing the bat image on a new location to make sure no trails/garbage is left on the screen.
**			  Using a mask for this would be better/quicker - That is for another example

			opt d+

			machine 68080						; NOTE - Tells the assembler to treat this source as 68080 code.

			incdir	"include:"
			include	"lvo/exec_lib.i"
			include	"exec/exec.i"

			output	RAM:TrappedBat					; Final code is saved to RAM-Disk


POTGOR		equ	$dff016		
DMACON		equ	$dff096
DMACONR		equ	$dff002
GFXCON		equ	$dff1f4
GFXCONR		equ	$dfe1f4
BPLHMOD		equ	$dff1e6
BPLHMODR	equ	$dfe1e6
BPLHPTH		equ	$dff1ec
BPLHPTHR	equ	$dfe1ec
SPRHSTRT	equ	$dff1d0
INTREQ		equ	$dff09c
INTREQR		equ	$dff01e

			
SCREEN_WIDTH	equ	1280
SCREEN_HEIGHT	equ	720
SCREEN_BPP	equ	2							; Bytes per pixel = 2 (16 bits screen or 1 word per pixel)
BAT_WIDTH	equ	320
BAT_HEIGHT	equ	183



			section mycode,code

			
_Init			move.w	POTGOR,d0
			andi.w	#$fe,d0						; 0 = Paula, 1=Arne (Full SAGA Chipset)
			beq.s	.quit						; If no Vampire v4/SAGA Chipset is detected, quit and don`t tell anyone :-)

			movea.l	4.w,a6
			move.l	#(SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_BPP)+32,d0
			move.l	#MEMF_CLEAR!MEMF_PUBLIC,d1			; Cleared memory, SAGA Graphics don`t need chipram - NO LIMITS !!!
			jsr	_LVOAllocMem(a6)				; Allocate memory for screen buffer + 32 bytes for alignment
			move.l	d0,_MemoryBuffer(pc)
			beq	.quit

			jsr	_LVODisable(a6)

			move.w	DMACONR,store_dmacon(pc)
			move.w	GFXCONR,store_gfxcon(pc)
			move.w	BPLHMODR,store_bplhmod(pc)
			move.l	BPLHPTHR,store_bplhpth(pc)

			move.w	#$7fff,DMACON
			clr.l	SPRHSTRT
			move.w	#$0a02,GFXCON					; 0a = 1280x720, 02 = 16 bit chunky 
			clr.w	BPLHMOD

			move.l	_MemoryBuffer(pc),d0
			add.l	#31,d0
			and.l	#$ffffffe0,d0
			move.l	d0,_ScreenPointer(pc)				; This trick aligns the Screenpointer to 32 bytes in the Framebuffer = Quicker access to the data

			move.l  d0,BPLHPTH


			move.l	#200,_BatXPos(pc)
			move.l	#150,_BatYPos(pc)
			move.l	#2,_BatXSpeed(pc)
			move.l	#2,_BatYSpeed(pc)				; Set start position of our bat

.waitLoop		btst	#5,INTREQR+1					; Test low byte bit 5 to wait for Vertical Blank
			beq.s	.waitLoop
			move.w	#$0020,INTREQ					; Clear VBL

			bsr	_AnimateBat
			
			btst	#6,$bfe001					; Check for left mousebutton
			bne.s	.waitLoop


			or.w    #$8000,store_dmacon				; Set the highest bit to enable write access
			move.w	store_dmacon(pc),DMACON
			move.w	store_gfxcon(pc),GFXCON
			move.w	store_bplhmod(pc),BPLHMOD
			move.l	store_bplhpth(pc),BPLHPTH

			movea.l	4.w,a6
			jsr	_LVOEnable(a6)

			movea.l	_MemoryBuffer(pc),a1
			move.l	#(SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_BPP)+32,d0
			jsr	_LVOFreeMem(a6)

.quit			moveq	#0,d0
			rts



			; _AnimateBat
			;--------------------------------------------------------------
						
_AnimateBat		move.l	_BatXPos(pc),d0
			move.l	_BatYPos(pc),d1
			move.l	#BAT_WIDTH,d2
			move.l	#BAT_HEIGHT,d3
			bsr	_ClearArea					; Read the bat's previous position and clear the area

			move.l	_BatXPos(pc),d0
			move.l	_BatYPos(pc),d1
			move.l	_BatXSpeed(pc),d2
			move.l	_BatYSpeed(pc),d3
			
			add.l	d2,d0						; Moves X position by given X speed
			add.l	d3,d1						; Moves Y position by given Y speed

			cmp.l	#SCREEN_WIDTH-BAT_WIDTH,d0			; Compare current X position with screens right edge - width of bat
			bge.s	.flipX
			cmp.l	#0,d0						; Compare current X position with screens left edge
			ble.s	.flipX
			
.doneX			cmp.l	#SCREEN_HEIGHT-BAT_HEIGHT,d1			; Compare current Y position with screens bottom edge - height of bat
			bge.s	.flipY
			cmp.l	#0,d1						; Compare current Y position with screens top edge
			ble.s	.flipY
			
.doneY			move.l	d0,_BatXPos(pc)
			move.l	d1,_BatYPos(pc)
			move.l	d2,_BatXSpeed(pc)
			move.l	d3,_BatYSpeed(pc)
			bsr	_DrawBat					; Draw bat at new position
			rts

.flipX			neg.l	d2						; X hit left or right edge. Reverse speed
			bra.s	.doneX

.flipY			neg.l	d3						; Y hit top or bottom edge. Reverse speed
			bra.s	.doneY



			; _DrawBat - Fast copy since we know the Image is divideable by 8
			;----------------------------------------------------------------
			; Inoput:
			;	d0 = X Pos
			;	d1 = Y Pos

_DrawBat		lea	_BatImage,a0
			movea.l	_ScreenPointer(pc),a1
			
			add.l	d0,d0						; Multiply X by 2 to get position in 16 bit word
			mulu.l	#SCREEN_WIDTH*2,d1				; Multiply Y by Screens width in 16 bit word
			add.l	d1,d0
			add.l	d0,a1						; a1 = start position
			
			move.l	#BAT_HEIGHT-1,d0
.drawYLoop		move.l	#BAT_WIDTH/8-1,d1				; Divide by 8 since we are writing 8 pixles per iteration of the loop
.drawXLoop		move16	(a0)+,(a1)+					; Copy 16 bytes = 8 pixels in one go
			dbf	d1,.drawXLoop
			add.l	#(SCREEN_WIDTH*2)-(BAT_WIDTH*2),a1		; Find position in memory for the next line
			dbf	d0,.drawYLoop			
			rts



			; _ClearArea
			;--------------------------------------------------------------
			; Input:
			;	d0 = X position
			;	d1 = Y position
			;	d2 = Width
			;	d3 = Height
						
_ClearArea		movea.l	_ScreenPointer(pc),a0

			add.l	d0,d0						; d0 = d0 * 2 - Convert pixel position to word
			mulu.l	#SCREEN_WIDTH*2,d1
			add.l	d1,d0
			add.l	d0,a0						; a0 = start position
			
			
			move.l	#SCREEN_WIDTH*2,d5
			sub.l	d2,d5
			sub.l	d2,d5						; d5 = number of byte to next line

			divu.l	#8,d2
			move.l	d2,d4						; X times in loop in both d2 and d4

			load	#0,e0
			
.loop			store	e0,(a0)+
			store	e0,(a0)+
			subq.l	#1,d2
			tst.l	d2
			bne.s	.loop
			add.l	d5,a0						; Place pointer at start of next line
			move.l	d4,d2						; Reset X counter
			subq.l	#1,d3
			tst.l	d3
			bne.s	.loop
			rts

			
			
			; Declaring data in code section for smaller pc-relative code.

			even							; Align data to avoid problems
			
_MemoryBuffer		ds.l	1
_ScreenPointer		ds.l	1						; Aligned and populated at runtime
store_dmacon		ds.w	1
store_gfxcon		ds.w	1
store_bplhmod		ds.w	1
store_bplhpth		ds.l	1
_BatXPos		ds.l	1
_BatYPos		ds.l	1
_BatXSpeed		ds.l	1
_BatYSpeed		ds.l	1

			section	mydata,data

_BatImage		incbin	"Bat320x183.raw"
