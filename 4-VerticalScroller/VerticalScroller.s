**
**	$VER: VerticalScroller.s v1.0 release (February 2026)
**	Platform: Apollo Vampire (SAGA Graphics)
**	Assemble command:
**				Programs:Developer/VASM/vasmm68k_mot VerticalScroller.s -Fhunkexe
**	
**	Author: Tomas Jacobsen - Bedroomcoders.com
**	Description: 
**
**			This code build on previous examples and and copy a large image from our data section to the allocated screen.
**			Further it shows a classic hardware trick that is available on many computer platform, Vertical scroll without moving any data.
**			The Screens buffer containing the image is larger than the screen resolution, and only a portion of it is displayed.
**			By manipulating the screenpointer (where we tell the hardware to show data on screen), we can create the effect of
**			scrolling up and down or image.


			opt d+

			machine 68080						; NOTE - Tells the assembler to treat this source as 68080 code.

			incdir	"include:"
			include	"lvo/exec_lib.i"
			include	"exec/exec.i"

			output	RAM:VerticalScroller				; Final code is saved to RAM-Disk


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
SCREEN_HEIGHT	equ	3200
SCREEN_BPP	equ	2							; Bytes per pixel = 2 (16 bits screen or 1 word per pixel)
IMAGE_HEIGHT	equ	3200
IMAGE_WIDTH	equ	1280
VIEW_HEIGHT	equ	720


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


			bsr	_CopyImageToScreen

			move.l	#0,_ViewOffset
			move.l	#1,_YDirection


.waitLoop		btst	#5,INTREQR+1					; Test low byte bit 5 to wait for Vertical Blank
			beq.s	.waitLoop
			move.w	#$0020,INTREQ					; Clear VBL

			bsr	_AnimateViewPort
			
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



			; _CopyImageToScreen
			;--------------------------------------------------------------
						
_CopyImageToScreen	lea	_Image,a0
			movea.l	_ScreenPointer(pc),a1
			move.l	#((IMAGE_WIDTH/8)*IMAGE_HEIGHT)-1,d0
.copy			move16	(a0)+,(a1)+
			dbf.l	d0,.copy			
			rts



			; _AnimateViewPort
			;--------------------------------------------------------------
						
_AnimateViewPort	movea.l	_ScreenPointer(pc),a0
			move.l	_ViewOffset(pc),d0
			mulu.l	#SCREEN_WIDTH*2,d0
			
			add.l	d0,a0
			move.l	a0,BPLHPTH
			
			move.l	_ViewOffset(pc),d0
			move.l	_YDirection(pc),d1
			add.l	d1,d0
			cmp.l	#SCREEN_HEIGHT-VIEW_HEIGHT,d0
			bge.s	.flipY
			cmp.l	#0,d0
			ble.s	.flipY

.done			move.l	d0,_ViewOffset(pc)
			rts

.flipY			neg.l	_YDirection(pc)
			bra.s	.done



			; Declaring data in code section for smaller pc-relative code.

			even							; Align data to avoid problems
			
_MemoryBuffer		ds.l	1
_ScreenPointer		ds.l	1						; Aligned and populated at runtime
store_dmacon		ds.w	1
store_gfxcon		ds.w	1
store_bplhmod		ds.w	1
store_bplhpth		ds.l	1
_ViewOffset		ds.l	1
_YDirection		ds.l	1


			section	mydata,data
_Image			incbin	"Workers-1280x3200.raw"

