

EFFECT_NONE              = $00
EFFECT_NOTE_SLIDE_UP     = $01
EFFECT_NOTE_SLIDE_DOWN   = $02
EFFECT_NOTE_SLIDE_TO     = $03
EFFECT_NOTE_SLIDE_VOLUME = $05
EFFECT_VOLUME_SLIDE      = $0A
EFFECT_SET_VOLUME        = $0C
EFFECT_PATTERN_BREAK     = $0D
EFFECT_SET_SPEED         = $0F

FNUMBER_MIN = $0156
FNUMBER_MAX = $02AE

SongData .struct
patternOffsets      .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                    .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                    .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                    .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
orderListOffset     .word $00000000

songLength          .byte $00
InitialSpeed        .byte $06
hasSlowTimer        .byte $00 ;BOOL $00 = False, $01 = True
.ends

PlayerVariables .struct
loopSong            .byte $01 ; Bool
orders              .byte $00
line                .byte $00
tick                .byte $00
speed               .byte $06
endOfPattern        .byte $00 ; Bool
channelNote         .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
pitchSlideDest      .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
efftectParameter    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00
pitchSlideSpeed     .byte $00, $00, $00, $00, $00, $00, $00, $00, $00
patternBreak        .byte $FF
.ends

; special characters for notes
                    ;     C    C#   D    D#   E    F    F#   G    G#   A    A#   B    
note_array          .byte $43, $90, $44, $91, $45, $46, $92, $47, $93, $41, $94, $42, $43

; ************************************************************************************************
; We are assuming that the RAD File is already Loaded Somewhere
; ************************************************************************************************
RAD_INIT_PLAYER
            JSL OPL2_INIT   ; Init OPL2
              
            ; READ the RAD file
            setaxl
            LDA #<>RAD_FILE_TEMP ; Set the Pointer where the File Begins
            STA OPL2_ADDY_PTR_LO;
            LDA #<`RAD_FILE_TEMP
            STA OPL2_ADDY_PTR_HI;
            setas
            ; get the version of the file
            LDY #$0010
            LDA [OPL2_ADDY_PTR_LO],Y
            CMP #$10 ; BCD version 1.0 or 2.1
            BNE LOAD_VERSION_21
            JSL READ_VERSION_10
            RTL  ; End of RAD_INIT_PLAYER

    LOAD_VERSION_21
            JSL READ_VERSION_21
            RTL  ; End of RAD_INIT_PLAYER

; ************************************************************************************************
; Read a RAD file version 2.1
; ************************************************************************************************
READ_VERSION_21
            ;not implemented
            RTL  ; End of READ_VERSION_21

; ************************************************************************************************
; Read a RAD file version 1.1
; ************************************************************************************************
READ_VERSION_10
            JSR PARSER_RAD_FILE_INSTRUMENT_10; Go Parse the Instrument and Order list
            JSR PROCESS_ORDER_LIST_10
            JSR READ_PATTERNS_10

            RTL  ; End of READ_VERSION_10

ADLIB_OFFSETS .byte 7,1,8,2,9,3,10,4,5,11,6
;ADLIB_OFFSETS .byte 1,7,2,8,3,9,4,10,5,6,11

