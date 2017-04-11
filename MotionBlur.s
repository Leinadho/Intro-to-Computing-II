	AREA	MotionBlur, CODE, READONLY
	IMPORT	main
	IMPORT	getPicAddr
	IMPORT	putPic
	IMPORT	getPicWidth
	IMPORT	getPicHeight
	PRESERVE8  {TRUE}
	EXPORT	start

start
	
						;R0 = spare3
	
	BL	getPicAddr		; load the start address of the image in R4
	MOV	R4, R0			;R4 = A
	BL	getPicHeight	; load the height of the image (rows) in R5
	MOV	R5, R0			;R5 = H
	BL	getPicWidth		; load the width of the image (columns) in R6
	MOV	R6, R0			;R6 = W

	LDR R1, =5			;R1 = radius
	MUL R2, R6, R5		;R2 = N = number of pixels
	LDR R3, =0			;R3 = I:  initialise pixel index to zero
	
						;R7 = X
						;R8 = Y 
						;R9 = I'
						;R10= n
						;R11= spare
						;R12= spare2
	
forPixelI
	
	CMP R3,R2				;COMPARE I and N
	BEQ endForPixelI
	BL 	pixelToRadiusSample;(A,I,W,H,radius)
	ADD R3,R3,#1
	B forPixelI
endForPixelI
	BL	putPic				; re-display the updated image
stop	B	stop

;;;;;;;;;;;;;;;;;;;;;;;;;;;
pixelToRadiusSample;(R4=A,R3=I,R5=W,R6=H,R1=radius) RETURNS NONE
	STMFD SP!, {LR}

	
	BL pixelCoordinates;(I,W,H) returns X, Y in 2 new registers (R7,R8)
	;STORE CENTER PIXEL IN STACK
	BL coordinatesToIndex
	LDR R0,=4
	MUL R12,R9,R0
	LDR R0,[R4,R12]
	STMFD SP!, {R0}
	
	LDR R10, =1
	
	LDR R11,=1

forDescendingPixels
	CMP R11, R1
	BEQ endForDescendingPixels
	
	;INCREMENT X,Y
	ADD R7,#1
	ADD R8,#1
	
	;OUT OF BOUNDS TEST
	CMP R7,R6
	BGE outOfBounds
	CMP R8,R5
	BGE outOfBounds
	
	;LOAD PIXEL, STORE IT TO STACK, N++
	ADD R10, R10, #1
	BL coordinatesToIndex;(X,Y,W,H) returns 1 additional register, I', in R9
	
	LDR R0, =4
	MUL R12, R9, R0
	LDR R0, [R4, R12]
	STMFD SP!, {R0}	;pop word-sized pixel to stack 
	
outOfBounds

	;COUNT++
	ADD R11,R11,#1
	B	forDescendingPixels
endForDescendingPixels

	BL pixelCoordinates
	;LDR R10,=1
	LDR R11,=1
	
forAscendingPixels
	CMP R11, R1
	BEQ endForAscendingPixels
	;DECREMENT X,Y
	SUB R7,#1
	SUB R8,#1
	
	;OUT OF BOUNDS TEST
	CMP R7,#0
	BLT outOfBounds2
	CMP R8,#0
	BLT outOfBounds2
	
	;LOAD PIXEL, STORE IT TO STACK, N++
	ADD R10, R10, #1
	BL coordinatesToIndex;(R7=X,R8=Y,R5=W,R6=H) returns 1 additional register, I', in R9
	
	LDR R0, =4
	MUL R12, R9, R0
	LDR R0, [R4, R12]
	STMFD SP!, {R0}	;pop word-sized pixel to stack 
	
outOfBounds2
	;COUNT++
	ADD R11,R11,#1
	B	forAscendingPixels
endForAscendingPixels

	LDR R11,=0 ;total R
	LDR R12,=0 ;total G
	LDR R0,=0 ;total B
	
	LDR R9,=0
	

forStackedPixels		;add stacked RGB vlalues to R, G, B
	CMP R9, R10			;while(I'<n) ie, stack hasn't been emptied of pixels
	BEQ endForStackedPixels

	LDRB R7, [SP] 
	ADD R11,R11,R7	;add the red byte of the word in the stack to the red sum
	
	LDRB R7, [SP,#1]!  ;HERE, spare, spare2, spare3 are R,G,B values respectively
	ADD R12,R12,R7		 ;The store is the register which held X, R7
	
	LDRB R7, [SP,#1]!
	ADD R0,R0,R7		;add the blue byte to the R register (R11)
	
	ADD SP,SP,#2		
	
	ADD R9, R9,#1	
	B forStackedPixels
endForStackedPixels

	MOV R7, R11		;move sum R to R7 
	BL divideColour;(X, n); returns R/n in I' (R9)
	MOV R11, R9
	
	MOV R7, R12
	BL divideColour;(X, n); returns G/n in I'
	MOV R12, R9
	
	MOV R7, R0
	BL divideColour;(X, n); returns B/n in I'
	MOV R0, R9
	
	;COLOUR CHECKER
	CMP R0, #0			;Ensure colour value is within 
	LDRLT R0, =0		;range 0-255
	CMP R0, #255
	LDRGT R0, =255
	
	CMP R11, #0			;Ensure colour value is within 
	LDRLT R11, =0		;range 0-255
	CMP R11, #255
	LDRGT R11, =255
	
	CMP R12, #0			;Ensure colour value is within 
	LDRLT R12, =0		;range 0-255
	CMP R12, #255
	LDRGT R12, =255
	
	
	LDR R7, =4
	MUL R9, R3, R7		;I changed R12 to R7 here, as it's I' = 4*I
	
	ADD R9, R9, #1
	STRB R0, [R4,R9] 			;STORE BLUE VALUE IN A + 4*I + 1
	
	ADD R9, R9, #1
	STRB R12, [R4,R9]
	
	ADD R9, R9, #1
	STRB R11, [R4,R9]

	;end of subroutine

	LDMFD SP!, {PC}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

divideColour;(R10 = n): returns quotient C/n in register I'
	STMFD SP!, {LR}
	
	LDR R9,=0
while_divide
	CMP R7,R10	;R10 is n (mostly r)
	BLT endWhile_divide
	ADD R9,R9,#1
	SUB R7, R7, R10
	B while_divide 
endWhile_divide

	LDMFD SP!, {PC}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

pixelCoordinates;(R3=I,R5=W,R6=H) returns two registers: X, Y (R7,R8)
	STMFD SP!, {LR}
	
	MOV R7, R3
	LDR R8, =0

while
	CMP R7, R6
	BLT endwhile
	ADD R8,R8,#1
	SUB R7,R7,R6
	B while
endwhile
	
	LDMFD SP!, {PC}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

coordinatesToIndex;(R7=X,R8=Y,R5=W,R6=H)returns one register, I' = X + W*Y
	STMFD SP!, {LR}

	MUL R9, R6, R8
	ADD R9, R9, R7
	
	LDMFD SP!, {PC}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	
	

	END	