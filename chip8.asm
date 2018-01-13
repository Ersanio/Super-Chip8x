;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; CHIP-8 EMULATOR
;;; WRITTEN FOR THE SNES BY Ersanio
;;; https://twitter.com/Ersanio
;;; https://github.com/Ersanio/Super-Chip8x/
;;;
;;; Extra thanks goes to:
;;; - p4plus2 for pointing me in the right direction whenever I got stuck
;;; - Lui37 for hardware testing and helping a bit with audio
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LOROM
incsrc const.asm

ORG $808000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; INITIALIZE THE SNES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RESET:
		SEI

		; Exit emulation mode
		CLC
		XCE
		
		; Clear interrupts, DMA, HDMA
		STZ $4200
		STZ $420B
		STZ $420C

		; Jump to FastROM area. Works because ORG specifies bank $80
		JML +

+		REP #$20

		; Set stack pointer to $00:0FFF
		LDA #$0FFF
		TCS
		
		; Set data bank to $80 (FastROM area)
		PHK
		PLB
		
		; Set direct page register to $0000
.zero	PEA $0000
		PLD

		; Enable FastROM through hardware register
		LDX #$01
		STX $420D

		SEP #$20
	
		SEI
		LDA.b #SPC
		STA $00
		LDA.b #SPC>>8
		STA $01
		LDA.b #SPC>>16
		STA $02	
		JSR UploadDataToSPC

		REP #$10

		; Clear RAM $7E:0000-$7F:FFFF
		LDX #$8008
		STX $4300
		LDX.w #.zero+1
		STX $4302
		LDA.b #.zero+1>>16
		STA $4304
		LDX #$0000
		STX $4305
		STX $2181
		STZ $2183
		LDA #$01
		STA $420B
		LDA #$01
		STA $2183
		STA $420B
		SEP #$10
		
		; Initialize every single hardware register ($21xx & $42xx)
		PHD
		PEA $2100
		PLD
		LDA #$80
		STA $00
		STZ $01
		STZ $02
		STZ $03
		STZ $04
		STZ $05
		STZ $06
		STZ $07
		STZ $08
		STZ $09
		STZ $0A
		STZ $0B
		STZ $0C
		STZ $0D
		STZ $0D
		STZ $0E
		STZ $0E
		STZ $0F
		STZ $0F
		STZ $10
		STZ $10
		STZ $11
		STZ $11
		STZ $12
		STZ $12
		STZ $13
		STZ $13
		STZ $14
		STZ $14
		STZ $15
		STZ $16
		STZ $17
		STZ $18
		STZ $19
		STZ $1A
		STZ $1B
		STZ $1B
		STZ $1C
		STZ $1C
		STZ $1D
		STZ $1D
		STZ $1E
		STZ $1E
		STZ $1F
		STZ $1F
		STZ $20
		STZ $20
		STZ $21
		STZ $22
		STZ $22
		STZ $23
		STZ $24
		STZ $25
		STZ $26
		STZ $27
		STZ $28
		STZ $29
		STZ $2A
		STZ $2B
		STZ $2C
		STZ $2D
		STZ $2E
		STZ $2F
		STZ $30
		STZ $31
		LDA #$80
		STA $32
		LDA #$40
		STA $32
		LDA #$20
		STA $32
		STZ $33
		STZ $40
		STZ $41
		STZ $42
		STZ $43
		PEA $4200
		PLD
		STZ $01
		STZ $02
		STZ $03
		STZ $04
		STZ $05
		STZ $06
		STZ $07
		STZ $08
		STZ $09
		STZ $0A
		STZ $0B
		STZ $0C
		PLD
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; INITIALIZE THE SCREEN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		LDA #$07	; Mode 7
		STA $2105	;
		
		LDA #$01	; BG1 main screen
		STA $212C
		STZ $212D	; No subscreen
		LDA #$80
		STA $211A

		JSR ClearVRAM
		JSR InitTilemapRAM		
		JSR UploadPalette
		
		;Color math designation on backdrop
		LDA #$20
		STA $2131

		; NMI and auto-read joypad enable
		LDA #$81
		STA $4200

		LDA #$08
		STA !Mode7ScaleX
		STA !Mode7ScaleY

		REP #$20
		LDA #$FFCF		;vertically center
		STA !BG1Y
		STZ !BG1X
		LDA #$0080
		STA !Mode7CenterX
		STA !Mode7CenterY
		SEP #$20
		JSR ProcessMode7ScalingAndRotation
		JSR ScreenHDMA
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; INITIALIZE THE EMULATOR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		
		JSR ResetEmu
		JSR LoadROM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; START THE EMULATOR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		STZ.b !ROMnumber

		;Enable screen
		LDA #$0F
		STA $2100
		
EmuLoop:
		WAI
		LDA !Wait
		BEQ EmuLoop
		;CLI					;Enable IRQ

		JSR ProcessEmuROMSwitching
		;JSR TranslateButtonsToKeypresses

		LDA !OpcodesPerFrame
		STA !OpcodeLoop
		
-		JSR TickEmu
		DEC !OpcodeLoop
		BNE -
		
		JSR DecreaseTimers

		STZ.b !Wait
		BRA EmuLoop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SPC-700 UPLOAD CODE
;;; Borrowed from "Super Mario World" (SNES)
;;; Disassembly from "SMW IRQ" bank_00.asm: 
;;; https://github.com/Alcaro/smw-irq/
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

UploadDataToSPC:
		SEI
		JSR UploadSPC700Data
		CLI
		RTS

UploadSPC700Data:
		PHP						;$008079	\ Preserve processor flags
		REP #$30				;$00807A	 |  16 bit A/X/Y
		LDY.w #$0000			;$00807C	 |
		LDA.w #$BBAA			;$00807F	 |\ Value to check if the SPC is ready
.SPC_wait						;			 | |
		CMP.w $2140				;$008082	 | | Wait for the SPC to be ready
		BNE .SPC_wait			;$008085	 |/
		SEP #$20				;$008087	 | 8 bit A
		LDA.b #$CC				;$008089	 |\ Byte used to enable SPC block upload
		BRA send_SPC_block		;$00808B	 |/
SPC_transfer_bytes:				;			 |\
		LDA [$00],Y				;$00808D	 | | Load the Byte into the low byte
		INY						;$00808F	 | | Increase the index
		XBA						;$008090	 | | Move it to the high byte
		LDA.b #$00				;$008091	 |/ Set the validation byte to the low byte
		BRA start_block_upload	;$008093	 |
next_byte:						;			 |\
		XBA						;$008095	 | | Switch the high and low byte
		LDA [$00],Y				;$008096	 | | Load a new low byte
		INY						;$008098	 | | Increase the index
		XBA						;$008099	 |/ Switch the new low byte to the high byte
.SPC_wait						;			 |\ SPC wait loop
		CMP.w $2140				;$00809A	 | | Wait till $2140 matches the validation byte
		BNE .SPC_wait			;$00809D	 |/
		INC A					;$00809F	 | Increment the validation byte
start_block_upload:				;			 |\
		REP #$20				;$0080A0	 | | 16 bit A
		STA.w $2140				;$0080A2	 | | Store to $2140/$2141
		SEP #$20				;$0080A5	 | | 8 bit A
		DEX						;$0080A7	 |/ Decrement byte counter
		BNE next_byte			;$0080A8	 |
