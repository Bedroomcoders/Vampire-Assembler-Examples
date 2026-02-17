**
**	$VER: TinyBeatbox.s v1.0 release (February 2026)
**	Platform: Apollo Vampire (SAGA Graphics)
**	Assemble command:
**				Programs:Developer/VASM/vasmm68k_mot TinyBeatbox.s -Fhunkexe
**	
**	Author: Tomas Jacobsen - Bedroomcoders.com
**	Description: 
**
**			Here we are upping the game slightly. This code will:
**			- Init hardware and open screen like previous examples
**			- Copy Logo and buttons to the screen
**			- Convert audio samples from a PC`s little endian format to Amiga`s big endian format
**			- Use the Vertical blank loop to sync a 125 Beat per minute Kickdrum
**			- Read keyboard input to let user play hihats, clap, snare and maracas
**			- Exit cleanly when ESC or Left mousebutton is pressed


			opt d+

			machine 68080						; NOTE - Tells the assembler to treat this source as 68080 code.

			incdir	"include:"
			include	"lvo/exec_lib.i"
			include	"exec/exec.i"

			output	RAM:TinyBeatbox


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
AUD0L		equ	$dff400
DMACON2		equ	$dff296
CIAAPRA		equ	$bfe001
CIAASDR		equ	$bfec01
CIAACRA		equ	$bfee01




			
SCREEN_WIDTH	equ	1280
SCREEN_HEIGHT	equ	720
SCREEN_BPP	equ	2							; Bytes per pixel = 2 (16 bits screen or 1 word per pixel)

KICK_SIZE		equ	audio_Kick_End-audio_Kick
OPENHIHAT_SIZE		equ	audio_OpenHihat_End-audio_OpenHihat
CLOSEDHIHAT_SIZE	equ	audio_ClosedHihat_End-audio_ClosedHihat
SNARE_SIZE		equ	audio_Snare_End-audio_Snare
CLAP_SIZE		equ	audio_Clap_End-audio_Clap
MARACAS_SIZE		equ	audio_Maracas_End-audio_Maracas


PAD_WIDTH	equ 	208
PAD_HEIGHT	equ	170


			section mycode,code

			
