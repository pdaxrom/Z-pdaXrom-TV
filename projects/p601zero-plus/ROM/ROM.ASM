;
; BOOTROM for Z/pdaXrom hw 1.3
; (c) sashz <sashz@pdaXrom.org>, 2018
;

	include DEVMAP.INC

;
; BootROM variables and functions
;

	include BOOTROM.INC

	include BOOTMEM.INC

	org	BOOTROM_BASE

reset	sei

	ldaa	RAMPAGE_CTL
	oraa	#BRAM_DISABLE
	staa	RAMPAGE_CTL

; SRAM chip initialization
	ldaa	#0
sramini	ldx	#$A55A
	stx	$0
	ldx	$0
	cpx	#$A55A
	bne	sramin1
	bra	sramok
sramin1	inca
	bne	sramini

onbrom	ldab	RAMPAGE_CTL
	andb	#($FF^BRAM_DISABLE)
	stab	RAMPAGE_CTL
	ldab	#$1C
	stab	IO_L7HI
sramok	staa	$2
	staa	IO_L7LO

; setup stubs
	ldx	#0
	stx	VECIRQP
	stx	VECNMIP

	ldx	#vstub_irq
	stx	VECIRQ
	ldx	#vstub_nmi
	stx	VECNMI
	ldx	#swihndl
	stx	VECSWI

; setup syscalls

	ldx	#BROM_SWIPAG
clrswipag clr	0,x
	inx
	cpx	#BROM_SWIPAG+$280
	bne	clrswipag

	lds	#romvecbeg
	des
	ldx	#BROM_SWIVEC+$C0*2
copyswiv pula
	staa	0,x
	inx
	cpx	#BROM_SWIVEC+$C0*2+(romvecend-romvecbeg)
	bne	copyswiv

warmres	lds	#BROM_STACK

; init putchar queue for control sequences
	clr	QUEUELEN
	ldx	#QUEUEBUF
	stx	QUEUEPTR

	ldaa	#$80
	ldx	#FBTEXT
	jsr	setvideomode

; setup prescaler: 24MHz / (Baud * 8)
	ldx	#26
	stx	UART_PRESCALER

; disable UART interrupts (clear UART_TIE and UART_RIE)
	clra
	staa	UART_CONFIG

	ldx	#pylogo
	jsr	putstr

	ldaa	RAMPAGE_CTL
	bita	#BRAM_DISABLE
	beq	bramen
	ldx	#txt_extram
	bra	ramtxt
bramen	ldx	#txt_bram
ramtxt	jsr	putstr

	ldx	#txt_kbd
	jsr	putstr
	ldx	#txt_uart
	jsr	putstr

;
; Trying to boot from SD
;
	jsr	sd_init
	tsta
	bne	no_sd_boot
	ldx	#txt_sd
	jsr	putstr

	ldx	#boot_sec
	jsr	sd_read
	tsta
	bne	no_sd_boot
	ldx	$2FE
	cpx	#$55AA
	bne	no_sd_boot
	jsr	$13E

no_sd_boot ldx	#txt_nl
	jsr	putstr

loop	bsr	uart_in
	cmpa	#'L'
	beq	cmd_load
	cmpa	#'S'
	beq	cmd_save
	cmpa	#'G'
	beq	cmd_go
	ldaa	#'E'
	bsr	uart_out
	bra	loop

cmd_load
	bsr	get_block_addr
cmd_lo1	bsr	uart_in
	staa	0,x
	inx
	cpx	END_ADDR
	bne	cmd_lo1
cmd_oka	ldaa	#'O'
	bsr	uart_out
	bra	loop

cmd_save
	bsr	get_block_addr
cmd_sa1	ldaa	0,x
	bsr	uart_out
	inx
	cpx	END_ADDR
	bne	cmd_sa1
	bra	cmd_oka

cmd_go
	bsr	get_word
	jsr	0,x
	jmp	warmres

get_block_addr proc
	bsr	get_word
	pshx
	bsr	get_word
	stx	END_ADDR
	pulx
	rts
	endp

;; UART IN/OUT

uart_in proc
	ldaa	UART_STATUS
	bita	#UART_RRD
	beq	uart_in
	ldaa	UART_DATA
	rts
	endp

uart_out proc
	pshb
loop	ldab	UART_STATUS
	bitb	#UART_TRD
	beq	loop
	staa	UART_DATA
	pulb
	rts
	endp

get_word proc
	bsr	uart_in
	tab
	bsr	uart_in
	psha
	pshb
	pulx
	rts
	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Get PS/2 keyboard code