; ************************************************************************************************
; Read the instrument table
; ************************************************************************************************
PARSER_RAD_FILE_INSTRUMENT_10
            INY ; $11 bit 7: description, bit6: slow timer, bits4..0: speed
            
            LDA [OPL2_ADDY_PTR_LO],Y
            ;Will Ignore the has slowSlowTimer for now
            AND #$1F
            STA @lTuneInfo.InitialSpeed
            LDA [OPL2_ADDY_PTR_LO],Y
            AND #$80
            BEQ READ_INSTR_DATA
    Not_Done_With_Description
            INY ; Move the Pointer Forward
            LDA [OPL2_ADDY_PTR_LO],Y
            CMP #$00  ; Check for the End of Text
            BNE Not_Done_With_Description

    READ_INSTR_DATA
            INY ; This points after either After Description or next to Offset 0x11
            
            ; Let's Init the Address Point for the instrument Tables
            LDA #<`INSTRUMENT_ACCORDN
            STA RAD_ADDR + 2
            
            ; Let's Read Some Instruments HERE
    ProcessNextInstruments
            setas
            LDA [OPL2_ADDY_PTR_LO],Y  ; Read Instrument Number
            BEQ DoneProcessingInstrument;
            
            setal
            ; find the address of the instrument by multiplying by the record length
            DEC A
            STA @lM0_OPERAND_A
            LDA #INSTR_REC_LEN
            STA @lM0_OPERAND_B
            LDA @lM0_RESULT  ; not sure why this one requires a long address - bank is still 0
            
            CLC
            ADC #<>INSTRUMENT_ACCORDN
            STA RAD_ADDR
            LDA #0
            setas
            
            INY
            STZ RAD_TEMP
            STA [RAD_ADDR]  ; Not a drum instrument
            
    Transfer_Instrument_Info
            LDX RAD_TEMP
            LDA ADLIB_OFFSETS,X  ; RAD uses a different order for registers
            TAX
            
            LDA [OPL2_ADDY_PTR_LO],Y  ; Read Register
            PHY
            TXY
            STA [RAD_ADDR],Y  ; Write to the instrument table 
            PLY
            INY
            INC RAD_TEMP
            LDA RAD_TEMP
            CMP #11
            BCC Transfer_Instrument_Info
            
            PHY ; store the position in the file on the stack
            LDY #12 ; beginning of text
            LDA #$20
            ;TODO: set description to 'RAD INST #'
    BLANK_INSTR_DESCR
            STA [RAD_ADDR],Y
            INY
            CPY #22
            BNE BLANK_INSTR_DESCR
            PLY
            
            BRA ProcessNextInstruments;
            
    DoneProcessingInstrument
            INY
            RTS

; ************************************************************************************************
; * Read the orders list
; ************************************************************************************************
PROCESS_ORDER_LIST_10
            LDA [OPL2_ADDY_PTR_LO],Y  ; Read Song Length
            STA @lTuneInfo.songLength
            TAX
            INY
            
            setal
            LDA #<>ORDERS
            STA RAD_ADDR
            LDA #<`ORDERS
            STA RAD_ADDR + 2
            setas
    READ_ORDER
            LDA [OPL2_ADDY_PTR_LO],Y
            INY
            STA [RAD_ADDR]
            INC RAD_ADDR
            BCS ORDER_CONTINUE
            INC RAD_ADDR + 1
    ORDER_CONTINUE
            DEX
            BNE READ_ORDER
            RTS

; ************************************************************************************************
; * Read the pattern table
; * Y contains the position in the file
; ************************************************************************************************
READ_PATTERNS_10
            ; RAD_PATTRN holds the pattern number
            STZ RAD_PATTRN
            ; high byte of the pattern address
            LDA #<`PATTERNS
            STA RAD_PTN_DEST + 2
    NEXT_PATTERN
            
            ; read the file offset
            setal
            LDA [OPL2_ADDY_PTR_LO],Y
            BEQ SKIP_PATTERN
            
            PHY
            TAY
            
            ; compute the start address of the pattern
            LDA RAD_PATTRN
            AND #$00FF
            STA @lM0_OPERAND_A
            LDA #PATTERN_BYTES
            STA @lM0_OPERAND_B
            LDA @lM0_RESULT
            INC A ; skip the pattern byte
            STA RAD_PTN_DEST
            
            setas
            JSR READ_PATTERN_10
            PLY
            
    SKIP_PATTERN
            INY
            INY
            setas
            INC RAD_PATTRN
            LDA RAD_PATTRN
            CMP #32
            BNE NEXT_PATTERN
            RTS

