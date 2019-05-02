;  Reinhart Fagel
;  CS 218 - Assignment #11
;  Functions Template

; ---------------------------------------------------------
;	MACROS 

; Get msgLen ----------------------------
; %1 = return len by ref
; %2 = Address of error message
%macro msgLen 2

	%%msgLen_chrCnt:
		inc		%1

		cmp		byte[%2 + %1], NULL
		jne		%%msgLen_chrCnt

%endmacro

; Prints the error message passed -------
; %1 = Address of error message
%macro	printErr 1
push	rax
push	rdi
push	rsi
push	rdx

	xor		rdx, rdx

	mov		rax, SYS_write
	mov		rdi, STDOUT
	mov		rsi, %1
	msgLen	rdx, %1
	syscall

pop		rdx
pop		rsi
pop		rdi
pop		rax
%endmacro

; ***********************************************************************
;  Data declarations
;	Note, the error message strings should NOT be changed.
;	All other variables may changed or ignored...

section	.data

; -----
;  Define standard constants.

LF			equ	10			; line feed
NULL		equ	0			; end of string
SPACE		equ	0x20			; space

TRUE		equ	1
FALSE		equ	0

SUCCESS		equ	1			; successful operation
NOSUCCESS	equ	0			; Unsuccessful operation

STDIN		equ	0			; standard input
STDOUT		equ	1			; standard output
STDERR		equ	2			; standard error

SYS_read	equ	0			; system call code for read
SYS_write	equ	1			; system call code for write
SYS_open	equ	2			; system call code for file open
SYS_close	equ	3			; system call code for file close
SYS_fork	equ	57			; system call code for fork
SYS_exit	equ	60			; system call code for terminate
SYS_creat	equ	85			; system call code for file open/create
SYS_time	equ	201			; system call code for get time

O_CREAT		equ	0x40
O_TRUNC		equ	0x200
O_APPEND	equ	0x400

O_RDONLY	equ	000000q			; file permission - read only
O_WRONLY	equ	000001q			; file permission - write only
O_RDWR		equ	000002q			; file permission - read and write

S_IRUSR		equ	00400q
S_IWUSR		equ	00200q
S_IXUSR		equ	00100q

; -----
;  Define program specific constants.

GRAYSCALE	equ	1
BRIGHTEN	equ	2
DARKEN		equ	3

MIN_FILE_LEN	equ	5
BUFF_SIZE		equ	500000			; buffer size
; BUFF_SIZE		equ	3				; buffer size

ARG_AMNT	equ 4

; -----
;  Variables for getArguments() function.

eof		db	FALSE

usageMsg		db	"Usage: ./image <-gr|-br|-dk> <inputFile.bmp> "
				db	"<outputFile.bmp>", LF, NULL
errIncomplete	db	"Error, incomplete command line arguments.", LF, NULL
errExtra		db	"Error, too many command line arguments.", LF, NULL
errOption		db	"Error, invalid image processing option.", LF, NULL
; errReadSpec		db	"Error, invalid read specifier.", LF, NULL
; errWriteSpec	db	"Error, invalid write specifier.", LF, NULL
errReadName		db	"Error, invalid source file name.  Must be '.bmp' file.", LF, NULL
errWriteName	db	"Error, invalid output file name.  Must be '.bmp' file.", LF, NULL
errReadFile		db	"Error, unable to open input file.", LF, NULL
errWriteFile	db	"Error, unable to open output file.", LF, NULL

; -----
;  Variables for readHeader() function.

HEADER_SIZE	equ	54			; BMP file header size

errReadHdr	db	"Error, unable to read header from source image file."
		db	LF, NULL
errFileType	db	"Error, invalid file signature.", LF, NULL
errDepth	db	"Error, unsupported color depth.  Must be 24-bit color."
		db	LF, NULL
errCompType	db	"Error, only non-compressed images are supported."
		db	LF, NULL
errSize		db	"Error, bitmap block size inconsistant.", LF, NULL
errWriteHdr	db	"Error, unable to write header to output image file.", LF,
		db	"Program terminated.", LF, NULL