.SPC_wait						;			 |\ SPC wait loop
		CMP.w $2140				;$0080AA	 | |
		BNE .SPC_wait			;$0080AD	 |/
.add_three						;			 |\
		ADC.b #$03				;$0080AD	 | | If A is 0 add 3 again
		BEQ .add_three			;$0080B1	 |/
send_SPC_block:					;			 |
		PHA						;$0080B3	 | Preserve A to store to $2140 later
		LDA $7FFFFF
		REP #$20				;$0080B4	 | 16 bit A
		LDA [$00],Y				;$0080B6	 |\ Get data length
		INY						;$0080B8	 | |
		INY						;$0080B9	 | |
		TAX						;$0080BA	 |/
		LDA [$00],Y				;$0080BB	 |\ Get address to write to in SPC RAM
		INY						;$0080BD	 | |
		INY						;$0080BE	 |/
		STA.w $2142				;$0080BF	 | Store the address of SPC RAM to write to
		SEP #$20				;$0080C2	 | 8 bit A
		CPX.w #$0001			;$0080C4	 |
		LDA.b #$00				;$0080C7	 |\ Store the carry flag in $2141
		ROL						;$0080C9	 | |
		STA.w $2141				;$0080CA	 |/
		ADC.b #$7F				;$0080CD	 | if A is one this sets the overflow flag
		PLA						;$0080CF	 |\ Store the A pushed earlier
		STA.w $2140				;$0080D0	 |/
.SPC_wait						;			 |\ SPC wait loop
		CMP.w $2140				;$0080D3	 | |
		BNE .SPC_wait			;$0080D6	 |/
		BVS SPC_transfer_bytes	;$0080D8	 | If the overflow is not set, keep uploading
		STZ.w $2140				;$0080DA	 |\ Clear SPC I/O ports
		STZ.w $2141				;$0080DD	 | |
		STZ.w $2142				;$0080E0	 | |
		STZ.w $2143				;$0080E3	 |/
		PLP						;$0080E6	 | Restore processor flag
		RTS						;$0080E7	/

incsrc spc700.asm
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; EMULATOR CODE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Decrease global timers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DecreaseTimers:
		INC.b !FrameCounter
		LDA.b !DelayTimer
		BEQ +
		DEC.b !DelayTimer
+		LDA.b !SoundTimer
		BEQ +
		DEC.b !SoundTimer
+		LDA.b !ROMSwitchDelay
		BEQ +
		DEC.b !ROMSwitchDelay
+		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; HDMA to paint the Chip-8 region different in a different
;;; color
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ScreenHDMA:
;note: level number can be anything from 000-1FF of course.

level101:
		PHP
		REP #$20
		LDY #$03
		STY $4350
		LDY #$21
		STY $4351
		LDA.w #.Table
		STA $4352
		LDY.b #.Table>>16
		STY $4354
		SEP #$20
		LDA #$20
		TSB !HDMA
		PLP
		RTS
		
.Table
db $30 : dw $0000,!BlackBarsColor
db $80 : dw $0000,!BackgroundColor
db $30 : dw $0000,!BlackBarsColor
db $00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Processes back and forth switching of the ROMs
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ProcessEmuROMSwitching:
		LDA !ROMSwitchDelay
		BNE +
		LDA !ControllerData2
		BIT #$20
		BNE .previous
		
		BIT #$10
		BNE .next
+		RTS
		
.previous
		LDA !ROMnumber
		BNE .notunderflowing
		LDA.b #ROMS_END-ROMS/5-1
		STA !ROMnumber
		JSR .reset
		RTS
.notunderflowing
		DEC !ROMnumber
		JSR .reset
		RTS
		
.next
		LDA !ROMnumber
		CMP.b #ROMS_END-ROMS/5-1
		BNE .notoverflowing
		STZ !ROMnumber
		JSR .reset
		RTS
.notoverflowing
		INC !ROMnumber
		JSR .reset
		RTS

.reset
		LDA #$20
		STA !ROMSwitchDelay
		JSR ResetEmu
		JSR LoadROM
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; (Re)initialize the emulator and all its variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ResetEmu:
		JSR ClearBuffer
		JSR ClearChip8Memory
		JSR LoadCHRROM
		
		REP #$20
		LDA #$0200
		STA !ProgramCounter

		STZ.b !Stack
		STZ.b !Stack+2
		STZ.b !Stack+4
		STZ.b !Stack+6
		STZ.b !Stack+8
		STZ.b !Stack+10
		STZ.b !Stack+12
		STZ.b !Stack+14		

		STZ.b !Vreg
		STZ.b !Vreg+2
		STZ.b !Vreg+4
		STZ.b !Vreg+6
		STZ.b !Vreg+8
		STZ.b !Vreg+10
		STZ.b !Vreg+12
		STZ.b !Vreg+14
		STZ.b !Vreg+16

		STZ.b !Ireg
		
		STZ.b !NNN
		STZ.b !NN
		STZ.b !N
		STZ.b !X
		STZ.b !Y
		
		SEP #$20
		
		LDA #$1E
		STA !StackPointer
		STZ.b !DelayTimer
		STZ.b !SoundTimer
		STZ.b !DrawOffsetX
		STZ.b !DrawOffsetY
		STZ.b !PressedKey
		STZ.b !IsPressingKey
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Actual emulator code which handles opcode interpretation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TickEmu:
		REP #$30
		LDX.b !ProgramCounter
		LDA.w !Chip8Memory,x
		XBA
		STA.b !Opcode
		INX
		INX
		STX.w !ProgramCounter
		SEP #$10
		
		AND #$0FFF
		STA.b !NNN
		SEP #$20
		AND #$FF
		STA.b !NN
		AND #$0F
		STA.b !N
		REP #$20
		LDA !Opcode
		AND #$0F00
		XBA ; lsr 8
		TAY
		STY.b !X
		LDA.b !Opcode
		AND #$00F0
		REP 4 : LSR A
		TAY
		STY.b !Y
		SEP #$20
		
		LDA !Opcode+1
		AND #$F0
		LSR A
		LSR A
		LSR A
		TAX
		JMP (Opcodes,x)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; OPCODES
;;; This block handles opcodes $0-$F.
;;; Opcodes $8 and $F are handled in yet another table as
;;; they contain multiple other opcodes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Opcodes:
		dw ClearOrReturn		; $00
		dw Jump					; $01
		dw CallSubroutine		; $02
		dw SkipIfXEqual			; $03
		dw SkipIfXNotEqual		; $04
		dw SkipIfXEqualY		; $05
		dw SetX					; $06
		dw AddX					; $07
		dw Arithmetic			; $08
		dw SkipIfXNotEqualY		; $09
		dw SetI					; $0A
		dw JumpWithOffset		; $0B
		dw Rnd					; $0C
		dw DrawSprite			; $0D
		dw SkipOnKey			; $0E
		dw Misc					; $0F

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Clear or Return
;;; Either clears the screen
;;; or returns from a subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ClearOrReturn:
		LDA.b !NN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Clear the screen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		CMP #$E0
		BNE +

		JSR ClearBuffer
		LDA #$01
		STA.b !UpdateGFX
		RTS	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Return from CALL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
+		CMP #$EE
		BNE +
		
		JSR PopAndRET