; Return A - code
;
;getscancode proc
;loop	ldaa	PS2_STATUS
;	bita	#PS2_KRD
;	beq	loop
;	ldaa	PS2_DATA
;	rts
;	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Set video mode
; A = $00 - text, $03 - graphics,
; X = Video address
;

setvideomode proc
	pshx
	pshb
	psha
	stx	SCRADDR
	stab	SCRATTR
	tab
	anda	#$7F
	staa	SCRMODE
	ldx	txtmode
	stx	SCRSZX
	ldx	txtmode+2
	stx	SCRXADJ
	ldx	txtmode+4
	stx	SCRMASK
	cmpa	#0
	bne	mode3
	inc	SCRSZY		; 27 text rows
	inc	SCRSZY		;
	bitb	#$80
	beq	next
	ldaa	SCRSZY
	bra	clrs
mode3	cmpa	#3
	bne	exit
	ldaa	#VPU_GRF
	staa	SCRBITS
	bitb	#$80
	beq	next
	ldaa	SCRSZY
	lsla
	lsla
	lsla
clrs	jsr	clrscry
	clr	CURX
	clr	CURY
next	ldx	#SCRADDR
	bsr	vpuconfig
	ldaa	CURX
	ldaa	CURY
	bsr	setcursor
exit	pula
	pulb
	pulx
	rts

txtmode	db	40, 25, 11, 60, $FF^VPU_GRF, 0
	endp

; Configure VPU
; X = ptr
;
; ptr dw vaddr  ; 0
;     db width  ; 2
;     db height ; 3
;     db hadj   ; 4
;     db vadj   ; 5
;     db mask   ; 6
;     db bits   ; 7
;

vpuconfig proc
	pshb
	psha

; Set framebuffer address
	ldd	0,x
	std	VPU_VADDR

; Set start line
	clra
	ldab	5,x
	std	VPU_VSTART

; Set end line
	clra
	ldab	3,x
	lsld
	lsld
	lsld
	addd	VPU_VSTART
	std	VPU_VEND

; Framebuffer horisontal position
	ldaa	4,x
	staa	VPU_HSTART

; Start dma engine
	ldaa	2,x
	staa	VPU_HSIZE

; Set bits
	ldaa	#VPU_GRF
	anda	6,x
	oraa	7,x
	staa	VPU_CFG

	pula
	pulb
	rts
	endp

; Get video mode
; Return
; X - address
; A - mode
; B - attributes

getvideomode proc
	ldaa	SCRMODE
	ldab	SCRATTR
	ldx	SCRADDR
	rts
	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Set VPU cursor
; A - column
; B - row
;

vpucursor proc
	pshx
	pshb
	psha
	adda	#11
	inca
	staa	VPU_CPOS
	clra
	lsld
	lsld
	lsld
	ldx	#60
	pshx
	tsx
	addd	0,x
	pulx
	std	VPU_CSTART
	addd	#7
	std	VPU_CEND

	ldaa	VPU_CFG
	oraa	#VPU_CEN
	oraa	#VPU_CIN
;	anda	#($FF ^ VPU_CIN)
	staa	VPU_CFG

	pula
	pulb
	pulx
	rts
	endp

setcursor proc
	cmpa	SCRSZX
	bcc	exit
	cmpb	SCRSZY
	bcc	exit
	pshb
	psha
	staa	CURX
	stab	CURY
	bsr	vpucursor
	ldaa	SCRSZX
	mul
	std	CURPTR
	clra
	ldab	CURX
	addd	CURPTR
	addd	SCRADDR
	std	CURPTR
	pula
	pulb
exit	rts
	endp

getcursor proc
	ldaa	CURX
	ldab	CURY
	ldx	CURPTR
	rts
	endp

putchar	proc
	pshx
	pshb
	psha
	jsr	uart_out

	ldab	SCRMODE
	andb	#$03
	bne	return1		; graf mode not supported

	tst	QUEUELEN
	beq	putch0
queue1	ldx	QUEUEPTR
	staa	0,x
	inx
	stx	QUEUEPTR
	dec	QUEUELEN
	bne	return1
	ldx	#QUEUEBUF
	stx	QUEUEPTR
	ldaa	0,x
	cmpa	#$1E
	bne	queue1b
	ldaa	1,x
	suba	#$20
	ldab	2,x
	subb	#$20
	bsr	setcursor
	bra	return1
