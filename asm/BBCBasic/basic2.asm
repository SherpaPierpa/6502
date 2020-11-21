; Source for 6502 BASIC II
; BBC BASIC Copyright (C) 1982/1983 Acorn Computer and Roger Wilson
; Source reconstruction and commentary Copyright (C) J.G.Harston
; Port to CC65 by Jeff Tranter

; Macros to pack instruction mnemonics into two high bytes
.macro MNEML c1,c2,c3
        .byte ((c2 & $1F) << 5 + (c3 & $1F)) & $FF
.endmacro

.macro MNEMH c1,c2,c3
        .byte ((c1 & $1F) << 2 + (c2 & $1F) / 8) & $FF
.endmacro

; Symbols
        FAULT   = $FD
        ESCFLG  = $FF

; MOS Entry Points:
        OS_CLI  = $FFF7
        OSBYTE  = $FFF4
        OSWORD  = $FFF1
        OSWRCH  = $FFEE
        OSWRCR  = $FFEC
        OSNEWL  = $FFE7
        OSASCI  = $FFE3
        OSRDCH  = $FFE0
        OSFILE  = $FFDD
        OSARGS  = $FFDA
        OSBGET  = $FFD7
        OSBPUT  = $FFD4
        OSGBPB  = $FFD1
        OSFIND  = $FFCE
        BRKV    = $0202
        WRCHV   = $020E

; Dummy variables for non-Atom code
        OSECHO  = $0000
        OSLOAD  = $0000
        OSSAVE  = $0000
        OSRDAR  = $0000
        OSSTAR  = $0000
        OSSHUT  = $0000

; BASIC token values
        tknAND  = $80
        tknDIV  = $81
        tknEOR  = $82
        tknMOD  = $83
        tknOR   = $84
        tknERROR = $85
        tknLINE = $86
        tknOFF  = $87
        tknSTEP = $88
        tknSPC  = $89
        tknTAB  = $8A
        tknELSE = $8B
        tknTHEN = $8C
        tknERL  = $9E
        tknEXP  = $A1
        tknEXT  = $A2
        tknFN   = $A4
        tknLOG  = $AB
        tknTO   = $B8
        tknAUTO = $C6
        tknPTRc = $CF
        tknDATA = $DC
        tknDEF  = $DD
        tknRENUMBER = $CC
        tknDIM  = $DE
        tknEND  = $E0
        tknFOR  = $E3
        tknGOSUB = $E4
        tknGOTO = $E5
        tknIF   = $E7
        tknLOCAL = $EA
        tknMODE = $EB
        tknON   = $EE
        tknPRINT = $F1
        tknPROC = $F2
        tknREPEAT = $F5
        tknSTOP = $FA
        tknLOMEM = $92
        tknHIMEM = $93
        tknREPORT = $F6

        .org    $8000

; BBC Code Header

L8000:
        cmp     #$01            ; Language entry
        beq     L8023
        rts
        nop

        .byte   $60             ; ROM type=Lang+Tube+6502 BASIC
        .byte   L800E-L8000     ; Offset to copyright string
        .byte   $01             ; ROM version number, 2=$01, 3=$03
        .byte   "BASIC"         ; ROM title
L800E:
        .byte   0
        .byte   "(C)1982 Acorn" ; ROM copyright string
        .byte   10
        .byte   13
        .byte   0
        .word   $8000
        .word   $0000

; Language startup

L8023:
        lda     #$84            ; Read top of memory
        jsr     OSBYTE
        stx     $06             ; Set HIMEM
        sty     $07
        lda     #$83
        jsr     OSBYTE          ; Read bottom of memory
        sty     $18             ; Set PAGE
        ldx     #$00
        stx     $1F             ; Set LISTO to 0
        stx     $0402           ; Set @5 to 0000xxxx
        stx     $0403
        dex                     ; Set WIDTH to $FF
        stx     $23
        ldx     #$0A            ; Set @% to $0000090A
        stx     $0400
        dex
        stx     $0401
        lda     #$01            ; Check RND seed
        and     $11
        ora     $0D
        ora     $0E
        ora     $0F             ; If nonzero, skip past
        ora     $10
        bne     L8063
        lda     #$41            ; Set RND seed to $575241
        sta     $0D
        lda     #$52
        sta     $0E
        lda     #$57            ; "ARW" - Acorn Roger Wilson?
        sta     $0F
L8063:
        lda     #$02            ; Set up error handler
        sta     BRKV
        lda     #$B4
        sta     $0203
        cli                     ; Enable IRQs, jump to immediate loop
        jmp     L8ADD