+		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Jump: Jumps to a subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Jump:
		REP #$20
		LDA.b !NNN
		STA.b !ProgramCounter
		SEP #$20
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Call: Jumps to a subroutine, pushes return address
;;; to the stack
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CallSubroutine:
		JSR PushPC
		REP #$20
		LDA.b !NNN
		STA.b !ProgramCounter
		SEP #$20
		RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Skip if X equal - Skip next opcode if V[X] == NN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SkipIfXEqual:
		LDX.b !X
		LDA.b !Vreg,x
		CMP !NN
		BNE +
		REP #$20
		LDA.b !ProgramCounter
		INC
		INC
		STA.b !ProgramCounter
		SEP #$20
+		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Skip if X not equal - Skip next opcode if V[X] != NN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SkipIfXNotEqual:
		LDX.b !X
		LDA.b !Vreg,x
		CMP !NN
		BEQ +
		REP #$20
		INC.b !ProgramCounter
		INC.b !ProgramCounter
		SEP #$20
+		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Skip if X equals Y - Skip next opcode if V[X] == V[Y]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SkipIfXEqualY:
		LDX.b !X
		LDY.b !Y
		LDA.b !Vreg,x
		CMP.w !Vreg,y
		BNE +
		REP #$20
		INC.b !ProgramCounter
		INC.b !ProgramCounter
		SEP #$20
+		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Set X: V[X] = NN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetX:
		LDX.b !X
		LDA.b !NN
		STA.b !Vreg,x
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Add X: V[X] += NN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AddX:
		LDX.b !X
		LDA.b !NN
		CLC
		ADC.b !Vreg,x
		STA.b !Vreg,x
		RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Arithmetic and bitwise operations
;;; This opcode contains multiple opcodes, depending on N
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Arithmetic:
		LDA.b !N
		ASL A
		TAX
		JSR (.JumpTable,x)
		RTS

.JumpTable
		dw LD_XY	; $0 - X = Y
		dw OR_XY	; $1 - X |= Y
		dw AND_XY	; $2 - X &= Y
		dw XOR_XY	; $3 - X ^= Y
		dw ADD_XY	; $4 - X += Y
		dw SUB_XY	; $5 - X -= Y
		dw SHR_X	; $6 - X = X>>2
		dw SUBN_YX	; $7 - X = Y-X  (opposite of $5 basically)
		dw dummy	; $8 - Unused
		dw dummy	; $9 - Unused 
		dw dummy	; $A - Unused
		dw dummy	; $B - Unused
		dw dummy	; $C - Unused
		dw dummy	; $D - Unused
		dw SHL_X	; $E - X = X<<2
		dw dummy	; $F - Unused	

dummy:
		RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; V[X] = V[Y]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LD_XY:
		LDX.b !Y
		LDA.b !Vreg,x
		LDX.b !X
		STA.b !Vreg,x
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; V[X] |= V[Y]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OR_XY:
		LDX.b !X
		LDY.b !Y
		LDA.b !Vreg,x
		ORA.w !Vreg,y
		STA.b !Vreg,x
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; V[X] &= V[Y]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AND_XY:
		LDX.b !X
		LDY.b !Y
		LDA.b !Vreg,x
		AND.w !Vreg,y
		STA.b !Vreg,x
		RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; V[X] ^= V[Y]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
XOR_XY:
		LDX.b !X
		LDY.b !Y
		LDA.b !Vreg,x
		EOR.w !Vreg,y
		STA.b !Vreg,x
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; V[X] += V[Y]
;;; V[0xF] = Carry
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ADD_XY:
		LDX.b !X
		LDY.b !Y
		LDA.b !Vreg,x
		CLC
		ADC.w !Vreg,y
		STA.b !Vreg,x
		JSR SetVFCarry
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; V[X] -= V[Y]
;;; V[0xF] = Carry
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SUB_XY:
		LDX.b !X
		LDY.b !Y
		
		LDA.b !Vreg,x
		SEC
		SBC.w !Vreg,y
		STA.b !Vreg,x
		JSR SetVFCarry
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; V[X] = V[X] >> 1
;;; V[0xF] = Carry
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SHR_X:
		LDX.b !X
		LDA.b !Vreg,x
		LSR A
		STA.b !Vreg,x
		JSR SetVFCarry
		RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; V[X] = V[Y] - V[X]
;;; V[0xF] = Carry
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SUBN_YX:
		LDX.b !X
		LDY.b !Y
		
		LDA.w !Vreg,y
		SEC
		SBC.b !Vreg,x
		STA.w !Vreg,x
		JSR SetVFCarry
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; V[X] = V[X] << 1
;;; V[0xF] = Carry
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SHL_X:
		LDX.b !X
		LDA.b !Vreg,x
		ASL A
		STA.b !Vreg,x
		JSR SetVFCarry
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Set V[0xF] = Carry subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetVFCarry:
		LDA #$00
		ROL A
		STA !Vreg+$0F
		RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; End Arithmetic block
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Skip if X doesn't equal Y - Skip next opcode if V[X] != V[Y]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SkipIfXNotEqualY:
		LDX.b !X
		LDY.b !Y
		LDA.b !Vreg,x
		CMP.w !Vreg,y
		BEQ +
		REP #$20
		LDA.b !ProgramCounter
		INC
		INC
		STA.b !ProgramCounter
		SEP #$20
+		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Set I: Set I register
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetI:
		REP #$20
		LDA.b !NNN
		STA.b !Ireg
		SEP #$20
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Jump with Offset: Jump to NNN+V[0]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
JumpWithOffset:
		LDA #$00
		XBA
		LDA.b !Vreg
		REP #$20
		CLC
		ADC.b !NNN
		STA.b !ProgramCounter
		SEP #$20
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Random: Generate random number, AND with NN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Rnd:
		LDX.b !X
		JSR GetRand
		LDA.b !RNGOutput
		AND.b !NN
		STA.b !Vreg,x
		RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Draw: Draws a sprite on-screen by XORing pixels
;;; This allows for 'undrawing' a sprite by drawing sprite B over sprite A
;;; Sprite is 8 pixels wide
;;; Sprite is N pixels high (max 15)
;;; Each line of pixels is exactly 1 byte
;;; Screen X pos is V[X]
;;; Screen Y pos is V[Y]
;;; Set V[0xF] if there is a collision
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DrawSprite:
		STZ.b !Vreg+$F
		STZ.b !DrawOffsetY

		LDY #$00
--		REP #$30
		TYA
		CLC
		ADC.b !Ireg
		TAX
		SEP #$20
		LDA !Chip8Memory,x
		SEP #$10

		STZ.b !DrawOffsetX
		LDX #$00		;bits
-		PHA
		AND .bits,x
		BEQ +

		PHX
		LDX.b !X
		LDA.b !Vreg,x
		CLC
		ADC.b !DrawOffsetX
		STA $00
		LDX.b !Y
		LDA.b !Vreg,x
		CLC
		ADC.b !DrawOffsetY
		STA $01
		JSR DrawPixel
		PLX
	
+		PLA
		INC.b !DrawOffsetX
		INX
		CPX #$08
		BNE -

		INC.b !DrawOffsetY
		INY
		CPY.b !N
		BNE --
		
		LDA #$01
		STA.b !UpdateGFX
		
		RTS