queue1b	cmpa	#$1B
	bne	return1
	ldaa	1,x
	bra	putnorm

return1	pula
	pulb
	pulx
	rts

putch0	cmpa	#$1B
	bne	putc1e
	ldab	#2
queueup	stab	QUEUELEN
	bra	queue1
putc1e	cmpa	#$1E
	bne	putc08
	ldab	#3
	bra	queueup
putc08	cmpa	#$08
	bne	putc09
	ldaa	CURX
	deca
	ldab	CURY
	bra	setcur
putc09	cmpa	#$09
	bne	putc0a
	ldaa	CURX
	adda	#8
	anda	#%11111000
	ldab	CURY
	bra	setcur
putc0a	cmpa	#$0A
	bne	putch0c
	ldaa	CURX
	ldab	CURY
	incb
	cmpb	SCRSZY
	bne	setcur
	bsr	scroll
	bra	return1
putch0c	cmpa	#$0C
	bne	putch0d
	bsr	clrscr
	clra
	clrb
	bra	setcur
putch0d	cmpa	#$0D
	bne	putch18
	clra
	ldab	CURY
	bra	setcur
putch18	cmpa	#$18
	bne	putch7f
	bsr	clr2eol
	bra	return1
putch7f	cmpa	#$7F
	bne	putnorm
	ldaa	CURX
	beq	return1
	deca
	ldx	CURPTR
	dex
	clr	0,x
	ldab	CURY
	bra	setcur
putnorm	ldx	CURPTR
	staa	0,x
	ldaa	CURX
	ldab	CURY
	inca
setcur	jsr	setcursor
	jmp	return1
	endp

clrscr	proc
	global	clrscry, clr2eol
	ldaa	SCRSZY
clrscry	ldab	SCRSZX
	mul
	ldx	SCRADDR
clrs1	clr	0,x
	inx
	subd	#1
	bne	clrs1
	rts

clr2eol	ldx	CURPTR
	ldaa	SCRSZY
	suba	CURX
eoloop	clr	0,x
	inx
	deca
	bne	eoloop
	rts
	endp

scroll	proc
	ldx	SCRADDR
	ldab	SCRSZX
	abx
	ldaa	SCRSZY
	deca
	mul

	pshy
	ldy	SCRADDR
loop	psha
	ldaa	0,x
	staa	0,y
	inx
	iny
	pula
	subd	#1
	bne	loop
	ldaa	SCRSZX
loop1	clr	0,y
	iny
	deca
	bne	loop1
	puly

	rts
	endp

puthex proc
	psha
	pshb
	tab
	bsr	OUTNIBH
	tba
	bsr	OUTNIBL
	pulb
	pula
	rts
OUTNIBH	lsra
	lsra
	lsra
	lsra
OUTNIBL	anda	#$0F
	oraa	#$30
	cmpa	#$39
	bls	OUTNIBX
	adda	#$7
OUTNIBX jmp	putchar
	endp

putstr	proc
	pshx
	psha
loop	ldaa	0,x
	beq	ret
	jsr	putchar
	inx
	bra	loop
ret	pula
	pulx
	rts
	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Select spi device
; A 1 Enable / 0 Disable
sdspi_select proc
	tsta
	beq	disable
	ldaa	SDSPI_CONFIG
	oraa	#SDSPI_SEL
	staa	SDSPI_CONFIG
	bra	okay
disable	ldaa	SDSPI_CONFIG
	anda	#($FF^SDSPI_SEL)
	staa	SDSPI_CONFIG
okay	rts
	endp

sdspi_write proc
	global	sdspi_read
	staa	SDSPI_DATA
loop	ldaa	SDSPI_STATUS
	bita	#SDSPI_READY
	beq	loop
	ldaa	SDSPI_DATA
	rts
sdspi_read ldaa	#$FF
	bra	sdspi_write
	endp

sd_delay proc
	pshx
	ldx	#4000
loop	dex
	bne	loop
	pulx
	rts
	endp

sd_init_cmd0	db	$40, $00, $00, $00, $00, $95
sd_init_cmd1	db	$41, $00, $00, $00, $00, $FF
sd_init_cmd8	db	$48, $00, $00, $01, $AA, $87
sd_init_cmd16	db	$50, $00, $00, $02, $00, $FF
sd_init_cmd55	db	$77, $00, $00, $00, $00, $01
sd_init_acmd41	db	$69, $40, $00, $00, $00, $00
sd_init_cmd58	db	$7A, $00, $00, $00, $00, $00

