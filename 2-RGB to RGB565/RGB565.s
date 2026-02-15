**
**	$VER: RGB565.s v1.0 release (February 2026)
**	Platform: Apollo Vampire (SAGA Graphics)
**	Assemble command:
**				Programs:Developer/VASM/vasmm68k_mot RGB565.s -Fhunkexe
**	
**	Author: Tomas Jacobsen - Bedroomcoders.com
**	Description: 
**
**			This code build on previous examples and shows how to fill screen fast with any color as input.
**			In addition it shows how to convert one single RGB (24 bit) color to 16 bit RGB565.
**			Please mind that for superfast convertion of 2x2 32bit RGBA to RGB565 we would use the AMMX instruction PACK3216
**			That would be more suitable for converting a 24 bit image to 16 bits. 
**			but this code give better understanding of how it`s done.


			opt d+

			machine 68080						; NOTE - Tells the assembler to treat this source as 68080 code.

			incdir	"include:"
			include	"lvo/exec_lib.i"
			include	"exec/exec.i"

			output	RAM:RGB565					; Final code is saved to RAM-Disk


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
			
SCREEN_WIDTH	equ	1280
SCREEN_HEIGHT	equ	720
SCREEN_BPP	equ	2							; Bytes per pixel = 2 (16 bits screen or 1 word per pixel)



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


			move.l	#$44ff88,d0					; Red = $44, Green = $ff, Blue = $88
			bsr	_ConvertRGB565
			bsr	_ClearScreen					; d0 is returned from _ConvertRGB565

			
.lmbLoop		btst	#6,$bfe001					; Wait for left mousebutton
			bne.s	.lmbLoop

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



			; _ConvertRGB565
			;--------------------------------------------------------------
			; Input:
			;	d0.w = RGB888 - 24 bits color to convert
			; Result
			;	d0.w = RGB565 - 16 bits color

_ConvertRGB565		moveq	#0,d1
										; Red
			move.l	d0,d2						; d2 = 00RRGGBB (Red, Green, Blue)
			lsr.l	#8,d2						; d2 = RRGGBB00
			and.w	#%1111100000000000,d2				; d2 = 5 bits of R, rest is 0
			or.w	d2,d1
										; Green
			move.l	d0,d2						; d2 = 00RRGGBB
			lsr.l	#5,d2						; Shift Green to bits 5-10 (6 bits in total)
			and.w	#%0000011111100000,d2				; Mask out other colors
			or.w	d2,d1
										; Blue
			move.l	d0,d2						; d2 = 00RRGGBB
			lsr.w	#3,d2						; Shift Blue to bits 0-4 (5 bits)
			and.w	#%0000000000011111,d2				; Mask out other bits
			or.w	d2,d1						; d1 = combined result = RGB565

			move.l	d1,d0						; Return in d0
			rts
			


			; _ClearScreen
			;--------------------------------------------------------------
			; Input:
			;	d0.w = RGB565 color to clear screen with
						
_ClearScreen		movea.l	_ScreenPointer,a0

			move.w	d0,d1
			swap	d1
			move.w	d0,d1							; d1 = color repeated twice (32 bit)

			load	d1,e0
			lslq	#32,e0,e1						; shift low 32 bits of e0 to high 32 bits of e1
			por	e0,e1,e0						; combine e0 and e1. e0 = color repeated four times (64 bit)
			

			move.l	#((SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_BPP)/8)-1,d0	; Divide by 8 since we write 8 bytes for every iteration of the loop
.loop			store	e0,(a0)+						; Store command write 8 bytes (4 pixels) in one go
			dbf.l	d0,.loop						; dbf is running in second pipe and does not consume extra CPU time
			rts


			
			; Declaring data in code section for smaller pc-relative code.

			even							; Align data to avoid problems
			
_MemoryBuffer		ds.l	1
_ScreenPointer		ds.l	1						; Aligned and populated at runtime
store_dmacon		ds.w	1
store_gfxcon		ds.w	1
store_bplhmod		ds.w	1
store_bplhpth		ds.l	1
