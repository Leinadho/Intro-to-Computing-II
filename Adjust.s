	AREA	Adjust, CODE, READONLY
	IMPORT	main
	IMPORT	getPicAddr
	IMPORT	putPic
	IMPORT	getPicWidth
	IMPORT	getPicHeight
	PRESERVE8 {TRUE}
	EXPORT	start

	;Q=R0
	;A = R4
	;N = R5
	;I = R6
	;a = R7
	;b = R8
	;spare1 = R9
	;spare2 = R10
	;i = R11
	;C = R12
start

	BL	getPicAddr	; load the start address of the image in R4
	MOV	R4, R0
	BL	getPicHeight	; load the height of the image (rows) in R5
	MOV	R5, R0
	BL	getPicWidth	; load the width of the image (columns) in R6
	MOV	R6, R0

	MUL R7, R5,R6	;R7 = N = W*H = NUMBER OF PIXELZ
	LDR R9, =0	;I=0, INITIALISE PIXEL INDEX
	
	
	LDR R0, =10	;contrast increase = 20
	LDR R1, =-10	;brightness inc = 50
	
	
for
	CMP R9, R7		;if last pixel has been modified
	BEQ endfor		;stop for loop
	BL changePixel	;this method makes the required change of brightness and contrast for each pixel
	ADD R9, R9, #1	;increment the pixel index
	B for
endfor
	
	BL	putPic		; re-display the updated image

stop	B	stop

;;;;;;;;;;;;;;;;;;;;;;;;;

changePixel;(A(R4), I(R9), a(R0), b(R1) ), R3 = i
	STMFD SP!, {LR}
	LDR R3, =0		;i=0, the byte index
for_cp
	LDR R8, =4		
	MUL R10,R9 ,R8		;R10 = I*4
	ADD R10,R10,R3	 	;R10 = spare2 = I*4 + i
	
	LDRB R11, [R4, R10]	;LOAD [A + I*4 + i]  load primary colour byte (r/g/b) to C = R11 = storage for manipulation
	
	MOV R10,R11
	MUL R11, R10, R0	;multiply colour value by contrast scale
	
	;BL divide_by_16;(C(R11))	;divide product by 16
	
	MOV R10, R11		;spare2 = C = coulour*16
	LDR R11,=0			;C = storage = 0
whileDiv16
	CMP R10, #16
	BLT endWhileDiv16
	ADD R11, R11, #1	;C++
	SUB R10, R10, #16	;spare2-16
	B whileDiv16
endWhileDiv16
	;result of division is now in C, the colour storage = colour*a/16
	
	ADD R11,R11,R1 		;C = STORAGE = C + BRIGHTNESS
	
	
	CMP R11, #0			;Ensure colour value is within 
	LDRLT R11, =0		;range 0-255
	CMP R11, #255
	LDRGT R11, =255
	
	LDR R10, = 4
	MUL R8, R9, R10		; R8 = I*4
	ADD R8, R8, R3		; R8 = I*4 + i
	STRB R11, [R4, R8]	;store modified colour back in memory
	
	ADD R3, R3, #1		;i++ //move on to next colour value
	CMP R3,#3
	BEQ endfor_cp
	B for_cp
endfor_cp
	LDMFD SP!, {PC}

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	END	