SD_CT_MMC	equ	$01
SD_CT_SD1	equ	$02
SD_CT_SD2	equ	$04
SD_CT_BLOCK	equ	$08

;
; Initialize SD card
; Return A - error code
;        B - card type
;
sd_init	proc
	pshb
	pshx
	ldaa	#40
	staa	SDSPI_PRESCALER
	jsr	sd_disable
	ldab	#10
loop	jsr	sdspi_read
	decb
	bne	loop

	ldx	#sd_init_cmd0
	ldab	#10
loop1	jsr	sd_command
	cmpa	#$01
	beq	init_sdver
	bsr	sd_delay
	decb
	bne	loop1
	ldaa	#1
	jmp	exit

init_sdver ldx	#sd_init_cmd8
	jsr	sd_command
	cmpa	#$01
	bne	init_mmc
	bsr	sdspi_read
	bsr	sdspi_read
	bsr	sdspi_read
	tab
	bsr	sdspi_read
	xgdx
	cpx	#$AA01
	beq	init_sdv2
	ldaa	#$82
	bra	exit

init_sdv2 ldab	#$FF
loop2	ldx	#sd_init_cmd55
	jsr	sd_command
	ldx	#sd_init_acmd41
	jsr	sd_command
	tsta
	beq	init_ccs
	jsr	sd_delay
	decb
	bne	loop2
	ldaa	#$83
	bra	exit

init_ccs ldx	#sd_init_cmd58
	jsr	sd_command
	tsta
	beq	init_ccs2
	ldaa	#$84
	bra	exit

init_ccs2 jsr	sdspi_read
	tab
	jsr	sdspi_read
	jsr	sdspi_read
	jsr	sdspi_read

	ldaa	#SD_CT_SD2
	andb	#$40
	beq	init_ccs2a
	oraa	#SD_CT_BLOCK
init_ccs2a staa	SDMODE
	bra	noerr

init_mmc ldx	#sd_init_cmd1
	ldab	#255
loop3	jsr	sd_command
	tsta
	beq	init_bsize
	jsr	sd_delay
	decb
	bne	loop3
	ldaa	#2
	bra	exit

init_bsize ldx	#sd_init_cmd16
	jsr	sd_command
	clr	SDMODE
noerr	clra
exit	pulx
	pulb
	bra	sd_disable
	endp

sd_command proc
	bsr	sd_disable
	bsr	sd_enable

	ldaa	0,x		; cmd
	jsr	sdspi_write
	ldaa	1,x		; arg
	jsr	sdspi_write
	ldaa	2,x		; arg
	jsr	sdspi_write
	ldaa	3,x		; arg
	jsr	sdspi_write
	ldaa	4,x		; arg
	jsr	sdspi_write
	ldaa	5,x		; CRC
	jsr	sdspi_write

	pshb
	ldab	#10
loop	jsr	sdspi_read
	cmpa	#$FF
	bne	exit
	decb
	bne	loop
exit	pulb
	rts
	endp

sd_enable proc
	pshx
	pshb
wait	ldaa	#1
	jsr	sdspi_select
	jsr	sdspi_read
	ldx	#5000
loop	jsr	sdspi_read
	cmpa	#$FF
	beq	exit
	jsr	sd_delay
	dex
	bne	loop
	bsr	sd_disable
	ldaa	#0
exit	inca
	pulb
	pulx
	rts
	endp

sd_disable proc
	pshb
	psha
	ldaa	#0
	jsr	sdspi_select
	jsr	sdspi_read
	pula
	pulb
	rts
	endp

;
; read sector from SD
;
; A = 0 - No error
;
; X - ptr to structure:
; ds 4 - sector
; ds 2 - buffer ptr
;
sd_read proc
	pshx
	pshb

;
; sector * 512
;
	ldaa	#$FF
	psha
	ldaa	SDMODE
	anda	#SD_CT_BLOCK
	beq	mul512
	ldaa	3,x
	psha
	ldaa	2,x
	psha
	ldaa	1,x
	psha
	ldaa	0,x
	psha
	bra	cmd17

mul512	clra
	psha
	ldaa	3,x
	rola
	psha
	ldaa	2,x
	rola
	psha
	ldaa	1,x
	rola
	psha

cmd17	ldaa	#$51		; CMD17
	psha
	ldx	4,x		; buffer
	pshx
	tsx
	inx
	inx			; X to saved data for sd_command
	jsr	sd_command
	pulx

	tsta
	beq	next
	ldaa	#1
	bra	exit

