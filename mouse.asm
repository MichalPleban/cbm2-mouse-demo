

;--------------------------------------------------------------------
; KERNAL variables
;--------------------------------------------------------------------

CursorType  = $D4
CharPtr		= $C8
RS232Status = $037A

;--------------------------------------------------------------------
; KERNAL routines
;--------------------------------------------------------------------

SCROUT  = $e00d
SETLFS  = $ffba
SETNAM  = $ffbd
OPEN    = $ffc0
CHKIN   = $ffc6
GETIN   = $ffe4
PLOT    = $fff0

;--------------------------------------------------------------------
; I/O chip ports
;--------------------------------------------------------------------

CRTC_RegNo = $D800
CRTC_RegVal = $D801
ACIA_Command = $DD02

;--------------------------------------------------------------------
; BASIC loader stub & startup code
;--------------------------------------------------------------------

.incbin "stub.bin"
.org $0400
        lda #$0F
        sta $01
        jsr screen_init
        jsr serial_open
        jmp main_loop

;--------------------------------------------------------------------
; Code variables
;--------------------------------------------------------------------

; RS-232 file name
serial_name:
        .byte $18, $00

; Ignore first bytes from the mosue
serial_ignore:
        .byte 3
        
; Screen coordinates
screen_x:
        .byte 40
screen_y:
        .byte 13
                
; Bytes read from the mouse
mouse_buttons = $F0
mouse_dx      = $F1
mouse_dy      = $F2

;--------------------------------------------------------------------
; Clear screen
;--------------------------------------------------------------------

screen_init:
        lda #$93
        jsr SCROUT
        lda #$0a
        sta CRTC_RegNo
        lda #$40
        sta CRTC_RegVal
        sta CursorType
        ldy screen_x
        ldx screen_y
        clc
        jsr PLOT
        rts

;--------------------------------------------------------------------
; Open #2 file for RS-232
;--------------------------------------------------------------------

serial_open:
        lda #$02
        tax
        tay
        jsr SETLFS
        lda #<serial_name
        ldx #>serial_name
        ldy #$0f
        sta $F0
        stx $F1
        sty $F2
        lda #$02
        ldx #$F0
        jsr SETNAM
        clc
        jsr OPEN
        ldx #$02
        jsr CHKIN
        ; Set RTS ad DTR lines
        lda #$0B
        sta ACIA_Command
        ; Ignore identification bytes
serial_first:
        jsr serial_read
        dec serial_ignore
        bne serial_first
        rts

;--------------------------------------------------------------------
; Read from the RS-232
;--------------------------------------------------------------------

serial_read:
        jsr GETIN
        tax
        ; Loop if no input
        lda RS232Status
        and #$10
        bne serial_read
        txa
        and #$7F
        rts
        
;--------------------------------------------------------------------
; Main loop
;--------------------------------------------------------------------

main_loop:
        ; Look for the first byte with 6th but set
        jsr serial_read
        sta mouse_buttons
        and #$40
        beq main_loop
        ; Read two more bytes
        jsr serial_read
        sta mouse_dx
        jsr serial_read
        sta mouse_dy
        ; Combine bytes to form DX and DY
        asl mouse_buttons
        asl mouse_buttons
        lda mouse_buttons
        and #$0C
        asl
        asl
        asl
        asl
        ora mouse_dx
        sta mouse_dx
        lda mouse_buttons
        and #$30
        asl
        asl
        ora mouse_dy
        sta mouse_dy
        ; Divide DX by 4
        lda mouse_dx
        lsr
        lsr
        bit mouse_dx
        bpl dx_positive
        ora #$C0
dx_positive:
        ; Add DX to coordinates
        clc
        adc screen_x
        bpl x_positive
        lda #0
x_positive:
        cmp #79
        bcc x_inside
        lda #79
x_inside:
        sta screen_x
        tay
        ; Divide DY by 8
        lda mouse_dy
        lsr
        lsr
        lsr
        bit mouse_dy
        bpl dy_positive
        ora #$E0
dy_positive:
        ; Add DX to coordinates
        clc
        adc screen_y
        bpl y_positive
        lda #0
y_positive:
        cmp #24
        bcc y_inside
        lda #24
y_inside:
        sta screen_y
        tax
        clc        
        jsr PLOT
        ; Check if mouse buttons pressed
        bit mouse_buttons
        bmi mouse_left
        bvc main_loop
        ; Right button pressed
        lda #$20
        .byte $2C
mouse_left:
        ; Left button pressed
        lda #$23
        sta (CharPtr), y
        jmp main_loop