.bits
		db $80,$40,$20,$10,$08,$04,$02,$01

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Skip on Key: Skips the next instruction based on the key at V[x] being pressed/not pressed.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SkipOnKey:
		JSR TranslateButtonsToKeypresses
		LDA.b !NN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Skip if key X pressed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		CMP #$9E
		BNE +
		
		LDA.b !IsPressingKey
		BEQ .notpressinganything
		
		LDA.b !PressedKey
		LDX.b !X
		CMP.b !Vreg,x
		BNE .notthesame
		REP #$20
		INC.b !ProgramCounter
		INC.b !ProgramCounter
		SEP #$20
	
.notthesame
.notpressinganything
		RTS	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Skip if key X not pressed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
+		CMP #$A1
		BNE +

		LDA.b !PressedKey
		CMP #$00
		BEQ .iszeropressed
.zeroispressedafterall
		LDA.b !PressedKey
		LDX.b !X
		CMP.b !Vreg,x
		BEQ .pressed
		REP #$20
		INC.b !ProgramCounter
		INC.b !ProgramCounter
		SEP #$20
.pressed
+		RTS

.iszeropressed
		LDA.b !IsPressingKey
		BEQ .zeroispressedafterall
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Miscellaneous operations
;;; This opcode contains multiple opcodes, depending on NN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Misc:
		LDA.b !NN
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Set X to Delay: Set V[X] to DelayTimer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		CMP #$07
		BNE +
		
		; Set X to delay
		LDA.b !DelayTimer
		LDX.b !X
		STA.b !Vreg,x
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Wait for key: Infinitely loop until a key is pressed,
;;; store pressed key into V[X]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
+		CMP #$0A
		BNE +	
		JSR TranslateButtonsToKeypresses
		LDA.b !IsPressingKey
		BNE .foundpress
		REP #$20
		DEC.b !ProgramCounter
		DEC.b !ProgramCounter
		SEP #$20
		RTS
		
.foundpress
		LDA.b !PressedKey
		LDX.b !X
		STA.b !Vreg,x
		RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Set Delay: Set DelayTimer to V[X]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
+		CMP #$15
		BNE +
		
		; Set Delay
		LDX.b !X
		LDA.b !Vreg,x
		STA.b !DelayTimer
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Set Sound: Set SoundTimer to V[X]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
+		CMP #$18
		BNE +
		
		; Set Sound timer
		LDX.b !X
		LDA.b !Vreg,x
		STA.b !SoundTimer
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Add V[X] to I: Increase I with V[X], increasing the memory pointer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
+		CMP #$1E
		BNE +

		; Add X to I
		LDX.b !X
		LDA #$00
		XBA
		LDA !Vreg,x
		REP #$20
		CLC
		ADC.b !Ireg
		STA.b !Ireg
		SEP #$20
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Set I to character address. Each char is 5 bytes.
;;; Memory base address is $0000
;;; This will allow for easy character drawing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
+		CMP #$29
		BNE +

		LDA #$00
		XBA	
		LDX.b !X
		LDA.b !Vreg,x
		STA $00
		STZ $01
		REP #$20
		ASL A
		ASL A
		CLC
		ADC.b $00
		STA.b !Ireg
		SEP #$20
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Binary Coded Decimal (BCD): Convert V[X] to decimal.
;;; Store hundreds to Memory[I]
;;; Store tens to Memory[I+1]
;;; Store ones to Memory[I+2]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
+		CMP #$33
		BNE ++

		; Binary Coded Decimal
		; Convert hex to dec basically
		LDX.b !X
		LDA !Vreg,x

		;get index to memory
		REP #$30
		PHA
		LDA.b !Ireg
		TAX
		PLA
		SEP #$20

		LDY #$0000		;clear counter
.hundreds
		CMP #$64
		BCC .tens
		SBC #$64
		INY
		BRA .hundreds
	
.tens
		PHA
		TYA
		STA.w !Chip8Memory,x
		PLA
		LDY #$0000		;clear hundreds
		INX
-		CMP #$0A
		BCC .ones
		SBC #$0A
		INY
		BRA -
		
.ones
		PHA
		TYA
		STA.w !Chip8Memory,x
		PLA
		LDY #$0000		;clear tens
		INX
		
+		STA.w !Chip8Memory,x
		SEP #$10
		RTS
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Dump V[0] to V[X] to Memory[I]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
++		CMP #$55
		BNE +
		
		LDA #$00
		XBA

		; Save X to I
		LDY.b !X
		TYA
		REP #$30
		CLC
		ADC !Ireg
		TAX
		SEP #$20
-		LDA.w !Vreg,y
		STA.w !Chip8Memory,x
		DEX
		DEY
		BPL -
		SEP #$10
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Dump Memory[I] to V[0]-V[X]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
+		CMP #$65
		BNE +

		LDA #$00
		XBA
		
		; Load X from I
		LDY.b !X
		TYA
		REP #$30
		CLC
		ADC !Ireg
		TAX
		SEP #$20
-		LDA.w !Chip8Memory,x
		STA.w !Vreg,y
		DEX
		DEY
		BPL -
		SEP #$10
+		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Helper routine: Push return address to stack
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PushPC:
		REP #$20
		LDA.b !ProgramCounter
		LDX.b !StackPointer
		STA.b !Stack,x
		DEX
		DEX
		STX.b !StackPointer
		SEP #$20
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Helper routine: Pull return address into PC, thus return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PopAndRET:
		LDX.b !StackPointer
		INX
		INX
		REP #$20
		LDA.b !Stack,x
		STA.b !ProgramCounter
		SEP #$20
		STX.b !StackPointer
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DMA Routines
;;; They are mostly copy-pastes of each other
;;; but I got plenty of ROM space to spare
;;; anyway.
;;;
;;; Laziness prevails.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DMA: Upload the chip-8 character set to the interpreter-memory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoadCHRROM:
		REP #$10
		LDX #$8000
		STX $4310
		LDX.w #chr
		STX $4312
		LDA.b #chr>>16
		STA $4314
		LDX.w #$0050
		STX $4315
		LDX.w #!Chip8Memory
		STX $2181
		LDA.b #!Chip8Memory>>16&$01
		STA $2183
		LDA #$02
		STA $420B
		SEP #$10
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DMA: Load the selected ROM into the chip-8 ROM/RAM memory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoadROM:
		REP #$10
		LDX #$8000
		STX $4310

		LDA #$00
		XBA
		LDA !ROMnumber
		ASL A
		ASL A
		CLC
		ADC !ROMnumber
		TAY
		
		LDX.w ROMS,y
		STX $4312
		LDA.w ROMS+2,y
		STA $4314
		LDX.w ROMS+3,y
		STX $4315
		LDX.w #!Chip8MemoryROM
		STX $2181
		LDA.b #!Chip8MemoryROM>>16&$01
		STA $2183
		LDA #$02
		STA $420B
		SEP #$10
		RTS