next	ldab	#255
next1	jsr	sdspi_read
	cmpa	#$FF
	bne	next2
	jsr	sd_delay
	decb
	bne	next1
	ldaa	#2
	bra	exit
next2	cmpa	#$FE
	beq	next3
	ldaa	#3
	bra	exit
next3	bsr	rcvr
	bsr	rcvr
	jsr	sdspi_read
	jsr	sdspi_read
	ldaa	#0

exit	tsx
	ldab	#6
	abx
	txs
	bsr	sd_disable

	pulb
	pulx
	rts

rcvr	ldab	#0
rcvr1	jsr	sdspi_read
	staa	0,x
	inx
	decb
	bne	rcvr1
	rts
	endp

;
; write sector to SD
;
; A = 0 - No error
;
; X - ptr to structure:
; ds 4 - sector
; ds 2 - buffer ptr
;
sd_write proc
	pshx
	pshb

;
; sector * 512
;
	ldaa	#$FF
	psha
	ldaa	SDMODE
	anda	#SD_CT_BLOCK
	beq	mul512
	ldaa	3,x
	psha
	ldaa	2,x
	psha
	ldaa	1,x
	psha
	ldaa	0,x
	psha
	bra	cmd24

mul512	clra
	psha
	ldaa	3,x
	rola
	psha
	ldaa	2,x
	rola
	psha
	ldaa	1,x
	rola
	psha

cmd24	ldaa	#$58		; CMD24
	psha
	ldx	4,x		; buffer
	pshx
	tsx
	inx
	inx			; X to saved data for sd_command
	jsr	sd_command
	pulx

	tsta
	beq	next
	ldaa	#1
	bra	exit

next	ldab	#255
next1	jsr	sdspi_read
	cmpa	#$FF
	beq	next2
	jsr	sd_delay
	decb
	bne	next1
	ldaa	#2
	bra	exit
next2	ldaa	#$FE
	jsr	sdspi_write
	bsr	xmit
	bsr	xmit
	jsr	sdspi_read
	jsr	sdspi_read
	jsr	sdspi_read
	anda	#$1F
	cmpa	#$05
	bne	next3
	ldaa	#0
	bra	exit
next3	ldaa	#3

exit	tsx
	ldab	#6
	abx
	txs
	jsr	sd_disable

	pulb
	pulx
	rts

xmit	ldab	#0
xmit1	ldaa	0,x
	jsr	sdspi_write
	inx
	decb
	bne	xmit1
	rts
	endp

sd_flush proc
	jsr	sd_enable
	tsta
	bne	exit
	jsr	sd_disable
exit	rts
	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
umult	proc
P	equ	0
Q	equ	2
R	equ	4
	pshx		; R
	pshx		; R
	pshx		; Q
	pshb		; P
	psha		; P
	tsx

	clrb
	clra
	std	R,x
	ldaa	P+1,x
	ldab	Q+1,x
	mul
	std	R+2,x
	ldaa	P,x
	ldab	Q+1,x
	mul
	addd	R+1,x
	std	R+1,x
	bcc	MUL002
	inc	R,x
MUL002	ldaa	P+1,x
	ldab	Q,x
	mul
	addd	R+1,x
	std	R+1,x
	bcc	MUL004
	inc	R,x
MUL004	ldaa	P,x
	ldab	Q,x
	mul
	addd	R,x
;	std	R,x
;	ldx	R+2,x
	pulx
	pulx
	pulx
	pulx
	xgdx
	rts
	endp

udiv	proc
DIV	equ	3
QUO	equ	1
KT	equ	0

	pshb		; divisor
	psha		;
	pshx		; dividend
	ldab	#1
	pshb		; counter
	tsx

	ldd	DIV,x
	beq	error
	bmi	DIV002
DIV001	inc	KT,x
	asld
	bpl	DIV001
	std	DIV,x
DIV002	ldd	QUO,x
	clr	QUO,x
	clr	QUO+1,x
DIV003	subd	DIV,x
	bcc	DIV004
	addd	DIV,x
	clc
	bra	DIV005
DIV004	sec
DIV005	rol	QUO+1,x
	rol	QUO,x
	lsr	DIV,x
	ror	DIV+1,x
	dec	KT,x
	bne	DIV003

	pshb
	psha
	ldd	QUO,x
	pulx

	clc
	bra	okay
error	sec
okay	ins
	ins
	ins
	ins
	ins
	rts
	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