_Init			move.w	POTGOR,d0
			andi.w	#$fe,d0						; 0 = Paula, 1=Arne (Full SAGA Chipset)
			beq	.quit						; If no Vampire v4/SAGA Chipset is detected, quit and don`t tell anyone :-)

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


			bsr	_BuildGraphics					; Draw Logo and buttons on screen
			bsr	_ConvertAllSamples				; Convert samples to Amiga format

			bsr	_MainLoop

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



			; _MainLoop
			;--------------------------------------------------------------
			;
			; We sync to VBL (50hz). 50 hz * 60 second = 3000 iterations of the loop per minute
			; We want a beat synced to 125 beats per minute and want to be able to play each quarter note
			; 125 BPM * 4 quarter notes = 500 ticks.
			; 3000 VBL / 500 ticks = 6 frames per quarter note

_MainLoop		move.l	#0,_Quit(pc)			
			move.l	#0,_QuarterNote_Counter(pc)

.exitLoop		moveq	#6-1,d0
.timingLoop		btst	#5,INTREQR+1
			beq.s	.timingLoop
			move.w	#$0020,INTREQ
			dbf	d0,.timingLoop					; Wait 6 frames
			
			
			cmp.l	#0,_QuarterNote_Counter				; Only play Kickdrum on first quarter note
			bne.s	.noKickdrum
			moveq	#0,d0
			bsr	_StopAudio					; Stop sound on channel 0
			lea	audio_Kick,a0
			move.l	#KICK_SIZE,d0
			moveq	#0,d1						; Audio channel 0-15
			move.l	#$ffff,d2					; Volume left/right
			bsr	_PlayAudio					; Play kick on channel 0

.noKickdrum		bsr	_KeyboardHandler				; Perform actions depending on keypresses

			addq.l	#1,_QuarterNote_Counter
			cmp.l	#3,_QuarterNote_Counter
			ble.s	.noReset
			move.l	#0,_QuarterNote_Counter

.noReset		cmp.l	#1,_Quit(pc)
			beq.s	.exit

			btst	#6,CIAAPRA					; Check for left mousebutton
			bne.s	.exitLoop

.exit			rts



			; _KeyboardHandler
			;--------------------------------------------------------------

_KeyboardHandler	bsr	_ReadKeyboard

			cmp.b	#$45,d0						; ESC key
			bne.s	.noESC
			move.l	#1,_Quit(pc)
			
.noESC			cmp.b	#$01,d0						; 1 Key
			bne.s	.not1
			moveq	#1,d0
			bsr	_StopAudio
			lea	audio_OpenHihat,a0
			move.l	#OPENHIHAT_SIZE,d0
			moveq	#1,d1						; Audio channel 0-15
			move.l	#$ffff,d2					; Volume left/right
			bsr	_PlayAudio
			
.not1			cmp.b	#$02,d0						; 2 Key
			bne.s	.not2
			moveq	#2,d0
			bsr	_StopAudio
			lea	audio_ClosedHihat,a0
			move.l	#CLOSEDHIHAT_SIZE,d0
			moveq	#2,d1						; Audio channel 0-15
			move.l	#$ffff,d2					; Volume left/right
			bsr	_PlayAudio
			
.not2			cmp.b	#$03,d0						; 3 Key
			bne.s	.not3
			moveq	#3,d0
			bsr	_StopAudio
			lea	audio_Snare,a0
			move.l	#SNARE_SIZE,d0
			moveq	#3,d1						; Audio channel 0-15
			move.l	#$ffff,d2					; Volume left/right
			bsr	_PlayAudio
			
.not3			cmp.b	#$04,d0						; 4 Key
			bne.s	.not4
			moveq	#4,d0
			bsr	_StopAudio
			lea	audio_Clap,a0
			move.l	#CLAP_SIZE,d0
			moveq	#4,d1						; Audio channel 0-15
			move.l	#$ffff,d2					; Volume left/right
			bsr	_PlayAudio
			
.not4			cmp.b	#$05,d0						; 5 Key
			bne.s	.not5
			moveq	#5,d0
			bsr	_StopAudio
			lea	audio_Maracas,a0
			move.l	#MARACAS_SIZE,d0
			moveq	#5,d1						; Audio channel 0-15
			move.l	#$ffff,d2					; Volume left/right
			bsr	_PlayAudio
			
.not5			rts
			
			

			; _ReadKeyboard
			;--------------------------------------------------------------
			;
			; Output:
			;	d0 = Keycode
			
_ReadKeyboard
			move.b	CIAASDR,d0					; Read from keyboard serial interface
			bset	#6,CIAACRA					
			ror.b	#1,d0
			not.b	d0

			moveq	#50,d1
.waitLoop		tst.b	CIAAPRA
			dbf	d1,.waitLoop					; System needs a wait before clearing the data
			
			bclr	#6,CIAACRA
			rts

			
			
			; _PlayAudio
			;--------------------------------------------------------------
			; INPUT:
			;	a0 = Sample/Audio to play (16-bit, 44.1Khz, RAW bigendian format)
			;	d0 = Sample size in bytes
			;	d1 = Channel - Number between 0 and 15
			;	d2 = Volume - Word with left and right volume in each byte. d2=$80ff would pan volume slightly to the right
			
_PlayAudio		movem.l	d0-d3/a0-a1,-(sp)

			move.l	d1,d3						; Save channel in d3

			movea.l	#AUD0L,a1					; Base address of channel 0
			lsl.l	#4,d1						; Muliply channel by 16 to find byte offset
			add.l	d1,a1						; a1 = base of selected channel

			lsr.l	#2,d0						; Divide by 4 to get lenght in pairs of 16 bit samples
			
			move.l	a0,(a1)						; AUDxL 	- Set audio sample
			move.l	d0,$4(a1)					; AUDxLEN 	- Lenght
			move.w	d2,$8(a1)					; AUDxVOL 	- Volume
			move.w	#80,$c(a1)					; AUDxPER 	- Set 44.1Khz sample rate\
			move.w	#3,$a(a1)					; AUDxCTRL	- Set 16 bit mono - Play sample once
			
			cmp.l	#3,d3
			bgt.s	.highChannel
			move.w	#$8200,d0					; Prepare to set bit 15 and enable DMA
			bset	d3,d0						; Set 0,1,2, or 3 depending on selected channel
			move.w	d0,DMACON					; Start playing
			
			bra.s	.done
			
.highChannel		subq.w	#4,d3						; Channel 4 starts at bit 0
			move.w	#$8000,d0					; Set bit 15
			bset	d3,d0						
			move.w	d0,DMACON2
			move.w	#$8200,DMACON					; DMACON is used to start sound even for higher channels
			
.done			movem.l	(sp)+,d0-d3/a0-a1
			rts



			; _StopAudio
			;--------------------------------------------------------------
			; INPUT:
			;	d0 = Channel - Number between 0 and 15
			
_StopAudio		movem.l	d0-d3/a0-a1,-(sp)

			move.l	d0,d3						; Save channel in d3

			cmp.l	#3,d3
			bgt.s	.highChannel
			moveq	#0,d0						; Clear bit 15
			bset	d3,d0						; Set 0,1,2, or 3 depending on selected channel
			move.w	d0,DMACON					; Stop audio on channel
			
			bra.s	.done
			
.highChannel		subq.w	#4,d3						; Channel 4 starts at bit 0
			moveq	#0,d0						; Clear bit 15
			bset	d3,d0
			move.w	d0,DMACON2					; Stop any audio on this channel
			move.w	#$8200,DMACON					; Do it!

.done			moveq	#50,d1
.waitLoop		tst.b	CIAAPRA
			dbf	d1,.waitLoop					; System needs to wait a bit before new sound can be set on this channel
			
			movem.l	(sp)+,d0-d3/a0-a1
			rts



			; _ConvertAllSamples
			;---------------------------------------------------------------------

_ConvertAllSamples	lea	audio_Kick,a0
			move.l	#KICK_SIZE,d0
			bsr	_SwapEndian

			lea	audio_OpenHihat,a0
			move.l	#OPENHIHAT_SIZE,d0
			bsr	_SwapEndian

			lea	audio_ClosedHihat,a0
			move.l	#CLOSEDHIHAT_SIZE,d0
			bsr	_SwapEndian
			
			lea	audio_Snare,a0
			move.l	#SNARE_SIZE,d0
			bsr	_SwapEndian
			
			lea	audio_Clap,a0
			move.l	#CLAP_SIZE,d0
			bsr	_SwapEndian

			lea	audio_Maracas,a0
			move.l	#MARACAS_SIZE,d0
			bsr	_SwapEndian
			rts



			; _SwapEndian - Convert between PC and Amiga format (Little<->Bigendian)
			;---------------------------------------------------------------------
			; Input:
			;   a0 = Sample data
			;   d0 = Size in bytes

_SwapEndian		

			lsr.l	#1,d0				; Divide by 2
			subq.l	#1,d0				; Sub 1 to prevent overflow on dbf.l

.loop			move.w	(a0),d1
			movex.w	d1,d1
			move.w	d1,(a0)+
			dbf.l	d0,.loop
			rts



			; _BuildGraphics - Draw initial graphic elements
			;---------------------------------------------------------------------

_BuildGraphics
			lea	gfx_TinyBeatBoxLogo,a0
			move.l	#280,d0
			move.l	#50,d1
			move.l	#720,d2
			move.l	#130,d3
			bsr	_DrawImage16					; Draw Logo

			lea	gfx_Pad1,a0
			move.l	#70,d0
			move.l	#250,d1
			move.l	#PAD_WIDTH,d2
			move.l	#PAD_HEIGHT,d3
			bsr	_DrawImage16					; Draw Pad1

			lea	gfx_Pad2,a0
			move.l	#298,d0
			move.l	#250,d1
			move.l	#PAD_WIDTH,d2
			move.l	#PAD_HEIGHT,d3
			bsr	_DrawImage16					; Draw Pad2

			lea	gfx_Pad3,a0
			move.l	#526,d0
			move.l	#250,d1
			move.l	#PAD_WIDTH,d2
			move.l	#PAD_HEIGHT,d3
			bsr	_DrawImage16					; Draw Pad3

			lea	gfx_Pad4,a0
			move.l	#754,d0
			move.l	#250,d1
			move.l	#PAD_WIDTH,d2
			move.l	#PAD_HEIGHT,d3
			bsr	_DrawImage16					; Draw Pad4

			lea	gfx_Pad5,a0
			move.l	#982,d0
			move.l	#250,d1
			move.l	#PAD_WIDTH,d2
			move.l	#PAD_HEIGHT,d3
			bsr	_DrawImage16					; Draw Pad5

			rts



			; _DrawImage16 - Copy 16 bit image to screen.
			;---------------------------------------------------------------------
			; Input:
			;	Coordinates and size is defined in pixels
			;
			;	a0 = Image
			;	d0 = X position
			;	d1 = Y position
			;	d2 = Width - Must be dividable by 8
			;	d3 = Height

_DrawImage16		movem.l	d0-d4/a0-a1,-(sp)

			movea.l	_ScreenPointer(pc),a1
			add.l	d0,d0						; Multiply X by 2 to get position in 16 bit word
			mulu.l	#SCREEN_WIDTH*SCREEN_BPP,d1			; Multiply Y by Screens width in 16 bit word
			add.l	d1,d0						; Add offset
			add.l	d0,a1						; a1 = Start position in memory
			
			move.l	d3,d0
			subq.l	#1,d0						; Substract 1 to prevent overflow in dbf
.yLoop			move.l	d2,d1
			lsr.l	#3,d1						; Divide by 8 since we are writing 8 pixels in one go
			subq.l	#1,d1						; Substract 1 to prevent overflow in dbf
.xLoop			move16	(a0)+,(a1)+
			dbf.l	d1,.xLoop
			move.l	#SCREEN_WIDTH*SCREEN_BPP,d4
			sub.l	d2,d4
			sub.l	d2,d4
			add.l	d4,a1						; a1 = position of next line to copy
			dbf.l	d0,.yLoop			

			movem.l	(sp)+,d0-d4/a0-a1
			rts



			; Declaring data in code section for smaller pc-relative code.

			even							; Align data to avoid problems
			
_MemoryBuffer		ds.l	1
_ScreenPointer		ds.l	1						; Aligned and populated at runtime
_Quit			ds.l	1
_QuarterNote_Counter	ds.l	1
store_dmacon		ds.w	1
store_gfxcon		ds.w	1
store_bplhmod		ds.w	1
store_bplhpth		ds.l	1



			section	mydata,data

audio_Kick		incbin	"audio/808 Kick.raw"
audio_Kick_End

audio_OpenHihat		incbin	"audio/808 Open Hihat.raw"
audio_OpenHihat_End

audio_ClosedHihat	incbin	"audio/808 Closed Hihat.raw"
audio_ClosedHihat_End

audio_Snare		incbin	"audio/808 Snare.raw"
audio_Snare_End

audio_Clap		incbin	"audio/808 Clap.raw"
audio_Clap_End

audio_Maracas		incbin	"audio/808 Maracas.raw"
audio_Maracas_End




gfx_TinyBeatBoxLogo	incbin	"graphics/tinybeatboxlogo-720x130.raw"
gfx_Pad1		incbin	"graphics/pad1-208x172.raw"
gfx_Pad2		incbin	"graphics/pad2-208x172.raw"
gfx_Pad3		incbin	"graphics/pad3-208x172.raw"
gfx_Pad4		incbin	"graphics/pad4-208x172.raw"
gfx_Pad5		incbin	"graphics/pad5-208x172.raw"
