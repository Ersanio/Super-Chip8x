# Super Chip8x
The Super Chip8x is a Chip-8 Emulator for the Super Nintendo Entertainment System, written entirely in the 65c816 assembly language (and SPC-700 assembly for the audio).

# Screenshots
![title](https://user-images.githubusercontent.com/4497840/118404619-ee462200-b673-11eb-9882-342507db819d.gif)
![pong](https://user-images.githubusercontent.com/4497840/118404620-ef774f00-b673-11eb-8e7d-621753d8e70e.gif)
![bricks](https://user-images.githubusercontent.com/4497840/118404621-f00fe580-b673-11eb-840c-520eb120aa5e.gif)
![tetris](https://user-images.githubusercontent.com/4497840/118404623-f0a87c00-b673-11eb-992e-9cae2bb405b9.gif)
![maze](https://user-images.githubusercontent.com/4497840/118404624-f1411280-b673-11eb-89f8-459a6d3fc4c1.gif)

# Features
The emulator supports the option to mapping the 16 Chip-8 keys to SNES buttons (except for start and select) per ROM basis. The user will have to define the mapping manually. SNES button combinations are supported (e.g. B could be key 1, L+B could be key 2).

Some features (such as the sound pitch, the screen color, pixel color, etc.) can be controlled in const.asm

# Usage
Assemble chip8.asm by using the [asar](https://www.smwcentral.net/?p=section&s=tools&u=0&f%5Bname%5D=asar&f%5Bauthor%5D=&f%5Btags%5D=&f%5Bsource%5D=&f%5Bfeatured%5D=&f%5Bdescription%5D=) assembler.

To add ROMs, a few steps need to be done:
- chip8.asm: label "GAMES": Add the path to your ROM with labels:
```
ROMNAME:
	incbin c8games/ROMNAME ;the name of the file. Doesn't have to match label name
.END
```
- chip8.asm: label "ROMS": Add a pointer to the path you added in above step:
```
  dl ROMNAME : dw ROMNAME_END-ROMNAME ; the name of the labels surrounding the ROM file
```
- chip8.asm: label "ControllerLayouts": Add a pointer to a controller layout, CDefault if none.
- Make sure the ControllerLayouts is in sync with the ROMs table e.g. if the "tetris" game is the first game in ROMs, it has to be the first game in ControllerLayouts also.
- chip8.asm: below pointertable "ControllerLayouts": Add a controller layout in the format `"dw !pressedbutton : db $emulatedkey"`, repeat per key.

To switch between ROMs:
- Use Start to go forward a ROM
- Use Select to go backwards a ROM

Each ROM switch assumes a hard reset, re-initializing each Chip-8 register to their default values.