; -----
;  Variables for getRow() function.

buffMax		dq	BUFF_SIZE
curr		dq	BUFF_SIZE
wasEOF		db	FALSE
pixelCount	dq	0

errRead		db	"Error, reading from source image file.", LF,
		db	"Program terminated.", LF, NULL

; -----
;  Variables for writeRow() function.

errWrite	db	"Error, writting to output image file.", LF,
		db	"Program terminated.", LF, NULL

; ---------
; My variables

; file names
inFN 	dq 0
outFN	dq 0

sig			dw	0
fSize		dd	0
hSize		dd	0
width		dd	0
height		dd	0
pixByte		dd	0
compress	dd	0
iSize		dd	0

; double three
three		dq	3

; width in bytes
bWidth 		dq  0

; debug

temp dd 0
temp2 dw 0

; ------------------------------------------------------------------------
;  Unitialized data

section	.bss

buffer		resb	BUFF_SIZE
header		resb	HEADER_SIZE


;#############################################################################
; 	CODE
;#############################################################################

section	.text

; ***************************************************************
;  Routine to get arguments.
;	Verify files by attempting to open the files (to make
;	sure they are valid and available).

;  Command Line format:
;	./image <-gr|-br|-dk> <inputFileName> <outputFileName>

; -----
;  Arguments:
;	rdi: argc (value)
;	rsi: argv table (address)
;	rdx: image option variable (address)
;	rcx: read file descriptor (address)
;	r8: write file descriptor (address)
;  Returns:
;	rax: SUCCES or NOSUCCESS


global getArguments
getArguments:
	push 	r12
	push 	r13

	mov		r13, rsi

	; =====================================================
	; Usage Msg
	cmp		rdi, 1
	jne		check_cl
	printErr	usageMsg
	jmp		getArguments_failed

	; =====================================================
	; Check for incorrect argc
	check_cl:
	cmp		rdi, ARG_AMNT
	je		checkArgs
	ja		extraArg

	printErr	errIncomplete
	jmp		getArguments_failed
	extraArg:
	printErr	errExtra
	jmp		getArguments_failed

	; NOTE: rdi is now free

	; =====================================================
	; Check for incorrect arguments
	checkArgs:

	; -------------
	; check image option variable
	mov		r12, qword[r13 + 8]
	mov		r12d, dword[r12]
	cmp		r12d, "-gr"
	je		retIOV
	cmp		r12d, "-br"
	je		retIOV
	cmp		r12d, "-dk"
	je		retIOV

	printErr errOption
	jmp		getArguments_failed

	retIOV:

	;return iov by reference (rdx)
	mov		r12, qword[r13 + 8]
	mov		r12b, byte[r12 + 1]
	mov		qword[rdx], r12

	; -------------
	; check input file
	mov		rdi, qword[r13 + 16]
	call	checkIOFile
	cmp		rax, SUCCESS
	je		checkInOpen

	printErr errReadName
	jmp		getArguments_failed

	; if file opens, if so pass address by reference (rcx)
	checkInOpen:
	push	rcx
	mov		rax, SYS_open
	mov		rsi, O_RDWR
	syscall
	pop		rcx

	cmp		rax, 0
	jl		inNotOpened

	mov		qword[inFN], rax
	mov		qword[rcx], inFN
	jmp		inOpened

	inNotOpened:
	printErr errReadFile
	jmp		getArguments_failed

	inOpened:

	; -------------
	; check output file

	; if correct file extension
	mov		rdi, qword[r13 + 24] ; Output file
	call	checkIOFile
	cmp		rax, SUCCESS
	je		checkOutOpen

	printErr errWriteName
	jmp		getArguments_failed
	
	; if file opens, if so pass address by reference (r8)
	checkOutOpen:
	push	rcx
	mov		rax, SYS_creat
	mov		rsi, S_IRUSR | S_IWUSR
	syscall
	pop		rcx

	cmp		rax, 0
	jl		outNotOpened

	mov		qword[outFN], rax
	mov		qword[r8], outFN	; passed
	jmp		outOpened

	outNotOpened:
	printErr errWriteFile
	jmp		getArguments_failed

	outOpened:
	

	; Arguments are good
	mov		rax, SUCCESS
	jmp		getArguments_done

	; Arguments are bad
	getArguments_failed:
	mov		rax, NOSUCCESS

	getArguments_done:
	pop 	r13
	pop 	r12