; TOKEN TABLE
; ===========
; string, token (b7=1), flag
;
; Token flag:
; Bit 0 - Conditional tokenisation (don't tokenise if followed by an alphabetic character).
; Bit 1 - Go into "middle of Statement" mode.
; Bit 2 - Go into "Start of Statement" mode.
; Bit 3 - FN/PROC keyword - don't tokenise the name of the subroutine.
; Bit 4 - Start tokenising a line number now (after a GOTO, etc...).
; Bit 5 - Don't tokenise rest of line (REM, DATA, etc...)
; Bit 6 - Pseudo variable flag - add &40 to token if at the start of a statement/hex number
; Bit 7 - Unused - used externally for quote toggle.

L8071:
        .byte   "AND",$80,$00   ; 00000000
        .byte   "ABS",$94,$00   ; 00000000
        .byte   "ACS",$95,$00   ; 00000000
        .byte   "ADVAL",$96,$00 ; 00000000
        .byte   "ASC",$97,$00   ; 00000000
        .byte   "ASN",$98,$00   ; 00000000
        .byte   "ATN",$99,$00   ; 00000000
        .byte   "AUTO",$C6,$10  ; 00010000
        .byte   "BGET",$9A,$01  ; 00000001
        .byte   "BPUT",$D5,$03  ; 00000011
        .byte   "COLOUR",$FB,$02 ; 00000010
        .byte   "CALL",$D6,$02  ; 00000010
        .byte   "CHAIN",$D7,$02 ; 00000010
        .byte   "CHR$",$BD,$00  ; 00000000
        .byte   "CLEAR",$D8,$01 ; 00000001
        .byte   "CLOSE",$D9,$03 ; 00000011
        .byte   "CLG",$DA,$01   ; 00000001
        .byte   "CLS",$DB,$01   ; 00000001
        .byte   "COS",$9B,$00   ; 00000000
        .byte   "COUNT",$9C,$01 ; 00000001
        .byte   "DATA",$DC,$20  ; 00100000
        .byte   "DEG",$9D,$00   ; 00000000
        .byte   "DEF",$DD,$00   ; 00000000
        .byte   "DELETE",$C7,$10 ; 00010000
        .byte   "DIV",$81,$00   ; 00000000
        .byte   "DIM",$DE,$02   ; 00000010
        .byte   "DRAW",$DF,$02  ; 00000010
        .byte   "ENDPROC",$E1,$01 ; 00000001
        .byte   "END",$E0,$01   ; 00000001
        .byte   "ENVELOPE",$E2,$02 ; 00000010
        .byte   "ELSE",$8B,$14  ; 00010100
        .byte   "EVAL",$A0,$00  ; 00000000
        .byte   "ERL",$9E,$01   ; 00000001
        .byte   "ERROR",$85,$04 ; 00000100
        .byte   "EOF",$C5,$01   ; 00000001
        .byte   "EOR",$82,$00   ; 00000000
        .byte   "ERR",$9F,$01   ; 00000001
        .byte   "EXP",$A1,$00   ; 00000000
        .byte   "EXT",$A2,$01   ; 00000001
        .byte   "FOR",$E3,$02   ; 00000010
        .byte   "FALSE",$A3,$01 ; 00000001
        .byte   "FN",$A4,$08    ; 00001000
        .byte   "GOTO",$E5,$12  ; 00010010
        .byte   "GET$",$BE,$00  ; 00000000
        .byte   "GET",$A5,$00   ; 00000000
        .byte   "GOSUB",$E4,$12 ; 00010010
        .byte   "GCOL",$E6,$02  ; 00000010
        .byte   "HIMEM",$93,$43 ; 00100011
        .byte   "INPUT",$E8,$02 ; 00000010
        .byte   "IF",$E7,$02    ; 00000010
        .byte   "INKEY$",$BF,$00 ; 00000000
        .byte   "INKEY",$A6,$00 ; 00000000
        .byte   "INT",$A8,$00   ; 00000000
        .byte   "INSTR(",$A7,$00 ; 00000000
        .byte   "LIST",$C9,$10  ; 00010000
        .byte   "LINE",$86,$00  ; 00000000
        .byte   "LOAD",$C8,$02  ; 00000010
        .byte   "LOMEM",$92,$43 ; 01000011
        .byte   "LOCAL",$EA,$02 ; 00000010
        .byte   "LEFT$(",$C0,$00 ; 00000000
        .byte   "LEN",$A9,$00   ; 00000000
        .byte   "LET",$E9,$04   ; 00000100
        .byte   "LOG",$AB,$00   ; 00000000
        .byte   "LN",$AA,$00    ; 00000000
        .byte   "MID$(",$C1,$00 ; 00000000
        .byte   "MODE",$EB,$02  ; 00000010
        .byte   "MOD",$83,$00   ; 00000000
        .byte   "MOVE",$EC,$02  ; 00000010
        .byte   "NEXT",$ED,$02  ; 00000010
        .byte   "NEW",$CA,$01   ; 00000001
        .byte   "NOT",$AC,$00   ; 00000000
        .byte   "OLD",$CB,$01   ; 00000001
        .byte   "ON",$EE,$02    ; 00000010
        .byte   "OFF",$87,$00   ; 00000000
        .byte   "OR",$84,$00    ; 00000000
        .byte   "OPENIN",$8E,$00 ; 00000000
        .byte   "OPENOUT",$AE,$00 ; 00000000
        .byte   "OPENUP",$AD,$00 ; 00000000
        .byte   "OSCLI",$FF,$02 ; 00000010
        .byte   "PRINT",$F1,$02 ; 00000010
        .byte   "PAGE",$90,$43  ; 01000011
        .byte   "PTR",$8F,$43   ; 01000011
        .byte   "PI",$AF,$01    ; 00000001
        .byte   "PLOT",$F0,$02  ; 00000010
        .byte   "POINT(",$B0,$00 ; 00000000
        .byte   "PROC",$F2,$0A  ; 00001010
        .byte   "POS",$B1,$01   ; 00000001
        .byte   "RETURN",$F8,$01 ; 00000001
        .byte   "REPEAT",$F5,$00 ; 00000000
        .byte   "REPORT",$F6,$01 ; 00000001
        .byte   "READ",$F3,$02  ; 00000010
        .byte   "REM",$F4,$20   ; 00100000
        .byte   "RUN",$F9,$01   ; 00000001
        .byte   "RAD",$B2,$00   ; 00000000
        .byte   "RESTORE",$F7,$12 ; 00010010
        .byte   "RIGHT$(",$C2,$00 ; 00000000
        .byte   "RND",$B3,$01   ; 00000001
        .byte   "RENUMBER",$CC,$10 ; 00010000
        .byte   "STEP",$88,$00  ; 00000000
        .byte   "SAVE",$CD,$02  ; 00000010
        .byte   "SGN",$B4,$00   ; 00000000
        .byte   "SIN",$B5,$00   ; 00000000
        .byte   "SQR",$B6,$00   ; 00000000
        .byte   "SPC",$89,$00   ; 00000000
        .byte   "STR$",$C3,$00  ; 00000000
        .byte   "STRING$(",$C4,$00 ; 00000000
        .byte   "SOUND",$D4,$02 ; 00000010
        .byte   "STOP",$FA,$01  ; 00000001
        .byte   "TAN",$B7,$00   ; 00000000
        .byte   "THEN",$8C,$14  ; 00010100
        .byte   "TO",$B8,$00    ; 00000000
        .byte   "TAB(",$8A,$00  ; 00000000
        .byte   "TRACE",$FC,$12 ; 00010010
        .byte   "TIME",$91,$43  ; 01000011
        .byte   "TRUE",$B9,$01  ; 00000001
        .byte   "UNTIL",$FD,$02 ; 00000010
        .byte   "USR",$BA,$00   ; 00000000
        .byte   "VDU",$EF,$02   ; 00000010
        .byte   "VAL",$BB,$00   ; 00000000
        .byte   "VPOS",$BC,$01  ; 00000001
        .byte   "WIDTH",$FE,$02 ; 00000010
        .byte   "PAGE",$D0,$00  ; 00000000
        .byte   "PTR",$CF,$00   ; 00000000
        .byte   "TIME",$D1,$00  ; 00000000
        .byte   "LOMEM",$D2,$00 ; 00000000
        .byte   "HIMEM",$D3,$00 ; 00000000

; FUNCTION/COMMAND DISPATCH TABLE, ADDRESS LOW BYTES
; ==================================================
L836D:
        .byte   $BF78 & $FF     ; &8E - OPENIN
        .byte   $BF47 & $FF     ; &8F - PTR
        .byte   $AEC0 & 255     ; &90 - PAGE
        .byte   $AEB4 & 255     ; &91 - TIME
        .byte   $AEFC & 255     ; &92 - LOMEM
        .byte   $AF03 & 255     ; &93 - HIMEM
        .byte   $AD6A & $FF     ; &94 - ABS
        .byte   $A8D4 & $FF     ; &95 - ACS
        .byte   $AB33 & $FF     ; &96 - ADVAL
        .byte   $AC9E & $FF     ; &97 - ASC
        .byte   $A8DA & $FF     ; &98 - ASN
        .byte   $A907 & $FF     ; &99 - ATN
        .byte   $BF6F & $FF     ; &9A - BGET
        .byte   $A98D & $FF     ; &9B - COS
        .byte   $AEF7 & $FF     ; &9C - COUNT
        .byte   $ABC2 & $FF     ; &9D - DEG
        .byte   $AF9F & $FF     ; &9E - ERL
        .byte   $AFA6 & $FF     ; &9F - ERR
        .byte   $ABE9 & $FF     ; &A0 - EVAL
        .byte   $AA91 & $FF     ; &A1 - EXP
        .byte   $BF46 & $FF     ; &A2 - EXT
        .byte   $AECA & $FF     ; &A3 - FALSE
        .byte   $B195 & $FF     ; &A4 - FN
        .byte   $AFB9 & $FF     ; &A5 - GET
        .byte   $ACAD & $FF     ; &A6 - INKEY
        .byte   $ACE2 & $FF     ; &A7 - INSTR(
        .byte   $AC78 & $FF     ; &A8 - INT
        .byte   $AED1 & $FF     ; &A9 - LEN
        .byte   $A7FE & $FF     ; &AA - LN
        .byte   $ABA8 & $FF     ; &AB - LOG
        .byte   $ACD1 & $FF     ; &AC - NOT
        .byte   $BF80 & $FF     ; &AD - OPENUP
        .byte   $BF7C & $FF     ; &AE - OPENOUT
        .byte   $ABCB & $FF     ; &AF - PI
        .byte   $AB41 & $FF     ; &B0 - POINT(
        .byte   $AB6D & $FF     ; &B1 - POS
        .byte   $ABB1 & $FF     ; &B2 - RAD
        .byte   $AF49 & $FF     ; &B3 - RND
        .byte   $AB88 & $FF     ; &B4 - SGN
        .byte   $A998 & $FF     ; &B5 - SIN
        .byte   $A7B4 & $FF     ; &B6 - SQR
        .byte   $A6BE & $FF     ; &B7 - TAN
        .byte   $AEDC & $FF     ; &B8 - TO
        .byte   $ACC4 & $FF     ; &B9 - TRUE
        .byte   $ABD2 & $FF     ; &BA - USR
        .byte   $AC2F & $FF     ; &BB - VAL
        .byte   $AB76 & $FF     ; &BC - VPOS
        .byte   $B3BD & $FF     ; &BD - CHR$
        .byte   $AFBF & $FF     ; &BE - GET$
        .byte   $B026 & $FF     ; &BF - INKEY$
        .byte   $AFCC & $FF     ; &C0 - LEFT$(
        .byte   $B039 & $FF     ; &C1 - MID$(
        .byte   $AFEE & $FF     ; &C2 - RIGHT$(
        .byte   $B094 & $FF     ; &C3 - STR$(
        .byte   $B0C2 & $FF     ; &C4 - STRING$(
        .byte   $ACB8 & $FF     ; &C5 - EOF
        .byte   L90AC & $FF     ; &C6 - AUTO
        .byte   L8F31 & $FF     ; &C7 - DELETE
        .byte   $BF24 & $FF     ; &C8 - LOAD
        .byte   $B59C & $FF     ; &C9 - LIST
        .byte   L8ADA & $FF     ; &CA - NEW
        .byte   L8AB6 & $FF     ; &CB - OLD
        .byte   L8FA3 & $FF     ; &CC - RENUMBER
        .byte   $BEF3 & $FF     ; &CD - SAVE
        .byte   L982A & $FF     ; &CE - unused
        .byte   $BF30 & $FF     ; &CF - PTR
        .byte   L9283 & $FF     ; &D0 - PAGE
        .byte   L92C9 & $FF     ; &D1 - TIME
        .byte   L926F & $FF     ; &D2 - LOMEM
        .byte   L925D & $FF     ; &D3 - HIMEM
        .byte   $B44C & $FF     ; &D4 - SOUND
        .byte   $BF58 & $FF     ; &D5 - BPUT
        .byte   L8ED2 & $FF     ; &D6 - CALL
        .byte   $BF2A & $FF     ; &D7 - CHAIN
        .byte   L928D & $FF     ; &D8 - CLEAR
        .byte   $BF99 & $FF     ; &D9 - CLOSE
        .byte   L8EBD & $FF     ; &DA - CLG
        .byte   L8EC4 & $FF     ; &DB - CLS
        .byte   L8B7D & $FF     ; &DC - DATA
        .byte   L8B7D & $FF     ; &DD - DEF
        .byte   L912F & $FF     ; &DE - DIM
        .byte   L93E8 & $FF     ; &DF - DRAW
        .byte   L8AC8 & $FF     ; &E0 - END
        .byte   L9356 & $FF     ; &E1 - ENDPROC
        .byte   $B472 & $FF     ; &E2 - ENVELOPE
        .byte   $B7C4 & $FF     ; &E3 - FOR
        .byte   $B888 & $FF     ; &E4 - GOSUB
        .byte   $B8CC & $FF     ; &E5 - GOTO
        .byte   L937A & $FF     ; &E6 - GCOL
        .byte   L98C2 & $FF     ; &E7 - IF
        .byte   $BA44 & $FF     ; &E8 - INPUT
        .byte   L8BE4 & $FF     ; &E9 - LET
        .byte   L9323 & $FF     ; &EA - LOCAL
        .byte   L939A & $FF     ; &EB - MODE
        .byte   L93E4 & $FF     ; &EC - MOVE
        .byte   $B695 & $FF     ; &ED - NEXT
        .byte   $B915 & $FF     ; &EE - ON
        .byte   L942F & $FF     ; &EF - VDU
        .byte   L93F1 & $FF     ; &F0 - PLOT
        .byte   L8D9A & $FF     ; &F1 - PRINT
        .byte   L9304 & $FF     ; &F2 - PROC
        .byte   $BB1F & $FF     ; &F3 - READ
        .byte   L8B7D & $FF     ; &F4 - REM
        .byte   $BBE4 & $FF     ; &F5 - REPEAT
        .byte   $BFE4 & $FF     ; &F6 - REPORT
        .byte   $BAE6 & $FF     ; &F7 - RESTORE
        .byte   $B8B6 & $FF     ; &F8 - RETURN
        .byte   $BD11 & $FF     ; &F9 - RUN
        .byte   L8AD0 & $FF     ; &FA - STOP
        .byte   L938E & $FF     ; &FB - COLOUR
        .byte   L9295 & $FF     ; &FC - TRACE
        .byte   $BBB1 & $FF     ; &FD - UNTIL
        .byte   $B4A0 & $FF     ; &FE - WIDTH
        .byte   $BEC2 & $FF     ; &FF - OSCLI

; FUNCTION/COMMAND DISPATCH TABLE, ADDRESS HIGH BYTES
; ===================================================
L83DF: ; &83E6
        .byte   $BF78 / 256     ; &8E - OPENIN
        .byte   $BF47 / 256     ; &8F - PTR
        .byte   $AEC0 / 256     ; &90 - PAGE
        .byte   $AEB4 / 256     ; &91 - TIME
        .byte   $AEFC / 256     ; &92 - LOMEM
        .byte   $AF03 / 256     ; &93 - HIMEM
        .byte   $AD6A / 256     ; &94 - ABS
        .byte   $A8D4 / 256     ; &95 - ACS
        .byte   $AB33 / 256     ; &96 - ADVAL
        .byte   $AC9E / 256     ; &97 - ASC
        .byte   $A8DA / 256     ; &98 - ASN
        .byte   $A907 / 256     ; &99 - ATN
        .byte   $BF6F / 256     ; &9A - BGET
        .byte   $A98D / 256     ; &9B - COS
        .byte   $AEF7 / 256     ; &9C - COUNT
        .byte   $ABC2 / 256     ; &9D - DEG
        .byte   $AF9F / 256     ; &9E - ERL
        .byte   $AFA6 / 256     ; &9F - ERR
        .byte   $ABE9 / 256     ; &A0 - EVAL
        .byte   $AA91 / 256     ; &A1 - EXP
        .byte   $BF46 / 256     ; &A2 - EXT
        .byte   $AECA / 256     ; &A3 - FALSE
        .byte   $B195 / 256     ; &A4 - FN
        .byte   $AFB9 / 256     ; &A5 - GET
        .byte   $ACAD / 256     ; &A6 - INKEY
        .byte   $ACE2 / 256     ; &A7 - INSTR(
        .byte   $AC78 / 256     ; &A8 - INT
        .byte   $AED1 / 256     ; &A9 - LEN
        .byte   $A7FE / 256     ; &AA - LN
        .byte   $ABA8 / 256     ; &AB - LOG
        .byte   $ACD1 / 256     ; &AC - NOT
        .byte   $BF80 / 256     ; &AD - OPENUP
        .byte   $BF7C / 256     ; &AE - OPENOUT
        .byte   $ABCB / 256     ; &AF - PI
        .byte   $AB41 / 256     ; &B0 - POINT(
        .byte   $AB6D / 256     ; &B1 - POS
        .byte   $ABB1 / 256     ; &B2 - RAD
        .byte   $AF49 / 256     ; &B3 - RND
        .byte   $AB88 / 256     ; &B4 - SGN
        .byte   $A998 / 256     ; &B5 - SIN
        .byte   $A7B4 / 256     ; &B6 - SQR
        .byte   $A6BE / 256     ; &B7 - TAN
        .byte   $AEDC / 256     ; &B8 - TO
        .byte   $ACC4 / 256     ; &B9 - TRUE
        .byte   $ABD2 / 256     ; &BA - USR
        .byte   $AC2F / 256     ; &BB - VAL
        .byte   $AB76 / 256     ; &BC - VPOS
        .byte   $B3BD / 256     ; &BD - CHR$
        .byte   $AFBF / 256     ; &BE - GET$
        .byte   $B026 / 256     ; &BF - INKEY$
        .byte   $AFCC / 256     ; &C0 - LEFT$(
        .byte   $B039 / 256     ; &C1 - MID$(
        .byte   $AFEE / 256     ; &C2 - RIGHT$(
        .byte   $B094 / 256     ; &C3 - STR$(
        .byte   $B0C2 / 256     ; &C4 - STRING$(
        .byte   $ACB8 / 256     ; &C5 - EOF
        .byte   L90AC / 256     ; &C6 - AUTO
        .byte   L8F31 / 256     ; &C7 - DELETE
        .byte   $BF24 / 256     ; &C8 - LOAD
        .byte   $B59C / 256     ; &C9 - LIST
        .byte   L8ADA / 256     ; &CA - NEW
        .byte   L8AB6 / 256     ; &CB - OLD
        .byte   L8FA3 / 256     ; &CC - RENUMBER
        .byte   $BEF3 / 256     ; &CD - SAVE
        .byte   L982A / 256     ; &CE - unused
        .byte   $BF30 / 256     ; &CF - PTR
        .byte   L9283 / 256     ; &D0 - PAGE
        .byte   L92C9 / 256     ; &D1 - TIME
        .byte   L926F / 256     ; &D2 - LOMEM
        .byte   L925D / 256     ; &D3 - HIMEM
        .byte   $B44C / 256     ; &D4 - SOUND
        .byte   $BF58 / 256     ; &D5 - BPUT
        .byte   L8ED2 / 256     ; &D6 - CALL
        .byte   $BF2A / 256     ; &D7 - CHAIN
        .byte   L928D / 256     ; &D8 - CLEAR
        .byte   $BF99 / 256     ; &D9 - CLOSE
        .byte   L8EBD / 256     ; &DA - CLG
        .byte   L8EC4 / 256     ; &DB - CLS
        .byte   L8B7D / 256     ; &DC - DATA
        .byte   L8B7D / 256     ; &DD - DEF
        .byte   L912F / 256     ; &DE - DIM
        .byte   L93E8 / 256     ; &DF - DRAW
        .byte   L8AC8 / 256     ; &E0 - END
        .byte   L9356 / 256     ; &E1 - ENDPROC
        .byte   $B472 / 256     ; &E2 - ENVELOPE
        .byte   $B7C4 / 256     ; &E3 - FOR
        .byte   $B888 / 256     ; &E4 - GOSUB
        .byte   $B8CC / 256     ; &E5 - GOTO
        .byte   L937A / 256     ; &E6 - GCOL
        .byte   L98C2 / 256     ; &E7 - IF
        .byte   $BA44 / 256     ; &E8 - INPUT
        .byte   L8BE4 / 256     ; &E9 - LET
        .byte   L9323 / 256     ; &EA - LOCAL
        .byte   L939A / 256     ; &EB - MODE
        .byte   L93E4 / 256     ; &EC - MOVE
        .byte   $B695 / 256     ; &ED - NEXT
        .byte   $B915 / 256     ; &EE - ON
        .byte   L942F / 256     ; &EF - VDU
        .byte   L93F1 / 256     ; &F0 - PLOT
        .byte   L8D9A / 256     ; &F1 - PRINT
        .byte   L9304 / 256     ; &F2 - PROC
        .byte   $BB1F / 256     ; &F3 - READ
        .byte   L8B7D / 256     ; &F4 - REM
        .byte   $BBE4 / 256     ; &F5 - REPEAT
        .byte   $BFE4 / 256     ; &F6 - REPORT
        .byte   $BAE6 / 256     ; &F7 - RESTORE
        .byte   $B8B6 / 256     ; &F8 - RETURN
        .byte   $BD11 / 256     ; &F9 - RUN
        .byte   L8AD0 / 256     ; &FA - STOP
        .byte   L938E / 256     ; &FB - COLOUR
        .byte   L9295 / 256     ; &FC - TRACE
        .byte   $BBB1 / 256     ; &FD - UNTIL
        .byte   $B4A0 / 256     ; &FE - WIDTH
        .byte   $BEC2 / 256     ; &FF - OSCLI

; ASSEMBLER
; =========
;
; Packed mnemonic table, low bytes
; --------------------------------
L8451:
        MNEML 'B','R','K'
        MNEML 'C','L','C'
        MNEML 'C','L','D'
        MNEML 'C','L','I'
        MNEML 'C','L','V'
        MNEML 'D','E','X'
        MNEML 'D','E','Y'
        MNEML 'I','N','X'
        MNEML 'I','N','Y'
        MNEML 'N','O','P'
        MNEML 'P','H','A'
        MNEML 'P','H','P'
        MNEML 'P','L','A'
        MNEML 'P','L','P'
        MNEML 'R','T','I'
        MNEML 'R','T','S'
        MNEML 'S','E','C'
        MNEML 'S','E','D'
        MNEML 'S','E','I'
        MNEML 'T','A','X'
        MNEML 'T','A','Y'
        MNEML 'T','S','X'
        MNEML 'T','X','A'
        MNEML 'T','X','S'
        MNEML 'T','Y','A'
        MNEML 'B','C','C'
        MNEML 'B','C','S'
        MNEML 'B','E','Q'
        MNEML 'B','M','I'
        MNEML 'B','N','E'
        MNEML 'B','P','L'
        MNEML 'B','V','C'
        MNEML 'B','V','S'
        MNEML 'A','N','D'
        MNEML 'E','O','R'
        MNEML 'O','R','A'
        MNEML 'A','D','C'
        MNEML 'C','M','P'
        MNEML 'L','D','A'
        MNEML 'S','B','C'
        MNEML 'A','S','L'
        MNEML 'L','S','R'
        MNEML 'R','O','L'
        MNEML 'R','O','R'
        MNEML 'D','E','C'
        MNEML 'I','N','C'
        MNEML 'C','P','X'
        MNEML 'C','P','Y'
        MNEML 'B','I','T'
        MNEML 'J','M','P'
        MNEML 'J','S','R'
        MNEML 'L','D','X'
        MNEML 'L','D','Y'
        MNEML 'S','T','A'
        MNEML 'S','T','X'
        MNEML 'S','T','Y'
        MNEML 'O','P','T'
        MNEML 'E','Q','U'

; Packed mnemonic table, high bytes
; ---------------------------------
L848B:
        MNEMH 'B','R','K'
        MNEMH 'C','L','C'
        MNEMH 'C','L','D'
        MNEMH 'C','L','I'
        MNEMH 'C','L','V'
        MNEMH 'D','E','X'
        MNEMH 'D','E','Y'
        MNEMH 'I','N','X'
        MNEMH 'I','N','Y'
        MNEMH 'N','O','P'
        MNEMH 'P','H','A'
        MNEMH 'P','H','P'
        MNEMH 'P','L','A'
        MNEMH 'P','L','P'
        MNEMH 'R','T','I'
        MNEMH 'R','T','S'
        MNEMH 'S','E','C'
        MNEMH 'S','E','D'
        MNEMH 'S','E','I'
        MNEMH 'T','A','X'
        MNEMH 'T','A','Y'
        MNEMH 'T','S','X'
        MNEMH 'T','X','A'
        MNEMH 'T','X','S'
        MNEMH 'T','Y','A'
        MNEMH 'B','C','C'
        MNEMH 'B','C','S'
        MNEMH 'B','E','Q'
        MNEMH 'B','M','I'
        MNEMH 'B','N','E'
        MNEMH 'B','P','L'
        MNEMH 'B','V','C'
        MNEMH 'B','V','S'
        MNEMH 'A','N','D'
        MNEMH 'E','O','R'
        MNEMH 'O','R','A'
        MNEMH 'A','D','C'
        MNEMH 'C','M','P'
        MNEMH 'L','D','A'
        MNEMH 'S','B','C'
        MNEMH 'A','S','L'
        MNEMH 'L','S','R'
        MNEMH 'R','O','L'
        MNEMH 'R','O','R'
        MNEMH 'D','E','C'
        MNEMH 'I','N','C'
        MNEMH 'C','P','X'
        MNEMH 'C','P','Y'
        MNEMH 'B','I','T'
        MNEMH 'J','M','P'
        MNEMH 'J','S','R'
        MNEMH 'L','D','X'
        MNEMH 'L','D','Y'
        MNEMH 'S','T','A'
        MNEMH 'S','T','X'
        MNEMH 'S','T','Y'
        MNEMH 'O','P','T'
        MNEMH 'E','Q','U'

; Opcode base table
; -----------------
L84C5:

; No arguments
; ------------
        BRK
        CLC
        CLD
        CLI
        CLV
        DEX
        DEY
        INX
        INY
        NOP
        PHA
        PHP
        PLA
        PLP
        RTI
        RTS
        SEC
        SED
        SEI
        TAX
        TAY
        TSX
        TXA
        TXS
        TYA

; Branches
; --------
        .byte   $90, $B0, $F0, $30 ; BMI, BCC, BCS, BEQ
        .byte   $D0, $10, $50, $70 ; BNE, BPL, BVC, BVS

; Arithmetic
; ----------
        .byte   $21, $41, $01, $61 ; AND, EOR, ORA, ADC
        .byte   $C1, $A1, $E1, $06 ; CMP, LDA, SBC, ASL
        .byte   $46, $26, $66, $C6 ; LSR, ROL, ROR, DEC
        .byte   $E6, $E0, $C0, $20 ; INC, CPX, CPY, BIT

; Others
; ------
        .byte   $4C, $20, $A2, $A0 ; JMP, JSR, LDX, LDY
        .byte   $81, $86, $84      ; STA, STX, STY

; Exit Assembler
; --------------
L84FD:
        lda     #$FF            ; Set OPT to 'BASIC'
L84FF:
        sta     $28             ; Set OPT, return to execution loop
        jmp     L8BA3
L8504:
        lda     #$03            ; Set OPT 3, default on entry to '['
        sta     $28
L8508:
        jsr    L8A97            ; Skip spaces
        cmp    #']'             ; ']' - exit assembler
        beq    L84FD
        jsr    L986D
L8512:
        dec    $0A
        jsr    L85BA
        dec    $0A
        lda    $28
        lsr    a
        bcc    L857E
        lda    $1E
        adc    #$04
        sta    $3F
        lda    $38
        jsr    $B545
        lda    $37
        jsr    $B562
        ldx    #$FC
        ldy    $39
        bpl    L8536
        ldy    $36
L8536:
        sty    $38
        beq    L8556
        ldy    #$00
L853C:
        inx
        bne    L854C
        jsr    $BC25            ; Print newline
        ldx    $3F

L8544:
        jsr    $B565            ; Print a space
        dex                     ; Loop to print spaces
        bne    L8544
        ldx    #$FD
L854C:
        lda    ($3A),y
        jsr    $B562
        iny
        dec    $38
        bne    L853C
L8556:
        inx
        bpl    L8565
        jsr    $B565
        jsr    $B558
        jsr    $B558
        jmp    L8556
L8565:
        ldy    #$00
L8567:
        lda    ($0B),y
        cmp    #$3A
        beq    L8577
        cmp    #$0D
        beq    L857B
L8571:
        jsr    $B50E            ; Print character or token
        iny
        bne    L8567
L8577:
        cpy    $0A
        bcc    L8571
L857B:
        jsr    $BC25            ; Print newline
L857E:
        ldy    $0A
        dey
L8581:
        iny
        lda    ($0B),y
        cmp    #$3A
        beq    L858C
        cmp    #$0D
        bne    L8581
L858C:
        jsr    L9859
        dey
        lda    ($0B),y
        cmp    #$3A
        beq    L85A2
        lda    $0C
        cmp    #$07
        bne    L859F
        jmp    L8AF6
L859F:
        jsr    L9890
L85A2:
        jmp    L8508
L85A5:
        jsr    L9582
        beq    L8604
        bcs    L8604
        jsr    $BD94
        jsr    $AE3A            ; Find P%
        sta    $27
        jsr    $B4B4
        jsr    L8827
L85BA:
        ldx    #$03             ; Prepare to fetch three characters
        jsr    L8A97            ; Skip spaces
        ldy    #$00
        sty    $3D
        cmp    #':'             ; End of statement
        beq    L862B
        cmp    #$0D             ; End of line
        beq    L862B
        cmp    #'\'            ; Comment
        beq    L862B
        cmp    #'.'             ; Label
        beq    L85A5
        dec    $0A
L85D5:
        ldy    $0A              ; Get current character, inc. index
        inc    $0A
        lda    ($0B),y          ; Token, check for tokenied AND, EOR, OR
        bmi    L8607
        cmp    #$20             ; Space, step past
        beq    L85F1
        ldy    #$05
        asl    a                ; Compact first character
        asl    a
        asl    a
L85E6:
        asl    a
        rol    $3D
        rol    $3E
        dey
        bne    L85E6
        dex                     ; Loop to fetch three characters
        bne    L85D5

; The current opcode has now been compressed into two bytes
; ---------------------------------------------------------
L85F1:
        ldx    #$3A             ; Point to end of opcode lookup table
        lda    $3D              ; Get low byte of compacted mnemonic
L85F5:
        cmp    L8451-1,x        ; Low half doesn't match
        bne    L8601
        ldy    L848B-1,x        ; Check high half
        cpy    $3E              ; Mnemonic matches
        beq    L8620
L8601:
        dex                     ; Loop through opcode lookup table
        bne    L85F5
L8604:
        jmp    L982A            ; Mnemonic not matched, Mistake
L8607:
        ldx    #$22             ; opcode number for 'AND'
        cmp    #tknAND          ; Tokenised 'AND'
        beq    L8620
        inx                     ; opcode number for 'EOR'
        cmp    #tknEOR          ; Tokenized 'EOR'
        beq    L8620
        inx                     ; opcode number for 'ORA'
        cmp    #tknOR           ; Not tokenized 'OR'
        bne    L8604
        inc    $0A              ; Get next character
        iny
        lda    ($0B),y
        cmp    #'A'             ; Ensure 'OR' followed by 'A'
        bne    L8604

; Opcode found
; ------------
L8620:
        lda    L84C5-1,x        ; Get base opcode
        sta    $29
        ldy    #$01             ; Y=1 for one byte
        cpx    #$1A             ; Opcode $1A+ have arguments
        bcs    L8673
L862B:
        lda    $0440            ; Get P% low byte
        sta    $37
        sty    $39
        ldx    $28              ; Offset assembly (opt>3)
        cpx    #$04
        ldx    $0441            ; Get P% high byte
        stx    $38
        bcc    L8643            ; No offset assembly
        lda    $043C
        ldx    $043D            ; Get O%
L8643:
        sta    $3A              ; Store destination pointer
        stx    $3B
        tya
        beq    L8672
        bpl    L8650
        ldy    $36
        beq    L8672
L8650:
        dey                     ; Get opcode byte
        lda    $0029,y
        bit    $39              ; Opcode - jump to store it
        bpl    L865B
        lda    $0600,y          ; Get EQU byte
L865B:
        sta    ($3A),y          ; Store byte
        inc    $0440            ; Increment P%
        bne    L8665
        inc    $0441
L8665:
        bcc    L866F
        inc    $043C            ; Increment O%
        bne    L866F
        inc    $043D
L866F:
        tya
        bne    L8650
L8672:
        rts
L8673:
        cpx    #$22
        bcs    L86B7
        jsr    L8821
        clc
        lda    $2A
        sbc    $0440
        tay
        lda    $2B
        sbc    $0441
        cpy    #$01
        dey
        sbc    #$00
        beq    L86B2
        cmp    #$FF
        beq    L86AD
L8691:
        lda    $28              ; Get OPT
        lsr    a
        beq    L86A5            ; If OPT.b0=0, ignore error
        brk
        .byte  $01,"Out of range"
        brk
L86A5:
        tay
L86A6:
        sty    $2A
L86A8:
        ldy    #$02
        jmp    L862B
L86AD:
        tya
        bmi    L86A6
        bpl    L8691
L86B2:
        tya
        bpl    L86A6
        bmi    L8691
L86B7:
        cpx    #$29
        bcs    L86D3
        jsr    L8A97            ; Skip spaces
        cmp    #'#'
        bne    L86DA
        jsr    L882F
L86C5:
        jsr    L8821
L86C8:
        lda    $2B
        beq    L86A8
L86CC:
        brk
        .byte  $02,"Byte"
         brk

; Parse (zp),Y addressing mode
; ----------------------------
L86D3:
        cpx    #$36
        bne    L873F
        jsr    L8A97            ; Skip spaces
L86DA:
        cmp    #'('
        bne    L8715
        jsr    L8821
        jsr    L8A97            ; Skip spaces
        cmp    #')'
        bne    L86FB
        jsr    L8A97            ; Skip spaces
        cmp    #','             ; No comman, jump to Index error
        bne    L870D
        jsr    L882C
        jsr    L8A97            ; Skip spaces
        cmp    #'Y'             ; (z),Y missing Y, jump to Index error
        bne    L870D
        beq    L86C8

; Parse (zp,X) addressing mode
; ----------------------------
L86FB:
        cmp    #','             ; No comma, jump to Index error
        bne    L870D
        jsr    L8A97            ; Skip spaces
        cmp    #'X'             ; zp,X missing X, jump to Index error
        bne    L870D
        jsr    L8A97
        cmp    #')'             ; zp,X) - jump to process
        beq    L86C8
L870D:
        brk
        .byte  $03,"Index"
        brk
L8715:
        dec    $0A
        jsr    L8821
        jsr    L8A97            ; Skip spaces
        cmp    #','             ; No command - jump to process as abs,X
        bne    L8735
        jsr    L882C
        jsr    L8A97            ; Skip spaces
        cmp    #'X'             ; abs,X - jump to process
        beq    L8735
        cmp    #'Y'             ; Not abs,Y - jump to Index error
        bne    L870D
L872F:
        jsr    L882F
        jmp    L879A

; abs and abs,X
; -------------
L8735:
        jsr    L8832
L8738:
        lda    $2B
        bne    L872F
        jmp    L86A8
L873F:
        cpx    #$2F
        bcs    L876E
        cpx    #$2D
        bcs    L8750
        jsr    L8A97            ; Skip spaces
        cmp    #'A'             ; ins A -
        beq    L8767
        dec    $0A
L8750:
        jsr    L8821
        jsr    L8A97            ; Skip spaces
        cmp    #','
        bne    L8738            ; No comma, jump to ...
        jsr    L882C
        jsr    L8A97            ; Skip spaces
        cmp    #'X'
        beq    L8738            ; Jump with address,X
        jmp    L870D            ; Otherwise, jump to Index error
L8767:
        jsr    L8832
        ldy    #$01
        bne    L879C
L876E:
        cpx    #$32
        bcs    L8788
        cpx    #$31
        beq    L8782
        jsr    L8A97            ; Skip spaces
        cmp    #'#'
        bne    L8780            ; Not #, jump with address
        jmp    L86C5
L8780:
        dec    $0A
L8782:
        jsr    L8821
        jmp    L8735
L8788:
        cpx    #$33
        beq    L8797
        bcs    L87B2
        jsr    L8A97            ; Skip spaces
        cmp    #'('
        beq    L879F            ; Jump With (... addressing mode
        dec    $0A
L8797:
        jsr    L8821
L879A:
        ldy    #$03
L879C:
        jmp    L862B
L879F:
        jsr    L882C
        jsr    L882C
        jsr    L8821
        jsr    L8A97            ; Skip spaces
        cmp    #')'
        beq    L879A
        jmp    L870D            ; No ) - jump to Index error
L87B2:
        cpx    #$39
        bcs    L8813
        lda    $3D
        eor    #$01
        and    #$1F
        pha
        cpx    #$37
        bcs    L87F0
        jsr    L8A97            ; Skip spaces
        cmp    #'#'
        bne    L87CC
        pla
        jmp    L86C5
L87CC:
        dec    $0A
        jsr    L8821
        pla
        sta    $37
        jsr    L8A97
        cmp    #','
        beq    L87DE
        jmp    L8735
L87DE:
        jsr    L8A97
        and    #$1F
        cmp    $37
        bne    L87ED
        jsr    L882C
        jmp    L8735
L87ED:
        jmp    L870D            ; Jump to Index error
L87F0:
        jsr    L8821
        pla
        sta    $37
        jsr    L8A97
        cmp    #','
        bne    L8810
        jsr    L8A97
        and    #$1F
        cmp    $37
        bne    L87ED
        jsr    L882C
        lda    $2B
        beq    L8810            ; High byte=0, continue
        jmp    L86CC            ; value>255, jump to Byte error
L8810:
        jmp    L8738
L8813:
        bne    L883A
        jsr    L8821
        lda    $2A
        sta    $28
        ldy    #$00
        jmp    L862B
L8821:
        jsr    L9B1D
        jsr    L92F0
L8827:
        ldy    $1B
        sty    $0A
        rts
L882C:
        jsr    L882F
L882F:
        jsr    L8832
L8832:
        lda    $29
        clc
        adc    #$04
        sta    $29
        rts
L883A:
        ldx    #$01             ; Prepare for one byte
        ldy    $0A
        inc    $0A              ; Increment address
        lda    ($0B),y          ; Get next character
        cmp    #'B'
        beq    L8858            ; EQUB
        inx                     ; Prepare for two bytes
        cmp    #'W'
        beq    L8858            ; EQUW
        ldx    #$04             ; Prepare for four bytes
        cmp    #'D'
        beq    L8858            ; EQUD
        cmp    #'S'
        beq    L886A            ; EQUS
        jmp    L982A            ; Syntax error
L8858:
        txa
        pha
        jsr    L8821
        ldx    #$29
        jsr    $BE44
        pla
        tay
L8864:
        jmp    L862B
L8867:
        jmp    L8C0E
L886A:
        lda    $28
        pha
        jsr    L9B1D
        bne    L8867
        pla
        sta    $28
        jsr    L8827
        ldy    #$FF
        bne    L8864
L887C:
        pha
        clc
        tya
        adc    $37
        sta    $39
        ldy    #$00
        tya
        adc    $38
        sta    $3A
        pla
        sta    ($37),y
L888D:
        iny
        lda    ($39),y
        sta    ($37),y
        cmp    #$0D
        bne    L888D
        rts
L8897:
        and    #$0F
        sta    $3D
        sty    $3E
L889D:
        iny
        lda    ($37),y
        cmp    #'9'+1
        bcs    L88DA
        cmp    #'0'
        bcc    L88DA
        and    #$0F
        pha
        ldx    $3E
        lda    $3D
        asl    a
        rol    $3E
        bmi    L88D5
        asl    a
        rol    $3E
        bmi    L88D5
        adc    $3D
        sta    $3D
        txa
        adc    $3E
        asl    $3D
        rol    a
        bmi    L88D5
        bcs    L88D5
        sta    $3E
        pla
        adc    $3D
        sta    $3D
        bcc    L889D
        inc    $3E
        bpl    L889D
        pha
L88D5:
        pla
        ldy    #$00
        sec
        rts
L88DA:
        dey
        lda    #$8D
        jsr    L887C
        lda    $37
        adc    #$02
        sta    $39
        lda    $38
        adc    #$00
        sta    $3A
L88EC:
        lda    ($37),y
        sta    ($39),y
        dey
        bne    L88EC
        ldy    #$03
L88F5:
        lda    $3E
        ora    #$40
        sta    ($37),y
        dey
        lda    $3D
        and    #$3F
        ora    #$40
        sta    ($37),y
        dey
        lda    $3D
        and    #$C0
        sta    $3D
        lda    $3E
        and    #$C0
        lsr    a
        lsr    a
        ora    $3D
        lsr    a
        lsr    a
        eor    #$54
        sta    ($37),y
        jsr    L8944            ; Increment $37/8
        jsr    L8944            ; Increment $37/8
        jsr    L8944            ; Increment $37/8
        ldy    #$00
L8924:
        clc
        rts
L8926:
        cmp    #$7B
        bcs    L8924
        cmp    #$5F
        bcs    L893C
        cmp    #$5B
        bcs    L8924
        cmp    #$41
        bcs    L893C
L8936:
        cmp    #$3A
        bcs    L8924
        cmp    #$30
L893C:
        rts
L893D:
        cmp    #$2E
        bne    L8936
        rts
L8942:
        lda    ($37),y
L8944:
        inc    $37
        bne    L894A
        inc    $38
L894A:
        rts
L894B:
        jsr    L8944            ; Increment $37/8
        lda    ($37),y
        rts

; Tokenise line at &37/8
; ======================
L8951:
        ldy    #$00
        sty    $3B              ; Set tokenizer to left-hand-side
L8955:
        sty    $3C
L8957:
        lda    ($37),y          ; Get current character
        cmp    #$0D
        beq    L894A            ; Exit with <cr>
        cmp    #$20
        bne    L8966            ; Skip <spc>
L8961:
        jsr    L8944
        bne    L8957            ; Increment $37/8 and check next character
L8966:
        cmp    #'&'
        bne    L897C            ; Jump if not '&'
L896A:
        jsr    L894B            ; Increment $37/8 and get next character
        jsr    L8936
        bcs    L896A            ; Jump if numeric character
        cmp    #'A'
        bcc    L8957            ; Loop back if <'A'
        cmp    #'F'+1
        bcc    L896A            ; Step to next if 'A'..'F'
        bcs    L8957            ; Loop back for next character
L897C:
        cmp    #$22
        bne    L898C
L8980:
        jsr    L894B            ; Increment $37/8 and get next character
        cmp    #$22
        beq    L8961            ; Not quote, jump to process next character
        cmp    #$0D
        bne    L8980
        rts
L898C:
        cmp    #':'
        bne    L8996
        sty    $3B
        sty    $3C
        beq    L8961
L8996:
        cmp    #','
        beq    L8961
        cmp    #'*'
        bne    L89A3
        lda    $3B
        bne    L89E3
        rts
L89A3:
        cmp    #'.'
        beq    L89B5
        jsr    L8936
        bcc    L89DF
        ldx    $3C
        beq    L89B5
        jsr    L8897
        bcc    L89E9
L89B5:
        lda    ($37),y
        jsr    L893D
        bcc    L89C2
        jsr    L8944
        jmp    L89B5
L89C2:
        ldx    #$FF
        stx    $3B
        sty    $3C
        jmp    L8957
L89CB:
        jsr    L8926
        bcc    L89E3
L89D0:
        ldy    #$00
L89D2:
        lda    ($37),y
        jsr    L8926
        bcc    L89C2
        jsr    L8944
        jmp    L89D2
L89DF:
        cmp    #'A'
        bcs    L89EC            ; Jump if letter
L89E3:
        ldx    #$FF
        stx    $3B
        sty    $3C
L89E9:
        jmp    L8961
L89EC:
        cmp    #'X'
        bcs    L89CB            ; Jump if >='X', nothing starts with X,Y,Z
        ldx    #L8071 & 255     ; Point to token table
        stx    $39
        ldx    #L8071 / 256
        stx    $3A
L89F8:
        cmp    ($39),y
        bcc    L89D2
        bne    L8A0D
L89FE:
        iny
        lda    ($39),y
        bmi    L8A37
        cmp    ($37),y
        beq    L89FE
        lda    ($37),y
        cmp    #'.'
        beq    L8A18
L8A0D:
        iny
        lda    ($39),y
        bpl    L8A0D
        cmp    #$FE
        bne    L8A25
        bcs    L89D0
L8A18:
        iny
L8A19:
        lda    ($39),y
        bmi    L8A37
        inc    $39
        bne    L8A19
        inc    $3A
        bne    L8A19
L8A25:
        sec
        iny
        tya
        adc    $39
        sta    $39
        bcc    L8A30
        inc    $3A
L8A30:
        ldy    #$00
        lda    ($37),y
        jmp    L89F8
L8A37:
        tax
        iny
        lda    ($39),y
        sta    $3D              ; Get token flag
        dey
        lsr    a
        bcc    L8A48
        lda    ($37),y
        jsr    L8926
        bcs    L89D0
L8A48:
        txa
        bit    $3D
        bvc    L8A54
        ldx    $3B
        bne    L8A54
        clc                     ; Superfluous as all paths to here have CLC
        adc    #$40
L8A54:
        dey
        jsr    L887C
        ldy    #$00
        ldx    #$FF
        lda    $3D
        lsr    a
        lsr    a
        bcc    L8A66
        stx    $3B
        sty    $3C
L8A66:
        lsr    a
        bcc    L8A6D
        sty    $3B
        sty    $3C
L8A6D:
        lsr    a
        bcc    L8A81
        pha
        iny
L8A72:
        lda    ($37),y
        jsr    L8926
        bcc    L8A7F
        jsr    L8944
        jmp    L8A72
L8A7F:
        dey
        pla
L8A81:
        lsr    a
        bcc    L8A86
        stx    $3C
L8A86:
        lsr    a
        bcs    L8A96
        jmp    L8961

; Skip Spaces
; ===========
L8A8C:
        ldy    $1B              ; Get offset, increment it
        inc    $1B
        lda    ($19),y          ; Get current character
        cmp    #' '
        beq    L8A8C            ; Loop until not space
L8A96:
        rts
        
; Skip spaces at PtrA
; -------------------
L8A97:
        ldy    $0A
        inc    $0A
        lda    ($0B),y
        cmp    #$20
        beq    L8A97
L8AA1:
         rts
L8AA2:
        brk
        .byte  $05
        .byte "Missing ,"
        brk
L8AAE:
        jsr    L8A8C
        cmp    #','
        bne    L8AA2
        rts

; OLD - Attempt to restore program
; ================================
L8AB6:
        jsr    L9857            ; Chek end of statement
        lda    $18
        sta    $38              ; Point $37/8 to PAGE
        lda    #$00
        sta    $37
        sta    ($37),y          ; Remove end marker
        jsr    $BE6F            ; Check program and set TOP
        bne    L8AF3            ; Jump to clear heap and go to immediate mode

; END - Return to immediate mode
; ==============================
L8AC8:
        jsr    L9857            ; Check end of statement
        jsr    $BE6F            ; Check program and set TOP
        bne    L8AF6            ; Jump to immediate mode, keeping variables, etc

; STOP - Abort program with an error
; ==================================
L8AD0:
        jsr    L9857            ; Check end of statement
        brk
        .byte  $00
        .byte  "STOP"
        brk

; NEW - Clear program, enter immediate mode
; =========================================
L8ADA:
        jsr    L9857            ; Check end if statement

; Start up with NEW program
; -------------------------
L8ADD:
        lda    #$0D             ; TOP hi=PAGE hi
        ldy    $18
        sty    $13
        ldy    #$00             ; TOP=PAGE, TRACE OFF
        sty    $12
        sty    $20
        sta    ($12),y          ; ?(PAGE+0)=<cr>
        lda    #$FF             ; ?(PAGE+1)=$FF
        iny
        sta    ($12),y
        iny                     ; TOP=PAGE+2
        sty    $12
L8AF3:
        jsr    $BD20            ; Clear variables, heap, stack

; IMMEDIATE LOOP
; ==============
L8AF6:
        ldy    #$07             ; PtrA=&0700 - input buffer
        sty    $0C
        ldy    #$00
        sty    $0B
        lda    #$B433 & 255     ; ON ERROR OFF
        sta    $16
        lda    #$B433 / 256
        sta    $17
        lda    #'>'             ; Print '>' prompt, read input to bufer at PtrA
        jsr    $BC02

; Execute line at program pointer in &0B/C
; ----------------------------------------
L8B0B:
        lda    #$B433 & 255     ; ON ERROR OFF again
        sta    $16
        lda    #$B433 / 256
        sta    $17
        ldx    #$FF             ; OPT=$FF - not withing assembler
        stx    $28
        stx    $3C              ; Clear machine stack
        txs
        jsr    $BD3A            ; Clear DATA and stacks
        tay
        lda    $0B              ; Point $37/8 to program line
        sta    $37
        lda    $0C
        sta    $38
        sty    $3B
        sty    $0A
        jsr    L8957
        jsr    L97DF            ; Tokenise, jump forward if no line number
        bcc    L8B38
        jsr    $BC8D            ; Insert into program, jump back to immediate loop
        jmp    L8AF3

; Command entered at immediate prompt
; -----------------------------------
L8B38:
        jsr    L8A97            ; Skip spaces at PtrA
        cmp    #$C6             ; If command token, jump to execute command
        bcs    L8BB1
        bcc    L8BBF            ; Not command token, try variable assignment
L8B41:
        jmp    L8AF6            ; Jump back to immediate mode

; [ - enter assembler
; ===================
L8B44:
        jmp    L8504            ; Jump to assembler

; =<value> - return from FN
; =========================
; Stack needs to contain these items,
;  ret_lo, ret_hi, PtrB_hi, PtrB_lo, PtrB_off, numparams, PtrA_hi, PtrA_lo, PtrA_off, tknFN
L8B47:
        tsx                     ; If stack is empty, jump to give error
        cpx    #$FC
        bcs    L8B59
        lda    $01FF            ; If pushed token<>'FN', give error
        cmp    #tknFN
        bne    L8B59
        jsr    L9B1D            ; Evaluate expression
        jmp    L984C            ; Check for end of statement and return to pop from function
L8B59:
        brk
        .byte  $07,"No ",tknFN
        brk
        
; Check for =, *, [ commands
; ==========================
L8B60:
        ldy    $0A              ; Step program pointer back and fetch char
        dey
        lda    ($0B),y
        cmp    #'='             ; Jump for '=', return from FN
        beq    L8B47
        cmp    #'*'             ; Jump for '*', embedded *command
        beq    L8B73
        cmp    #'['             ; Jump for '[', start assembler
        beq    L8B44
        bne    L8B96            ; Otherwise, see if end of statement

; Embedded *command
; =================
L8B73:
        jsr    L986D            ; Update PtrA to current address
        ldx    $0B
        ldy    $0C
        jsr    OS_CLI           ; Pass command at ptrA to OSCLI


; DATA, DEF, REM, ELSE
; ====================
; Skip to end of line
; -------------------
L8B7D:
        lda    #$0D             ; Get program pointer
        ldy    $0A
        dey
L8B82:
        iny                     ; Loop until <cr> found
        cmp    ($0B),y
        bne    L8B82
L8B87:
        cmp    #tknELSE         ; If 'ELSE', jump to skip to end of line
        beq    L8B7D
        lda    $0C              ; Program in command buffer, jump back to immediate loop
        cmp    #$0700 /256
        beq    L8B41
        jsr    L9890            ; Check for end of program, step past <cr>
        bne    L8BA3
L8B96:
        dec    $0A
L8B98:
        jsr    L9857

; Main execution loop
; -------------------
L8B9B:
        ldy    #$00             ; Get current character
        lda    ($0B),y
        cmp    #':'             ; Not <colon>, check for ELSE
        bne    L8B87
L8BA3:
        ldy    $0A              ; Get program pointer, increment for next time
        inc    $0A
        lda    ($0B),y          ; Get current character
        cmp    #$20
        beq    L8BA3
        cmp    #$CF             ; Not program command, jump to try variable assignment
        bcc    L8BBF

; Dispatch function/command
; -------------------------
L8BB1:
        tax                     ; Index into dispatch table
        lda    L836D-$8E,x      ; Get routine address from table
        sta    $37
        lda    L83DF-$8E,x
        sta    $38
        jmp    ($0037)          ; Jump to routine

; Not a command byte, try variable assignment, or =, *, [
; -------------------------------------------------------
L8BBF:
        ldx    $0B              ; Copy PtrA to PtrB
        stx    $19
        ldx    $0C
        stx    $1A
        sty    $1B              ; Check if variable or indirection
        jsr    L95DD
        bne    L8BE9            ; NE - jump for existing variable or indirection assignment
        bcs    L8B60            ; CS - not variable assignment, try =, *, [ commands

; Variable not found, create a new one
; ------------------------------------
        stx    $1B              ; Check for and step past '='
        jsr    L9841
        jsr    L94FC            ; Create new variable
        ldx    #$05             ; X=&05 = float
        cpx    $2C              ; Jump if dest. not a float
        bne    L8BDF
        inx                     ; X=&06
L8BDF:
        jsr    L9531
        dec    $0A

; LET variable = expression
; =========================
L8BE4:
        jsr    L9582
        beq    L8C0B
L8BE9:
        bcc    L8BFB
        jsr    $BD94            ; Stack integer (address of data)
        jsr    L9813            ; Check for end of statement
        lda    $27              ; Get evaluation type
        bne    L8C0E            ; If not string, error
        jsr    L8C1E            ; Assign the string
        jmp    L8B9B            ; Return to execution loop
L8BFB:
        jsr    $BD94            ; Stack integer (address of data)
        jsr    L9813            ; Check for end of statement
        lda    $27              ; Get evaluation type
        beq    L8C0E            ; If not number, error
        jsr    $B4B4            ; Assign the number
        jmp    L8B9B            ; Return to execution loop
L8C0B:
        jmp    L982A
L8C0E:
        brk
        .byte   $06, "Type mismatch"
        brk
L8C1E:
        jsr    $BDEA            ; Unstack integer (address of data)
L8C21:
        lda    $2C
        cmp    #$80             ; Jump if absolute string $addr
        beq    L8CA2
        ldy    #$02
        lda    ($2A),y
        cmp    $36
        bcs    L8C84
        lda    $02
        sta    $2C
        lda    $03
        sta    $2D
        lda    $36
        cmp    #$08
        bcc    L8C43
        adc    #$07
        bcc    L8C43
        lda    #$FF
L8C43:
        clc
        pha
        tax
        lda    ($2A),y
        ldy    #$00
        adc    ($2A),y
        eor    $02
        bne    L8C5F
        iny
        adc    ($2A),y
        eor    $03
        bne    L8C5F
        sta    $2D
        txa
        iny
        sec
        sbc    ($2A),y
        tax
L8C5F:
        txa
        clc
        adc    $02
        tay
        lda    $03
        adc    #$00
        cpy    $04
        tax
        sbc    $05
        bcs    L8CB7
        sty    $02
        stx    $03
        pla
        ldy    #$02
        sta    ($2A),y
        dey
        lda    $2D
        beq    L8C84
        sta    ($2A),y
        dey
        lda    $2C
        sta    ($2A),y
L8C84:
        ldy    #$03
        lda    $36
        sta    ($2A),y
        beq    L8CA1
        dey
        dey
        lda    ($2A),y
        sta    $2D
        dey
        lda    ($2A),y
        sta    $2C
L8C97:
        lda    $0600,y
        sta    ($2C),y
        iny
        cpy    $36
        bne    L8C97
L8CA1:
        rts
L8CA2:
        jsr    $BEBA
        cpy    #$00
        beq    L8CB4
L8CA9:
        lda    $0600,y
        sta    ($2A),y
        dey
        bne    L8CA9
        lda    $0600
L8CB4:
        sta    ($2A),y
        rts
L8CB7:
        brk
        .byte   $00, "No room"
        brk
L8CC1:
        lda     $39
        cmp     #$80
        beq     L8CEE
        bcc     L8D03
        ldy     #$00
         lda    ($04),y
         tax
         beq    L8CE5
         lda    ($37),y
         sbc    #$01
         sta    $39
         iny
         lda    ($37),y
         sbc    #$00
         sta    $3A
L8CDD:
        lda    ($04),y
        sta    ($39),y
        iny
        dex
        bne    L8CDD
L8CE5:
        lda    ($04,x)
        ldy    #$03
L8CE9:
        sta    ($37),y
        jmp    $BDDC
L8CEE:
        ldy    #$00
        lda    ($04),y
        tax
        beq    L8CFF
L8CF5:
        iny
        lda    ($04),y
        dey
        sta    ($37),y
        iny
        dex
        bne    L8CF5
L8CFF:
        lda    #$0D
        bne    L8CE9
L8D03:
        ldy    #$00
        lda    ($04),y
        sta    ($37),y
        iny
        cpy    $39
        bcs    L8D26
        lda    ($04),y
        sta    ($37),y
        iny
        lda    ($04),y
        sta    ($37),y
        iny
        lda    ($04),y
        sta    ($37),y
        iny
        cpy    $39
        bcs    L8D26
        lda    ($04),y
        sta    ($37),y
        iny
L8D26:
        tya
        clc
        jmp    $BDE1
L8D2B:
        dec    $0A
        jsr    $BFA9
L8D30:
        tya
        pha
        jsr    L8A8C
        cmp    #$2C
        bne    L8D77
        jsr    L9B29
        jsr    $A385
        pla
        tay
        lda    $27
        jsr    OSBPUT
        tax
        beq    L8D64
        bmi    L8D57
        ldx    #$03
L8D4D:
        lda    $2A,x
        jsr    OSBPUT
        dex
        bpl    L8D4D
        bmi    L8D30
L8D57:
        ldx    #$04
L8D59:
        lda    $046C,x
        jsr    OSBPUT
        dex
        bpl    L8D59
        bmi    L8D30
L8D64:
        lda    $36
        jsr    OSBPUT
        tax
        beq    L8D30
L8D6C:
        lda    $05FF,x
        jsr    OSBPUT
        dex
        bne    L8D6C
        beq    L8D30
L8D77:
        pla
        sty    $0A
        jmp    L8B98

; End of PRINT statement
; ----------------------
L8D7D:
        jsr    $BC25            ; Output new line and set COUNT to zero
L8D80:
        jmp    L8B96            ; Check end of statement, return to execution loop
L8D83:
        lda    #$00             ; Set current field to zero, hex/dec flag to decimal
        sta    $14
        sta    $15
        jsr    L8A97            ; Get next non-space character
        cmp    #':'             ; <colon> found, finish printing
        beq    L8D80
        cmp    #$0D             ; <cr> found, finish printing
        beq    L8D80
        cmp    #tknELSE         ; 'ELSE' found, finish printing
        beq    L8D80
        bne    L8DD2            ; Otherwise, continue into main loop

; PRINT [~][print items]['][,][;]
; ===============================
L8D9A:
        jsr    L8A97            ; Get next non-space char
        cmp    #'#'             ; If '#' jump to do PRINT#
        beq    L8D2B
        dec    $0A              ; Jump into PRINT loop
        jmp    L8DBB

; Print a comma
; -------------
L8DA6:
        lda    $0400            ; If field width zero, no padding needed, jump back into main loop
        beq    L8DBB
        lda    $1E              ; Get COUNT
L8DAD:
        beq    L8DBB            ; Zero, just started a new line, no padding, jump back into main loop
        sbc    $0400            ; Get COUNT-field width
        bcs    L8DAD            ; Loop to reduce until (COUNT MOD fieldwidth)<0
        tay                     ; Y=number of spaces to get back to (COUNT MOD width)=zero
L8DB5:
        jsr    $B565            ; Loop to print required spaces
        iny
        bne    L8DB5
L8DBB:
        clc                     ; Prepare to print decimal
        lda    $0400            ; Set current field width from @%
        sta    $14
L8DC1:
        ror    $15              ; Set hex/dec flag from Carry
L8DC3:
        jsr    L8A97            ; Get next non-space character
        cmp    #':'             ; End of statement if <colon> found
        beq    L8D7D
        cmp    #$0D             ; End if statement if <cr> found
        beq    L8D7D
        cmp    #tknELSE         ; End of statement if 'ELSE' found
        beq    L8D7D
L8DD2:
        cmp    #'~'             ; Jump back to set hex/dec flag from Carry
        beq    L8DC1
        cmp    #','             ; Jump to pad to next print field
        beq    L8DA6
        cmp    #';'             ; Jump to check for end of print statement
        beq    L8D83
        jsr    L8E70            ; Check for ' TAB SPC, if print token found return to outer main loop
        bcc    L8DC3

; All print formatting have been checked, so it now must be an expression
; -----------------------------------------------------------------------
        lda    $14              ; Save field width and flags, as evaluator
        pha                     ;  may call PRINT (eg FN, STR$, etc.)
        lda    $15
        pha
        dec    $1B              ; Evaluate expression
        jsr    L9B29
        pla                     ; Restore field width and flags
        sta    $15
        pla
        sta    $14
        lda    $1B              ; Update program pointer
        sta    $0A
        tya                     ; If type=0, jump to print string
        beq    L8E0E
        jsr    L9EDF            ; Convert numeric value to string
        lda    $14              ; Get current field width
        sec                     ; A=width-stringlength
        sbc    $36
        bcc    L8E0E            ; length>width - print it
        beq    L8E0E            ; length=width - print it
        tay
L8E08:
        jsr    $B565            ; Loop to print required spaces to pad the number
        dey
        bne    L8E08

; Print string in string buffer
; -----------------------------
L8E0E:
        lda    $36              ; Null string, jump back to main loop
        beq    L8DC3
        ldy    #$00             ; Point to start of string
L8E14:
        lda    $0600,y          ; Print character from string buffer
        jsr    $B558
        iny                     ; Increment pointer, loop for full string
        cpy    $36
        bne    L8E14
        beq    L8DC3            ; Jump back for next print item
L8E21:
        jmp    L8AA2
L8E24:
        cmp    #','             ; No comma, jump to TAB(x)
        bne    L8E21
        lda    $2A              ; Save X
        pha
        jsr    $AE56
        jsr    L92F0

; BBC - send VDU 31,x,y sequence
; ------------------------------
        lda    #$1F             ; TAB()
        jsr    OSWRCH
        pla                     ; X coord
        jsr    OSWRCH
        jsr    L9456            ; Y coord
        jmp    L8E6A            ; Continue to next PRINT item
L8E40:
        jsr    L92DD
        jsr    L8A8C
        cmp    #')'
        bne    L8E24
        lda    $2A
        sbc    $1E
        beq    L8E6A
        tay
        bcs    L8E5F
        jsr    $BC25
        beq    L8E5B
L8E58:
        jsr    L92E3
L8E5B:
        ldy    $2A
        beq    L8E6A
L8E5F:
        jsr    $B565
        dey
        bne    L8E5F
        beq    L8E6A
L8E67:
        jsr    $BC25
L8E6A:
        clc
        ldy    $1B
        sty    $0A
        rts
L8E70:
        ldx    $0B
        stx    $19
        ldx    $0C
        stx    $1A
        ldx    $0A
        stx    $1B
        cmp    #$27
        beq    L8E67
        cmp    #$8A
        beq    L8E40
        cmp    #$89
        beq    L8E58
        sec
L8E89:
        rts
L8E8A:
        jsr    L8A97            ; Skip spaces
        jsr    L8E70
        bcc    L8E89
        cmp    #$22
        beq    L8EA7
        sec
        rts
L8E98:
        brk
        .byte $09, "Missing ", '"'
        brk
L8EA4:
        jsr    $B558
L8EA7:
        iny
        lda    ($19),y
        cmp    #$0D
        beq    L8E98
        cmp    #$22
        bne    L8EA4
        iny
        sty    $1B
        lda    ($19),y
        cmp    #$22
        bne    L8E6A
        beq    L8EA4

; CLG
; ===
L8EBD:
         jsr    L9857           ; Check end of statement
         lda    #$10            ; Jump to do VDU 16
         bne    L8ECC

; CLS
; ===
L8EC4:
        jsr    L9857            ; Check end of statement
        jsr    $BC28            ; Set COUNT to zero
        lda    #$0C             ; Do VDU 12
L8ECC:
        jsr    OSWRCH           ; Send A to OSWRCH, jump to execution loop
        jmp    L8B9B

; CALL numeric [,items ... ]
; ==========================
L8ED2:
        jsr    L9B1D
        jsr    L92EE
        jsr    $BD94
        ldy    #$00
        sty    $0600
L8EE0:
        sty    $06FF
        jsr    L8A8C
        cmp    #$2C
        bne    L8F0C
        ldy    $1B
        jsr    L95D5
        beq    L8F1B
        ldy    $06FF
        iny
        lda    $2A
        sta    $0600,y
        iny
        lda    $2B
        sta    $0600,y
        iny
        lda    $2C
        sta    $0600,y
        inc    $0600
        jmp    L8EE0
L8F0C:
        dec    $1B
        jsr    L9852
        jsr    $BDEA
        jsr    L8F1E
        cld
        jmp    L8B9B
L8F1B:
        jmp    $AE43

;Call code
;---------
L8F1E:
        lda    $040C            ; Get Carry from C%, A from A%
        lsr    a
        lda    $0404
        ldx    $0460            ; Get X from X%, Y from Y%
        ldy    $0464
        jmp    ($002A)          ; Jump to address in IntA
L8F2E:
        jmp    L982A

; DELETE linenum, linenum
; =======================
L8F31:
        jsr    L97DF
        bcc    L8F2E
        jsr    $BD94
        jsr    L8A97
        cmp    #$2C
        bne    L8F2E
        jsr    L97DF
        bcc    L8F2E
        jsr    L9857
        lda    $2A
        sta    $39
        lda    $2B
        sta    $3A
        jsr    $BDEA
L8F53:
        jsr    $BC2D
        jsr    L987B
        jsr    L9222
        lda    $39
        cmp    $2A
        lda    $3A
        sbc    $2B
        bcs    L8F53
        jmp    L8AF3
L8F69:
        lda    #$0A
        jsr    $AED8
        jsr    L97DF
        jsr    $BD94
        lda    #$0A
        jsr    $AED8
        jsr    L8A97
        cmp    #$2C
        bne    L8F8D
        jsr    L97DF
        lda    $2B
        bne    L8FDF
        lda    $2A
        beq    L8FDF
         inc    $0A
L8F8D:
         dec    $0A
         jmp    L9857
L8F92:
        lda    $12
        sta    $3B
        lda    $13
        sta    $3C
L8F9A:
        lda    $18
        sta    $38
        lda    #$01
        sta    $37
        rts

; RENUMBER [linenume [,linenum]]
; ==============================
L8FA3:
        jsr    L8F69
        ldx    #$39
        jsr    $BE0D
        jsr    $BE6F
        jsr    L8F92
L8FB1:
        ldy    #$00
        lda    ($37),y          ; Line.hi>&7F, end of program
        bmi    L8FE7
        sta    ($3B),y
        iny
        lda    ($37),y
        sta    ($3B),y
        sec
        tya
        adc    $3B
        sta    $3B
        tax
        lda    $3C
        adc    #$00
        sta    $3C
        cpx    $06
        sbc    $07
        bcs    L8FD6
        jsr    L909F
        bcc    L8FB1
L8FD6:
        brk
        .byte  $00, tknRENUMBER
        .byte  " space"         ; Terminated by following BRK
L8FDF:
        brk
        .byte  $00, "Silly"
        brk
L8FE7:
        jsr    L8F9A
L8FEA:
        ldy    #$00
        lda    ($37),y
        bmi    L900D
        lda    $3A
        sta    ($37),y
        lda    $39
        iny
        sta    ($37),y
        clc
        lda    $2A
        adc    $39
        sta    $39
        lda    #$00
        adc    $3A
        and    #$7F
        sta    $3A
        jsr    L909F
        bcc    L8FEA
L900D:
        lda    $18
        sta    $0C
        ldy    #$00
        sty    $0B
        iny
        lda    ($0B),y
        bmi    L903A
L901A:
        ldy    #$04
L901C:
        lda    ($0B),y
        cmp    #$8D
        beq    L903D
        iny
        cmp    #$0D
        bne    L901C
        lda    ($0B),y
        bmi    L903A
        ldy    #$03
        lda    ($0B),y
        clc
        adc    $0B
        sta    $0B
        bcc    L901A
        inc    $0C
        bcs    L901A
L903A:
        jmp    L8AF3
L903D:
        jsr    L97EB
        jsr    L8F92
L9043:
        ldy    #$00
        lda    ($37),y
        bmi    L9080
        lda    ($3B),y
        iny
        cmp    $2B
        bne    L9071
        lda    ($3B),y
        cmp    $2A
        bne    L9071
        lda    ($37),y
        sta    $3D
        dey
        lda    ($37),y
        sta    $3E
        ldy    $0A
        dey
        lda    $0B
        sta    $37
        lda    $0C
        sta    $38
        jsr    L88F5
L906D:
        ldy    $0A
        bne    L901C
L9071:
        jsr    L909F
        lda    $3B
        adc    #$02
        sta    $3B
        bcc    L9043
        inc    $3C
        bcs    L9043
L9080:
L9082:
        jsr    $BFCF            ; Print inline text
        .byte  "Failed at "
        iny
        lda    ($0B),y
        sta    $2B
        iny
        lda    ($0B),y
        sta    $2A
        jsr    L991F            ; Print in decimal
        jsr    $BC25            ; Print newline
        beq    L906D
L909F:
        iny
        lda    ($37),y
        adc    $37
        sta    $37
        bcc    L90AB
        inc    $38
        clc
L90AB:
        rts

; AUTO [numeric [, numeric ]]
; ===========================
L90AC:
        jsr    L8F69
        lda    $2A
        pha
        jsr    $BDEA
L90B5:
        jsr    $BD94
        jsr    L9923
        lda    #$20
        jsr    $BC02
        jsr    $BDEA
        jsr    L8951
        jsr    $BC8D
        jsr    $BD20
        pla
        pha
        clc
        adc    $2A
        sta    $2A
        bcc    L90B5
        inc    $2B
        bpl    L90B5
L90D9:
        jmp    L8AF3
L90DC:
        jmp    L9218
L90DF:
        dec    $0A
        jsr    L9582
        beq    L9127
        bcs    L9127
        jsr    $BD94
        jsr    L92DD
        jsr    L9222
        lda    $2D
        ora    $2C
        bne    L9127
        clc
        lda    $2A
        adc    $02
        tay
        lda    $2B
        adc    $03
        tax
        cpy    $04
        sbc    $05
        bcs    L90DC
        lda    $02
        sta    $2A
        lda    $03
        sta    $2B
        sty    $02
        stx    $03
        lda    #$00
        sta    $2C
        sta    $2D
        lda    #$40
        sta    $27
        jsr    $B4B4
        jsr    L8827
        jmp    L920B
L9127:
        brk
        .byte  10, "Bad ", tknDIM
        brk

; DIM numvar [numeric] [(arraydef)]
; =================================
L912F:
        jsr    L8A97
        tya
        clc
        adc    $0B
        ldx    $0C
        bcc    L913C
        inx
        clc
L913C:
        sbc    #$00
        sta    $37
        txa
        sbc    #$00
        sta    $38
        ldx    #$05
        stx    $3F
        ldx    $0A
        jsr    L9559
        cpy    #$01
        beq    L9127
        cmp    #'('
        beq    L916B
        cmp    #$24
        beq    L915E
        cmp    #$25
        bne    L9168
L915E:
        dec    $3F
        iny
        inx
        lda    ($37),y
        cmp    #'('
        beq    L916B
L9168:
        jmp    L90DF
L916B:
        sty    $39
        stx    $0A
        jsr    L9469
        bne    L9127
        jsr    L94FC
        ldx    #$01
        jsr    L9531
        lda    $3F
        pha
        lda    #$01
        pha
        jsr    $AED8
L9185:
        jsr    $BD94
        jsr    L8821
        lda    $2B
        and    #$C0
        ora    $2C
        ora    $2D
        bne    L9127
        jsr    L9222
        pla
        tay
        lda    $2A
        sta    ($02),y
        iny
        lda    $2B
        sta    ($02),y
        iny
        tya
        pha
        jsr    L9231
        jsr    L8A97
        cmp    #$2C
        beq    L9185
        cmp    #')'
        beq    L91B7
        jmp    L9127
L91B7:
        pla
        sta    $15
        pla
        sta    $3F
        lda    #$00
        sta    $40
        jsr    L9236
        ldy    #$00
        lda    $15
        sta    ($02),y
        adc    $2A
        sta    $2A
        bcc    L91D2
        inc    $2B
L91D2:
        lda    $03
        sta    $38
        lda    $02
        sta    $37
        clc
        adc    $2A
        tay
        lda    $2B
        adc    $03
        bcs    L9218
        tax
        cpy    $04
        sbc    $05
        bcs    L9218
        sty    $02
        stx    $03
        lda    $37
        adc    $15
        tay
        lda    #$00
        sta    $37
        bcc    L91FC
        inc    $38
L91FC:
        sta    ($37),y
        iny
        bne    L9203
        inc    $38
L9203:
        cpy    $02
        bne    L91FC
        cpx    $38
        bne    L91FC
L920B:
        jsr    L8A97
        cmp    #$2C
        beq    L9215
        jmp    L8B96
L9215:
        jmp    L912F
L9218:
        brk
        .byte  11, tknDIM, " space"
        brk
L9222:
        inc    $2A
        bne    L9230
        inc    $2B
        bne    L9230
        inc    $2C
        bne    L9230
        inc    $2D
L9230:
        rts
L9231:
        ldx    #$3F
        jsr    $BE0D
L9236:
        ldx    #$00
        ldy    #$00
L923A:
        lsr    $40
        ror    $3F
        bcc    L924B
        clc
        tya
        adc    $2A
        tay
        txa
        adc    $2B
        tax
        bcs    L925A
L924B:
        asl    $2A
        rol    $2B
        lda    $3F
        ora    $40
        bne    L923A
        sty    $2A
        stx    $2B
        rts
L925A:
        jmp    L9127

; HIMEM=numeric
; =============
L925D:
        jsr    L92EB            ; Set past '=', evaluate integer
        lda    $2A              ; Set HIMEM and STACK
        sta    $06
        sta    $04
        lda    $2B
        sta    $07
        sta    $05
        jmp    L8B9B            ; Jump back to execution loop

; LOMEM=numeric
; =============
L926F:
        jsr    L92EB            ; Step past '=', evaluate integer
        lda    $2A              ; Set LOMEM and VAREND
        sta    $00
        sta    $02
        lda    $2B
        sta    $01
        sta    $03
        jsr    $BD2F            ; Clear dynamic variables, jump to execution loop
        beq    L928A

; PAGE=numeric
; ============
L9283:
        jsr    L92EB            ; Step past '=', evaluate integer
        lda    $2B              ; Set PAGE
        sta    $18
L928A:
        jmp    L8B9B            ; Jump to execution loop

; CLEAR
; =====
L928D:
        jsr    L9857            ; Check end of statement
        jsr    $BD20            ; Clear heap, stack, data, variables
        beq    L928A            ; Jump to execution loop

; TRACE ON | OFF | numeric
; ========================
L9295:
        jsr    L97DF            ; If line number, jump for TRACE linenum
        bcs    L92A5
        cmp    #$EE             ; Jump for TRACE ON
        beq    L92B7
        cmp    #$87             ; Jump for TRACE OFF
        beq    L92C0
        jsr    L8821            ; Evaluate integer

; TRACE numeric
; -------------
L92A5:
        jsr    L9857            ; Check end of statement
        lda    $2A              ; Set trace limit low byte
        sta    $21
        lda    $2B
L92AE:
        sta    $22              ; Set trace limit high byte, set TRACE ON
        lda    #$FF
L92B2:
        sta    $20              ; Set TRACE flag, return to execution loop
        jmp    L8B9B

; TRACE ON
; --------
L92B7:
        inc    $0A              ; Step past, check end of statement
        jsr    L9857
        lda    #$FF             ; Jump to set TRACE &FFxx
        bne    L92AE
        
; TRACE OFF
; ---------
L92C0:
        inc    $0A              ; Step past, check end of statement
        jsr    L9857
        lda    #$00             ; Jump to set TRACE OFF
        beq    L92B2

; TIME=numeric
; ============
L92C9:
        jsr    L92EB            ; Step past '=', evaluate integer
        ldx    #$2A             ; Point to integer, set 5th byte to 0
        ldy    #$00
        sty    $2E
        lda    #$02             ; Call OSWORD &02 to do TIME=
        jsr    OSWORD
        jmp    L8B9B

; Evaluate <comma><numeric>
; =========================
L92DA:
        jsr    L8AAE            ; Check for and step past comma
L92DD:
        jsr    L9B29
        jmp    L92F0
L92E3:
        jsr    $ADEC
        beq    L92F7
        bmi    L92F4
L92EA:
        rts

; Evaluate <equals><integer>
; ==========================
L92EB:
        jsr    L9807            ; Check for equals, evaluate numeric
L92EE:
        lda    $27              ; Get result type
L92F0:
        beq    L92F7            ; String, jump to 'Type mismatch'
        bpl    L92EA            ; Integer, return
L92F4:
        jmp    $A3E4            ; Real, jump to convert to integer
L92F7:
        jmp    L8C0E            ; Jump to 'Type mismatch' error

; Evaluate <real>
; ===============
L92FA:
        jsr    $ADEC            ; Evaluate expression

; Ensure value is real
; --------------------
L92FD:
        beq    L92F7            ; String, jump to 'Type mismatch'
        bmi    L92EA            ; Real, return
        jmp    $A2BE            ; Integer, jump to convert to real

; PROCname [(parameters)]
; =======================
L9304:
        lda    $0B              ; PtrB=PtrA=>after 'PROC' token
        sta    $19
        lda    $0C
        sta    $1A
        lda    $0A
        sta    $1B
        lda    #$F2             ; Call PROC/FN dispatcher
        jsr    $B197            ; Will return here after ENDPROC
        jsr    L9852            ; Check for end of statement
        jmp    L8B9B            ; Return to execution loop

; Make string zero length
; -----------------------
L931B:
        ldy    #$03             ; Set length to zero
        lda    #$00
        sta    ($2A),y          ; Jump to look for next LOCAL item
        beq    L9341

; LOCAL variable [,variable ...]
; ==============================
L9323:
        tsx                     ; Not inside subroutine, error
        cpx    #$FC
        bcs    L936B
        jsr    L9582            ; Find variable, jump if bad variable name
        beq    L9353
        jsr    $B30D            ; Push value on stack, push variable info on stack
        ldy    $2C              ; If a string, jump to make zero length
        bmi    L931B
        jsr    $BD94
        lda    #$00             ; Set IntA to zero
        jsr    $AED8
        sta    $27              ; Set current variable to IntA (zero)
        jsr    $B4B4

; Next LOCAL item
; ---------------
L9341:
        tsx                     ; Increment number of LOCAL items
        inc    $0106,x
        ldy    $1B              ; Update line pointer
        sty    $0A
        jsr    L8A97            ; Get next character
        cmp    #$2C             ; Comma, loop back to do another item
        beq    L9323
        jmp    L8B96            ; Jump to main execution loop
L9353:
        jmp    L8B98

; ENDPROC
; =======
; Stack needs to contain these items,
;  ret_lo, ret_hi, PtrB_hi, PtrB_lo, PtrB_off, numparams, PtrA_hi, PtrA_lo, PtrA_off, tknPROC
L9356:
        tsx                     ; If stack empty, jump to give error
        cpx    #$FC
        bcs    L9365
        lda    $01FF            ; If pushed token<>'PROC', give error
        cmp    #$F2
        bne    L9365
        jmp    L9857            ; Check for end of statement and return to pop from subroutine
L9365:
        brk
        .byte  13, "No ", tknPROC ; Terminated by following BRK
L936B:
        brk
        .byte  12, "Not ", tknLOCAL ; Terminated by following BRK
L9372:
        brk
        .byte  $19, "Bad ", tknMODE
        brk

; GCOL numeric, numeric
; =====================
L937A:
        jsr    L8821            ; Evaluate integer
        lda    $2A
        pha
        jsr    L92DA            ; Step past comma, evaluate integer
        jsr    L9852            ; Update program pointer, check for end of statement
        lda    #$12             ; Send VDU 18 for GCOL
        jsr    OSWRCH
        jmp    L93DA            ; Jump to send two bytes to OSWRCH

; COLOUR numeric
; ==============
L938E:
        lda    #$11             ; Stack VDU 17 for COLOUR
        pha
        jsr    L8821            ; Evaluate integer, check end of statement
        jsr    L9857
        jmp    L93DA            ; Jump to send two bytes to OSWRCH

; MODE numeric
; ============
L939A:
        lda    #$16             ; Stack VDU 22 for MODE
        pha
        jsr    L8821            ; Evaluate integer, check end of statement
        jsr    L9857

; BBC - Check if changing MODE will move screen into stack
; --------------------------------------------------------
        jsr    $BEE7            ; Get machine address high word
        cpx    #$FF             ; Not &xxFFxxxx, skip memory test
        bne    L93D7
        cpy    #$FF             ; Not &FFFFxxxx, skip memory test
        bne    L93D7

; MODE change in I/O processor, must check memory limits

        lda    $04              ; STACK<>HIMEM, stack not empty, give 'Bad MODE' error
        cmp    $06
        bne    L9372
        lda    $05
        cmp    $07
        bne    L9372
        ldx    $2A              ; Get top of memory if we used this MODE
        lda    #$85
        jsr    OSBYTE
        cpx    $02              ; Would be below VAREND, give error
        tya
        sbc    $03
        bcc    L9372
        cpx    $12              ; Would be below TOP, give error
        tya
        sbc    $13
        bcc    L9372

; BASIC stack is empty, screen would not hit heap or program

        stx    $06              ; Set STACK and HIMEM to new address
        stx    $04
        sty    $07
        sty    $05

; Change MODE
L93D7:
        jsr    $BC28            ; Set COUNT to zero

; Send two bytes to OSWRCH, stacked byte, then IntA
; -------------------------------------------------
L93DA:
        pla                     ; Send stacked byte to OSWRCH
        jsr    OSWRCH
        jsr    L9456            ; Send IntA to OSWRCH, jump to execution loop
        jmp    L8B9B

; MOVE numeric, numeric
; =====================
L93E4:
        lda    #$04             ; Jump forward to do PLOT 4 for MOVE
        bne    L93EA

; DRAW numeric, numeric
; =====================
L93E8:
        lda    #$05             ; Do PLOT 5 for DRAW
L93EA:
        pha                     ; Evaluate first expression
        jsr    L9B1D
        jmp    L93FD            ; Jump to evaluate second expression and send to OSWRCH

; PLOT numeric, numeric, numeric
; ==============================
L93F1:
        jsr    L8821            ; Evaluate integer
        lda    $2A
        pha
        jsr    L8AAE            ; Step past comma, evaluate expression
        jsr    L9B29
L93FD:
        jsr    L92EE            ; Confirm numeric and ensure is integer
        jsr    $BD94            ; Stack integer
        jsr    L92DA            ; Step past command and evaluate integer
        jsr    L9852            ; Update program pointer, check for end of statement
        lda    #$19             ; Send VDU 25 for PLOT
        jsr    OSWRCH
        pla                     ; Send PLOT action
        jsr    OSWRCH
        jsr    $BE0B            ; Pop integer to temporary store at &37/8
        lda    $37              ; Send first coordinate to OSWRCH
        jsr    OSWRCH
        lda    $38
        jsr    OSWRCH
        jsr    L9456            ; Send IntA to OSWRCH, second coordinate
        lda    $2B              ; Send IntA high byte to OSWRCH
        jsr    OSWRCH
        jmp    L8B9B            ; Jump to execution loop
L942A:
        lda    $2B              ; Send IntA byte 2 to OSWRCH
        jsr    OSWRCH

; VDU num[,][;][...]
; ==================
L942F:
        jsr    L8A97            ; Get next character
L9432:
        cmp    #$3A             ; If end of statement, jump to exit
        beq    L9453
        cmp    #$0D
        beq    L9453
        cmp    #$8B
        beq    L9453
        dec    $0A              ; Step back to current character
        jsr    L8821            ; Evaluate integer and output low byte
        jsr    L9456
        jsr    L8A97            ; Get next character
        cmp    #','             ; Comma, loop to read another number
        beq    L942F
        cmp    #';'             ; Not semicolon, loop to check for end of statement
        bne    L9432
        beq    L942A            ; Loop to output high byte and read another
L9453:
        jmp    L8B96            ; Jump to execution loop
        
; Send IntA to OSWRCH via WRCHV
; =============================
L9456:
        lda    $2A
        jmp    (WRCHV)

; VARIABLE PROCESSING
; ===================
; Look for a FN/PROC in heap
; --------------------------
; On entry, (&37)+1=>FN/PROC token (ie, first character of name)
;
L945B:
        ldy    #$01             ; Get PROC/FN character
        lda    ($37),y
        ldy    #$F6             ; Get PROC/FN character
        cmp    #tknPROC         ; If PROC, jump to scan list
        beq    L946F
        ldy    #$F8             ; Point to FN list start and scan list
        bne    L946F

; Look for a variable in the heap
; -------------------------------
; On entry, (&37)+1=>first character of name
;
L9469:
        ldy    #$01             ; Get first character of variable
        lda    ($37),y
        asl    a                ; Double it to index into index list
        tay

; Scan though linked lists in heap
; --------------------------------
L946F:
        lda    $0400,y          ; Get start of linked list
        sta    $3A
        lda    $0401,y
        sta    $3B
L9479:
        lda    $3B              ; End of list
        beq    L94B2
        ldy    #$00
        lda    ($3A),y
        sta    $3C
        iny
        lda    ($3A),y
        sta    $3D
        iny                     ; Jump if not null name
        lda    ($3A),y
        bne    L949A
        dey
        cpy    $39
        bne    L94B3
        iny
        bcs    L94A7
L9495:
        iny
        lda    ($3A),y
        beq    L94B3
L949A:
        cmp    ($37),y
        bne    L94B3
        cpy    $39
        bne    L9495
        iny
        lda    ($3A),y
        bne    L94B3
L94A7:
        tya
        adc    $3A
        sta    $2A
        lda    $3B
        adc    #$00
        sta    $2B
L94B2:
        rts
L94B3:
        lda    $3D
        beq    L94B2
        ldy    #$00
        lda    ($3C),y
        sta    $3A
        iny
        lda    ($3C),y
        sta    $3B
        iny
        lda    ($3C),y
        bne    L94D4
        dey
        cpy    $39
        bne    L9479
        iny
        bcs    L94E1
L94CF:
        iny
        lda    ($3C),y
        beq    L9479
L94D4:
        cmp    ($37),y
        bne    L9479
        cpy    $39
        bne    L94CF
        iny
        lda    ($3C),y
        bne    L9479
L94E1:
        tya
        adc    $3C
        sta    $2A
        lda    $3D
        adc    #$00
        sta    $2B
        rts
L94ED:
        ldy    #$01
        lda    ($37),y
        tax
        lda    #$F6
        cpx    #$F2
        beq    L9501
        lda    #$F8
        bne    L9501
L94FC:
        ldy    #$01
        lda    ($37),y
        asl    a
L9501:
        sta    $3A
        lda    #$04
        sta    $3B
L9507:
        lda    ($3A),y
        beq    L9516
        tax
        dey
        lda    ($3A),y
        sta    $3A
        stx    $3B
        iny
        bpl    L9507
L9516:
        lda    $03
        sta    ($3A),y
        lda    $02
        dey
        sta    ($3A),y
        tya
        iny
        sta    ($02),y
        cpy    $39
        beq    L9558
L9527:
        iny
        lda    ($37),y
        sta    ($02),y
        cpy    $39
        bne    L9527
        rts
L9531:
        lda    #$00
L9533:
        iny
        sta    ($02),y
        dex
        bne    L9533
L9539:
        sec
        tya
        adc    $02
        bcc    L9541
        inc    $03
L9541:
        ldy    $03
        cpy    $05
        bcc    L9556
        bne    L954D
        cmp    $04
        bcc    L9556
L954D:
        lda    #$00
        ldy    #$01
        sta    ($3A),y
        jmp    L8CB7
L9556:
        sta    $02
L9558:
        rts

; Check if variable name is valid
; ===============================
L9559:
        ldy    #$01
L955B:
        lda    ($37),y
        cmp    #$30
        bcc    L9579
        cmp    #$40
        bcs    L9571
        cmp    #$3A
        bcs    L9579
        cpy    #$01
        beq    L9579
L956D:
        inx
        iny
        bne    L955B
L9571:
        cmp    #$5F
        bcs    L957A
        cmp    #$5B
        bcc    L956D
L9579:
        rts
L957A:
        cmp    #$7B
        bcc    L956D
        rts
L957F:
        jsr    L9531
L9582:
        jsr    L95C9
        bne    L95A4
        bcs    L95A4
        jsr    L94FC
        ldx    #$05
        cpx    $2C
        bne    L957F
        inx
        bne    L957F
L9595:
        cmp    #$21
        beq    L95A5
        cmp    #$24
        beq    L95B0
        eor    #$3F
        beq    L95A7
        lda    #$00
        sec
L95A4:
        rts
L95A5:
        lda    #$04
L95A7:
        pha
        inc    $1B
        jsr    L92E3
        jmp    L969F
L95B0:
        inc    $1B
        jsr    L92E3
        lda    $2B
        beq    L95BF
        lda    #$80
        sta    $2C
        sec
        rts
L95BF:
        brk
        .byte  8, "$ range"
        brk
L95C9:
        lda    $0B
        sta    $19
        lda    $0C
        sta    $1A
        ldy    $0A
        dey
L95D4:
        iny
L95D5:
        sty    $1B
        lda    ($19),y
        cmp    #$20
        beq    L95D4
L95DD:
        cmp    #$40
        bcc    L9595
        cmp    #$5B
        bcs    L95FF
        asl    a
        asl    a
        sta    $2A
        lda    #$04
        sta    $2B
        iny
        lda    ($19),y
        iny
        cmp    #$25
        bne    L95FF
        ldx    #$04
        stx    $2C
        lda    ($19),y
        cmp    #'('
        bne    L9665
L95FF:
        ldx    #$05
        stx    $2C
        lda    $1B
        clc
        adc    $19
        ldx    $1A
        bcc    L960E
        inx
        clc
L960E:
        sbc    #$00
        sta    $37
        bcs    L9615
        dex
L9615:
        stx    $38
        ldx    $1B
        ldy    #$01
L961B:
        lda    ($37),y
        cmp    #$41
        bcs    L962D
        cmp    #$30
        bcc    L9641
        cmp    #$3A
        bcs    L9641
        inx
        iny
        bne    L961B
L962D:
        cmp    #$5B
        bcs    L9635
        inx
        iny
        bne    L961B
L9635:
        cmp    #$5F
        bcc    L9641
        cmp    #$7B
        bcs    L9641
        inx
        iny
        bne    L961B
L9641:
        dey
        beq    L9673
        cmp    #$24
        beq    L96AF
        cmp    #$25
        bne    L9654
        dec    $2C
        iny
        inx
        iny
        lda    ($37),y
        dey
L9654:
        sty    $39
        cmp    #'('
        beq    L96A6
        jsr    L9469
        beq    L9677
        stx    $1B
L9661:
        ldy    $1B
        lda    ($19),y
L9665:
        cmp    #$21
        beq    L967F
        cmp    #$3F
        beq    L967B
        clc
        sty    $1B
        lda    #$FF
        rts
L9673:
        lda    #$00
        sec
        rts
 L9677:
        lda    #$00
        clc
        rts
L967B:
        lda    #$00
        beq    L9681
L967F:
        lda    #$04
L9681:
        pha
        iny
        sty    $1B
        jsr    $B32C
        jsr    L92F0
        lda    $2B
        pha
        lda    $2A
        pha
        jsr    L92E3
        clc
        pla
        adc    $2A
        sta    $2A
        pla
        adc    $2B
        sta    $2B
L969F:
        pla
        sta    $2C
        clc
        lda    #$FF
        rts
L96A6:
        inx
        inc    $39
        jsr    L96DF
        jmp    L9661
L96AF:
        inx
        iny
        sty    $39
        iny
        dec    $2C
        lda    ($37),y
        cmp    #'('
        beq    L96C9
        jsr    L9469
        beq    L9677
        stx    $1B
        lda    #$81
        sta    $2C
        sec
        rts
L96C9:
        inx
        sty    $39
        dec    $2C
        jsr    L96DF
        lda    #$81
        sta    $2C
        sec
        rts
L96D7:
        brk
        .byte   14, "Array"
        brk
L96DF:
        jsr    L9469
        beq    L96D7
        stx    $1B
        lda    $2C
        pha
        lda    $2A
        pha
        lda    $2B
        pha
        ldy    #$00
        lda    ($2A),y
        cmp    #$04
        bcc    L976C
        tya
        jsr    $AED8
        lda    #$01
        sta    $2D
L96FF:
        jsr    $BD94
        jsr    L92DD
        inc    $1B
        cpx    #$2C
        bne    L96D7
        ldx    #$39
        jsr    $BE0D
        ldy    $3C
        pla
        sta    $38
        pla
        sta    $37
        pha
        lda    $38
        pha
        jsr    L97BA
        sty    $2D
        lda    ($37),y
        sta    $3F
        iny
        lda    ($37),y
        sta    $40
        lda    $2A
        adc    $39
        sta    $2A
        lda    $2B
        adc    $3A
        sta    $2B
        jsr    L9236
        ldy    #$00
        sec
        lda    ($37),y
        sbc    $2D
        cmp    #$03
        bcs    L96FF
        jsr    $BD94
        jsr    $AE56
        jsr    L92F0
        pla
        sta    $38
        pla
        sta    $37
        ldx    #$39
        jsr    $BE0D
        ldy    $3C
        jsr    L97BA
        clc
        lda    $39
        adc    $2A
        sta    $2A
        lda    $3A
        adc    $2B
        sta    $2B
        bcc    L977D
L976C:
        jsr    $AE56
        jsr    L92F0
        pla
        sta    $38
        pla
        sta    $37
        ldy    #$01
        jsr    L97BA
L977D:
        pla
        sta    $2C
        cmp    #$05
        bne    L979B
        ldx    $2B
        lda    $2A
        asl    $2A
        rol    $2B
        asl    $2A
        rol    $2B
        adc    $2A
        sta    $2A
        txa
        adc    $2B
        sta    $2B
        bcc    L97A3
L979B:
        asl    $2A
        rol    $2B
        asl    $2A
        rol    $2B
L97A3:
        tya
        adc    $2A
        sta    $2A
        bcc    L97AD
        inc    $2B
        clc
L97AD:
        lda    $37
        adc    $2A
        sta    $2A
        lda    $38
        adc    $2B
        sta    $2B
        rts
L97BA:
        lda    $2B
        and    #$C0
        ora    $2C
        ora    $2D
        bne    L97D1
        lda    $2A
        cmp    ($37),y
        iny
        lda    $2B
        sbc    ($37),y
        bcs    L97D1
        iny
        rts
L97D1:
        brk
        .byte   15, "Subscript"
        brk
L97DD:
        inc    $0A
L97DF:
        ldy    $0A
        lda    ($0B),y
        cmp    #$20
        beq    L97DD
        cmp    #$8D
        bne    L9805
L97EB:
        iny
        lda    ($0B),y
        asl    a
        asl    a
        tax
        and    #$C0
        iny
        eor    ($0B),y
        sta    $2A
        txa
        asl    a
        asl    a
        iny
        eor    ($0B),y
        sta    $2B
        iny
        sty    $0A
        sec
        rts
        L9805:
        clc
        rts
L9807:
        lda    $0B
        sta    $19
        lda    $0C
        sta    $1A
        lda    $0A
        sta    $1B
L9813:
        ldy    $1B
        inc    $1B
        lda    ($19),y
        cmp    #$20
        beq    L9813
        cmp    #$3D
        beq    L9849
L9821:
        brk
        .byte   4, "Mistake"
L982A:
        brk
        .byte   16, "Syntax error"

; Escape error
; ------------
L9838:
        brk
        .byte   17, "Escape"
        brk
L9841:
        jsr    L8A8C
        cmp    #'='
        bne    L9821
        rts
L9849:
        jsr    L9B29
L984C:
        txa
        ldy    $1B
        jmp    L9861
L9852:
        ldy    $1B
        jmp    L9859

; Check for end of statement, check for Escape
; ============================================
L9857:
        ldy    $0A              ; Get program pointer offset
L9859:
        dey                     ; Step back to previous character
L985A:
        iny                     ; Get next character
        lda    ($0B),y
        cmp    #' '             ; Skip spaces
        beq    L985A
L9861:
        cmp    #':'             ; Colon, jump to update program pointer
        beq    L986D
        cmp    #$0D             ; <cr>, jump to update program pointer
        beq    L986D
        cmp    #tknELSE         ; Not 'ELSE', jump to 'Syntax error'
        bne    L982A

; Update program pointer
; ----------------------
L986D:
        clc                     ; Update program pointer in PtrA
        tya
        adc    $0B
        sta    $0B
        bcc    L9877
        inc    $0C
L9877:
        ldy    #$01
        sty    $0A

; Check background Escape state
; -----------------------------
L987B:

; BBC - check background Escape state
; -----------------------------------
        bit    ESCFLG           ; If Escape set, jump to give error
        bmi    L9838
L987F:
        rts
L9880:
        jsr    L9857
        dey
        lda    ($0B),y
        cmp    #$3A
        beq    L987F
        lda    $0C
        cmp    #$07
        beq    L98BC
L9890:
        iny
        lda    ($0B),y
        bmi    L98BC
        lda    $20
        beq    L98AC
        tya
        pha
        iny
        lda    ($0B),y
        pha
        dey
        lda    ($0B),y
        tay
        pla
        jsr    $AEEA
        jsr    L9905
        pla
        tay
L98AC:
        iny
        sec
        tya
        adc    $0B
        sta    $0B
        bcc    L98B7
        inc    $0C
L98B7:
        ldy    #$01
        sty    $0A
L98BB:
        rts
L98BC:
        jmp    L8AF6
L98BF:
        jmp    L8C0E

; IF numeric
; ==========
L98C2:
        jsr    L9B1D
        beq    L98BF
        bpl    L98CC
        jsr    $A3E4
L98CC:
        ldy    $1B
        sty    $0A
        lda    $2A
        ora    $2B
        ora    $2C
        ora    $2D
        beq    L98F1
        cpx    #$8C
        beq    L98E1
L98DE:
        jmp    L8BA3
L98E1:
        inc    $0A
L98E3:
        jsr    L97DF
        bcc    L98DE
        jsr    $B9AF
        jsr    L9877
        jmp    $B8D2
L98F1:
        ldy    $0A
L98F3:
        lda    ($0B),y
        cmp    #$0D
        beq    L9902
        iny
        cmp    #$8B
        bne    L98F3
        sty    $0A
        beq    L98E3
L9902:
        jmp    L8B87
L9905:
        lda    $2A
        cmp    $21
        lda    $2B
        sbc    $22
        bcs    L98BB
        lda    #$5B
L9911:
        jsr    $B558
        jsr    L991F
        lda    #$5D
        jsr    $B558
        jmp    $B565

;Print 16-bit decimal number
;===========================
L991F:
        lda    #$00             ; No padding
        beq    L9925
L9923:
        lda    #$05             ; Pad to five characters
L9925:
        sta    $14
        ldx    #$04
L9929:
        lda    #$00
        sta    $3F,x
        sec
L992E:
        lda    $2A
        sbc    L996B,x          ; Subtract 10s low byte
        tay
        lda    $2B
        sbc    L99B9,x          ; Subtract 10s high byte
        bcc    L9943            ; Result<0, no more for this digit
        sta    $2B              ; Update number
        sty    $2A
        inc    $3F,x
        bne    L992E
L9943:
        dex
        bpl    L9929
        ldx    #$05
L9948:
        dex
        beq    L994F
        lda    $3F,x
        beq    L9948
L994F:
        stx    $37
        lda    $14
        beq    L9960
        sbc    $37
        beq    L9960
        tay
L995A:
        jsr    $B565
        dey
        bne    L995A
L9960:
        lda    $3F,x
        ora    #$30
        jsr    $B558
        dex
        bpl    L9960
         rts

; Low bytes of powers of ten
L996B:
        .byte   1, 10, 100, $E8, $10

; Line Search
L9970:
        ldy    #$00
        sty    $3D
        lda    $18
        sta    $3E
L9978:
        ldy    #$01
        lda    ($3D),y
        cmp    $2B
        bcs    L998E
L9980:
        ldy    #$03
        lda    ($3D),y
        adc    $3D
        sta    $3D
        bcc    L9978
        inc    $3E
        bcs    L9978
L998E:
        bne    L99A4
        ldy    #$02
        lda    ($3D),y
        cmp    $2A
        bcc    L9980
        bne    L99A4
        tya
        adc    $3D
        sta    $3D
        bcc    L99A4
        inc    $3E
        clc
L99A4:
        ldy    #$02
        rts

L99A7:
        brk
        .byte  $12, "Division by zero"

; High byte of powers of ten
L99B9:
        brk
        brk
        brk
        .byte  $03
        .byte  $27

L99BE:
        tay
        jsr    L92F0
        lda    $2D
        pha
        jsr    $AD71
        jsr    L9E1D
        stx    $27
        tay
        jsr    L92F0
        pla
        sta    $38
        eor    $2D
        sta    $37
        jsr    $AD71
        ldx    #$39
        jsr    $BE0D
        sty    $3D
        sty    $3E
        sty    $3F
        sty    $40
        lda    $2D
        ora    $2A
        ora    $2B
        ora    $2C
        beq    L99A7
        ldy    #$20
L99F4:
        dey
        beq    L9A38
        asl    $39
        rol    $3A
        rol    $3B
        rol    $3C
        bpl    L99F4
L9A01:
        rol    $39
        rol    $3A
        rol    $3B
        rol    $3C
        rol    $3D
        rol    $3E
        rol    $3F
        rol    $40
        sec
        lda    $3D
        sbc    $2A
        pha
        lda    $3E
        sbc    $2B
        pha
        lda    $3F
        sbc    $2C
        tax
        lda    $40
        sbc    $2D
        bcc    L9A33
        sta    $40
        stx    $3F
        pla
        sta    $3E
        pla
        sta    $3D
        bcs    L9A35
L9A33:
        pla
        pla
L9A35:
        dey
        bne    L9A01
L9A38:
        rts

L9A39:
        stx    $27
        jsr    $BDEA
        jsr    $BD51
        jsr    $A2BE
        jsr    $A21E
        jsr    $BD7E
        jsr    $A3B5
        jmp    L9A62
L9A50:
        jsr    $BD51
        jsr    L9C42
        stx    $27
        tay
        jsr    L92FD
        jsr    $BD7E
L9A5F:
        jsr    $A34E

; Compare FPA = FPB
; -----------------
L9A62:
        ldx    $27
        ldy    #$00
        lda    $3B
        and    #$80
        sta    $3B
        lda    $2E
        and    #$80
        cmp    $3B
        bne    L9A92
        lda    $3D
        cmp    $30
        bne    L9A93
        lda    $3E
        cmp    $31
        bne    L9A93
        lda    $3F
        cmp    $32
        bne    L9A93
        lda    $40
        cmp    $33
        bne    L9A93
        lda    $41
        cmp    $34
        bne    L9A93
L9A92:
        rts

L9A93:
        ror    a
        eor    $3B
        rol    a
        lda    #$01
        rts

L9A9A:
        jmp    L8C0E            ; Jump to 'Type mismatch' error

; Evaluate next expression and compare with previous
; --------------------------------------------------
L9A9D:
        txa
L9A9E:
        beq    L9AE7            ; Jump if current is string
        bmi    L9A50            ; Jump if current is float
        jsr    $BD94            ; Stack integer
        jsr    L9C42            ; Evaluate next expression
        tay
        beq    L9A9A            ; Error if string
        bmi    L9A39            ; Float, jump to compare floats

; Compare IntA with top of stack
; ------------------------------
        lda    $2D
        eor    #$80
        sta    $2D
        sec
        ldy    #$00
        lda    ($04),y
        sbc    $2A
        sta    $2A
        iny
        lda    ($04),y
        sbc    $2B
        sta    $2B
        iny
        lda    ($04),y
        sbc    $2C
        sta    $2C
        iny
        lda    ($04),y
        ldy    #$00
        eor    #$80
        sbc    $2D
        ora    $2A
        ora    $2B
        ora    $2C
        php                     ; Drop integer from stack
        clc
        lda    #$04
        adc    $04
        sta    $04
        bcc    L9AE5
        inc    $05
L9AE5:
        plp
        rts

; Compare string with next expression
; -----------------------------------
L9AE7:
        jsr    $BDB2
        jsr    L9C42
        tay
        bne    L9A9A
        stx    $37
        ldx    $36
        ldy    #$00
        lda    ($04),y
        sta    $39
        cmp    $36
        bcs    L9AFF
        tax
L9AFF:
        stx    $3A
        ldy    #$00
L9B03:
        cpy    $3A
        beq    L9B11
        iny
        lda    ($04),y
        cmp    $05FF,y
        beq    L9B03
        bne    L9B15
L9B11:
        lda    $39
        cmp    $36
L9B15:
        php
        jsr    $BDDC
        ldx    $37
        plp
        rts

; EXPRESSION EVALUATOR
; ====================

; Evaluate expression at PtrA
; ---------------------------
L9B1D:
        lda    $0B              ; Copy PtrA to PtrB
        sta    $19
        lda    $0C
        sta    $1A
        lda    $0A
        sta    $1B

; Evaluate expression at PtrB
; ---------------------------
; TOP LEVEL EVALUATOR
;
; Evaluator Level 7 - OR, EOR
; ---------------------------
L9B29:
        jsr    L9B72            ; Call Evaluator Level 6 - AND
                                ; Returns A=type, value in IntA/FPA/StrA, X=next char
L9B2C:
        cpx    #tknOR           ; Jump if next char is OR
        beq    L9B3A
        cpx    #tknEOR          ; Jump if next char is EOR
        beq    L9B55
        dec    $1B              ; Step PtrB back to last char
        tay
        sta    $27
        rts

; OR numeric
; ----------
L9B3A:
        jsr    L9B6B            ; Stack as integer, call Evaluator Level 6
        tay
        jsr    L92F0            ; If float, convert to integer
        ldy    #$03
L9B43:
        lda    ($04),y          ; OR IntA with top of stack
        ora    $002A,y
        sta    $002A,y          ; Store result in IntA
        dey
        bpl    L9B43
L9B4E:
        jsr    $BDFF            ; Drop integer from stack
        lda    #$40
        bne    L9B2C            ; Return type=Int, jump to check for more OR/EOR

; EOR numeric
; -----------
L9B55:
        jsr    L9B6B
        tay
        jsr    L92F0            ; If float, convert to integer
        ldy    #$03
L9B5E:
        lda    ($04),y          ; EOR IntA with top of stack
        eor    $002A,y
        sta    $002A,y          ; Store result in IntA
        dey
        bpl    L9B5E
        bmi    L9B4E            ; Jump to drop from stack and continue

; Stack current as integer, evaluate another Level 6
; --------------------------------------------------
L9B6B:
        tay                     ; If float, convert to integer, push into stack
        jsr    L92F0
        jsr    $BD94

; Evaluator Level 6 - AND
; -----------------------
L9B72:
        jsr    L9B9C            ; Call Evaluator Level 5, < <= = >= > <>
L9B75:
        cpx    #tknAND          ; Return if next char not AND
        beq    L9B7A
        rts

; AND numeric
; -----------
L9B7A:
        tay                     ; If float, convert to integer, push onto stack
        jsr    L92F0
        jsr    $BD94
        jsr    L9B9C            ; Call Evaluator Level 5, < <= = >= > <>

        tay                     ; If float, convert to integer
        jsr    L92F0
        ldy    #$03
L9B8A:
        lda    ($04),y          ; AND IntA with top of stack
        and    $002A,y
        sta    $002A,y          ; Store result in IntA
        dey
        bpl    L9B8A
        jsr    $BDFF            ; Drop integer from stack
        lda    #$40             ; Return type=Int, jump to check for another AND
        bne    L9B75


; Evaluator Level 5 - >... =... or <...
; -------------------------------------
L9B9C:
        jsr    L9C42            ; Call Evaluator Level 4, + -
        cpx    #'>'+1           ; Larger than '>', return
        bcs    L9BA7
        cpx    #'<'             ; Smaller than '<', return
        bcs    L9BA8
L9BA7:
        rts

; >... =... or <...
; -----------------
L9BA8:
        beq    L9BC0            ; Jump with '<'
        cpx    #'>'             ; Jump with '>'
        beq    L9BE8            ; Must be '='

; = numeric
; ---------
        tax                     ; Jump with result=0 for not equal
        jsr    L9A9E
        bne    L9BB5
L9BB4:
        dey                     ; Decrement to &FF for equal
L9BB5:
        sty    $2A              ; Store 0/-1 in IntA
        sty    $2B
        sty    $2C
        sty    $2D              ; Return type=Int
        lda    #$40
        rts

; < <= <>
; -------
L9BC0:
        tax                     ; Get next char from PtrB
        ldy    $1B
        lda    ($19),y
        cmp    #'='             ; Jump for <=
        beq    L9BD4
        cmp    #'>'             ; Jump for <>
        beq    L9BDF

; Must be < numeric
; -----------------
        jsr    L9A9D            ; Evaluate next and compare
        bcc    L9BB4            ; Jump to return TRUE if <, FALSE if not <
        bcs    L9BB5

; <= numeric
; ----------
L9BD4:
        inc    $1B              ; Step past '=', evaluate next and compare
        jsr    L9A9D    
        beq    L9BB4            ; Jump to return TRUE if =, TRUE if <
        bcc    L9BB4
        bcs    L9BB5            ; Jump to return FALSE otherwise

; <> numeric
; ----------
L9BDF:
        inc    $1B              ; Step past '>', evaluate next and compare
        jsr    L9A9D
        bne    L9BB4            ; Jump to return TRUE if <>, FALSE if =
        beq    L9BB5

; > >=
; ----
L9BE8:
        tax                     ; Get next char from PtrB
        ldy    $1B
        lda    ($19),y
        cmp    #'='             ; Jump for >=
        beq    L9BFA

; > numeric
; ---------
  jsr    L9A9D                  ; Evaluate next and compare
  beq    L9BB5                  ; Jump to return FALSE if =, TRUE if >
  bcs    L9BB4
  bcc    L9BB5                  ; Jump to return FALSE if <

; >= numeric
; ----------
L9BFA:
        inc    $1B              ; Step past '=', evaluate next and compare
        jsr    L9A9D
        bcs    L9BB4            ; Jump to return TRUE if >=, FALSE if <
        bcc    L9BB5

L9C03:
        brk
        .byte  $13, "String too long"
        brk

; String addition
; ---------------
L9C15:
        jsr    $BDB2            ; Stack string, call Evaluator Level 2
        jsr    L9E20
        tay                     ; string + number, jump to 'Type mismatch' error
        bne    L9C88
        clc
        stx    $37
        ldy    #$00             ; Get stacked string length
        lda    ($04),y
        adc    $36              ; If added string length >255, jump to error
        bcs    L9C03
        tax                     ; Save new string length
        pha
        ldy    $36
L9C2D:
        lda    $05FF,y          ; Move current string up in string buffer
        sta    $05FF,x
        dex
        dey
        bne    L9C2D
        jsr    $BDCB            ; Unstack string to start of string buffer
        pla                     ; Set new string length
        sta    $36
        ldx    $37
        tya                     ; Set type=string, jump to check for more + or -
        beq    L9C45

; Evaluator Level 4, + -
; ----------------------
L9C42:
        jsr    L9DD1            ; Call Evaluator Level 3, * / DIV MOD
L9C45:
        cpx    #'+'             ; Jump with addition
        beq    L9C4E
        cpx    #'-'             ; Jump with subtraction
        beq    L9CB5
        rts

; + <value>
; ---------
L9C4E:
        tay                     ; Jump if current value is a string
        beq    L9C15
        bmi    L9C8B            ; Jump if current value is a float

; Integer addition
; ----------------
        jsr    L9DCE            ; Stack current and call Evaluator Level 3
        tay                     ; If int + string, jump to 'Type mismatch' error
        beq    L9C88
        bmi    L9CA7            ; If int + float, jump ...
        ldy    #$00
        clc                     ; Add top of stack to IntA
        lda    ($04),y
        adc    $2A
        sta    $2A
        iny                     ; Store result in IntA
        lda    ($04),y
        adc    $2B
        sta    $2B
        iny
        lda    ($04),y
        adc    $2C
        sta    $2C
        iny
        lda    ($04),y
        adc    $2D
L9C77:
        sta    $2D
        clc
        lda    $04              ; Drop integer from stack
        adc    #$04
        sta    $04
        lda    #$40             ; Set result=integer, jump to check for more + or -
        bcc    L9C45
        inc    $05
        bcs    L9C45
L9C88:
        jmp    L8C0E            ; Jump to 'Type mismatch' error

;Real addition
;-------------
L9C8B:
        jsr    $BD51            ; Stack float, call Evaluator Level 3
        jsr    L9DD1
        tay                     ; float + string, jump to 'Type mismatch' error
        beq    L9C88
        stx    $27              ; float + float, skip conversion
        bmi    L9C9B
        jsr    $A2BE            ; float + int, convert int to float
L9C9B:
        jsr    $BD7E            ; Pop float from stack, point FPTR to it
        jsr    $A500            ; Unstack float to FPA2 and add to FP1A
L9CA1:
        ldx    $27              ; Get nextchar back
        lda    #$FF             ; Set result=float, loop to check for more + or -
        bne    L9C45

; int + float
; -----------
L9CA7:
        stx    $27              ; Unstack integer to IntA
        jsr    $BDEA
        jsr    $BD51            ; Stack float, convert integer in IntA to float in FPA1
        jsr    $A2BE
        jmp    L9C9B            ; Jump to do float + <stacked float>

; - numeric
; ---------
L9CB5:
        tay                     ; If current value is a string, jump to error
        beq    L9C88
        bmi    L9CE1            ; Jump if current value is a float

; Integer subtraction
; -------------------
        jsr    L9DCE            ; Stack current and call Evaluator Level 3
        tay                     ; int + string, jump to error
        beq    L9C88
        bmi    L9CFA            ; int + float, jump to convert and do real subtraction
        sec
        ldy    #$00
        lda    ($04),y
        sbc    $2A
        sta    $2A
        iny                     ; Subtract IntA from top of stack
        lda    ($04),y
        sbc    $2B
        sta    $2B
        iny                     ; Store in IntA
        lda    ($04),y
        sbc    $2C
        sta    $2C
        iny
        lda    ($04),y
        sbc    $2D
        jmp    L9C77            ; Jump to pop stack and loop for more + or -

; Real subtraction
; ----------------
L9CE1:
        jsr    $BD51            ; Stack float, call Evaluator Level 3
        jsr    L9DD1
        tay                     ; float - string, jump to 'Type mismatch' error
        beq    L9C88
        stx    $27              ; float - float, skip conversion
        bmi    L9CF1
        jsr    $A2BE            ; float - int, convert int to float
L9CF1:
        jsr    $BD7E            ; Pop float from stack and point FPTR to it
        jsr    $A4FD            ; Unstack float to FPA2 and subtract it from FPA1
        jmp    L9CA1            ; Jump to set result and loop for more + or -

; int - float
; -----------
L9CFA:
        stx    $27              ; Unstack integer to IntA
        jsr    $BDEA
        jsr    $BD51            ; Stack float, convert integer in IntA to float in FPA1
        jsr    $A2BE
        jsr    $BD7E            ; Pop float from stack, point FPTR to it
        jsr    $A4D0            ; Subtract FPTR float from FPA1 float
        jmp    L9CA1            ; Jump to set result and loop for more + or -
L9D0E:
        jsr    $A2BE
L9D11:
        jsr    $BDEA
        jsr    $BD51
        jsr    $A2BE
        jmp    L9D2C
L9D1D:
        jsr    $A2BE
L9D20:
        jsr    $BD51
        jsr    L9E20
        stx    $27
        tay
        jsr    L92FD
L9D2C:
        jsr    $BD7E
        jsr    $A656
        lda    #$FF
        ldx    $27
        jmp    L9DD4
L9D39:
        jmp    L8C0E

; * <value>
; ---------
L9D3C:
        tay                     ; If current value is string, jump to error
        beq    L9D39
        bmi    L9D20            ; Jump if current value is a float
        lda    $2D
        cmp    $2C
        bne    L9D1D
        tay
        beq    L9D4E
        cmp    #$FF
        bne    L9D1D
L9D4E:
        eor    $2B
        bmi    L9D1D
        jsr    L9E1D
        stx    $27
        tay
        beq    L9D39
        bmi    L9D11
        lda    $2D
        cmp    $2C
        bne    L9D0E
        tay
        beq    L9D69
        cmp    #$FF
        bne    L9D0E
L9D69:
        eor    $2B
        bmi    L9D0E
        lda    $2D
        pha
        jsr    $AD71
        ldx    #$39
        jsr    $BE44
        jsr    $BDEA
        pla
        eor    $2D
        sta    $37
        jsr    $AD71
        ldy    #$00
        ldx    #$00
        sty    $3F
        sty    $40
L9D8B:
        lsr    $3A
        ror    $39
        bcc    L9DA6
        clc
        tya
        adc    $2A
        tay
        txa
        adc    $2B
        tax
        lda    $3F
        adc    $2C
        sta    $3F
        lda    $40
        adc    $2D
        sta    $40
L9DA6:
        asl    $2A
        rol    $2B
        rol    $2C
        rol    $2D
        lda    $39
        ora    $3A
        bne    L9D8B
        sty    $3D
        stx    $3E
        lda    $37
        php
L9DBB:
        ldx    #$3D
L9DBD:
        jsr    $AF56
        plp
        bpl    L9DC6
        jsr    $AD93
L9DC6:
        ldx    $27
        jmp    L9DD4
 
; * <value>
; ---------
L9DCB:
        jmp    L9D3C            ; Bounce back to multiply code

; Stack current value and continue in Evaluator Level 3
; ------------------------------------------------------- 
L9DCE:
        jsr    $BD94

; Evaluator Level 3, * / DIV MOD
; ------------------------------
L9DD1:
        jsr    L9E20            ; Call Evaluator Level 2, ^
L9DD4:
        cpx    #'*'             ; Jump with multiply
        beq    L9DCB
        cpx    # '/'            ; Jump with divide
        beq    L9DE5
        cpx    #tknMOD          ; Jump with MOD
        beq    L9E01
        cpx    #tknDIV          ; Jump with DIV
        beq    L9E0A
        rts

;/ <value>
;---------
L9DE5:
        tay                     ; Ensure current value is real
        jsr    L92FD
        jsr    $BD51            ; Stack float, call Evaluator Level 2
        jsr    L9E20
        stx    $27              ; Ensure current value is real
        tay
        jsr    L92FD
        jsr    $BD7E            ; Unstack to FPTR, call divide routine
        jsr    $A6AD
        ldx    $27              ; Set result, loop for more * / MOD DIV
        lda    #$FF
        bne    L9DD4

;MOD <value>
; -----------
L9E01:
        jsr    L99BE            ; Ensure current value is integer
        lda    $38
        php
        jmp    L9DBB            ; Jump to MOD routine

; DIV <value>
; -----------
L9E0A:
        jsr    L99BE            ; Ensure current value is integer
        rol    $39              ; Multiply IntA by 2
        rol    $3A
        rol    $3B
        rol    $3C
        bit    $37
        php
        ldx    #$39             ; Jump to DIV routine
        jmp    L9DBD

; Stack current integer and evaluate another Level 2
; --------------------------------------------------
L9E1D:
        jsr    $BD94            ; Stack integer

; Evaluator Level 2, ^
; --------------------
L9E20:
        jsr    $ADEC            ; Call Evaluator Level 1, - + NOT function ( ) ? ! $ | "
L9E23:
        pha
L9E24:
        ldy    $1B              ; Get character
        inc    $1B
        lda    ($19),y
        cmp    #' '             ; Skip spaces
        beq    L9E24
        tax
        pla
        cpx    #'^'             ; Return if not ^
        beq    L9E35
        rts

; ^ <value>
; ---------
L9E35:
        tay                     ; Ensure current value is a float
        jsr    L92FD
        jsr    $BD51            ; Stack float, evaluate a real
        jsr    L92FA
        lda    $30
        cmp    #$87
        bcs    L9E88
        jsr    $A486
        bne    L9E59
        jsr    $BD7E
        jsr    $A3B5
        lda    $4A
        jsr    $AB12
        lda    #$FF             ; Set result=real, loop to check for more ^
        bne    L9E23
L9E59:
        jsr    $A381
        lda    $04
        sta    $4B
        lda    $05
        sta    $4C
        jsr    $A3B5
        lda    $4A
        jsr    $AB12
L9E6C:
        jsr    $A37D
        jsr    $BD7E
        jsr    $A3B5
        jsr    $A801
        jsr    $AAD1
        jsr    $AA94
        jsr    $A7ED
        jsr    $A656
        lda    #$FF             ; Set result=real, loop to check for more ^
        bne    L9E23
L9E88:
        jsr    $A381
        jsr    $A699
        bne    L9E6C

;Convert number to hex string
;----------------------------
L9E90:
        tya                     ; Convert real to integer
        bpl    L9E96
        jsr    $A3E4
L9E96:
        ldx    #$00
        ldy    #$00
L9E9A:
        lda    $002A,y          ; Expand four bytes into eight digits
        pha
        and    #$0F
        sta    $3F,x
        pla
        lsr    a
        lsr    a
        lsr    a
        lsr    a
        inx
        sta    $3F,x
        inx
        iny
        cpy    #$04             ; Loop for four bytes
        bne    L9E9A
L9EB0:
        dex                     ; No digits left, output a single zero
        beq    L9EB7
        lda    $3F,x            ; Skip leading zeros
        beq    L9EB0
L9EB7:
        lda    $3F,x            ; Get byte from workspace
        cmp    #$0A
        bcc    L9EBF
        adc    #$06
L9EBF:
        adc    #'0'             ; Convert to digit and store in buffer
        jsr    $A066
        dex
        bpl    L9EB7
        rts

; Output nonzero real number
; --------------------------
L9EC8:
        bpl    L9ED1            ; Jump forward if positive
        lda    #'-'             ; A='-', clear sign flag
        sta    $2E
        jsr    $A066            ; Add '-' to string buffer
L9ED1:
        lda    $30              ; Get exponent
        cmp    #$81             ; If m*2^1 or larger, number>=1, jump to output it
        bcs    L9F25
        jsr    $A1F4            ; FloatA=FloatA*10
        dec    $49
        jmp    L9ED1

; Convert numeric value to string
; ===============================
; On entry, FloatA (&2E-&35)  = number
;           or IntA (&2A-&2D) = number
;                           Y = type
;                          @% = print format
;                     &15.b7 set if hex
; Uses,     &37=format type 0/1/2=G/E/F
;           &38=max digits
;           &49
; On exit,  StrA contains string version of number
;           &36=string length
;
L9EDF:
        ldx    $0402            ; Get format byte
        cpx    #$03             ; If <3, ok - use it
        bcc    L9EE8
        ldx    #$00             ; If invalid, &00 for General format
L9EE8:
        stx    $37              ; Store format type
        lda    $0401            ; If digits=0, jump to check format
        beq    L9EF5
        cmp    #$0A             ; If 10+ digits, jump to use 10 digits
        bcs    L9EF9
        bcc    L9EFB            ; If <10 digits, use specified number
L9EF5:
        cpx    #$02             ; If fixed format, use zero digits
        beq    L9EFB

; STR$ enters here to use general format
; --------------------------------------
L9EF9:
        lda    #$0A             ; Otherwise, default to ten digits
L9EFB:
        sta    $38              ; Store digit length
        sta    $4E
        lda    #$00             ; Set initial output length to 0, initial exponent to 0
        sta    $36
        sta    $49
        bit    $15              ; Jump for hex conversion if &15.b7 set
        bmi    L9E90
        tya                     ; Convert integer to real
        bmi    L9F0F
        jsr    $A2BE
L9F0F:
        jsr    $A1DA            ; Get -1/0/+1 sign, jump if not zero to output nonzero number
        bne    L9EC8
        lda    $37              ; If not General format, output fixed or exponential zero
        bne    L9F1D
        lda    #'0'             ; Store single '0' into string buffer and return
        jmp    $A066
L9F1D:
        jmp    L9F9C            ; Jump to output zero in fixed or exponential format
L9F20:
        jsr    $A699            ; FloatA=1.0
        bne    L9F34

; FloatA now is >=1, check that it is <10
; ---------------------------------------
L9F25:
        cmp    #$84             ; Exponent<4, FloatA<10, jump to convert it
        bcc    L9F39
        bne    L9F31            ; Exponent<>4, need to divide it
        lda    $31              ; Get mantissa top byte
        cmp    #$A0             ; Less than &A0, less than ten, jump to convert it
        bcc    L9F39
L9F31:
        jsr    $A24D            ; FloatA=FloatA / 10
L9F34:
        inc    $49              ; Jump back to get the number >=1 again
        jmp    L9ED1

; FloatA is now between 1 and 9.999999999
; ---------------------------------------
L9F39:
        lda    $35              ; Copy FloatA to FloatTemp at &27/&046C
        sta    $27
        jsr    $A385
        lda    $4E              ; Get number of digits
        sta    $38
        ldx    $37              ; Get print format
        cpx    #$02             ; Not fixed format, jump to do exponent/general
        bne    L9F5C
        adc    $49
        bmi    L9FA0
        sta    $38
        cmp    #$0B
        bcc    L9F5C
        lda    #$0A
        sta    $38
        lda    #$00
        sta    $37
L9F5C:
        jsr    $A686            ; Clear FloatA
        lda    #$A0
        sta    $31
        lda    #$83
        sta    $30
        ldx    $38
        beq    L9F71
L9F6B:
        jsr    $A24D            ; FloatA=FloatA/10
        dex
        bne    L9F6B
L9F71:
        jsr    $A7F5            ; Point to &46C
        jsr    $A34E            ; Unpack to FloatB
        lda    $27
        sta    $42
        jsr    $A50B            ; Add
L9F7E:
        lda    $30
        cmp    #$84
        bcs    L9F92
        ror    $31
        ror    $32
        ror    $33
        ror    $34
        ror    $35
        inc    $30
        bne    L9F7E
L9F92:
        lda    $31
        cmp    #$A0
        bcs    L9F20
        lda    $38
        bne    L9FAD

; Output zero in Exponent or Fixed format
; ---------------------------------------
L9F9C:
        cmp    #$01
        beq    L9FE6
L9FA0:
        jsr    $A686            ; Clear FloatA
        lda    #$00
        sta    $49
        lda    $4E
        sta    $38
        inc    $38
L9FAD:
        lda    #$01
        cmp    $37
        beq    L9FE6
        ldy    $49
        bmi    L9FC3
        cpy    $38
        bcs    L9FE6
        lda    #$00
        sta    $49
        iny
        tya
        bne    L9FE6
L9FC3:
        lda    $37
        cmp    #$02
        beq    L9FCF
        lda    #$01
        cpy    #$FF
        bne    L9FE6
L9FCF:
        lda    #'0'             ; Output '0'
        jsr    $A066
        lda    #'.'             ; Output '.'
        jsr    $A066
        lda    #'0'             ; Prepare '0'
L9FDB:
        inc    $49
        beq    L9FE4
        jsr    $A066            ; Output
         bne    L9FDB
L9FE4:
        lda    #$80
L9FE6:
        sta    $4E
L9FE8:
        jsr    $A040
        dec    $4E
        bne    L9FF4
        lda    #$2E
        jsr    $A066
L9FF4:
        dec    $38
        bne    L9FE8
        ldy    $37
        dey
        beq    $A015
        dey
        beq    $A011
        ldy    $36
LA002:
        dey
        lda    $0600,y
        cmp    #'0'
        beq    $A002
        cmp    #'.'
        beq    $A00F
        iny
LA00F:
        sty    $36
LA011:
        lda    $49
        beq    $A03F
LA015:
        lda    #'E'             ; Output 'E'
        jsr    $A066
        lda    $49
        bpl    $A028
        lda    #'-'             ; Output '-'
        jsr    $A066
        sec
        lda    #$00
        sbc    $49              ; Negate
LA028:
        jsr    $A052
        lda    $37
        beq    $A03F
        lda    #$20
        ldy    $49
        bmi    $A038
        jsr    $A066
LA038:
        cpx    #$00
        bne    $A03F
        jmp    $A066
LA03F:
        rts
LA040:
        lda    $31
        lsr    a
        lsr    a
        lsr    a
        lsr    a
        jsr    $A064
        lda    $31
        and    #$0F
        sta    $31
        jmp    $A197
LA052:
        ldx    #$FF
        sec
        inx
        sbc    #$0A
        bcs    $A055
        adc    #$0A
        pha
        txa
        beq    $A063
        jsr    $A064
LA063:
        pla
LA064:
        ora    #'0'

; Store character in string buffer
; --------------------------------
LA066:
        stx    $3B              ; Store character
        ldx    $36
        sta    $0600,x
        ldx    $3B              ; Increment string length
        inc    $36
        rts
LA072:
        clc
        stx    $35
        jsr    $A1DA
        lda    #$FF
        rts

; Scan decimal number
; -------------------
LA07B:
        ldx    #$00
 stx    $31
 stx    $32
 stx    $33
 stx    $34
 stx    $35
 stx    $48
 stx    $49
 cmp    #$2E
 beq    $A0A0
 cmp    #$3A
 bcs    $A072
 sbc    #$2F
 bmi    $A072
 sta    $35
 iny
 lda    ($19),y
 cmp    #$2E
 bne    $A0A8
 lda    $48
 bne    $A0E8
 inc    $48
 bne    $A099
 cmp    #$45
 beq    $A0E1
 cmp    #$3A
 bcs    $A0E8
 sbc    #$2F
 bcc    $A0E8
 ldx    $31
 cpx    #$18
 bcc    $A0C2
 ldx    $48
 bne    $A099
 inc    $49
 bcs    $A099
 ldx    $48
 beq    $A0C8
 dec    $49
 jsr    $A197
 adc    $35
 sta    $35
 bcc    $A099
 inc    $34
 bne    $A099
 inc    $33
 bne    $A099
 inc    $32
 bne    $A099
 inc    $31
 bne    $A099
 jsr    $A140
 adc    $49
 sta    $49
 sty    $1B
 lda    $49
 ora    $48
 beq    $A11F
 jsr    $A1DA
 beq    $A11B
 lda    #$A8
 sta    $30
 lda    #$00
 sta    $2F
 sta    $2E
 jsr    $A303
 lda    $49
 bmi    $A111
 beq    $A118
 jsr    $A1F4
 dec    $49
 bne    $A108
 beq    $A118
 jsr    $A24D
 inc    $49
 bne    $A111
 jsr    $A65C
 sec
 lda    #$FF
 rts
 lda    $32
 sta    $2D
 and    #$80
 ora    $31
 bne    $A0F5
 lda    $35
 sta    $2A
 lda    $34
 sta    $2B
 lda    $33
 sta    $2C
 lda    #$40
 sec
 rts
 jsr    $A14B
 eor    #$FF
 sec
 rts
 iny
 lda    ($19),y
 cmp    #$2D
 beq    $A139
 cmp    #$2B
 bne    $A14E
 iny
 lda    ($19),y
 cmp    #$3A
 bcs    $A174
 sbc    #$2F
 bcc    $A174
 sta    $4A
 iny
 lda    ($19),y
 cmp    #$3A
 bcs    $A170
 sbc    #$2F
 bcc    $A170
 iny
 sta    $43
 lda    $4A
 asl    a
 asl    a
 adc    $4A
 asl    a
 adc    $43
 rts
 lda    $4A
 clc
 rts
 lda    #$00
 clc
 rts
 lda    $35
 adc    $42
 sta    $35
 lda    $34
 adc    $41
 sta    $34
 lda    $33
 adc    $40
 sta    $33
 lda    $32
 adc    $3F
 sta    $32
 lda    $31
 adc    $3E
 sta    $31
 rts
 pha
 ldx    $34
 lda    $31
 pha
 lda    $32
 pha
 lda    $33
 pha
 lda    $35
 asl    a
 rol    $34
 rol    $33
 rol    $32
 rol    $31
 asl    a
 rol    $34
 rol    $33
 rol    $32
 rol    $31
 adc    $35
 sta    $35
 txa
 adc    $34
 sta    $34
 pla
 adc    $33
 sta    $33
 pla
 adc    $32
 sta    $32
 pla
 adc    $31
 asl    $35
 rol    $34
 rol    $33
 rol    $32
 rol    a
 sta    $31
 pla
 rts
 lda    $31
 ora    $32
 ora    $33
 ora    $34
 ora    $35
 beq    $A1ED
 lda    $2E
 bne    $A1F3
 lda    #$01
 rts
 sta    $2E
 sta    $30
 sta    $2F
 rts
 clc
 lda    $30
 adc    #$03
 sta    $30
 bcc    $A1FF
 inc    $2F
 jsr    $A21E
 jsr    $A242
 jsr    $A242
 jsr    $A178
 bcc    $A21D
 ror    $31
 ror    $32
 ror    $33
 ror    $34
 ror    $35
 inc    $30
 bne    $A21D
 inc    $2F
 rts
 lda    $2E
 sta    $3B
 lda    $2F
 sta    $3C
 lda    $30
 sta    $3D
 lda    $31
 sta    $3E
 lda    $32
 sta    $3F
 lda    $33
 sta    $40
 lda    $34
 sta    $41
 lda    $35
 sta    $42
 rts
 jsr    $A21E
 lsr    $3E
 ror    $3F
 ror    $40
 ror    $41
 ror    $42
 rts
 sec
 lda    $30
 sbc    #$04
 sta    $30
 bcs    $A258
 dec    $2F
 jsr    $A23F
 jsr    $A208
 jsr    $A23F
 jsr    $A242
 jsr    $A242
 jsr    $A242
 jsr    $A208
 lda    #$00
 sta    $3E
 lda    $31
 sta    $3F
 lda    $32
 sta    $40
 lda    $33
 sta    $41
 lda    $34
 sta    $42
 lda    $35
 rol    a
 jsr    $A208
 lda    #$00
 sta    $3E
 sta    $3F
 lda    $31
 sta    $40
 lda    $32
 sta    $41
 lda    $33
 sta    $42
 lda    $34
 rol    a
 jsr    $A208
 lda    $32
 rol    a
 lda    $31
 adc    $35
 sta    $35
 bcc    $A2BD
 inc    $34
 bne    $A2BD
 inc    $33
 bne    $A2BD
 inc    $32
 bne    $A2BD
 inc    $31
 bne    $A2BD
 jmp    $A20B
 rts
 ldx    #$00
 stx    $35
 stx    $2F
 lda    $2D
 bpl    $A2CD
 jsr    $AD93
 ldx    #$FF
 stx    $2E
 lda    $2A
 sta    $34
 lda    $2B
 sta    $33
 lda    $2C
 sta    $32
 lda    $2D
 sta    $31
 lda    #$A0
 sta    $30
 jmp    $A303
 sta    $2E
 sta    $30
 sta    $2F
 rts
 pha
 jsr    $A686
 pla
 beq    $A2EC
 bpl    $A2FD
 sta    $2E
 lda    #$00
 sec
 sbc    $2E
 sta    $31
 lda    #$88
 sta    $30
 lda    $31
 bmi    $A2EC
 ora    $32
 ora    $33
 ora    $34
 ora    $35
 beq    $A2E6
 lda    $30
 ldy    $31
 bmi    $A2EC
 bne    $A33A
 ldx    $32
 stx    $31
 ldx    $33
 stx    $32
 ldx    $34
 stx    $33
 ldx    $35
 stx    $34
 sty    $35
 sec
 sbc    #$08
 sta    $30
 bcs    $A313
 dec    $2F
 bcc    $A313
 ldy    $31
 bmi    $A2EC
 asl    $35
 rol    $34
 rol    $33
 rol    $32
 rol    $31
 sbc    #$00
 sta    $30
 bcs    $A336
 dec    $2F
 bcc    $A336
 ldy    #$04
 lda    ($4B),y
 sta    $41
 dey
 lda    ($4B),y
 sta    $40
 dey
 lda    ($4B),y
 sta    $3F
 dey
 lda    ($4B),y
 sta    $3B
 dey
 sty    $42
 sty    $3C
 lda    ($4B),y
 sta    $3D
 ora    $3B
 ora    $3F
 ora    $40
 ora    $41
 beq    $A37A
 lda    $3B
 ora    #$80
 sta    $3E
 rts
 lda    #$71
 bne    $A387
 lda    #$76
 bne    $A387
 lda    #$6C
 sta    $4B
 lda    #$04
 sta    $4C
 ldy    #$00
 lda    $30
 sta    ($4B),y
 iny
 lda    $2E
 and    #$80
 sta    $2E
 lda    $31
 and    #$7F
 ora    $2E
 sta    ($4B),y
 lda    $32
 iny
 sta    ($4B),y
 lda    $33
 iny
 sta    ($4B),y
 lda    $34
 iny
 sta    ($4B),y
 rts
 jsr    $A7F5
 ldy    #$04
 lda    ($4B),y
 sta    $34
 dey
 lda    ($4B),y
 sta    $33
 dey
 lda    ($4B),y
 sta    $32
 dey
 lda    ($4B),y
 sta    $2E
 dey
 lda    ($4B),y
 sta    $30
 sty    $35
 sty    $2F
 ora    $2E
 ora    $32
 ora    $33
 ora    $34
 beq    $A3E1
 lda    $2E
 ora    #$80
 sta    $31
 rts
 jsr    $A3FE
 lda    $31
 sta    $2D
 lda    $32
 sta    $2C
 lda    $33
 sta    $2B
 lda    $34
 sta    $2A
 rts
 jsr    $A21E
 jmp    $A686
 lda    $30
 bpl    $A3F8
 jsr    $A453
 jsr    $A1DA
 bne    $A43C
 beq    $A468
 lda    $30
 cmp    #$A0
 bcs    $A466
 cmp    #$99
 bcs    $A43C
 adc    #$08
 sta    $30
 lda    $40
 sta    $41
 lda    $3F
 sta    $40
 lda    $3E
 sta    $3F
 lda    $34
 sta    $3E
 lda    $33
 sta    $34
 lda    $32
 sta    $33
 lda    $31
 sta    $32
 lda    #$00
 sta    $31
 beq    $A40C
 lsr    $31
 ror    $32
 ror    $33
 ror    $34
 ror    $3E
 ror    $3F
 ror    $40
 ror    $41
 inc    $30
 bne    $A40C
 jmp    $A66C
 lda    #$00
 sta    $3B
 sta    $3C
 sta    $3D
 sta    $3E
 sta    $3F
 sta    $40
 sta    $41
 sta    $42
 rts
 bne    $A450
 lda    $2E
 bpl    $A485
 sec
 lda    #$00
 sbc    $34
 sta    $34
 lda    #$00
 sbc    $33
 sta    $33
 lda    #$00
 sbc    $32
 sta    $32
 lda    #$00
 sbc    $31
 sta    $31
 rts
 lda    $30
 bmi    $A491
 lda    #$00
 sta    $4A
 jmp    $A1DA
 jsr    $A3FE
 lda    $34
 sta    $4A
 jsr    $A4E8
 lda    #$80
 sta    $30
 ldx    $31
 bpl    $A4B3
 eor    $2E
 sta    $2E
 bpl    $A4AE
 inc    $4A
 jmp    $A4B0
 dec    $4A
 jsr    $A46C
 jmp    $A303
 inc    $34
 bne    $A4C6
 inc    $33
 bne    $A4C6
 inc    $32
 bne    $A4C6
 inc    $31
 beq    $A450
 rts
 jsr    $A46C
 jsr    $A4B6
 jmp    $A46C
 jsr    $A4FD
 jmp    $AD7E
 jsr    $A34E
 jsr    $A38D
 lda    $3B
 sta    $2E
 lda    $3C
 sta    $2F
 lda    $3D
 sta    $30
 lda    $3E
 sta    $31
 lda    $3F
 sta    $32
 lda    $40
 sta    $33
 lda    $41
 sta    $34
 lda    $42
 sta    $35
 rts
 jsr    $AD7E
 jsr    $A34E
 beq    $A4FC
 jsr    $A50B
 jmp    $A65C
 jsr    $A1DA
 beq    $A4DC
 ldy    #$00
 sec
 lda    $30
 sbc    $3D
 beq    $A590
 bcc    $A552
 cmp    #$25
 bcs    $A4FC
 pha
 and    #$38
 beq    $A53D
 lsr    a
 lsr    a
 lsr    a
 tax
 lda    $41
 sta    $42
 lda    $40
 sta    $41
 lda    $3F
 sta    $40
 lda    $3E
 sta    $3F
 sty    $3E
 dex
 bne    $A528
 pla
 and    #$07
 beq    $A590
 tax
 lsr    $3E
 ror    $3F
 ror    $40
 ror    $41
 ror    $42
 dex
 bne    $A543
 beq    $A590
 sec
 lda    $3D
 sbc    $30
 cmp    #$25
 bcs    $A4DC
 pha
 and    #$38
 beq    $A579
 lsr    a
 lsr    a
 lsr    a
 tax
 lda    $34
 sta    $35
 lda    $33
 sta    $34
 lda    $32
 sta    $33
 lda    $31
 sta    $32
 sty    $31
 dex
 bne    $A564
 pla
 and    #$07
 beq    $A58C
 tax
 lsr    $31
 ror    $32
 ror    $33
 ror    $34
 ror    $35
 dex
 bne    $A57F
 lda    $3D
 sta    $30
 lda    $2E
 eor    $3B
 bpl    $A5DF
 lda    $31
 cmp    $3E
 bne    $A5B7
 lda    $32
 cmp    $3F
 bne    $A5B7
 lda    $33
 cmp    $40
 bne    $A5B7
 lda    $34
 cmp    $41
 bne    $A5B7
 lda    $35
 cmp    $42
 bne    $A5B7
 jmp    $A686
 bcs    $A5E3
 sec
 lda    $42
 sbc    $35
 sta    $35
 lda    $41
 sbc    $34
 sta    $34
 lda    $40
 sbc    $33
 sta    $33
 lda    $3F
 sbc    $32
 sta    $32
 lda    $3E
 sbc    $31
 sta    $31
 lda    $3B
 sta    $2E
 jmp    $A303
 clc
 jmp    $A208
 sec
 lda    $35
 sbc    $42
 sta    $35
 lda    $34
 sbc    $41
 sta    $34
 lda    $33
 sbc    $40
 sta    $33
 lda    $32
 sbc    $3F
 sta    $32
 lda    $31
 sbc    $3E
 sta    $31
 jmp    $A303
 rts
 jsr    $A1DA
 beq    $A605
 jsr    $A34E
 bne    $A613
 jmp    $A686
 clc
 lda    $30
 adc    $3D
 bcc    $A61D
 inc    $2F
 clc
 sbc    #$7F
 sta    $30
 bcs    $A625
 dec    $2F
 ldx    #$05
 ldy    #$00
 lda    $30,x
 sta    $42,x
 sty    $30,x
 dex
 bne    $A629
 lda    $2E
 eor    $3B
 sta    $2E
 ldy    #$20
 lsr    $3E
 ror    $3F
 ror    $40
 ror    $41
 ror    $42
 asl    $46
 rol    $45
 rol    $44
 rol    $43
 bcc    $A652
 clc
 jsr    $A178
 dey
 bne    $A63A
 rts
 jsr    $A606
 jsr    $A303
 lda    $35
 cmp    #$80
 bcc    $A67C
 beq    $A676
 lda    #$FF
 jsr    $A2A4
 jmp    $A67C
 brk
 .byte  $14
 .byte  'T'
 .byte  'o'
 .byte  'o'
 jsr    $6962
 .byte  'g'
 brk
 lda    $34
 ora    #$01
 sta    $34
 lda    #$00
 sta    $35
 lda    $2F
 beq    $A698
 bpl    $A66C
 lda    #$00
 sta    $2E
 sta    $2F
 sta    $30
 sta    $31
 sta    $32
 sta    $33
 sta    $34
 sta    $35
 rts
 jsr    $A686
 ldy    #$80
 sty    $31
 iny
 sty    $30
 tya
 rts
 jsr    $A385
 jsr    $A699
 bne    $A6E7
 jsr    $A1DA
 beq    $A6BB
 jsr    $A21E
 jsr    $A3B5
 bne    $A6F1
 rts
 jmp    L99A7
 jsr    L92FA
 jsr    $A9D3
 lda    $4A
 pha
 jsr    $A7E9
 jsr    $A38D
 inc    $4A
 jsr    $A99E
 jsr    $A7E9
 jsr    $A4D6
 pla
 sta    $4A
 jsr    $A99E
 jsr    $A7E9
 jsr    $A6E7
 lda    #$FF
 rts
 jsr    $A1DA
 beq    $A698
 jsr    $A34E
 beq    $A6BB
 lda    $2E
 eor    $3B
 sta    $2E
 sec
 lda    $30
 sbc    $3D
 bcs    $A701
 dec    $2F
 sec
 adc    #$80
 sta    $30
 bcc    $A70A
 inc    $2F
 clc
 ldx    #$20
 bcs    $A726
 lda    $31
 cmp    $3E
 bne    $A724
 lda    $32
 cmp    $3F
 bne    $A724
 lda    $33
 cmp    $40
 bne    $A724
 lda    $34
 cmp    $41
 bcc    $A73F
 lda    $34
 sbc    $41
 sta    $34
 lda    $33
 sbc    $40
 sta    $33
 lda    $32
 sbc    $3F
 sta    $32
 lda    $31
 sbc    $3E
 sta    $31
 sec
 rol    $46
 rol    $45
 rol    $44
 rol    $43
 asl    $34
 rol    $33
 rol    $32
 rol    $31
 dex
 bne    $A70C
 ldx    #$07
 bcs    $A76E
 lda    $31
 cmp    $3E
 bne    $A76C
 lda    $32
 cmp    $3F
 bne    $A76C
 lda    $33
 cmp    $40
 bne    $A76C
 lda    $34
 cmp    $41
 bcc    $A787
 lda    $34
 sbc    $41
 sta    $34
 lda    $33
 sbc    $40
 sta    $33
 lda    $32
 sbc    $3F
 sta    $32
 lda    $31
 sbc    $3E
 sta    $31
 sec
 rol    $35
 asl    $34
 rol    $33
 rol    $32
 rol    $31
 dex
 bne    $A754
 asl    $35
 lda    $46
 sta    $34
 lda    $45
 sta    $33
 lda    $44
 sta    $32
 lda    $43
 sta    $31
 jmp    $A659
 brk
 ora    $2D,x
 ror    $65,x
 jsr    $6F72
 .byte  'o'
 .byte  't'
 brk
 jsr    L92FA
 jsr    $A1DA
 beq    $A7E6
 bmi    $A7A9
 jsr    $A385
 lda    $30
 lsr    a
 adc    #$40
 sta    $30
 lda    #$05
 sta    $4A
 jsr    $A7ED
 jsr    $A38D
 lda    #$6C
 sta    $4B
 jsr    $A6AD
 lda    #$71
 sta    $4B
 jsr    $A500
 dec    $30
 dec    $4A
 bne    $A7CF
 lda    #$FF
 rts
 lda    #$7B
 bne    $A7F7
 lda    #$71
 bne    $A7F7
 lda    #$76
 bne    $A7F7
 lda    #$6C
 sta    $4B
 lda    #$04
 sta    $4C
 rts
 jsr    L92FA
 jsr    $A1DA
 beq    $A808
 bpl    $A814
 brk
 asl    $4C,x
 .byte  'o'
 .byte  'g'
 jsr    $6172
 ror    $6567
 brk
 jsr    $A453
 ldy    #$80
 sty    $3B
 sty    $3E
 iny
 sty    $3D
 ldx    $30
 beq    $A82A
 lda    $31
 cmp    #$B5
 bcc    $A82C
 inx
 dey
 txa
 pha
 sty    $30
 jsr    $A505
 lda    #$7B
 jsr    $A387
 lda    #$73
 ldy    #$A8
 jsr    $A897
 jsr    $A7E9
 jsr    $A656
 jsr    $A656
 jsr    $A500
 jsr    $A385
 pla
 sec
 sbc    #$81
 jsr    $A2ED
 lda    #$6E
 sta    $4B
 lda    #$A8
 sta    $4C
 jsr    $A656
 jsr    $A7F5
 jsr    $A500
 lda    #$FF
 rts
 .byte  $7F
 lsr    $D85B,x
 tax
 .byte  $80
 and    ($72),y
 .byte  $17
 sed
 asl    $7A
 .byte  $12
 sec
 lda    $0B
 dey
 adc    $9F0E,y
 .byte  $F3
 .byte  '|'
 rol    a
 ldy    $B53F
 stx    $34
 ora    ($A2,x)
 .byte  'z'
 .byte  $7F
 .byte  'c'
 stx    $EC37
 .byte  $82
 .byte  $3F
 .byte  $FF
 .byte  $FF
 cmp    ($7F,x)
 .byte  $FF
 .byte  $FF
 .byte  $FF
 .byte  $FF
 sta    $4D
 sty    $4E
 jsr    $A385
 ldy    #$00
 lda    ($4D),y
 sta    $48
 inc    $4D
 bne    $A8AA
 inc    $4E
 lda    $4D
 sta    $4B
 lda    $4E
 sta    $4C
 jsr    $A3B5
 jsr    $A7F5
 jsr    $A6AD
 clc
 lda    $4D
 adc    #$05
 sta    $4D
 sta    $4B
 lda    $4E
 adc    #$00
 sta    $4E
 sta    $4C
 jsr    $A500
 dec    $48
 bne    $A8B5
 rts
 jsr    $A8DA
 jmp    $A927
 jsr    L92FA
 jsr    $A1DA
 bpl    $A8EA
 lsr    $2E
 jsr    $A8EA
 jmp    $A916
 jsr    $A381
 jsr    $A9B1
 jsr    $A1DA
 beq    $A8FE
 jsr    $A7F1
 jsr    $A6AD
 jmp    $A90A
 jsr    $AA55
 jsr    $A3B5
 lda    #$FF
 rts
 jsr    L92FA
 jsr    $A1DA
 beq    $A904
 bpl    $A91B
 lsr    $2E
 jsr    $A91B
 lda    #$80
 sta    $2E
 rts
 lda    $30
 cmp    #$81
 bcc    $A936
 jsr    $A6A5
 jsr    $A936
 jsr    $AA48
 jsr    $A500
 jsr    $AA4C
 jsr    $A500
 jmp    $AD7E
 lda    $30
 cmp    #$73
 bcc    $A904
 jsr    $A381
 jsr    $A453
 lda    #$80
 sta    $3D
 sta    $3E
 sta    $3B
 jsr    $A505
 lda    #$5A
 ldy    #$A9
 jsr    $A897
 jsr    $AAD1
 lda    #$FF
 rts
 ora    #$85
 .byte  $A3
 eor    $67E8,y
 .byte  $80
 .byte  $1C
 sta    $3607,x
 .byte  $80
 .byte  'W'
 .byte  $BB
 sei
 .byte  $DF
 .byte  $80
 dex
 txs
 asl    $8483
 sty    $CABB
 ror    $9581
 stx    $06,y
 dec    $0A81,x
 .byte  $C7
 jmp    ($7F52)
 adc    $90AD,x
 lda    ($82,x)
 .byte  $FB
 .byte  'b'
 .byte  'W'
 .byte  $2F
 .byte  $80
 adc    $3863
 bit    $FA20
 .byte  $92
 jsr    $A9D3
 inc    $4A
 jmp    $A99E
 jsr    L92FA
 jsr    $A9D3
 lda    $4A
 and    #$02
 beq    $A9AA
 jsr    $A9AA
 jmp    $AD7E
 lsr    $4A
 bcc    $A9C3
 jsr    $A9C3
 jsr    $A385
 jsr    $A656
 jsr    $A38D
 jsr    $A699
 jsr    $A4D0
 jmp    $A7B7
 jsr    $A381
 jsr    $A656
 lda    #$72
 ldy    #$AA
 jsr    $A897
 jmp    $AAD1
 lda    $30
 cmp    #$98
 bcs    $AA38
 jsr    $A385
 jsr    $AA55
 jsr    $A34E
 lda    $2E
 sta    $3B
 dec    $3D
 jsr    $A505
 jsr    $A6E7
 jsr    $A3FE
 lda    $34
 sta    $4A
 ora    $33
 ora    $32
 ora    $31
 beq    $AA35
 lda    #$A0
 sta    $30
 ldy    #$00
 sty    $35
 lda    $31
 sta    $2E
 bpl    $AA0E
 jsr    $A46C
 jsr    $A303
 jsr    $A37D
 jsr    $AA48
 jsr    $A656
 jsr    $A7F5
 jsr    $A500
 jsr    $A38D
 jsr    $A7ED
 jsr    $A3B5
 jsr    $AA4C
 jsr    $A656
 jsr    $A7F5
 jmp    $A500
 jmp    $A3B2
 brk
 .byte  $17
 eor    ($63,x)
 .byte  'c'
 adc    $72,x
 adc    ($63,x)
 adc    $6C20,y
 .byte  'o'
 .byte  's'
 .byte  't'
 brk
 lda    #$59
 bne    $AA4E
 lda    #$5E
 sta    $4B
 lda    #$AA
 sta    $4C
 rts
 lda    #$63
 bne    $AA4E
 sta    ($C9,x)
 bpl    $AA5D
 brk
 .byte  'o'
 ora    $77,x
 .byte  'z'
 adc    ($81,x)
 eor    #$0F
 .byte  $DA
 ldx    #$7B
 asl    $35FA
 .byte  $12
 stx    $65
 rol    $D3E0
 ora    $84
 txa
 nop
 .byte  $0C
 .byte  $1B
 sty    $1A
 ldx    $2BBB,y
 sty    $37
 eor    $55
 .byte  $AB
 .byte  $82
 cmp    $55,x
 .byte  'W'
 .byte  '|'
 .byte  $83
 cpy    #$00
 brk
 ora    $81
 brk
 brk
 brk
 brk
 jsr    L92FA
 lda    $30
 cmp    #$87
 bcc    $AAB8
 bne    $AAA2
 ldy    $31
 cpy    #$B3
 bcc    $AAB8
 lda    $2E
 bpl    $AAAC
 jsr    $A686
 lda    #$FF
 rts
 brk
 clc
 eor    $78
 bvs    $AAD2
 .byte  'r'
 adc    ($6E,x)
 .byte  'g'
 adc    $00
 jsr    $A486
 jsr    $AADA
 jsr    $A381
 lda    #$E4
 sta    $4B
 lda    #$AA
 sta    $4C
 jsr    $A3B5
 lda    $4A
 jsr    $AB12
 jsr    $A7F1
 jsr    $A656
 lda    #$FF
 rts
 lda    #$E9
 ldy    #$AA
 jsr    $A897
 lda    #$FF
 rts
 .byte  $82
 and    $54F8
 cli
 .byte  $07
 .byte  $83
 cpx    #$20
 stx    $5B
 .byte  $82
 .byte  $80
 .byte  'S'
 .byte  $93
 clv
 .byte  $83
 jsr    $0600
 lda    ($82,x)
 brk
 brk
 and    ($63,x)
 .byte  $82
 cpy    #$00
 brk
 .byte  $02
 .byte  $82
 .byte  $80
 brk
 brk
 .byte  $0C
 sta    ($00,x)
 brk
 brk
 brk
 sta    ($00,x)
 brk
 brk
 brk
 tax
 bpl    $AB1E
 dex
 txa
 eor    #$FF
 pha
 jsr    $A6A5
 pla
 pha
 jsr    $A385
 jsr    $A699
 pla
 beq    $AB32
 sec
 sbc    #$01
 pha
 jsr    $A656
 jmp    $AB25
 rts
 jsr    L92E3
 ldx    $2A
 lda    #$80
 jsr    OSBYTE
 txa
 jmp    $AEEA
 jsr    L92DD
 jsr    $BD94
 jsr    L8AAE
 jsr    $AE56
 jsr    L92F0
 lda    $2A
 pha
 lda    $2B
 pha
 jsr    $BDEA
 pla
 sta    $2D
 pla
 sta    $2C
 ldx    #$2A
 lda    #$09
 jsr    OSWORD
 lda    $2E
 bmi    $AB9D
 jmp    $AED8
 lda    #$86
 jsr    OSBYTE
 txa
 jmp    $AED8
 lda    #$86
 jsr    OSBYTE
 tya
 jmp    $AED8
 jsr    $A1DA
 beq    $ABA2
 bpl    $ABA0
 bmi    $AB9D
 jsr    $ADEC
 beq    $ABE6
 bmi    $AB7F
 lda    $2D
 ora    $2C
 ora    $2B
 ora    $2A
 beq    $ABA5
 lda    $2D
 bpl    $ABA0
 jmp    $ACC4
 lda    #$01
 jmp    $AED8
 lda    #$40
 rts
 jsr    $A7FE
 ldy    #$69
 lda    #$A8
 bne    $ABB8
 jsr    L92FA
 ldy    #$68
 lda    #$AA
 sty    $4B
 sta    $4C
 jsr    $A656
 lda    #$FF
 rts
 jsr    L92FA
 ldy    #$6D
 lda    #$AA
 bne    $ABB8
 jsr    $A8FE
 inc    $30
 tay
 rts
 jsr    L92E3
 jsr    L8F1E
 sta    $2A
 stx    $2B
 sty    $2C
 php
 pla
 sta    $2D
 cld
 lda    #$40
 rts
 jmp    L8C0E
 jsr    $ADEC
 bne    $ABE6
 inc    $36
 ldy    $36
 lda    #$0D
 sta    $05FF,y
 jsr    $BDB2
 lda    $19
 pha
 lda    $1A
 pha
 lda    $1B
 pha
 ldy    $04
 ldx    $05
 iny
 sty    $19
 sty    $37
 bne    $AC0F
 inx
 stx    $1A
 stx    $38
 ldy    #$FF
 sty    $3B
 iny
 sty    $1B
 jsr    L8955
 jsr    L9B29
 jsr    $BDDC
 pla
 sta    $1B
 pla
 sta    $1A
 pla
 sta    $19
 lda    $27
 rts
 jsr    $ADEC
 bne    $AC9B
 ldy    $36
 lda    #$00
 sta    $0600,y
 lda    $19
 pha
 lda    $1A
 pha
 lda    $1B
 pha
 lda    #$00
 sta    $1B
 lda    #$00
 sta    $19
 lda    #$06
 sta    $1A
 jsr    L8A8C
 cmp    #$2D
 beq    $AC66
 cmp    #$2B
 bne    $AC5E
 jsr    L8A8C
 dec    $1B
 jsr    $A07B
 jmp    $AC73
 jsr    L8A8C
 dec    $1B
 jsr    $A07B
 bcc    $AC73
 jsr    $AD8F
 sta    $27
 jmp    $AC23
 jsr    $ADEC
 beq    $AC9B
 bpl    $AC9A
 lda    $2E
 php
 jsr    $A3FE
 plp
 bpl    $AC95
 lda    $3E
 ora    $3F
 ora    $40
 ora    $41
 beq    $AC95
 jsr    $A4C7
 jsr    $A3E7
 lda    #$40
 rts
 jmp    L8C0E
 jsr    $ADEC
 bne    $AC9B
 lda    $36
 beq    $ACC4
 lda    $0600
 jmp    $AED8
 jsr    $AFAD
 cpy    #$00
 bne    $ACC4
 txa
 jmp    $AEEA
 jsr    $BFB5
 tax
 lda    #$7F
 jsr    OSBYTE
 txa
 beq    $ACAA
 lda    #$FF
 sta    $2A
 sta    $2B
 sta    $2C
 sta    $2D
 lda    #$40
 rts
 jsr    L92E3
 ldx    #$03
 lda    $2A,x
 eor    #$FF
 sta    $2A,x
 dex
 bpl    $ACD6
 lda    #$40
 rts
 jsr    L9B29
 bne    $AC9B
 cpx    #$2C
 bne    $AD03
 inc    $1B
 jsr    $BDB2
 jsr    L9B29
 bne    $AC9B
 lda    #$01
 sta    $2A
 inc    $1B
 cpx    #$29
 beq    $AD12
 cpx    #$2C
 beq    $AD06
 jmp    L8AA2
 jsr    $BDB2
 jsr    $AE56
 jsr    L92F0
 jsr    $BDCB
 ldy    #$00
 ldx    $2A
 bne    $AD1A
 ldx    #$01
 stx    $2A
 txa
 dex
 stx    $2D
 clc
 adc    $04
 sta    $37
 tya
 adc    $05
 sta    $38
 lda    ($04),y
 sec
 sbc    $2D
 bcc    $AD52
 sbc    $36
 bcc    $AD52
 adc    #$00
 sta    $2B
 jsr    $BDDC
 ldy    #$00
 ldx    $36
 beq    $AD4D
 lda    ($37),y
 cmp    $0600,y
 bne    $AD59
 iny
 dex
 bne    $AD42
 lda    $2A
 jmp    $AED8
 jsr    $BDDC
 lda    #$00
 beq    $AD4F
 inc    $2A
 dec    $2B
 beq    $AD55
 inc    $37
 bne    $AD3C
 inc    $38
 bne    $AD3C
 jmp    L8C0E
 jsr    $ADEC
 beq    $AD67
 bmi    $AD77
 bit    $2D
 bmi    $AD93
 bpl    $ADAA
 jsr    $A1DA
 bpl    $AD89
 bmi    $AD83
 jsr    $A1DA
 beq    $AD89
 lda    $2E
 eor    #$80
 sta    $2E
 lda    #$FF
 rts
 jsr    $AE02
 beq    $AD67
 bmi    $AD7E
 sec
 lda    #$00
 tay
 sbc    $2A
 sta    $2A
 tya
 sbc    $2B
 sta    $2B
 tya
 sbc    $2C
 sta    $2C
 tya
 sbc    $2D
 sta    $2D
 lda    #$40
 rts
 jsr    L8A8C
 cmp    #$22
 beq    $ADC9
 ldx    #$00
 lda    ($19),y
 sta    $0600,x
 iny
 inx
 cmp    #$0D
 beq    $ADC5
 cmp    #$2C
 bne    $ADB6
 dey
 jmp    $ADE1
 ldx    #$00
 iny
 lda    ($19),y
 cmp    #$0D
 beq    $ADE9
 iny
 sta    $0600,x
 inx
 cmp    #$22
 bne    $ADCC
 lda    ($19),y
 cmp    #$22
 beq    $ADCB
 dex
 stx    $36
 sty    $1B
 lda    #$00
 rts
 jmp    L8E98
 ldy    $1B
 inc    $1B
 lda    ($19),y
 cmp    #$20
 beq    $ADEC
 cmp    #$2D
 beq    $AD8C
 cmp    #$22
 beq    $ADC9
 cmp    #$2B
 bne    $AE05
 jsr    L8A8C
 cmp    #$8E
 bcc    $AE10
 cmp    #$C6
 bcs    $AE43
 jmp    L8BB1
 cmp    #$3F
 bcs    $AE20
 cmp    #$2E
 bcs    $AE2A
 cmp    #$26
 beq    $AE6D
 cmp    #$28
 beq    $AE56
 dec    $1B
 jsr    L95DD
 beq    $AE30
 jmp    $B32C
 jsr    $A07B
 bcc    $AE43
 rts
 lda    $28
 and    #$02
 bne    $AE43
 bcs    $AE43
 stx    $1B
 lda    $0440
 ldy    $0441
 jmp    $AEEA
 brk
 .byte  $1A
 lsr    $206F
 .byte  's'
 adc    $63,x
 pla
 jsr    $6176
 .byte  'r'
 adc    #$61
 .byte  'b'
 jmp    ($0065)
 jsr    L9B29
 inc    $1B
 cpx    #$29
 bne    $AE61
 tay
 rts
 brk
 .byte  $1B
 eor    $7369
 .byte  's'
 adc    #$6E
 .byte  'g'
 jsr    $0029
 ldx    #$00
 stx    $2A
 stx    $2B
 stx    $2C
 stx    $2D
 ldy    $1B
 lda    ($19),y
 cmp    #$30
 bcc    $AEA2
 cmp    #$3A
 bcc    $AE8D
 sbc    #$37
 cmp    #$0A
 bcc    $AEA2
 cmp    #$10
 bcs    $AEA2
 asl    a
 asl    a
 asl    a
 asl    a
 ldx    #$03
 asl    a
 rol    $2A
 rol    $2B
 rol    $2C
 rol    $2D
 dex
 bpl    $AE93
 iny
 bne    $AE79
 txa
 bpl    $AEAA
 sty    $1B
 lda    #$40
 rts
 brk
 .byte  $1C
 .byte  'B'
 adc    ($64,x)
 jsr    $4548
 cli
 brk
 ldx    #$2A
 ldy    #$00
 lda    #$01
 jsr    OSWORD
 lda    #$40
 rts
 lda    #$00
 ldy    $18
 jmp    $AEEA
 jmp    $AE43
 lda    #$00
 beq    $AED8
 jmp    L8C0E
 jsr    $ADEC
 bne    $AECE
 lda    $36
 ldy    #$00
 beq    $AEEA
 ldy    $1B
 lda    ($19),y
 cmp    #$50
 bne    $AEC7
 inc    $1B
 lda    $12
 ldy    $13
 sta    $2A
 sty    $2B
 lda    #$00
 sta    $2C
 sta    $2D
 lda    #$40
 rts
 lda    $1E
 jmp    $AED8
 lda    $00
 ldy    $01
 jmp    $AEEA
 lda    $06
 ldy    $07
 jmp    $AEEA
 inc    $1B
 jsr    $AE56
 jsr    L92F0
 lda    $2D
 bmi    $AF3F
 ora    $2C
 ora    $2B
 bne    $AF24
 lda    $2A
 beq    $AF6C
 cmp    #$01
 beq    $AF69
 jsr    $A2BE
 jsr    $BD51
 jsr    $AF69
 jsr    $BD7E
 jsr    $A606
 jsr    $A303
 jsr    $A3E4
 jsr    L9222
 lda    #$40
 rts
 ldx    #$0D
 jsr    $BE44
 lda    #$40
 sta    $11
 rts
 ldy    $1B
 lda    ($19),y
 cmp    #$28
 beq    $AF0A
 jsr    $AF87
 ldx    #$0D
 lda    $00,x
 sta    $2A
 lda    $01,x
 sta    $2B
 lda    $02,x
 sta    $2C
 lda    $03,x
 sta    $2D
 lda    #$40
 rts
 jsr    $AF87
 ldx    #$00
 stx    $2E
 stx    $2F
 stx    $35
 lda    #$80
 sta    $30
 lda    $0D,x
 sta    $31,x
 inx
 cpx    #$04
 bne    $AF78
 jsr    $A659
 lda    #$FF
 rts
 ldy    #$20
 lda    $0F
 lsr    a
 lsr    a
 lsr    a
 eor    $11
 ror    a
 rol    $0D
 rol    $0E
 rol    $0F
 rol    $10
 rol    $11
 dey
 bne    $AF89
 rts
 ldy    $09
 lda    $08
 jmp    $AEEA
 ldy    #$00
 lda    ($FD),y
 jmp    $AEEA
 jsr    L92E3
 lda    #$81
 ldx    $2A
 ldy    $2B
 jmp    OSBYTE
 jsr    OSRDCH
 jmp    $AED8
 jsr    OSRDCH
 sta    $0600
 lda    #$01
 sta    $36
 lda    #$00
 rts
 jsr    L9B29
 bne    $B033
 cpx    #$2C
 bne    $B036
 inc    $1B
 jsr    $BDB2
 jsr    $AE56
 jsr    L92F0
 jsr    $BDCB
 lda    $2A
 cmp    $36
 bcs    $AFEB
 sta    $36
 lda    #$00
 rts
 jsr    L9B29
 bne    $B033
 cpx    #$2C
 bne    $B036
 inc    $1B
 jsr    $BDB2
 jsr    $AE56
 jsr    L92F0
 jsr    $BDCB
 lda    $36
 sec
 sbc    $2A
 bcc    $B023
 beq    $B025
 tax
 lda    $2A
 sta    $36
 beq    $B025
 ldy    #$00
 lda    $0600,x
 sta    $0600,y
 inx
 iny
 dec    $2A
 bne    $B017
 lda    #$00
 rts
 jsr    $AFAD
 txa
 cpy    #$00
 beq    $AFC2
 lda    #$00
 sta    $36
 rts
 jmp    L8C0E
 jmp    L8AA2
 jsr    L9B29
 bne    $B033
 cpx    #$2C
 bne    $B036
 jsr    $BDB2
 inc    $1B
 jsr    L92DD
 lda    $2A
 pha
 lda    #$FF
 sta    $2A
 inc    $1B
 cpx    #$29
 beq    $B061
 cpx    #$2C
 bne    $B036
 jsr    $AE56
 jsr    L92F0
 jsr    $BDCB
 pla
 tay
 clc
 beq    $B06F
 sbc    $36
 bcs    $B02E
 dey
 tya
 sta    $2C
 tax
 ldy    #$00
 lda    $36
 sec
 sbc    $2C
 cmp    $2A
 bcs    $B07F
 sta    $2A
 lda    $2A
 beq    $B02E
 lda    $0600,x
 sta    $0600,y
 iny
 inx
 cpy    $2A
 bne    $B083
 sty    $36
 lda    #$00
 rts
 jsr    L8A8C
 ldy    #$FF
 cmp    #$7E
 beq    $B0A1
 ldy    #$00
 dec    $1B
 tya
 pha
 jsr    $ADEC
 beq    $B0BF
 tay
 pla
 sta    $15
 lda    $0403
 bne    $B0B9
 sta    $37
 jsr    L9EF9
 lda    #$00
 rts
 jsr    L9EDF
 lda    #$00
 rts
 jmp    L8C0E
 jsr    L92DD
 jsr    $BD94
 jsr    L8AAE
 jsr    $AE56
 bne    $B0BF
 jsr    $BDEA
 ldy    $36
 beq    $B0F5
 lda    $2A
 beq    $B0F8
 dec    $2A
 beq    $B0F5
 ldx    #$00
 lda    $0600,x
 sta    $0600,y
 inx
 iny
 beq    $B0FB
 cpx    $36
 bcc    $B0E1
 dec    $2A
 bne    $B0DF
 sty    $36
 lda    #$00
 rts
 sta    $36
 rts
 jmp    L9C03
 pla
 sta    $0C
 pla
 sta    $0B
 brk
 ora    $6F4E,x
 jsr    $7573
 .byte  'c'
 pla
 jsr    $2FA4
 .byte  $F2
 brk
 lda    $18
 sta    $0C
 lda    #$00
 sta    $0B
 ldy    #$01
 lda    ($0B),y
 bmi    $B0FE
 ldy    #$03
 iny
 lda    ($0B),y
 cmp    #$20
 beq    $B122
 cmp    #$DD
 beq    $B13C
 ldy    #$03
 lda    ($0B),y
 clc
 adc    $0B
 sta    $0B
 bcc    $B11A
 inc    $0C
 bcs    $B11A
 iny
 sty    $0A
 jsr    L8A97
 tya
 tax
 clc
 adc    $0B
 ldy    $0C
 bcc    $B14D
 iny
 clc
 sbc    #$00
 sta    $3C
 tya
 sbc    #$00
 sta    $3D
 ldy    #$00
 iny
 inx
 lda    ($3C),y
 cmp    ($37),y
 bne    $B12D
 cpy    $39
 bne    $B158
 iny
 lda    ($3C),y
 jsr    L8926
 bcs    $B12D
 txa
 tay
 jsr    L986D
 jsr    L94ED
 ldx    #$01
 jsr    L9531
 ldy    #$00
 lda    $0B
 sta    ($02),y
 iny
 lda    $0C
 sta    ($02),y
 jsr    L9539
 jmp    $B1F4
 brk
 asl    $6142,x
 .byte  'd'
 jsr    $6163
 jmp    ($006C)
 lda    #$A4
 sta    $27
 tsx
 txa
 clc
 adc    $04
 jsr    $BE2E
 ldy    #$00
 txa
 sta    ($04),y
 inx
 iny
 lda    $0100,x
 sta    ($04),y
 cpx    #$FF
 bne    $B1A6
 txs
 lda    $27
 pha
 lda    $0A
 pha
 lda    $0B
 pha
 lda    $0C
 pha
 lda    $1B
 tax
 clc
 adc    $19
 ldy    $1A
 bcc    $B1CA
 iny
 clc
 sbc    #$01
 sta    $37
 tya
 sbc    #$00
 sta    $38
 ldy    #$02
 jsr    L955B
 cpy    #$02
 beq    $B18A
 stx    $1B
 dey
 sty    $39
 jsr    L945B
 bne    $B1E9
 jmp    $B112
 ldy    #$00
 lda    ($2A),y
 sta    $0B
 iny
 lda    ($2A),y
 sta    $0C
 lda    #$00
 pha
 sta    $0A
 jsr    L8A97
 cmp    #$28
 beq    $B24D
 dec    $0A
 lda    $1B
 pha
 lda    $19
 pha
 lda    $1A
 pha
 jsr    L8BA3
 pla
 sta    $1A
 pla
 sta    $19
 pla
 sta    $1B
 pla
 beq    $B226
 sta    $3F
 jsr    $BE0B
 jsr    L8CC1
 dec    $3F
 bne    $B21C
 pla
 sta    $0C
 pla
 sta    $0B
 pla
 sta    $0A
 pla
 ldy    #$00
 lda    ($04),y
 tax
 txs
 iny
 inx
 lda    ($04),y
 sta    $0100,x
 cpx    #$FF
 bne    $B236
 tya
 adc    $04
 sta    $04
 bcc    $B24A
 inc    $05
 lda    $27
 rts
 lda    $1B
 pha
 lda    $19
 pha
 lda    $1A
 pha
 jsr    L9582
 beq    $B2B5
 lda    $1B
 sta    $0A
 pla
 sta    $1A
 pla
 sta    $19
 pla
 sta    $1B
 pla
 tax
 lda    $2C
 pha
 lda    $2B
 pha
 lda    $2A
 pha
 inx
 txa
 pha
 jsr    $B30D
 jsr    L8A97
 cmp    #$2C
 beq    $B24D
 cmp    #$29
 bne    $B2B5
 lda    #$00
 pha
 jsr    L8A8C
 cmp    #$28
 bne    $B2B5
 jsr    L9B29
 jsr    $BD90
 lda    $27
 sta    $2D
 jsr    $BD94
 pla
 tax
 inx
 txa
 pha
 jsr    L8A8C
 cmp    #$2C
 beq    $B28E
 cmp    #$29
 bne    $B2B5
 pla
 pla
 sta    $4D
 sta    $4E
 cpx    $4D
 beq    $B2CA
 ldx    #$FB
 txs
 pla
 sta    $0C
 pla
 sta    $0B
 brk
 .byte  $1F
 eor    ($72,x)
 .byte  'g'
 adc    $6D,x
 adc    $6E
 .byte  't'
 .byte  's'
 brk
 jsr    $BDEA
 pla
 sta    $2A
 pla
 sta    $2B
 pla
 sta    $2C
 bmi    $B2F9
 lda    $2D
 beq    $B2B5
 sta    $27
 ldx    #$37
 jsr    $BE44
 lda    $27
 bpl    $B2F0
 jsr    $BD7E
 jsr    $A3B5
 jmp    $B2F3
 jsr    $BDEA
 jsr    $B4B7
 jmp    $B303
 lda    $2D
 bne    $B2B5
 jsr    $BDCB
 jsr    L8C21
 dec    $4D
 bne    $B2CA
 lda    $4E
 pha
 jmp    $B202
 ldy    $2C
 cpy    #$04
 bne    $B318
 ldx    #$37
 jsr    $BE44
 jsr    $B32C
 php
 jsr    $BD90
 plp
 beq    $B329
 bmi    $B329
 ldx    #$37
 jsr    $AF56
 jmp    $BD94
 ldy    $2C
 bmi    $B384
 beq    $B34F
 cpy    #$05
 beq    $B354
 ldy    #$03
 lda    ($2A),y
 sta    $2D
 dey
 lda    ($2A),y
 sta    $2C
 dey
 lda    ($2A),y
 tax
 dey
 lda    ($2A),y
 sta    $2A
 stx    $2B
 lda    #$40
 rts
 lda    ($2A),y
 jmp    $AEEA
 dey
 lda    ($2A),y
 sta    $34
 dey
 lda    ($2A),y
 sta    $33
 dey
 lda    ($2A),y
 sta    $32
 dey
 lda    ($2A),y
 sta    $2E
 dey
 lda    ($2A),y
 sta    $30
 sty    $35
 sty    $2F
 ora    $2E
 ora    $32
 ora    $33
 ora    $34
 beq    $B37F
 lda    $2E
 ora    #$80
 sta    $31
 lda    #$FF
 rts
 cpy    #$80
 beq    $B3A7
 ldy    #$03
 lda    ($2A),y
 sta    $36
 beq    $B3A6
 ldy    #$01
 lda    ($2A),y
 sta    $38
 dey
 lda    ($2A),y
 sta    $37
 ldy    $36
 dey
 lda    ($37),y
 sta    $0600,y
 tya
 bne    $B39D
 rts
 lda    $2B
 beq    $B3C0
 ldy    #$00
 lda    ($2A),y
 sta    $0600,y
 eor    #$0D
 beq    $B3BA
 iny
 bne    $B3AD
 tya
 sty    $36
 rts
 jsr    L92E3
 lda    $2A
 jmp    $AFC2
 ldy    #$00
 sty    $08
 sty    $09
 ldx    $18
 stx    $38
 sty    $37
 ldx    $0C
 cpx    #$07
 beq    $B401
 ldx    $0B
 jsr    L8942
 cmp    #$0D
 bne    $B3F9
 cpx    $37
 lda    $0C
 sbc    $38
 bcc    $B401
 jsr    L8942
 ora    #$00
 bmi    $B401
 sta    $09
 jsr    L8942
 sta    $08
 jsr    L8942
 cpx    $37
 lda    $0C
 sbc    $38
 bcs    $B3D9
 rts
 jsr    $B3C5
 sty    $20
 lda    ($FD),y
 bne    $B413
 lda    #$33
 sta    $16
 lda    #$B4
 sta    $17
 lda    $16
 sta    $0B
 lda    $17
 sta    $0C
 jsr    $BD3A
 tax
 stx    $0A
 lda    #$DA
 jsr    OSBYTE
 lda    #$7E
 jsr    OSBYTE
 ldx    #$FF
 stx    $28
 txs
 jmp    L8BA3
 inc    $3A,x
 .byte  $E7
 .byte  $9E
 sbc    ($22),y
 jsr    $7461
 jsr    $696C
 ror    $2065
 .byte  $22
 .byte  $3B
 .byte  $9E
 .byte  $3A
 cpx    #$8B
 sbc    ($3A),y
 cpx    #$0D
 jsr    L8821
 ldx    #$03
 lda    $2A
 pha
 lda    $2B
 pha
 txa
 pha
 jsr    L92DA
 pla
 tax
 dex
 bne    $B451
 jsr    L9852
 lda    $2A
 sta    $3D
 lda    $2B
 sta    $3E
 ldy    #$07
 ldx    #$05
 bne    $B48F
 jsr    L8821
 ldx    #$0D
 lda    $2A
 pha
 txa
 pha
 jsr    L92DA
 pla
 tax
 dex
 bne    $B477
 jsr    L9852
 lda    $2A
 sta    $44
 ldx    #$0C
 ldy    #$08
 pla
 sta    $37,x
 dex
 bpl    $B48F
 tya
 ldx    #$37
 ldy    #$00
 jsr    OSWORD
 jmp    L8B9B
 jsr    L8821
 jsr    L9852
 ldy    $2A
 dey
 sty    $23
 jmp    L8B9B
 jmp    L8C0E
 jsr    L9B29
 jsr    $BE0B
 lda    $39
 cmp    #$05
 beq    $B4E0
 lda    $27
 beq    $B4AE
 bpl    $B4C6
 jsr    $A3E4
 ldy    #$00
 lda    $2A
 sta    ($37),y
 lda    $39
 beq    $B4DF
 lda    $2B
 iny
 sta    ($37),y
 lda    $2C
 iny
 sta    ($37),y
 lda    $2D
 iny
 sta    ($37),y
 rts
 lda    $27
 beq    $B4AE
 bmi    $B4E9
 jsr    $A2BE
 ldy    #$00
 lda    $30
 sta    ($37),y
 iny
 lda    $2E
 and    #$80
 sta    $2E
 lda    $31
 and    #$7F
 ora    $2E
 sta    ($37),y
 iny
 lda    $32
 sta    ($37),y
 iny
 lda    $33
 sta    ($37),y
 iny
 lda    $34
 sta    ($37),y
 rts
 sta    $37
 cmp    #$80
 bcc    $B558
 lda    #$71
 sta    $38
 lda    #$80
 sta    $39
 sty    $3A
 ldy    #$00
 iny
 lda    ($38),y
 bpl    $B520
 cmp    $37
 beq    $B536
 iny
 tya
 sec
 adc    $38
 sta    $38
 bcc    $B51E
 inc    $39
 bcs    $B51E
 ldy    #$00
 lda    ($38),y
 bmi    $B542
 jsr    $B558
 iny
 bne    $B538
 ldy    $3A
 rts
 pha
 lsr    a
 lsr    a
 lsr    a
 lsr    a
 jsr    $B550
 pla
 and    #$0F
 cmp    #$0A
 bcc    $B556
 adc    #$06
 adc    #$30
 cmp    #$0D
 bne    $B567
 jsr    OSWRCH
 jmp    $BC28
 jsr    $B545
 lda    #$20
 pha
 lda    $23
 cmp    $1E
 bcs    $B571
 jsr    $BC25
 pla
 inc    $1E
 jmp    (WRCHV)
 and    $1F
 beq    $B589
 txa
 beq    $B589
 bmi    $B565
 jsr    $B565
 jsr    $B558
 dex
 bne    $B580
 rts
 inc    $0A
 jsr    L9B1D
 jsr    L984C
 jsr    L92EE
 lda    $2A
 sta    $1F
 jmp    L8AF6
 iny
 lda    ($0B),y
 cmp    #$4F
 beq    $B58A
 lda    #$00
 sta    $3B
 sta    $3C
 jsr    $AED8
 jsr    L97DF
 php
 jsr    $BD94
 lda    #$FF
 sta    $2A
 lda    #$7F
 sta    $2B
 plp
 bcc    $B5CF
 jsr    L8A97
 cmp    #$2C
 beq    $B5D8
 jsr    $BDEA
 jsr    $BD94
 dec    $0A
 bpl    $B5DB
 jsr    L8A97
 cmp    #$2C
 beq    $B5D8
 dec    $0A
 jsr    L97DF
 lda    $2A
 sta    $31
 lda    $2B
 sta    $32
 jsr    L9857
 jsr    $BE6F
 jsr    $BDEA
 jsr    L9970
 lda    $3D
 sta    $0B
 lda    $3E
 sta    $0C
 bcc    $B60F
 dey
 bcs    $B602
 jsr    $BC25
 jsr    L986D
 lda    ($0B),y
 sta    $2B
 iny
 lda    ($0B),y
 sta    $2A
 iny
 iny
 sty    $0A
 lda    $2A
 clc
 sbc    $31
 lda    $2B
 sbc    $32
 bcc    $B61D
 jmp    L8AF6
 jsr    L9923
 ldx    #$FF
 stx    $4D
 lda    #$01
 jsr    $B577
 ldx    $3B
 lda    #$02
 jsr    $B577
 ldx    $3C
 lda    #$04
 jsr    $B577
 ldy    $0A
 lda    ($0B),y
 cmp    #$0D
 beq    $B5FC
 cmp    #$22
 bne    $B651
 lda    #$FF
 eor    $4D
 sta    $4D
 lda    #$22
 jsr    $B558
 iny
 bne    $B639
 bit    $4D
 bpl    $B64B
 cmp    #$8D
 bne    $B668
 jsr    L97EB
 sty    $0A
 lda    #$00
 sta    $14
 jsr    L991F
 jmp    $B637
 cmp    #$E3
 bne    $B66E
 inc    $3B
 cmp    #$ED
 bne    $B678
 ldx    $3B
 beq    $B678
 dec    $3B
 cmp    #$F5
 bne    $B67E
 inc    $3C
 cmp    #$FD
 bne    $B688
 ldx    $3C
 beq    $B688
 dec    $3C
 jsr    $B50E
 iny
 bne    $B639
 brk
 jsr    $6F4E
 jsr    $00E3
 jsr    L95C9
 bne    $B6A3
 ldx    $26
 beq    $B68E
 bcs    $B6D7
 jmp    L982A
 bcs    $B6A0
 ldx    $26
 beq    $B68E
 lda    $2A
 cmp    $04F1,x
 bne    $B6BE
 lda    $2B
 cmp    $04F2,x
 bne    $B6BE
 lda    $2C
 cmp    $04F3,x
 beq    $B6D7
 txa
 sec
 sbc    #$0F
 tax
 stx    $26
 bne    $B6A9
 brk
 and    ($43,x)
 adc    ($6E,x)
 .byte  $27
 .byte  't'
 jsr    $614D
 .byte  't'
 .byte  'c'
 pla
 jsr    $00E3
 lda    $04F1,x
 sta    $2A
 lda    $04F2,x
 sta    $2B
 ldy    $04F3,x
 cpy    #$05
 beq    $B766
 ldy    #$00
 lda    ($2A),y
 adc    $04F4,x
 sta    ($2A),y
 sta    $37
 iny
 lda    ($2A),y
 adc    $04F5,x
 sta    ($2A),y
 sta    $38
 iny
 lda    ($2A),y
 adc    $04F6,x
 sta    ($2A),y
 sta    $39
 iny
 lda    ($2A),y
 adc    $04F7,x
 sta    ($2A),y
 tay
 lda    $37
 sec
 sbc    $04F9,x
 sta    $37
 lda    $38
 sbc    $04FA,x
 sta    $38
 lda    $39
 sbc    $04FB,x
 sta    $39
 tya
 sbc    $04FC,x
 ora    $37
 ora    $38
 ora    $39
 beq    $B741
 tya
 eor    $04F7,x
 eor    $04FC,x
 bpl    $B73F
 bcs    $B741
 bcc    $B751
 bcs    $B751
 ldy    $04FE,x
 lda    $04FF,x
 sty    $0B
 sta    $0C
 jsr    L9877
 jmp    L8BA3
 lda    $26
 sec
 sbc    #$0F
 sta    $26
 ldy    $1B
 sty    $0A
 jsr    L8A97
 cmp    #$2C
 bne    $B7A1
 jmp    $B695
 jsr    $B354
 lda    $26
 clc
 adc    #$F4
 sta    $4B
 lda    #$05
 sta    $4C
 jsr    $A500
 lda    $2A
 sta    $37
 lda    $2B
 sta    $38
 jsr    $B4E9
 lda    $26
 sta    $27
 clc
 adc    #$F9
 sta    $4B
 lda    #$05
 sta    $4C
 jsr    L9A5F
 beq    $B741
 lda    $04F5,x
 bmi    $B79D
 bcs    $B741
 bcc    $B751
 bcc    $B741
 bcs    $B751
 jmp    L8B96
 brk
 .byte  $22
 .byte  $E3
 jsr    $6176
 .byte  'r'
 adc    #$61
 .byte  'b'
 jmp    ($0065)
 .byte  $23
 .byte  'T'
 .byte  'o'
 .byte  'o'
 jsr    $616D
 ror    $2079
 .byte  $E3
 .byte  's'
 brk
 bit    $4E
 .byte  'o'
 jsr    $00B8
 jsr    L9582
 beq    $B7A4
 bcs    $B7A4
 jsr    $BD94
 jsr    L9841
 jsr    $B4B1
 ldy    $26
 cpy    #$96
 bcs    $B7B0
 lda    $37
 sta    $0500,y
 lda    $38
 sta    $0501,y
 lda    $39
 sta    $0502,y
 tax
 jsr    L8A8C
 cmp    #$B8
 bne    $B7BD
 cpx    #$05
 beq    $B84F
 jsr    L92DD
 ldy    $26
 lda    $2A
 sta    $0508,y
 lda    $2B
 sta    $0509,y
 lda    $2C
 sta    $050A,y
 lda    $2D
 sta    $050B,y
 lda    #$01
 jsr    $AED8
 jsr    L8A8C
 cmp    #$88
 bne    $B81F
 jsr    L92DD
 ldy    $1B
 sty    $0A
 ldy    $26
 lda    $2A
 sta    $0503,y
 lda    $2B
 sta    $0504,y
 lda    $2C
 sta    $0505,y
 lda    $2D
 sta    $0506,y
 jsr    L9880
 ldy    $26
 lda    $0B
 sta    $050D,y
 lda    $0C
 sta    $050E,y
 clc
 tya
 adc    #$0F
 sta    $26
 jmp    L8BA3
 jsr    L9B29
 jsr    L92FD
 lda    $26
 clc
 adc    #$08
 sta    $4B
 lda    #$05
 sta    $4C
 jsr    $A38D
 jsr    $A699
 jsr    L8A8C
 cmp    #$88
 bne    $B875
 jsr    L9B29
 jsr    L92FD
 ldy    $1B
 sty    $0A
 lda    $26
 clc
 adc    #$03
 sta    $4B
 lda    #$05
 sta    $4C
 jsr    $A38D
 jmp    $B837
 jsr    $B99A
 jsr    L9857
 ldy    $25
 cpy    #$1A
 bcs    $B8A2
 lda    $0B
 sta    $05CC,y
 lda    $0C
 sta    $05E6,y
 inc    $25
 bcc    $B8D2
 brk
 and    $54
 .byte  'o'
 .byte  'o'
 jsr    $616D
 ror    $2079
 cpx    $73
 brk
 rol    $4E
 .byte  'o'
 jsr    $00E4
 jsr    L9857
 ldx    $25
 beq    $B8AF
 dec    $25
 ldy    $05CB,x
 lda    $05E5,x
 sty    $0B
 sta    $0C
 jmp    L8B9B
 jsr    $B99A
 jsr    L9857
 lda    $20
 beq    $B8D9
 jsr    L9905
 ldy    $3D
 lda    $3E
 sty    $0B
 sta    $0C
 jmp    L8BA3
 jsr    L9857
 lda    #$33
 sta    $16
 lda    #$B4
 sta    $17
 jmp    L8B9B
 jsr    L8A97
 cmp    #$87
 beq    $B8E4
 ldy    $0A
 dey
 jsr    L986D
 lda    $0B
 sta    $16
 lda    $0C
 sta    $17
 jmp    L8B7D
 brk
 .byte  $27
 inc    $7320
 adc    $746E,y
 adc    ($78,x)
 brk
 jsr    L8A97
 cmp    #$85
 beq    $B8F2
 dec    $0A
 jsr    L9B1D
 jsr    L92F0
 ldy    $1B
 iny
 sty    $0A
 cpx    #$E5
 beq    $B931
 cpx    #$E4
 bne    $B90A
 txa
 pha
 lda    $2B
 ora    $2C
 ora    $2D
 bne    $B97D
 ldx    $2A
 beq    $B97D
 dex
 beq    $B95C
 ldy    $0A
 lda    ($0B),y
 iny
 cmp    #$0D
 beq    $B97D
 cmp    #$3A
 beq    $B97D
 cmp    #$8B
 beq    $B97D
 cmp    #$2C
 bne    $B944
 dex
 bne    $B944
 sty    $0A
 jsr    $B99A
 pla
 cmp    #$E4
 beq    $B96A
 jsr    L9877
 jmp    $B8D2
 ldy    $0A
 lda    ($0B),y
 iny
 cmp    #$0D
 beq    $B977
 cmp    #$3A
 bne    $B96C
 dey
 sty    $0A
 jmp    $B88B
 ldy    $0A
 pla
 lda    ($0B),y
 iny
 cmp    #$8B
 beq    $B995
 cmp    #$0D
 bne    $B980
 brk
 plp
 inc    $7220
 adc    ($6E,x)
 .byte  'g'
 adc    $00
 sty    $0A
 jmp    L98E3
 jsr    L97DF
 bcs    $B9AF
 jsr    L9B1D
 jsr    L92F0
 lda    $1B
 sta    $0A
 lda    $2B
 and    #$7F
 sta    $2B
 jsr    L9970
 bcs    $B9B5
 rts
 brk
 and    #$4E
 .byte  'o'
 jsr    $7573
 .byte  'c'
 pla
 jsr    $696C
 ror    a:$0065
 jmp    L8C0E
 jmp    L982A
 sty    $0A
 jmp    L8B98
 dec    $0A
 jsr    $BFA9
 lda    $1B
 sta    $0A
 sty    $4D
 jsr    L8A97
 cmp    #$2C
 bne    $B9CA
 lda    $4D
 pha
 jsr    L9582
 beq    $B9C7
 lda    $1B
 sta    $0A
 pla
 sta    $4D
 php
 jsr    $BD94
 ldy    $4D
 jsr    OSBGET
 sta    $27
 plp
 bcc    $BA19
 lda    $27
 bne    $B9C4
 jsr    OSBGET
 sta    $36
 tax
 beq    $BA13
 jsr    OSBGET
 sta    $05FF,x
 dex
 bne    $BA0A
 jsr    L8C1E
 jmp    $B9DA
 lda    $27
 beq    $B9C4
 bmi    $BA2B
 ldx    #$03
 jsr    OSBGET
 sta    $2A,x
 dex
 bpl    $BA21
 bmi    $BA39
 ldx    #$04
 jsr    OSBGET
 sta    $046C,x
 dex
 bpl    $BA2D
 jsr    $A3B2
 jsr    $B4B4
 jmp    $B9DA
 pla
 pla
 jmp    L8B98
 jsr    L8A97
 cmp    #$23
 beq    $B9CF
 cmp    #$86
 beq    $BA52
 dec    $0A
 clc
 ror    $4D
 lsr    $4D
 lda    #$FF
 sta    $4E
 jsr    L8E8A
 bcs    $BA69
 jsr    L8E8A
 bcc    $BA5F
 ldx    #$FF
 stx    $4E
 clc
 php
 asl    $4D
 plp
 ror    $4D
 cmp    #$2C
 beq    $BA5A
 cmp    #$3B
 beq    $BA5A
 dec    $0A
 lda    $4D
 pha
 lda    $4E
 pha
 jsr    L9582
 beq    $BA3F
 pla
 sta    $4E
 pla
 sta    $4D
 lda    $1B
 sta    $0A
 php
 bit    $4D
 bvs    $BA99
 lda    $4E
 cmp    #$FF
 bne    $BAB0
 bit    $4D
 bpl    $BAA2
 lda    #$3F
 jsr    $B558
 jsr    $BBFC
 sty    $36
 asl    $4D
 clc
 ror    $4D
 bit    $4D
 bvs    $BACD
 sta    $1B
 lda    #$00
 sta    $19
 lda    #$06
 sta    $1A
 jsr    $ADAD
 jsr    L8A8C
 cmp    #$2C
 beq    $BACA
 cmp    #$0D
 bne    $BABD
 ldy    #$FE
 iny
 sty    $4E
 plp
 bcs    $BADC
 jsr    $BD94
 jsr    $AC34
 jsr    $B4B4
 jmp    $BA5A
 lda    #$00
 sta    $27
 jsr    L8C21
 jmp    $BA5A
 ldy    #$00
 sty    $3D
 ldy    $18
 sty    $3E
 jsr    L8A97
 dec    $0A
 cmp    #$3A
 beq    $BB07
 cmp    #$0D
 beq    $BB07
 cmp    #$8B
 beq    $BB07
 jsr    $B99A
 ldy    #$01
 jsr    $BE55
 jsr    L9857
 lda    $3D
 sta    $1C
 lda    $3E
 sta    $1D
 jmp    L8B9B
 jsr    L8A97
 cmp    #$2C
 beq    $BB1F
 jmp    L8B96
 jsr    L9582
 beq    $BB15
 bcs    $BB32
 jsr    $BB50
 jsr    $BD94
 jsr    $B4B1
 jmp    $BB40
 jsr    $BB50
 jsr    $BD94
 jsr    $ADAD
 sta    $27
 jsr    L8C1E
 clc
 lda    $1B
 adc    $19
 sta    $1C
 lda    $1A
 adc    #$00
 sta    $1D
 jmp    $BB15
 lda    $1B
 sta    $0A
 lda    $1C
 sta    $19
 lda    $1D
 sta    $1A
 ldy    #$00
 sty    $1B
 jsr    L8A8C
 cmp    #$2C
 beq    $BBB0
 cmp    #$DC
 beq    $BBB0
 cmp    #$0D
 beq    $BB7A
 jsr    L8A8C
 cmp    #$2C
 beq    $BBB0
 cmp    #$0D
 bne    $BB6F
 ldy    $1B
 lda    ($19),y
 bmi    $BB9C
 iny
 iny
 lda    ($19),y
 tax
 iny
 lda    ($19),y
 cmp    #$20
 beq    $BB85
 cmp    #$DC
 beq    $BBAD
 txa
 clc
 adc    $19
 sta    $19
 bcc    $BB7A
 inc    $1A
 bcs    $BB7A
 brk
 rol    a
 .byte  'O'
 adc    $74,x
 jsr    $666F
 jsr    $00DC
 .byte  $2B
 lsr    $206F
 sbc    $00,x
 iny
 sty    $1B
 rts
 jsr    L9B1D
 jsr    L984C
 jsr    L92EE
 ldx    $24
 beq    $BBA6
 lda    $2A
 ora    $2B
 ora    $2C
 ora    $2D
 beq    $BBCD
 dec    $24
 jmp    L8B9B
 ldy    $05A3,x
 lda    $05B7,x
 jmp    $B8DD
 brk
 bit    $6F54
 .byte  'o'
 jsr    $616D
 ror    $2079
 sbc    $73,x
 brk
 ldx    $24
 cpx    #$14
 bcs    $BBD6
 jsr    L986D
 lda    $0B
 sta    $05A4,x
 lda    $0C
 sta    $05B8,x
 inc    $24
 jmp    L8BA3
 ldy    #$00
 lda    #$06
 bne    $BC09
 jsr    $B558
 ldy    #$00
 lda    #$07
 sty    $37
 sta    $38
 lda    #$EE
 sta    $39
 lda    #$20
 sta    $3A
 ldy    #$FF
 sty    $3B
 iny
 ldx    #$37
 tya
 jsr    OSWORD
 bcc    $BC28
 jmp    L9838
 jsr    OSNEWL
 lda    #$00
 sta    $1E
 rts
 jsr    L9970
 bcs    $BC80
 lda    $3D
 sbc    #$02
 sta    $37
 sta    $3D
 sta    $12
 lda    $3E
 sbc    #$00
 sta    $38
 sta    $13
 sta    $3E
 ldy    #$03
 lda    ($37),y
 clc
 adc    $37
 sta    $37
 bcc    $BC53
 inc    $38
 ldy    #$00
 lda    ($37),y
 sta    ($12),y
 cmp    #$0D
 beq    $BC66
 iny
 bne    $BC55
 inc    $38
 inc    $13
 bne    $BC55
 iny
 bne    $BC6D
 inc    $38
 inc    $13
 lda    ($37),y
 sta    ($12),y
 bmi    $BC7C
 jsr    $BC81
 jsr    $BC81
 jmp    $BC5D
 jsr    $BE92
 clc
 rts
 iny
 bne    $BC88
 inc    $13
 inc    $38
 lda    ($37),y
 sta    ($12),y
 rts
 sty    $3B
 jsr    $BC2D
 ldy    #$07
 sty    $3C
 ldy    #$00
 lda    #$0D
 cmp    ($3B),y
 beq    $BD10
 iny
 cmp    ($3B),y
 bne    $BC9E
 iny
 iny
 iny
 sty    $3F
 inc    $3F
 lda    $12
 sta    $39
 lda    $13
 sta    $3A
 jsr    $BE92
 sta    $37
 lda    $13
 sta    $38
 dey
 lda    $06
 cmp    $12
 lda    $07
 sbc    $13
 bcs    $BCD6
 jsr    $BE6F
 jsr    $BD20
 brk
 brk
 stx    $20
 .byte  's'
 bvs    $BD34
 .byte  'c'
 adc    $00
 lda    ($39),y
 sta    ($37),y
 tya
 bne    $BCE1
 dec    $3A
 dec    $38
 dey
 tya
 adc    $39
 ldx    $3A
 bcc    $BCEA
 inx
 cmp    $3D
 txa
 sbc    $3E
 bcs    $BCD6
 sec
 ldy    #$01
 lda    $2B
 sta    ($3D),y
 iny
 lda    $2A
 sta    ($3D),y
 iny
 lda    $3F
 sta    ($3D),y
 jsr    $BE56
 ldy    #$FF
 iny
 lda    ($3B),y
 sta    ($3D),y
 cmp    #$0D
 bne    $BD07
 rts
 jsr    L9857
 jsr    $BD20
 lda    $18
 sta    $0C
 stx    $0B
 jmp    L8B0B
 lda    $12
 sta    $00
 sta    $02
 lda    $13
 sta    $01
 sta    $03
 jsr    $BD3A
 ldx    #$80
 lda    #$00
 sta    $047F,x
 dex
 bne    $BD33
 rts
 lda    $18
 sta    $1D
 lda    $06
 sta    $04
 lda    $07
 sta    $05
 lda    #$00
 sta    $24
 sta    $26
 sta    $25
 sta    $1C
 rts
 lda    $04
 sec
 sbc    #$05
 jsr    $BE2E
 ldy    #$00
 lda    $30
 sta    ($04),y
 iny
 lda    $2E
 and    #$80
 sta    $2E
 lda    $31
 and    #$7F
 ora    $2E
 sta    ($04),y
 iny
 lda    $32
 sta    ($04),y
 iny
 lda    $33
 sta    ($04),y
 iny
 lda    $34
 sta    ($04),y
 rts
 lda    $04
 clc
 sta    $4B
 adc    #$05
 sta    $04
 lda    $05
 sta    $4C
 adc    #$00
 sta    $05
 rts
 beq    $BDB2
 bmi    $BD51
 lda    $04
 sec
 sbc    #$04
 jsr    $BE2E
 ldy    #$03
 lda    $2D
 sta    ($04),y
 dey
 lda    $2C
 sta    ($04),y
 dey
 lda    $2B
 sta    ($04),y
 dey
 lda    $2A
 sta    ($04),y
 rts
 clc
 lda    $04
 sbc    $36
 jsr    $BE2E
 ldy    $36
 beq    $BDC6
 lda    $05FF,y
 sta    ($04),y
 dey
 bne    $BDBE
 lda    $36
 sta    ($04),y
 rts
 ldy    #$00
 lda    ($04),y
 sta    $36
 beq    $BDDC
 tay
 lda    ($04),y
 sta    $05FF,y
 dey
 bne    $BDD4
 ldy    #$00
 lda    ($04),y
 sec
 adc    $04
 sta    $04
 bcc    $BE0A
 inc    $05
 rts
 ldy    #$03
 lda    ($04),y
 sta    $2D
 dey
 lda    ($04),y
 sta    $2C
 dey
 lda    ($04),y
 sta    $2B
 dey
 lda    ($04),y
 sta    $2A
 clc
 lda    $04
 adc    #$04
 sta    $04
 bcc    $BE0A
 inc    $05
 rts
 ldx    #$37
 ldy    #$03
 lda    ($04),y
 sta    $03,x
 dey
 lda    ($04),y
 sta    $02,x
 dey
 lda    ($04),y
 sta    $01,x
 dey
 lda    ($04),y
 sta    $00,x
 clc
 lda    $04
 adc    #$04
 sta    $04
 bcc    $BE0A
 inc    $05
 rts
 sta    $04
 bcs    $BE34
 dec    $05
 ldy    $05
 cpy    $03
 bcc    $BE41
 bne    $BE40
 cmp    $02
 bcc    $BE41
 rts
 jmp    L8CB7
 lda    $2A
 sta    $00,x
 lda    $2B
 sta    $01,x
 lda    $2C
 sta    $02,x
 lda    $2D
 sta    $03,x
 rts
 clc
 tya
 adc    $3D
 sta    $3D
 bcc    $BE5F
 inc    $3E
 ldy    #$01
 rts
 jsr    $BEDD
 tay
 lda    #$FF
 sty    $3D
 ldx    #$37
 jsr    OSFILE
 lda    $18
 sta    $13
 ldy    #$00
 sty    $12
 iny
 dey
 lda    ($12),y
 cmp    #$0D
 bne    $BE9E
 iny
 lda    ($12),y
 bmi    $BE90
 ldy    #$03
 lda    ($12),y
 beq    $BE9E
 clc
 jsr    $BE93
 bne    $BE78
 iny
 clc
 tya
 adc    $12
 sta    $12
 bcc    $BE9B
 inc    $13
 ldy    #$01
 rts
 jsr    $BFCF
 ora    $6142
 .byte  'd'
 jsr    $7270
 .byte  'o'
 .byte  'g'
 .byte  'r'
 adc    ($6D,x)
 ora    $4CEA
 inc    $8A,x
 lda    #$00
 sta    $37
 lda    #$06
 sta    $38
 ldy    $36
 lda    #$0D
 sta    $0600,y
 rts
 jsr    $BED2
 ldx    #$00
 ldy    #$06
 jsr    OS_CLI
 jmp    L8B9B
 jmp    L8C0E
 jsr    L9B1D
 bne    $BECF
 jsr    $BEB2
 jmp    L984C
 jsr    $BED2
 dey
 sty    $39
 lda    $18
 sta    $3A
 lda    #$82
 jsr    OSBYTE
 stx    $3B
 sty    $3C
 lda    #$00
 rts
 jsr    $BE6F
 lda    $12
 sta    $45
 lda    $13
 sta    $46
 lda    #$23
 sta    $3D
 lda    #$80
 sta    $3E
 lda    $18
 sta    $42
 jsr    $BEDD
 stx    $3F
 sty    $40
 stx    $43
 sty    $44
 stx    $47
 sty    $48
 sta    $41
 tay
 ldx    #$37
 jsr    OSFILE
 jmp    L8B9B
 jsr    $BE62
 jmp    L8AF3
 jsr    $BE62
 jmp    $BD14
 jsr    $BFA9
 pha
 jsr    L9813
 jsr    L92EE
 pla
 tay
 ldx    #$2A
 lda    #$01
 jsr    OSARGS
 jmp    L8B9B
 sec
 lda    #$00
 rol    a
 rol    a
 pha
 jsr    $BFB5
 ldx    #$2A
 pla
 jsr    OSARGS
 lda    #$40
 rts
 jsr    $BFA9
 pha
 jsr    L8AAE
 jsr    L9849
 jsr    L92EE
 pla
 tay
 lda    $2A
 jsr    OSBPUT
 jmp    L8B9B
 jsr    $BFB5
 jsr    OSBGET
 jmp    $AED8
 lda    #$40
 bne    $BF82
 lda    #$80
 bne    $BF82
 lda    #$C0
 pha
 jsr    $ADEC
 bne    $BF96
 jsr    $BEBA
 ldx    #$00
 ldy    #$06
 pla
 jsr    OSFIND
 jmp    $AED8
 jmp    L8C0E
 jsr    $BFA9
 jsr    L9852
 ldy    $2A
 lda    #$00
 jsr    OSFIND
 jmp    L8B9B
 lda    $0A
 sta    $1B
 lda    $0B
 sta    $19
 lda    $0C
 sta    $1A
 jsr    L8A8C
 cmp    #$23
 bne    $BFC3
 jsr    L92E3
 ldy    $2A
 tya
 rts

LBFC3:
        brk
        .byte   $2D, "Missing #"
        brk

; Print inline text
; =================
LBFCF:
        pla                     ; Pop return address to pointer
        sta    $37
        pla
        sta    $38
        ldy    #$00             ; Jump into loop
        beq    $BFDC
LBFD9:
        jsr    OSASCI           ; Print character
LBFDC:
        jsr    L894B            ; Update pointer, get character, loop if b7=0
        bpl    $BFD9
        jmp    ($0037)          ; Jump back to program

; REPORT
; ======
LBFE4:
        jsr    L9857            ; Check end of statement, print newline, clear COUNT
        jsr    $BC25
        ldy    #$01
LBFEC:
        lda    (FAULT),y        ; Get byte, exit if &00 terminator
        beq    $BFF6
        jsr    $B50E            ; Print character or token, loop for next
        iny
        bne    $BFEC
LBFF6:
        jmp    L8B9B            ; Jump to main execution loop
        brk
        .byte  "Roger"
        brk
LC000: