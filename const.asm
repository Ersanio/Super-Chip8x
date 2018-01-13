;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; EMULATION SPEED
;;; Since Chip-8 doesn't have a defined processor speed,
;;; it is up to the coder user to define it.
;;;
;;; This variable controls the amount of chip-8 opcodes
;;; processed per frame.
;;;
;;; The higher the value, the faster the emulation speed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		!OpcodesPerFrame = #$0A

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Various emulator settings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		!PixelColor = $7BDE
		!BackgroundColor = $4A73
		!BlackBarsColor = $1CA4
		
		!BeepSamplePitch = $0BD4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Misc. operational RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		!Wait = $10
		!FrameCounter = $11
		
		;a x l r 0 0 0 0 b y select start U D L R		
		!ControllerData = $12  ;\
		!ControllerData2 = $13 ;/word
		
		!IsPressingKey = $14
		
		!ROMnumber = $15
		!ROMSwitchDelay = $16
		!HDMA = $17

		!UpdateGFX = $18 ;flag
		!OpcodeLoop = $19 ;byte
		
		!RNG1 = $1A
		!RNG2 = $1B
		
		!DrawOffsetX = $1C
		!DrawOffsetY = $1D
		
		;!SFX = $1F
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SNES display-related RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		!BG1X = $20
		!BG1Y = $22
		
		!Mode7CenterX = $24 ;word
		!Mode7CenterY = $26 ;word
		!Mode7MatrixA = $28 ;word
		!Mode7MatrixB = $2A ;word
		!Mode7MatrixC = $2C ;word
		!Mode7MatrixD = $2E ;word
		
		!Mode7Rotate = $30 ;word
		!Mode7ScaleX = $32 ;byte
		!Mode7ScaleY = $33 ;byte
		
		!Tilemap = $7E0040 ;32 (0x20) bytes
		!Graphics = $7E0100 ;2048 (0x800) bytes
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Chip-8 memory and registers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		!Chip8Memory = $7E1000 ;0x1000 bytes
		
		!Chip8MemoryROM = !Chip8Memory+$200
		
		!Vreg = $70 ;16 bytes
		!Stack = $80 ; 32 bytes (16 words)
		!Ireg = $A0 ;word
		!DelayTimer = $A2 ;byte
		!SoundTimer = $A3 ;byte
		!StackPointer = $A4 ;byte
		!RNGOutput = $A5
		!ProgramCounter = $A6 ;word
		!PressedKey = $1E

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Chip-8 opcode parameters RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		!Opcode = $A8 ;word
		!NNN = $AA ;word
		!NN = $AC ;byte
		!N = $AD ;byte
		!X = $AE ;byte
		!Y = $AF ;byte