ret

global checkIOFile
checkIOFile:
	push	r12
	mov		r12, 0

	; Goes to end of file name
	; Takes last 4 char which should be NULL, ".bmp"
	getExt:
		cmp		byte[rdi + r12], NULL
		je		getExt_done
		inc		r12
		jmp		getExt
	getExt_done:
	sub		r12, 4
	
	cmp		dword[rdi + r12], ".bmp"
	je		goodIOFile
	mov		rax, NOSUCCESS
	jmp		checkIOFile_done

	goodIOFile:
	mov		rax, SUCCESS

	checkIOFile_done:
	pop		r12
ret


; ***************************************************************
;  Read and verify header information
;	status = readHeader(readFileDesc, writeFileDesc,
;				fileSize, picWidth, picHeight)

; -----
;  2 -> BM							(+0)
;  4 file size						(+2)
;  4 skip							(+6)
;  4 header size					(+10)
;  4 skip							(+14)
;  4 width							(+18)
;  4 height							(+22)
;  2 skip							(+26)
;  2 depth (16/24/32)				(+28)
;  4 compression method code		(+30)
;  4 bytes of pixel data			(+34)
;  skip remaing header entries

; -----
;   Arguments:
;	rdi: read file descriptor (value)
;	rsi: write file descriptor (value)
;	rdx: file size (address)
;	rcx: image width (address)
;	r8:  image height (address)

;  Returns:
;	file size (via reference)
;	image width (via reference)
;	image height (via reference)
;	SUCCESS or NOSUCCESS

global readHeader
readHeader:
	push 	r12
	push	r13
	push	r14

	mov		r12, rsi	; r12 = write file desc (value)
	mov		r13, rdx	; r13 = file size	(address)
	mov		r14, rcx	; r14 = image width (address)

	; note: rsi, rdx, rcx are free to use

	; read file
	mov 	rax, SYS_read
	mov		rdi, qword[rdi]
	mov		rsi, header
	mov		rdx, HEADER_SIZE
	syscall

	cmp		rax, 0
	jge		canReadHeader

	printErr errReadHdr
	jmp		badHeader

	canReadHeader:

	;----------------------------------------------
	; Check if good .bmp file

	; BM (0)
	cmp 	word[header], "BM"
	je		goodBM	

	printErr errFileType
	jmp		badHeader

	goodBM:	

	; Comp (30) = 0
	cmp		dword[header + 30], 0
	je		goodComp

	printErr errCompType
	jmp 	badHeader

	goodComp:

	; Depth (28) = 24
	cmp		word[header + 28], 24
	je		goodDepth

	printErr errDepth
	jmp		badHeader

	goodDepth:

	; file size = size bytes (34) + header size
	mov		edx, dword[header + 34]
	add 	edx, HEADER_SIZE
	cmp		edx, dword[header + 2]
	je		goodFS

	printErr errSize
	jmp		badHeader

	goodFS:

	;----------------------------------------------
	; Returns

	; file size (via reference) r13
	mov		edx, dword[header + 2]
	mov		dword[fSize], edx
	mov		qword[r13], fSize

	; image width (via reference) r14
	mov		edx, dword[header + 18]
	mov		dword[width], edx
	mov		qword[r14], width

	; image height (via reference) r8
	mov		edx, dword[header + 22]
	mov		dword[height], edx
	mov		qword[r8], height

	;----------------------------------------------
	; Write to output

	mov		rax, SYS_write
	mov		rdi, qword[r12]
	mov		rsi, header
	mov		rdx, HEADER_SIZE
	syscall

	cmp		rax, 0
	jge		canWrite

	printErr errWriteHdr
	jmp		badHeader

	canWrite:
	; Storing width*3 for later
	mov		eax, dword[width]
	mul		qword[three]
	mov		qword[bWidth], rax

	mov		rax, TRUE
	jmp		readHeader_done

	badHeader:
	mov		rax, FALSE

	readHeader_done:
	pop		r14
	pop		r13
	pop		r12