; ************************************************************************************************
; * Read the pattern table
; * Y contains the position in the RAD 1.0 file
; * RAD_PTN_DEST is the address to write to
; ************************************************************************************************
READ_PATTERN_10
            LDA [OPL2_ADDY_PTR_LO],Y ; read the line number - bit 7 indicates the last line 
            STA @lRAD_LINE
            INY
            setal
            AND #$7F
            STA @lM0_OPERAND_A
            LDA #LINE_BYTES
            STA @lM0_OPERAND_B
            LDA @lM0_RESULT
            INC A ; skip the line number
            STA @lRAD_LINE_PTR
            setas
            
    READ_NOTE
            LDX RAD_LINE_PTR ; X contains the offset in the destination memory
 
            LDA [OPL2_ADDY_PTR_LO],Y ; channel - bit 7 indicates the last note
            INY
            STA @lRAD_LAST_NOTE
            AND #$F
            STA @lRAD_CHANNEL
            
            setal
            TXA
            CLC
            ADC RAD_CHANNEL ; multiply channel by 3
            ADC RAD_CHANNEL 
            ADC RAD_CHANNEL
            TAX
            setas
            
            LDA [OPL2_ADDY_PTR_LO],Y ; note / octave
            PHY
            TXY
            STA [RAD_PTN_DEST],Y
            PLY
            INY
            INX 
            
            LDA [OPL2_ADDY_PTR_LO],Y ; instrument/effect
            PHY
            TXY
            STA [RAD_PTN_DEST],Y
            PLY
            INY
            INX
            
            AND #$F
            BEQ CHECK_LASTNOTE
            
            LDA [OPL2_ADDY_PTR_LO],Y ; effect parameter
            PHY
            TXY
            STA [RAD_PTN_DEST],Y
            PLY
            INY
            INX
     CHECK_LASTNOTE
            LDA @lRAD_LAST_NOTE
            BPL READ_NOTE
            
            LDA @lRAD_LINE
            BPL READ_PATTERN_10
            RTS


;*****************************
; Draw 18 '-' in line 0 of the display
;*****************************
DRAW_BLANKS
            .as
            PHY
            PHX
            LDX #18
            LDY #0
            LDA #'-'
    BL_NEXT
            STA [SCREENBEGIN], Y
            INY
            DEX
            BNE BL_NEXT
            PLX
            PLY
            RTS
            
;**********************************************************
; Draw the RAD_PTN_DEST address at position specified by Y
;**********************************************************
DISPLAY_RAD_PTN_DEST
            .as
            PHY
            LDA RAD_PTN_DEST+2
            JSR WRITE_HEX
            INY
            INY
            LDA RAD_PTN_DEST+1
            JSR WRITE_HEX
            INY
            INY
            LDA RAD_PTN_DEST
            JSR WRITE_HEX
            PLY
            RTS
            
;**********************************************************
; Draw the value of A at position specified by Y
;**********************************************************
WRITE_A_LNG
            .al
            PHA
            PHA
            setas
            PLA
            JSR WRITE_HEX
            DEY
            DEY
            PLA
            JSR WRITE_HEX
            setal
            PLA
            RTS
            
; ************************************************************************************************
; * Turn off all notes to all 9 channels
; ************************************************************************************************
RAD_ALL_NOTES_OFF
            .as
            PHY
            setal
            LDA #<>OPL2_S_BASE
            STA OPL2_IND_ADDY_LL
            LDA #`OPL2_S_BASE
            STA OPL2_IND_ADDY_LL + 2
            setas
            LDY #$A0
            LDA #0
        NEXT_NOTE_OFF
            STA [OPL2_IND_ADDY_LL],Y
            INY
            CPY #$B9
            BNE NEXT_NOTE_OFF
            PLY
            RTS