swihndl proc
	sei
	tsx
	ldd	7,x
	addd	#1
	std	7,x
	xgdx
	dex
	ldaa	0,x

	ldab	RAMPAGE_SEL
	pshb
	tab
	ldx	#BROM_SWIPAG
	lsrb
	abx
	ldab	0,x
	bcc	swih1
	lsrb
	lsrb
	lsrb
	lsrb
swih1	andb	#$0F
	beq	swih2
	stab	RAMPAGE_SEL

swih2	tab
	ldx	#BROM_SWIVEC
	abx
	abx
	ldx	0,x
	cpx	#0
	beq	exit
	xgdx
	ldx	#swiret
	pshx
	pshb
	psha

	tsx
	ldab	6,x
	ldaa	7,x
	psha
	ldaa	5,x
;	db	$1a		; ldy prefix
;	ldx	10,x		; ldy 10,x
	ldx	8,x
	tap
	pula
	rts

swiret	sei
	pshx
	tsx
	stab	4,x
	staa	5,x
	pula
	staa	6,x
	pula
	staa	7,x
	sty	8,x
exit	pulb
	stab	RAMPAGE_SEL
	rti
	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
bpt	proc
	pshy
	pshb
	psha
	pshx
	tpa
	psha
	ldx	#regstxt
	jsr	putstr
	tsx
	ldaa	0,x
	bsr	regshex
	ldaa	3,x
	bsr	regshex
	ldaa	4,x
	bsr	regshex
	ldaa	1,x
	bsr	regshex
	ldaa	2,x
	bsr	regshex
	ldaa	5,x
	bsr	regshex
	ldaa	6,x
	bsr	regshex
	tsx
	xgdx
	addd	#$12
	xgdx
	dex
	ldd	0,x
	inx
	xgdx
	pshx
	bsr	regshex
	tba
	bsr	regshex
	pula
	bsr	regshex
	pula
	bsr	regshex
	ldx	#regsnl
	jsr	putstr
	pula
	tap
	pulx
	pula
	pulb
	puly
	rts
regshex	jmp	puthex

regstxt	db	10, 13, 'P_A_B_X___Y___SP__PC__', 10, 13, 0
regsnl	db	10, 13, 0
	endp

;
;----
inthandlers proc
	global vstub_irq, vstub_swi, vstub_nmi
vstub_irq
	ldx	#vectextIRQ
	bra	ret

vstub_swi
	ldx	#vectextSWI
	bra	ret

vstub_nmi
	ldx	#vectextNMI
ret	jsr	putstr
	rti
	endp

vectextIRQ	db	'IRQ',0
vectextSWI	db	'SWI',0
vectextNMI	db	'NMI',0

;----
intvectors proc
	global vec_irq, vec_swi, vec_nmi
vec_irq	ldab	VECIRQP
	ldx	VECIRQ
callvec	ldaa	RAMPAGE_SEL
	psha
	stab	RAMPAGE_SEL
	cpx	#0
	beq	exit
	jsr	0,x
exit	pula
	staa	RAMPAGE_SEL
	rti

vec_swi	ldx	VECSWI
	jmp	0,x

vec_nmi	ldab	VECNMIP
	ldx	VECNMI
	bra	callvec
	endp

romvecbeg
	dw	reset
	dw	warmres
	dw	uart_in
	dw	uart_out
	dw	vpuconfig
	dw	vpucursor
	dw	0	;spi_reset
	dw	0	;spi_getstat
	dw	0	;spi_select
	dw	0	;spi_write
	dw	0	;spi_read
	dw	sd_init
	dw	sd_read
	dw	sd_write
	dw	sd_flush
	dw	0	;psg_send
	dw	0	;psg_write
	dw	umult
	dw	udiv
	dw	bpt
	dw	setvideomode
	dw	getvideomode
	dw	setcursor
	dw	getcursor
	dw	putchar
	dw	puthex
	dw	putstr
romvecend

boot_sec db	$00,$00,$00,$00
	dw	$100

pylogo		db	'Z/pdaXrom', 10, 13, '+ ', 0
;		db	'(c) sashz <sash@pdaXrom.org>, 1997-2017', 10, 13, 0
txt_bram	db	'IRAM ', 0
txt_extram	db	'SRAM ', 0
txt_kbd		db	'KBD ', 0
txt_uart	db	'UART ', 0
txt_sd		db	'SD '
txt_nl		db	'*', 10, 13, 0

	ds	$fff8-*, $ff
	dw	vec_irq
	dw	vec_swi
	dw	vec_nmi
	dw	reset