ret

; ***************************************************************
;  Return a row from read buffer
;	This routine performs all buffer management

; ----
;  HLL Call:
;	status = getRow(readFileDesc, picWidth, rowBuffer);

;   Arguments:
;	rdi: read file descriptor (value)
;	rsi: image width (value)
;	rdx: row buffer (address)
;  Returns:
;	SUCCESS or NOSUCCESS

; -----
;  This routine returns SUCCESS when row has been returned
;	and returns NOSUCCESS only if there is an
;	error on write (which would not normally occur).

;  The read buffer itself and some misc. variables are used
;  ONLY by this routine and as such are not passed.

global getRow
getRow:
	push	r12
	push	r13

	mov		r12, 0 				; Row buffer index
	mov		r13, qword[curr] 	; buffer index

	getRowMain:
		cmp		r13, qword[buffMax]
		jl		currBuff

		; if eof
		cmp		byte[eof], TRUE
		je		isEOF

		push 	rdi
		push	rsi
		push	rdx
		; read file
		mov		rax, SYS_read
		mov		rdi, qword[inFN]
		mov		rsi, buffer
		mov		rdx, BUFF_SIZE
		syscall
		pop		rdx
		pop		rsi
		pop		rdi

		; If chr > BUFF_SIZE
		; Moves crap into buffer
		cmp		rax, BUFF_SIZE
		jge		resetBuffIndx

		; If < 0, print error
		; If == 0, return false
		cmp		rax, 0
		je 		isZero
		jl		isLess
		jmp		foundEOF

		isLess:
		printErr errRead
		isZero:
		jmp 	getRow_bad

		foundEOF:
		mov		qword[buffMax], rax
		mov		byte[eof], TRUE


	resetBuffIndx:
		mov		r13, 0
		mov		qword[curr], 0

	currBuff:
		mov		sil, byte[buffer + r13]
		mov		byte[rdx + r12], sil

		inc		r12	; row buffer indx
		inc		r13 ; buffer indx

		cmp		r12, qword[bWidth]
		jl		getRowMain

		mov		rax, TRUE
		jmp		getRow_done

	isEOF:
	getRow_bad:
	mov		rax, FALSE

	getRow_done:
	mov		qword[curr], r13

	pop		r13
	pop		r12
ret

; ***************************************************************
;  Write image row to output file.
;	Writes exactly (width*3) bytes to file.
;	No requirement to buffer here.

; -----
;  HLL Call:
;	status = writeRow(writeFileDesc, picWidth, rowBuffer);

;  Arguments are:
;	rdi: write file descriptor (value)
;	rsi: image width (value)
;	rdx: row buffer (address)

;  Returns:
;	SUCCESS or NOSUCESS

; -----
;  This routine returns SUCCESS when row has been written
;	and returns NOSUCCESS only if there is an
;	error on write (which would not normally occur).

;  The read buffer itself and some misc. variables are used
;  ONLY by this routine and as such are not passed.

global writeRow
writeRow:
	push 	r12

	mov		r12, 0
	mov		r12, qword[bWidth]

	mov		rax, SYS_write
	mov		rdi, qword[outFN]
	mov		rsi, rdx
	mov		rdx, r12
	syscall

	cmp		rax, 0
	jge		goodWrite

	printErr	errWrite
	mov		rax, FALSE
	jmp		writeRow_done

	goodWrite:
	mov		rax, TRUE

	writeRow_done:
	pop 	r12
ret

; ***************************************************************
;  Convert pixels to grayscale.

; -----
;  HLL Call:
;	status = imageCvtToBW(picWidth, rowBuffer);

;  Arguments are:
;	rdi: image width (value)
;	rsi: row buffer (address)
;  Returns:
;	updated row buffer (via reference)

