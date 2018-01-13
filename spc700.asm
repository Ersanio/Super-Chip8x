;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SPC-700 CODE
;;; The init code is from "Xka Shack"'s
;;; SPC engine, which was written by smkdan.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

!EngineAddress = $0200
!SampleAddress = $3000

!IsPlaying = $2004

macro WriteDSP(DSP, Value)
	mov $f2,#<DSP>
	mov $f3,<Value>
endmacro

;SPC engine block
SPC: {
	dw SPCEND-SPCSTART
	dw !EngineAddress
SPCSTART:
	arch spc700
	base !EngineAddress
	call InitDSP	;brief DSP setup
	call StartSNES	;tell SNES to begin

MainLoop:
	mov a,$F4
	beq .stopsound
	mov a,!IsPlaying
	bne .stillplaying
	mov a,#$01
	mov !IsPlaying,a
	%WriteDSP($4C, #$01)
	%WriteDSP($5C, #$00)
	jmp MainLoop
	
.stopsound
	mov a,!IsPlaying
	beq .alreadysilenced
	%WriteDSP($4C, #$00)
	%WriteDSP($5C, #$01)
	mov a,#$00
	mov !IsPlaying,a

.alreadysilenced
.stillplaying
	jmp MainLoop
	
;intializes registers
;--------------------

InitDSP:
;GLOBAL
	%WriteDSP($6C, #$80) ;'soft-reset' itself
	%WriteDSP($6C, #$20) ;= 20, normal operation and disable echo writes
	%WriteDSP($5C, #$00) ;key off 0
	%WriteDSP($0C, #$7F) ;left master volume max
	%WriteDSP($1C, #$7F) ;right master volume max
	%WriteDSP($5D, #$20) ;Sample pointer table at $2000
	%WriteDSP($2C, #$00) ;echo left mute
	%WriteDSP($3C, #$00) ;echo right mute
	%WriteDSP($2D, #$00) ;disable pitch modulation
	%WriteDSP($3D, #$00) ;disable noise
	%WriteDSP($4D, #$00) ;disable echo
	
;CH 0
	%WriteDSP($00, #$7F) ;left volume
	%WriteDSP($01, #$7F) ;right volume
	
	%WriteDSP($02, #!BeepSamplePitch&$00FF) ;pitch low
	%WriteDSP($03, #!BeepSamplePitch>>8) ; pitch high

	%WriteDSP($04, #$00) ;sample #
	
	%WriteDSP($05, #$00) ;clear ADSR1
	%WriteDSP($06, #$00) ;clear ADSR2
	%WriteDSP($07, #$7F) ;GAIN at max

;sample dir
	mov a,#!SampleAddress&$00FF		;pointer low
	mov x,#!SampleAddress>>8		;pointer high

	mov $2000,a		;main pointer xx00
	mov $2001,x		;main pointer 30xx

	mov $2002,a		;loop pointer is same
	mov $2003,x

	mov a,#$00
	mov !IsPlaying,a
	ret

;signal ready to stream
;2140 = $11
;2141 = $22
;----------------------

StartSNES:
	mov $f4,#$11	;2140 = 11
	mov $f5,#$22	;2141 = 22
	
	mov $f1,#$30	;reset all input regs

	ret
base off
arch 65816
SPCEND: }

;Sample block
TriangleSample: {
		dw .end-.start
		dw !SampleAddress
.start
		db $B0,$01,$23,$45,$67,$76,$54,$32,$10
		db $B3,$FE,$DC,$BA,$98,$89,$AB,$CD,$EF
.end }

;Terminator block
{
		dw $0000
		dw !EngineAddress ;SPC jumps to this address to start running the engine
}