; ************************************************************************************************
; * Play the notes given a pattern and line number.
; ************************************************************************************************
RAD_PLAYNOTES
            .as
            PHY
            JSR DRAW_BLANKS
            
            setal
            LDA PATTERN_NUM
            AND #$FF
            DEC A ; start at 0
            STA @lM0_OPERAND_A
            LDA #PATTERN_BYTES
            STA @lM0_OPERAND_B
            LDA @lM0_RESULT
            INC A ; skip the pattern number byte
            STA RAD_PTN_DEST
            
            setas
            LDA #<`PATTERNS
            STA RAD_PTN_DEST + 2
            LDY #128 * 2
            JSR DISPLAY_RAD_PTN_DEST
            setal
            
            LDA LINE_NUM_HEX
            AND #$7F
            STA @lM0_OPERAND_A
            LDA #LINE_BYTES
            STA @lM0_OPERAND_B
            LDA @lM0_RESULT
            INC A  ; skip the line number byte
            PHY
            LDY #128 + 2
            JSR WRITE_A_LNG
            PLY
            
            TAY
            LDA #0
            setas
            STZ OPL2_REG_REGION
        PN_NEXT_NOTE
            STA @lOPL2_CHANNEL
            
            LDA [RAD_PTN_DEST],Y  ; octave/note
            AND #$7F
            BEQ SKIP_NOTE  ; if the note is 0, don't play anything.
            JSR RAD_WRITE_OCT_NOTE
            
            LDA [RAD_PTN_DEST],Y  ; bit 7 is bit 4 of the instrument number
            AND #$80
            LSR A
            LSR A
            LSR A
            STA RAD_TEMP
            
            INY
            LDA [RAD_PTN_DEST],Y  ; instrument/effect
            AND #$F0
            LSR A
            LSR A
            LSR A
            LSR A
            ADC RAD_TEMP
            DEC A  ; instruments are starting at 0
            STA @lINSTR_NUMBER
     
            PHY
            LDX OPL2_CHANNEL
            LDA #0
            XBA
            LDA @lregisterOffsets_operator0,X
            TAX
            JSR LOAD_INSTRUMENT
            PLY
     
            LDA #0
            XBA
            LDA [RAD_PTN_DEST],Y  ; instrument/effect
            AND #$F
            ASL A ; double bytes
            ; we don't do anything with the effect
            TAX
            INY
            JSR (RAD_EFFECT_TABLE,X)
            INY
            setal
            PHY
            JSR OPL2_GET_REG_OFFSET
            JSL OPL2_PLAYNOTE
            PLY
            setas
            
    PN_CONTINUE
            ; increment the channel
            LDA @lOPL2_CHANNEL
            INC A
            CMP #9
            BNE PN_NEXT_NOTE
            BRA PN_END
    SKIP_NOTE
            INY
            INY
            INY
            BRA PN_CONTINUE
    PN_END
            PLY
            RTS

RAD_EFFECT_TABLE
            .word <>RAD_EFFECT_NONE              ; 00
            .word <>RAD_EFFECT_NOTE_SLIDE_UP     ; 01
            .word <>RAD_EFFECT_NOTE_SLIDE_DOWN   ; 02
            .word <>RAD_EFFECT_NOTE_SLIDE_TO     ; 03
            .word <>RAD_NOOP            
            .word <>RAD_EFFECT_NOTE_SLIDE_VOLUME ; 05
            .word <>RAD_NOOP            
            .word <>RAD_NOOP            
            .word <>RAD_NOOP            
            .word <>RAD_NOOP            
            .word <>RAD_EFFECT_VOLUME_SLIDE      ; 0A
            .word <>RAD_NOOP            
            .word <>RAD_EFFECT_SET_VOLUME        ; 0C
            .word <>RAD_EFFECT_PATTERN_BREAK     ; 0D
            .word <>RAD_NOOP            
            .word <>RAD_EFFECT_SET_SPEED         ; 0F

; ******************************************************
; * Y contains the pointer to the effect parameter
; ******************************************************
RAD_NOOP
RAD_EFFECT_NONE
RAD_EFFECT_NOTE_SLIDE_UP
RAD_EFFECT_NOTE_SLIDE_DOWN
RAD_EFFECT_NOTE_SLIDE_TO
RAD_EFFECT_NOTE_SLIDE_VOLUME
RAD_EFFECT_VOLUME_SLIDE
RAD_EFFECT_PATTERN_BREAK
RAD_EFFECT_SET_SPEED
            .as
            RTS