ROMS:
		;  pointer : size
		;  first rom is the first rom people will see
		;  (duh)
		
		dl BOOT : dw BOOT_END-BOOT
		dl FIFTEENPUZZLE : dw FIFTEENPUZZLE_END-FIFTEENPUZZLE
		dl BLINKY : dw BLINKY_END-BLINKY
		dl BLITZ : dw BLITZ_END-BLITZ
		dl BRIX : dw BRIX_END-BRIX
		dl CAVE : dw CAVE_END-CAVE
		dl CONNECT4 : dw CONNECT4_END-CONNECT4
		dl GUESS : dw GUESS_END-GUESS
		dl HIDDEN : dw HIDDEN_END-HIDDEN
		dl IBM : dw IBM_END-IBM
		dl INVADERS : dw INVADERS_END-INVADERS
		dl KALEID : dw KALEID_END-KALEID
		dl KEYPAD : dw KEYPAD_END-KEYPAD
		dl MAZE : dw MAZE_END-MAZE
		dl MERLIN : dw MERLIN_END-MERLIN
		dl MISSILE : dw MISSILE_END-MISSILE
		dl PONG : dw PONG_END-PONG
		dl PONG2 : dw PONG2_END-PONG2
		dl PUZZLE : dw PUZZLE_END-PUZZLE
		dl REVERSI : dw REVERSI_END-REVERSI
		dl RNG : dw RNG_END-RNG
		dl RUSHHOUR : dw RUSHHOUR_END-RUSHHOUR
		dl SNAKE : dw SNAKE_END-SNAKE
		dl STARS : dw STARS_END-STARS
		dl SYZYGY : dw SYZYGY_END-SYZYGY
		dl TANK : dw TANK_END-TANK
		dl TETRIS : dw TETRIS_END-TETRIS
		dl TICTAC : dw TICTAC_END-TICTAC
		dl TRIP8 : dw TRIP8_END-TRIP8
		dl UFO : dw UFO_END-UFO
		dl VBRIX : dw VBRIX_END-VBRIX
		dl VERS : dw VERS_END-VERS
		dl WALL : dw WALL_END-WALL
		dl WIPEOFF : dw WIPEOFF_END-WIPEOFF
.END

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DMA: Clear the entire chip-8 memory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ClearChip8Memory:
		; Clear RAM
		REP #$10
		LDX #$8008
		STX $4310
		LDX.w #.zero+1
		STX $4312
		LDA.b #.zero+1>>16
		STA $4314
		LDX #$1000
		STX $4315
		LDX.w #!Chip8Memory
		STX $2181
		LDA.b #!Chip8Memory>>16&$01
		STA $2183
		LDA #$02
		STA $420B
		SEP #$10
		RTS

.zero	dw $0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DMA: Update the mode 7 SNES graphics
;;; Chip-8 graphics are written in RAM.
;;; Thus, this transfers RAM to VRAM.
;;; Only run this during NMI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateMode7GFX:
		LDA #$80
		STA $2115
		LDX #$0040
		STX $2116
		
		STZ $4300
		LDA #$19
		STA $4301
		LDX.w #!Graphics
		STX $4302
		LDA.b #!Graphics>>16
		STA $4304
		
		LDX #$0800
		STX $4305
		
		LDA #$01
		STA $420B
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DMA: Clear the entire chip-8 display
;;; The 'display' in fact is a chunk of RAM on the SNES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ClearBuffer:
		; Clear screen
		REP #$10
		LDX #$8008
		STX $4310
		LDX.w #.zero+1
		STX $4312
		LDA.b #.zero+1>>16
		STA $4314
		LDX #$0800
		STX $4315
		LDX.w #!Graphics
		STX $2181
		LDA.b #!Graphics>>16&$01
		STA $2183
		LDA #$02
		STA $420B
		SEP #$10
		RTS
.zero	dw $0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DMA: Transfer the mode 7 tilemap to VRAM
;;; Only run this during NMI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
UpdateMode7Tilemap:
		STZ $2115
		STX $2116
		
		STZ $4300
		
		LDA #$18
		STA $4301

		REP #$20
		TYA
		LDX.w #!Tilemap
		STX $00
		CLC
		ADC $00
		STA $00
		SEP #$20
		
		LDX $00
		STX $4302
		LDA.b #!Tilemap>>16
		STA $4304
		
		LDX #$0008
		STX $4305
		
		LDA.b #$01
		STA.w $420B

		RTS
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DMA: Transfer the palette to CGRAM
;;; As the palette is loaded from ROM, this is only used
;;; during the SNES init
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;			
UploadPalette:
		PHP
		SEP #$20
		REP #$10
		STZ $2121
		STZ $4300
		LDA #$22
		STA $4301
		LDX.w #pal
		STX $4302
		LDA.b #pal>>16
		STA $4304
		LDX #$0004
		STX $4305
		LDA #$01
		STA $420B
		PLP
		RTS
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DMA: Clear VRAM
;;; To be honest I'm not even sure if this is necessary.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ClearVRAM:
		; Clear VRAM $0000-$FFFF
		PHP
		LDA #$80
		STA $2115

		REP #$10
		LDX #$0000
		STX $2116

		LDA #$09
		STA $4300
		LDA #$18
		STA $4301
		LDX.w #.zero+1
		STX $4302
		LDA.b #.zero+1>>16
		STA $4304
		LDX #$0000
		STX $4305
		LDA #$01
		STA $420B
		
		PLP
		RTS

.zero	dw $0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MISCELLANEOUS HELPER ROUTINES
;;; This block has helper routines which are
;;; necessary for the emulator to function
;;; properly.
;;;
;;; I decided to map the controllers differently
;;; depending on the game so the game would be
;;; playable. For games without a mapped controller
;;; layout, there's a default layout to support all
;;; sixteen keys:
;;; ABXY
;;; L+ABXY
;;; R+AXBY
;;; LR+ABXY
;;; 
;;; The KEYPAD ROM is a good test ROM for this
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

TranslateButtonsToKeypresses:
		REP #$10
		LDA #$00
		XBA
		LDA !ROMnumber
		ASL A
		CLC
		ADC !ROMnumber
		TAX
		
		REP #$20
		LDA.w ControllerLayouts,x
		STA $00
		SEP #$20
		LDA.w ControllerLayouts+2,x
		STA $02
		SEP #$10
		
		REP #$20
		LDY.b $02
		DEY
		DEY
		DEY ;off by 3
.loop
		LDA ($00),y
		CMP !ControllerData
		BEQ .foundpress
		DEY
		DEY
		DEY
		BPL .loop
		SEP #$20
		RTS
	
.foundpress
		INC $00
		INC $00
		SEP #$20
		LDA ($00),y
		STA.b !PressedKey
		INC.b !IsPressingKey
		RTS

; Make sure this is in sync with the ROMS pointer table		
ControllerLayouts:
		dw CDefault : db CDefault_end-CDefault ;boot
		dw CDefault : db CDefault_end-CDefault ; fifteenpuzzle
		dw CBlinky : db CBlinky_end-CBlinky
		dw CBlitz : db CBlitz_end-CBlitz
		dw CBrix : db CBrix_end-CBrix
		dw CCave : db CCave_end-CCave
		dw CConnect4 : db CConnect4_end-CConnect4
		dw CDefault : db CDefault_end-CDefault ;guess
		dw CHidden : db CHidden_end-CHidden
		dw CDefault : db CDefault_end-CDefault ;ibm
		dw CInvaders : db CInvaders_end-CInvaders
		dw CKaleid : db CKaleid_end-CKaleid
		dw CDefault : db CDefault_end-CDefault ;keypad
		dw CDefault : db CDefault_end-CDefault ;maze
		dw CMerlin : db CMerlin_end-CMerlin
		dw CMissile : db CMissile_end-CMissile
		dw CPong : db CPong_end-CPong
		dw CPong2 : db CPong2_end-CPong2
		dw CPuzzle : db CPuzzle_end-CPuzzle
		dw CReversi : db CReversi_end-CReversi
		dw CDefault : db CDefault_end-CDefault ;rng
		dw CRushhour : db CRushhour_end-CRushhour
		dw CSnake : db CSnake_end-CSnake
		dw CDefault : db CDefault_end-CDefault ;stars
		dw CSyzygy : db CSyzygy_end-CSyzygy
		dw CTank : db CTank_end-CTank
		dw CTetris : db CTetris_end-CTetris
		dw CDefault : db CDefault_end-CDefault ;tictac
		dw CDefault : db CDefault_end-CDefault ;trip8
		dw CUFO : db CUFO_end-CUFO
		dw CVbrix : db CVbrix_end-CVbrix
		dw CVers : db CVers_end-CVers
		dw CWall : db CWall_end-CWall
		dw CWipeoff : db CWipeoff_end-CWipeoff
		
		!CUP = $0800
		!CDOWN = $0400
		!CLEFT = $0200
		!CRIGHT = $0100

		!CY = $4000
		!CX = $0040
		!CB = $8000
		!CA = $0080

		!CL = $0020
		!CR = $0010
		
