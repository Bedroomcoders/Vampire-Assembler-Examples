**
**	$VER: BlueScreenFast.s v1.0 release (February 2026)
**	Platform: Apollo Vampire (SAGA Graphics)
**	Assemble command:
**				Programs:Developer/VASM/vasmm68k_mot BlueScreenFast.s -Fhunkexe
**	
**	Author: Tomas Jacobsen - Bedroomcoders.com
**	Description: 
**			This small code demonstrates how to :
**			- Check if we are running on a compatible Vampire (v4)
**			- Allocate memory for our screen buffer
**			- Align screen buffer data to 32 bytes for quick write access by the 68080
**			- Freeze OS for our complete control of the hardware
**			- Open a SAGA screen of 1280x720 resolution in 16 bit.
**			- Fill screen with blue color using a 68080 optimized loop
**			- Wait for user to press left mousebutton
**			- Free memory and return to OS in a clean manner
**
**


			opt d+							; Debug information is included in final code. Delete for release code.

			machine 68080						; NOTE - Tells the assembler to treat this source as 68080 code.

			incdir	"include:"					; I prefer to create an assign to my include files
			include	"lvo/exec_lib.i"				; Include definitions of exec.library functions
			include	"exec/exec.i"

			output	RAM:BlueScreenFast				; Final code is saved to RAM-Disk


			; Let`s name the hardware registers for easier use - Constants are usually defined in upper case characters
			; Registers with an R added to the name are Read registers
			
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

			; Other constants
			
SCREEN_WIDTH	equ	1280
SCREEN_HEIGHT	equ	720
SCREEN_BPP	equ	2							; Bytes per pixel = 2 (16 bits screen or 1 word per pixel)



			section mycode,code

			
_Init			move.w	POTGOR,d0
			andi.w	#$fe,d0						; 0 = Paula, 1=Arne (Full SAGA Chipset)
			beq.s	.quit						; If no Vampire v4/SAGA Chipset is detected, quit and don`t tell anyone :-)
			
			movea.l	4.w,a6						; a6 = ExecBase
			move.l	#(SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_BPP)+32,d0
			move.l	#MEMF_CLEAR!MEMF_PUBLIC,d1			; Cleared memory, SAGA Graphics don`t need chipram - NO LIMITS !!!
			jsr	_LVOAllocMem(a6)				; Allocate memory for screen buffer + 32 bytes for alignment
			move.l	d0,_MemoryBuffer(pc)
			beq	.quit

			jsr	_LVODisable(a6)					; Disable all interrupts and task scheduling

			move.w	DMACONR,store_dmacon(pc)			; Save current DMA register
			move.w	GFXCONR,store_gfxcon(pc)			; Save current screen resolution - NOTE 16 bit register (move.w)
			move.w	BPLHMODR,store_bplhmod(pc)			; Save current modulo
			move.l	BPLHPTHR,store_bplhpth(pc)			; Save current bitplane pointer - NOTE 32 bit register (move.l)

			move.w	#$7fff,DMACON					; Disable all DMA (Interrups, audio, disk, etc)
			clr.l	SPRHSTRT					; Clear mousepointers sprite
			move.w	#$0a02,GFXCON					; 0a = 1280x720, 02 = 16 bit chunky 
			clr.w	BPLHMOD						; Clear modulo

			move.l	_MemoryBuffer(pc),d0
			add.l	#31,d0
			and.l	#$ffffffe0,d0
			move.l	d0,_ScreenPointer(pc)				; This trick aligns the Screenpointer to 32 bytes in the Framebuffer = Quicker access to the data

			move.l  d0,BPLHPTH					; Writes our aligned screenpointer to BPLHPTH and the hardware displays the data on screen

			bsr	_BlueScreen
			
.lmbLoop		btst	#6,$bfe001					; Wait for left mousebutton
			bne.s	.lmbLoop

			or.w    #$8000,store_dmacon				; Set the highest bit to enable write access
			move.w	store_dmacon(pc),DMACON				; Restore DMA to previous settings
			move.w	store_gfxcon(pc),GFXCON				; Restore graphics resolution
			move.w	store_bplhmod(pc),BPLHMOD			; Restore modulo
			move.l	store_bplhpth(pc),BPLHPTH			; Restore bitplane pointer

			movea.l	4.w,a6
			jsr	_LVOEnable(a6)					; Enable interrupts and task scheduling before returning to OS.

			movea.l	_MemoryBuffer(pc),a1
			move.l	#(SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_BPP)+32,d0
			jsr	_LVOFreeMem(a6)

.quit			moveq	#0,d0
			rts



			; _BlueScreen - Fills framebuffer with blue pixels the fast way
			;--------------------------------------------------------------
			
_BlueScreen		
			movea.l	_ScreenPointer(pc),a0
			load	#$001f001f001f001f,e0					; Blue color 4 times in the 64-bit register
			move.l	#((SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_BPP)/8)-1,d0	; Divide by 8 since we write 8 bytes for every iteration of the loop

.loop			store	e0,(a0)+						; Store command write 8 bytes (4 pixels) in one go
			dbf.l	d0,.loop						; dbf is running in second pipe and does not consume extra CPU time
											; 8 bytes are stored every clock cycle
			rts
			
			
			
			; Declaring data in code section for smaller pc-relative code.

			even							; Align data to avoid problems
			
_MemoryBuffer		ds.l	1
_ScreenPointer		ds.l	1						; Aligned and populated at runtime
store_dmacon		ds.w	1						; Reserve 1 word of data (16 bits)
store_gfxcon		ds.w	1 						
store_bplhmod		ds.w	1						
store_bplhpth		ds.l	1						; Reserve 1 long word of data (32 bits)