; ******************************************************
; * Y contains the pointer to the effect parameter
; ******************************************************
RAD_EFFECT_SET_VOLUME
            .as
            PHY
            setal
            LDA #<>OPL2_S_BASE
            STA OPL2_IND_ADDY_LL
            LDA #`OPL2_S_BASE
            STA OPL2_IND_ADDY_LL + 2
            setas

            LDA [RAD_PTN_DEST],Y  ; effect parameter
            AND #$7F
            BEQ HANDLE_ZERO
            DEC A
        HANDLE_ZERO
            EOR #$3F ; complement
            STA RAD_TEMP
            setxs
            LDX OPL2_CHANNEL
            LDA @lregisterOffsets_operator0,X
            CLC
            ADC #$40
            TAY
            LDA [OPL2_IND_ADDY_LL],Y
            AND #$C0 ; 
            CLC
            ADC RAD_TEMP
            STA [OPL2_IND_ADDY_LL],Y
            INY
            INY
            INY
            LDA [OPL2_IND_ADDY_LL],Y
            AND #$C0 ;
            CLC
            ADC RAD_TEMP
            STA [OPL2_IND_ADDY_LL],Y
            setxl
            PLY
            RTS

; ********************************
; * A contain the octave/note byte
; ********************************
RAD_WRITE_OCT_NOTE
            .as
            PHY
            PHA
            PHA
            LDA @lOPL2_CHANNEL
            ASL A
            TAY
            PLA
            JSR WRITE_HEX
            AND #$70 ; octave
            LSR
            LSR
            LSR
            LSR
            STA @lOPL2_OCTAVE
            PLA
            AND #$0F ; note
            STA @lOPL2_NOTE
            PLY
            RTS

RAD_PITCH_ADJUST
              setal
              LDA OPL2_PARAMETER2 ;amount = OPL2_PARAMETER2, OPL2_PARAMETER3
              JSL OPL2_GET_BLOCK
              STA OPL2_BLOCK
              JSL OPL2_GET_FNUMBER ;OPL2_PARAMETER0, OPL2_PARAMETER1
              setal
              CLC
              LDA OPL2_PARAMETER2
              ADC OPL2_PARAMETER0
              STA OPL2_PARAMETER0
              AND #$03FF
              CMP #FNUMBER_MIN ; 0x156
              BCS IncreaseOneOctave
              setas
              LDA OPL2_BLOCK
              CMP #$00
              BEQ ExitDropAnOctave
              DEC OPL2_BLOCK
;
;
;  // Drop one octave (if possible) when the F-number drops below octave minimum.
;  if (fNumber < FNUMBER_MIN) {
;    if (block > 0) {
;      block --;
;      fNumber = FNUMBER_MAX - (FNUMBER_MIN - fNumber);
;    }

;  // Increase one octave (if possible) when the F-number reaches above octave maximum.
;  } else if (fNumber > FNUMBER_MAX) {
;    if (block < 7) {
;      block ++;;
;      fNumber = FNUMBER_MIN + (fNumber - FNUMBER_MAX);;
;    }
;  }




ExitDropAnOctave
IncreaseOneOctave

              RTS


RAD_PLAYNOTE_2
              setas
              LDA #$00
              STA OPL2_PARAMETER0 ; Set Keyon False
              JSL OPL2_SET_KEYON
              ; Set Octave
              LDA OPL2_NOTE    ;Divide Note/12
              STA D0_OPERAND_A
              LDA #$00
              STA D0_OPERAND_A+1
              STA D0_OPERAND_B+1
              LDA #$0C
              STA D0_OPERAND_B
              CLC
              LDA OPL2_OCTAVE
              PHA
              ADC D0_RESULT
              STA OPL2_OCTAVE
              JSL OPL2_SET_BLOCK  ; OPL2_SET_BLOCK Already to OPL2_OCTAVE
              ; Now lets go pick the FNumber for the note we want
              PLA
              STA OPL2_OCTAVE
              setal
              CLC
              LDA OPL2_NOTE
              AND #$00FF
              ADC D0_REMAINDER    ; Remainder of the Division Modulo
              ASL A ;<<<<<<<<<<<<<<<<<<<<<<<<<
              TAX
              LDA @lnoteFNumbers,X
              ADC D0_REMAINDER    ; Remainder of the Division Modulo
              STA OPL2_PARAMETER0 ; Store the 16bit in Param OPL2_PARAMETER0 & OPL2_PARAMETER1
              JSL OPL2_SET_FNUMBER
              setas
              LDA #$01
              STA OPL2_PARAMETER0 ; Set Keyon False
              JSL OPL2_SET_KEYON
              setxl
              RTS