global imageCvtToBW
imageCvtToBW:
	push 	r12
	push	r13
	push	rbx

	mov		rdi, 0
	mov		r12, 0 ; counter
	mov		dil, 3 ; for dividing bytes

	toGrey:
		cmp		r12, qword[bWidth]
		je		toGrey_done
		xor		rax, rax
		xor		rdx, rdx

		mov		al, byte[rsi + r12]
		mov		ah, 0

		div		dil
		mov		byte[rsi + r12], al

		inc 	r12
		
		; check if % 3
		mov		rax, r12
		mov		rdx, 0
		div		rdi
		cmp		rdx, 0
		je 		isMod3

		jmp		toGrey
	toGrey_done:

		jmp		imageCvtToBW_done

	; add all rgb and set them equal
	isMod3:
		dec		r12
		mov		al, byte[rsi + r12]
		dec		r12
		add		al, byte[rsi + r12]
		dec		r12
		add		al, byte[rsi + r12]

		mov		byte[rsi + r12], al
		inc		r12
		mov		byte[rsi + r12], al
		inc		r12
		mov		byte[rsi + r12], al
		inc		r12

		jmp 	toGrey

	imageCvtToBW_done:
	pop		rbx
	pop		r13
	pop		r12
ret

; ***************************************************************
;  Update pixels to increase brightness

; -----
;  HLL Call:
;	status = imageBrighten(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)

global imageBrighten
imageBrighten:
	push	r12
	push	r13

	mov		r12, 0 ; Counter
	mov		dil, 2 ; 2 for div bytes

	; Brightens img
	; clrValue/2 + clrvalue
	brightenImg:
		cmp		r12, qword[bWidth]
		je		brightenImg_done
		xor		rax, rax
		xor		rdx, rdx
		xor		r13, r13

		mov		al, byte[rsi + r12]
		cmp		al, 255
		je		isWhite
		mov		ah, 0

		div		dil
        mov     r13b, al
        xor     rax, rax
		mov		al, byte[rsi + r12]
        add     r13w, ax
        cmp     r13w, 255
		jle		goodBright
        mov     r13b, 255
		goodBright:
		mov		byte[rsi + r12], r13b

		isWhite:
		inc 	r12
		jmp		brightenImg

	brightenImg_done:

	pop		r13
	pop 	r12
ret

; ***************************************************************
;  Update pixels to darken (decrease brightness)

; -----
;  HLL Call:
;	status = imageDarken(picWidth, rowBuffer);

;  Arguments are:
;	rdi: image width (value)
;	rsi: row buffer (address)
;  Returns:
;	updated row buffer (via reference)

global	imageDarken
imageDarken:
	push	r12
	push	r13

	mov		r12, 0 ; Counter
	mov		dil, 2 ; 2 for div bytes

	; Darkens img
	; clrValue/2
	darkenImg:
		cmp		r12, qword[bWidth]
		je		darkenImg_done
		xor		rax, rax
		xor		rdx, rdx

		mov		al, byte[rsi + r12]
		cmp		al, 0
		je		isBlack
		mov		ah, 0

		div		dil
		mov		byte[rsi + r12], al

		isBlack:
		inc 	r12
		jmp		darkenImg
	darkenImg_done:

	pop		r13
	pop 	r12
ret

; ***************************************************************
;  Generic function to display a string to the screen.
;  String must be NULL terminated.

;  Algorithm:
;	Count characters in string (excluding NULL)
;	Use syscall to output characters

;  Arguments:
;	1) address, string
;  Returns:
;	nothing

global	printString
printString:
	push	rbx

; -----
;  Count characters in string.

	mov	rbx, rdi			; str addr
	mov	rdx, 0
strCountLoop:
	cmp	byte [rbx], NULL
	je	strCountDone
	inc	rbx
	inc	rdx
	jmp	strCountLoop
strCountDone:

	cmp	rdx, 0
	je	prtDone

; -----
;  Call OS to output string.

	mov	rax, SYS_write		; system code for write()
	mov	rsi, rdi			; address of characters to write
	mov	rdi, STDOUT			; file descriptor for standard in
							; EDX=count to write, set above
	syscall					; system call

; -----
;  String printed, return to calling routine.

prtDone:
	pop	rbx
	ret

; ***************************************************************