;b y select start U D L R a x l r 0 0 0 0 	
CDefault:
		dw $4000 : db $01 ; Y
		dw $0040 : db $02 ; X
		dw $8000 : db $03 ; B
		dw $0080 : db $0C ; A
		dw $4000|$0020 : db $04 ; Y + L
		dw $0040|$0020 : db $05 ; X + L
		dw $8000|$0020 : db $06 ; B + L
		dw $0080|$0020 : db $0d ; A + L
		dw $4000|$0010 : db $07 ; Y + R
		dw $0040|$0010 : db $08 ; X + R
		dw $8000|$0010 : db $09 ; B + R
		dw $0080|$0010 : db $0e ; A + R
		dw $4000|$0030 : db $0a ; Y + LR
		dw $0040|$0030 : db $00 ; X + LR
		dw $8000|$0030 : db $0b ; B + LR
		dw $0080|$0030 : db $0f ; A + LR
		
		;generally accepted directional keys
		dw $0800 : db $02 ; up
		dw $0200 : db $04 ; left
		dw $0100 : db $06 ; right
		dw $0400 : db $08 ; down
.end

CBlinky:
		dw !CUP : db $03
		dw !CDOWN : db $06
		dw !CLEFT : db $07
		dw !CRIGHT : db $08
		dw !CA : db $0F
		dw !CB : db $0F
		dw !CY : db $0F
		dw !CX : db $0F
.end

CBlitz:
		dw !CB : db $07
		dw !CA : db $07
		dw !CY : db $05
		dw !CX : db $05
.end

CBrix:
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
.end

CConnect4:
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
		dw !CA : db $05
		dw !CB : db $05
		dw !CY : db $05
		dw !CX : db $05
.end

CCave:
		dw !CUP : db $02
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
		dw !CDOWN : db $08
		dw !CA : db $0F
		dw !CB : db $0F
		dw !CY : db $0F
		dw !CX : db $0F
.end

CHidden:
		dw !CUP : db $02
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
		dw !CDOWN : db $08
		dw !CA : db $05
		dw !CB : db $05
		dw !CY : db $05
		dw !CX : db $05
.end

CInvaders:
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
		dw !CA : db $05
		dw !CB : db $05
		dw !CY : db $05
		dw !CX : db $05
.end

CKaleid:
		dw !CUP : db $02
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
		dw !CDOWN : db $08
		dw !CA : db $00
		dw !CB : db $00
		dw !CY : db $00
		dw !CX : db $00
.end

CMerlin:
		dw !CB : db $07
		dw !CA : db $08
		dw !CY : db $04
		dw !CX : db $05
.end

CMissile:
		dw !CB : db $08
		dw !CA : db $08
		dw !CY : db $08
		dw !CX : db $08
.end

CPong:
		dw !CUP : db $01
		dw !CDOWN : db $04
		dw !CB : db $0D
		dw !CA : db $0D
		dw !CY : db $0C
		dw !CX : db $0C
.end

CPong2:
		dw !CUP : db $01
		dw !CDOWN : db $04
		dw !CB : db $0D
		dw !CA : db $0D
		dw !CY : db $0C
		dw !CX : db $0C
.end

CPuzzle:
		dw !CUP : db $08
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
		dw !CDOWN : db $02
.end

CReversi:
		dw !CUP : db $02
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
		dw !CDOWN : db $08
		dw !CUP|!CRIGHT : db $03
		dw !CUP|!CLEFT : db $01
		dw !CDOWN|!CRIGHT : db $09
		dw !CDOWN|!CLEFT : db $07
		dw !CB : db $05
		dw !CA : db $05
		dw !CY : db $05
		dw !CX : db $05
.end

CRushhour:
		dw !CUP : db $05
		dw !CLEFT : db $07
		dw !CRIGHT : db $09
		dw !CDOWN : db $08
		dw !CB : db $0A
		dw !CA : db $0A
		dw !CY : db $01
		dw !CX : db $01
.end

CSnake:
		dw !CUP : db $05
		dw !CLEFT : db $07
		dw !CRIGHT : db $09
		dw !CDOWN : db $08
.end

CSyzygy:
		dw !CUP : db $03
		dw !CLEFT : db $07
		dw !CRIGHT : db $08
		dw !CDOWN : db $06
		dw !CB : db $0E
		dw !CA : db $0E
		dw !CY : db $0E
		dw !CX : db $0E
.end

CTank:
		dw !CUP : db $08
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
		dw !CDOWN : db $02
		dw !CB : db $05
		dw !CA : db $05
		dw !CY : db $05
		dw !CX : db $05		
.end

CTetris:
		dw !CLEFT : db $05
		dw !CRIGHT : db $06
		dw !CDOWN : db $07
		dw !CB : db $04
		dw !CA : db $04
		dw !CY : db $04
		dw !CX : db $04	
.end

CUFO:
		dw !CUP : db $05
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
.end

CVbrix:
		dw !CUP : db $01
		dw !CDOWN : db $04
		dw !CB : db $07
		dw !CA : db $07
		dw !CY : db $07
		dw !CX : db $07	
.end

CVers:
		dw !CUP : db $07
		dw !CLEFT : db $01
		dw !CRIGHT : db $02
		dw !CDOWN : db $0A
		dw !CB : db $0D
		dw !CA : db $0F
		dw !CY : db $0B
		dw !CX : db $0C		
.end

CWall:
		dw !CUP : db $01
		dw !CDOWN : db $04
.end

CWipeoff:
		dw !CLEFT : db $04
		dw !CRIGHT : db $06