;
RAD_SETINSTRUMENT
              PHY
              ; Carrier
              setas
              LDA #$01
              STA OPL2_OPERATOR
              setal

              LDA #<`INSTRUMENT_ACCORDN
              STA OPL2_ADDY_PTR_HI
              LDA OPL2_PARAMETER0
              AND #$00FF
              DEC A
              ASL A
              ASL A
              ASL A
              ASL A
              CLC
              ADC #<>INSTRUMENT_ACCORDN
              STA OPL2_ADDY_PTR_LO
              setal
              LDA #$0020
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0000
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              setal
              LDA #$0040
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0002
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              setal
              LDA #$0060
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0004
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              setal
              LDA #$0080
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0006
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              setal
              LDA #$00E0
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0009
              LDA [OPL2_ADDY_PTR_LO],Y
              AND #$0F
              STA [OPL2_IND_ADDY_LL]
              ; MODULATOR
              LDA #$00
              STA OPL2_OPERATOR
              ;  opl2.setRegister(0x20 + registerOffset, instruments[instrumentIndex][1]);
              setal
              LDA #$0020
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0001
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              ;  opl2.setRegister(0x40 + registerOffset, instruments[instrumentIndex][3]);
              setal
              LDA #$0040
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0003
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              ; opl2.setRegister(0x60 + registerOffset, instruments[instrumentIndex][5]);
              setal
              LDA #$0060
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0005
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              ;  opl2.setRegister(0x80 + registerOffset, instruments[instrumentIndex][7]);
              setal
              LDA #$0080
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$00071
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              ;  opl2.setRegister(0xE0 + registerOffset, (instruments[instrumentIndex][9] & 0xF0) >> 4);
              setal
              LDA #$00E0
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0009
              LDA [OPL2_ADDY_PTR_LO],Y
              AND #$F0
              LSR A
              LSR A
              LSR A
              LSR A
              STA [OPL2_IND_ADDY_LL]
              ;  opl2.setRegister(0xC0 + channel, instruments[instrumentIndex][8]);
              LDA OPL2_CHANNEL
              CLC
              AND #$0F  ; This is just precaution, it should be between 0 to 8
              ADC #$C0
              STA OPL2_REG_OFFSET
              LDA #$00
              STA OPL2_REG_OFFSET+1;
              setaxl
              CLC
              LDA #<>OPL2_S_BASE
              ADC OPL2_REG_OFFSET
              STA OPL2_IND_ADDY_LL
              LDA #`OPL2_S_BASE
              STA OPL2_IND_ADDY_HL
              setas
              LDY #$0008
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              PLY
              RTS

COMPUTE_POINTER
              setal
              LDA #$000A ; Clear  ; Let's Find the Pointer in the Instruments List
              STA M1_OPERAND_A
              LDA OPL2_PARAMETER0 ; Which Entry in the list
              STA M1_OPERAND_B  ;
              CLC
              LDA OPL2_IND_ADDY_LL
              ADC M1_RESULT
              STA OPL2_IND_ADDY_LL
              RTS
;
;#define OPERATOR1 0
;#define OPERATOR2 1
;#define MODULATOR 0
;#define CARRIER   1

* = $170000
TuneInfo .dstruct SongData

.align 16
PlayerInfo .dstruct PlayerVariables


* = $178000
RAD_FILE_TEMP
.binary "RAD_Files/action.rad"  ; v1.0
;.binary "RAD_Files/adlibsp.rad"  ; v1.0
;.binary "RAD_Files/sp2.rad"      ; v1.0
;.binary "RAD_Files/backlash.rad" ; v1.0
;.binary "RAD_Files/burnzone.rad" ; v2.1 file
;.binary "RAD_Files/cpw.rad"      ; v1.0