.end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Draw a pixel on the chip-8 screen
;;;
;;; The chip-8 screen is 64x32 and is not tilemap based.
;;; To make things more difficult, the SNES mode 7 screen 
;;; is made of 8x8 tiles. Thus, I needed a formula to write 
;;; to a 64x32 area on the SNES screen. I had to convert X and Y 
;;; parameters into the SNES tile number and the pixel number 
;;; within that tile.
;;;
;;; What I came up with is this beautiful formula:
;;; PixelAddress = !Graphics + ((((Y/8) * 8) + (X/8)) * 64) + ((X % 8) + ((Y % 8) *8))
;;;
;;; Thankfully, p4plus2 took the liberty to simplify it:
;;; PixelAddress = !Graphics + (((Y & 0xF8) + (X >> 3)) <<  6) + ((X & 0x07) + ((Y & 0x07) << 3))
;;;
;;; Parameters:
;;; $00 - X offset in pixels
;;; $01 - Y offset in pixels
;;;
;;; The chip-8 also has collision capabilities by using XOR
;;; rather than a conventional store. If the result of the
;;; pixel write is 0, there has been a collision on a pixel
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DrawPixel:
		LDA #$00	;Clear high byte to not mess up 16-bit bitshift math later
		XBA
		LDA $00
		AND #$3F
		STA $00
		;LDA $01
		;AND #$1F ;oops - no support for vertical wraps
		;STA $01  ;commenting this fixes emulation error in BLITZ where bottom of building sticks out through top
		LDA $01
		BMI .return
		CMP #$20
		BCS .return

		
		LDA $01
		AND #$F8
		STA $02
		LDA $00
		LSR A
		LSR A
		LSR A
		CLC
		ADC $02
		REP #$20
		ASL A
		ASL A
		ASL A
		ASL A
		ASL A
		ASL A
		STA $02
		LDA #$0000
		SEP #$20
		
		LDA $00
		AND #$07
		STA $04
		LDA $01
		AND #$07
		ASL A
		ASL A
		ASL A
		CLC
		ADC $04
		REP #$20
		ADC $02
		ADC.w #!Graphics
		STA $02
		SEP #$20

		LDA.b #!Graphics>>16
		STA $04
		LDA [$02]
		EOR #$01
		STA [$02]
		BNE .nocollision
		LDA #$01
		STA.b !Vreg+$F
.return
.nocollision
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Process mode 7 scaling and rotation RAM
;;; "Borrowed" from Super Mario World (SNES)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ProcessMode7ScalingAndRotation:
		LDA !Mode7ScaleY
		STA $00
		REP #$30
		JSR CODE_008AE8
		LDA !Mode7ScaleX
		STA $00
		REP #$30
		LDA !Mode7MatrixA
		STA !Mode7MatrixD
		LDA !Mode7MatrixB
		EOR.w #$FFFF
		INC A
		STA !Mode7MatrixC
CODE_008AE8:
		LDA !Mode7Rotate
		ASL
		PHA
		XBA
		AND #$0003
		ASL
		TAY
		PLA
		AND #$00FE
		EOR DATA_008AB4,Y
		CLC
		ADC DATA_008ABC,Y
		TAX
		JSR CODE_008B2B
		CPY #$0004
		BCC CODE_008B0A
		EOR #$FFFF
		INC A
CODE_008B0A:
		STA !Mode7MatrixB
		TXA
		EOR #$00FE
		CLC
		ADC #$0002
		AND #$01FF
		TAX
		JSR CODE_008B2B
		DEY
		DEY
		CPY #$0004
		BCS CODE_008B26
		EOR #$FFFF
		INC A
CODE_008B26:
		STA !Mode7MatrixA
		SEP #$30
		RTS

CODE_008B2B:
		SEP #$20
		LDA DATA_008B58,X
		BEQ CODE_008B34
		LDA $00
CODE_008B34:
		STA $01
		LDA DATA_008B57,X
		STA $4202
		LDA $00
		STA $4203
		NOP
		NOP
		NOP
		NOP
		LDA $4217
		CLC
		ADC $01
		XBA
		LDA $4216
		REP #$20
		LSR
		LSR
		LSR
		LSR
		LSR
		RTS

DATA_008AB4:
		db $00,$00,$FE,$00,$00,$00,$FE,$00

DATA_008ABC:
		db $00,$00,$02,$00,$00,$00,$02,$00
		db $00,$00,$00,$01,$FF,$FF,$00,$10
		db $F0

DATA_008B57:
		db $00

DATA_008B58:
		db $00,$03,$00,$06,$00,$09,$00,$0C
		db $00,$0F,$00,$12,$00,$15,$00,$19
		db $00,$1C,$00,$1F,$00,$22,$00,$25
		db $00,$28,$00,$2B,$00,$2E,$00,$31
		db $00,$35,$00,$38,$00,$3B,$00,$3E
		db $00,$41,$00,$44,$00,$47,$00,$4A
		db $00,$4D,$00,$50,$00,$53,$00,$56
		db $00,$59,$00,$5C,$00,$5F,$00,$61
		db $00,$64,$00,$67,$00,$6A,$00,$6D
		db $00,$70,$00,$73,$00,$75,$00,$78
		db $00,$7B,$00,$7E,$00,$80,$00,$83
		db $00,$86,$00,$88,$00,$8B,$00,$8E
		db $00,$90,$00,$93,$00,$95,$00,$98
		db $00,$9B,$00,$9D,$00,$9F,$00,$A2
		db $00,$A4,$00,$A7,$00,$A9,$00,$AB
		db $00,$AE,$00,$B0,$00,$B2,$00,$B5
		db $00,$B7,$00,$B9,$00,$BB,$00,$BD
		db $00,$BF,$00,$C1,$00,$C3,$00,$C5
		db $00,$C7,$00,$C9,$00,$CB,$00,$CD
		db $00,$CF,$00,$D1,$00,$D3,$00,$D4
		db $00,$D6,$00,$D8,$00,$D9,$00,$DB
		db $00,$DD,$00,$DE,$00,$E0,$00,$E1
		db $00,$E3,$00,$E4,$00,$E6,$00,$E7
		db $00,$E8,$00,$EA,$00,$EB,$00,$EC
		db $00,$ED,$00,$EE,$00,$EF,$00,$F1
		db $00,$F2,$00,$F3,$00,$F4,$00,$F4
		db $00,$F5,$00,$F6,$00,$F7,$00,$F8
		db $00,$F9,$00,$F9,$00,$FA,$00,$FB
		db $00,$FB,$00,$FC,$00,$FC,$00,$FD
		db $00,$FD,$00,$FE,$00,$FE,$00,$FE
		db $00,$FF,$00,$FF,$00,$FF,$00,$FF
		db $00,$FF,$00,$FF,$00,$FF,$00,$00
		db $01,$B7,$3C,$B7,$BC,$B8,$3C,$B9
		db $3C,$BA,$3C,$BB,$3C,$BA,$3C,$BA
		db $BC,$BC,$3C,$BD,$3C,$BE,$3C,$BF
		db $3C,$C0,$3C,$B7,$BC,$C1,$3C,$B9
		db $3C,$C2,$3C,$C2,$BC,$B7,$3C,$C0
		db $FC,$3A,$38,$3B,$38,$3B,$38,$3A
		db $78		

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Process random number generation
;;; "Borrowed" from Super Mario World (SNES)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GetRand:
		JSR RNGMaths         
		RTS

RNGMaths:
		LDA.b !RNG1
		ASL                       
		ASL                       
		SEC                       
		ADC.b !RNG1
		STA.b !RNG1
		ASL.b !RNG2
		LDA #$20                
		BIT.b !RNG2
		BCC .Label1           
		BEQ .Label2            
		BNE .Label3           
.Label1
		BNE .Label2  
.Label3
		INC.b !RNG2
.Label2
		LDA.b !RNG2
		EOR.b !RNG1
		STA.w !RNGOutput
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Initialize the mode 7 tilemap in the RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
InitTilemapRAM:
		LDX #$1F
-		TXA
		INC
		STA.b !Tilemap,x
		DEX
		BPL -
		RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Update the SNES controller RAMs
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
ControllerUpdate:
		LSR $4212
		BCS ControllerUpdate
		LDA $4218
		STA.b !ControllerData
		
		LDA $4219
		STA.b !ControllerData2
		
		LDA $4218
		AND #$C0		;filter out the L+R modifiers
		ORA $4219
		BNE .press
		STZ.b !IsPressingKey
		STZ.b !PressedKey
.press	RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; VECTORS AND THEIR ROUTINES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; NMI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
NMI:	JML +
+		SEI
		REP #$30
		PHA
		PHX
		PHY
		PHD
		PEA $0000
		PLD
		PHB
		PHK
		PLB
		SEP #$30
		
		LDA !SoundTimer
		STA $2140
				
		;mode 7 mirrors
		LDA !Mode7CenterX
		STA $211F					;Mode 7 Center position X
		LDA !Mode7CenterX+1
		STA $211F					;Mode 7 Center position X
		LDA !Mode7CenterY
		STA $2120					; Mode 7 Center Position Y
		LDA !Mode7CenterY+1
		STA $2120					; Mode 7 Center Position Y
		LDA !Mode7MatrixA
		STA $211B					; Mode 7 Matrix Parameter A
		LDA !Mode7MatrixA+1
		STA $211B					; Mode 7 Matrix Parameter A
		LDA !Mode7MatrixB
		STA $211C					; Mode 7 Matrix Parameter B
		LDA !Mode7MatrixB+1
		STA $211C					; Mode 7 Matrix Parameter B
		LDA !Mode7MatrixC
		STA $211D					; Mode 7 Matrix Parameter C
		LDA !Mode7MatrixC+1
		STA $211D					; Mode 7 Matrix Parameter C
		LDA !Mode7MatrixD
		STA $211E					; Mode 7 Matrix Parameter D
		LDA !Mode7MatrixD+1
		STA $211E					; Mode 7 Matrix Parameter D
		
		LDA !BG1X
		STA $210D
		LDA !BG1X+1
		STA $210D
		LDA !BG1Y
		STA $210E
		LDA !BG1Y+1
		STA $210E

		REP #$10
		LDX $00
		PHX
		LDX #$0C18/2
		LDY #$0000
		JSR UpdateMode7Tilemap
		LDX #$0D18/2
		LDY #$0008
		JSR UpdateMode7Tilemap
		LDX #$0E18/2
		LDY #$0010
		JSR UpdateMode7Tilemap
		LDX #$0F18/2
		LDY #$0018
		JSR UpdateMode7Tilemap
		PLX
		STX $00
		
		LDA.b !UpdateGFX
		BEQ +
		JSR UpdateMode7GFX
		STZ.b !UpdateGFX
+		
		JSR ControllerUpdate

		LDA !HDMA
		STA $420C

		INC !Wait
		LDA $4210       ; Clear NMI flag
		REP #$30
		PLB
		PLD
		PLY
		PLX
		PLA
		RTI
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; IRQ. Currently unused
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IRQ:
		JML +
+		SEI
		REP #$30
		PHA
		PHX
		PHY
		PHD
		PEA $0000
		PLD
		PHB
		PHK
		PLB
		SEP #$30
		
		LDA $4211
		BPL .IRQEnding
	
.IRQEnding
		REP #$30
		PLB
		PLD
		PLY
		PLX
		PLA
		RTI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; BRK, COP, ABORT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
youscrewedup:
		LDA #$0F
		STA $2100
		LDX #$00
		STX $2121
		LDX #$1F
		STX $2122
		LDX #$00
		STX $2122
		STP				; we don't want high energy bills

; I mostly copypasted this header ROM from an old project of mine
; I'm not sure if the values are correct or not BUT HEY the rom works
org $80FFB0
		db "FF"				;maker code.
		db "FFFF"			;game code.
		db $00,$00,$00,$00,$00,$00,$00	;fixed value, must be 0
		db $00				;expansion RAM size. SRAM size. 128kB
		db $00				;special version, normally 0
		db $00				;cartridge sub number, normally 0s

		db "SUPER CHIP8X         "	;ROM NAME
		db $30				;MAP MODE. Mode 30 = fastrom
		db $02				;cartridge type. ROM and RAM and SRAM
		db $09				;3-4 MBit ROM		
		db $00				;64K RAM		
		db $00				;Destination code: Japan
		db $33				;Fixed Value	
		db $00				;Mask ROM. This ROM is NOT revised.
		dw $B50F			;Complement Check.
		dw $4AF0			;Checksum

		;emulation mode
		dw $FFFF			;Unused
		dw $FFFF			;Unused
		dw youscrewedup		;COP
		dw youscrewedup		;BRK
		dw youscrewedup		;ABORT
		dw NMI				;NMI
		dw $FFFF			;Unused
		dw IRQ				;IRQ

		;native mode
		dw $FFFF			;Unused
		dw $FFFF			;Unused
		dw youscrewedup		;COP
		dw youscrewedup		;BRK
		dw youscrewedup		;ABORT
		dw $FFFF			;NMI
		dw RESET			;RESET
		dw $FFFF			;IRQ

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Data bank
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ORG $818000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; The palette
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pal:
	dw $0000,!PixelColor

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; The 0-9A-F chip-8 graphics
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
chr:
	incbin chrrom.bin

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; The chip-8 ROMs
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GAMES:
BOOT:
	incbin c8games/BOOT
.END
FIFTEENPUZZLE:
	incbin c8games/15PUZZLE
.END
BLINKY:
	incbin c8games/BLINKY
.END
BLITZ:
	incbin c8games/BLITZ
.END
BRIX:
	incbin c8games/BRIX
.END
CAVE:
	incbin c8games/CAVE
.END
CONNECT4:
	incbin c8games/CONNECT4
.END
GUESS:
	incbin c8games/GUESS
.END
HIDDEN:
	incbin c8games/HIDDEN
.END
INVADERS:
	incbin c8games/INVADERS
.END
KALEID:
	incbin c8games/KALEID
.END
KEYPAD:
	incbin c8games/KEYPAD
.END
MAZE:
	incbin c8games/MAZE
.END
MERLIN:
	incbin c8games/MERLIN
.END
MISSILE:
	incbin c8games/MISSILE
.END
PONG:
	incbin c8games/PONG
.END
PONG2:
	incbin c8games/PONG2
.END
PUZZLE:
	incbin c8games/PUZZLE
.END
REVERSI:
	incbin c8games/REVERSI
.END
RUSHHOUR:
	incbin c8games/RUSH_HOUR
.END
SNAKE:
	incbin c8games/SNAKE
.END
SYZYGY:
	incbin c8games/SYZYGY
.END
TANK:
	incbin c8games/TANK
.END
TETRIS:
	incbin c8games/TETRIS
.END
TICTAC:
	incbin c8games/TICTAC
.END
UFO:
	incbin c8games/UFO
.END
VBRIX:
	incbin c8games/VBRIX
.END
VERS:
	incbin c8games/VERS
.END
WALL:
	incbin c8games/WALL
.END
WIPEOFF:
	incbin c8games/WIPEOFF
.END
RNG:
	incbin c8games/RNG
.END
TRIP8:
	incbin c8games/TRIP8
.END
STARS:
	incbin c8games/STARS
.END
IBM:
	incbin c8games/IBM
.END

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Just making sure the ROM is 128kB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ORG $83FFFF
db $FF