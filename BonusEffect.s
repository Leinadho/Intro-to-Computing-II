	AREA	BonusEffect, CODE, READONLY
	IMPORT	main
	IMPORT	getPicAddr
	IMPORT	putPic
	IMPORT	getPicWidth
	IMPORT	getPicHeight
	PRESERVE8 {TRUE}
	EXPORT	start

start

	BL	getPicAddr	; load the start address of the image in R4
	MOV	R4, R0
	BL	getPicHeight	; load the height of the image (rows) in R5
	MOV	R5, R0
	BL	getPicWidth	; load the width of the image (columns) in R6
	MOV	R6, R0

	;R7 = Number of pixels (N)
	MUL R7,R5,R6
	

	LDR R9,=ITERATIONS
forIterations
	CMP R9,#0
	BEQ endForIterations
	SUB R9,#1
	;R8 = PIXEL INDEX I
	LDR R8,=0
	STMFD SP!, {R9}
forPixel
	CMP R8, R7
	BEQ endForPixel
	BL modifyPixel
	ADD R8, #1
	B forPixel
endForPixel
	LDMFD SP!, {R9}
	B forIterations
endForIterations

	BL	putPic		; re-display the updated image

stop	B	stop

;/******************************************************************************
;** Function name:		modifyPixel
;**
;** Descriptions:		modifies a pixel I by the convolution matrix MATRIX stored in memory
;**
;** parameters:			R4  = Address of image
;**						R5  = Height of image	
;**						R6  = Width of image
;**						R8  = Current pixel index
;**						
;**
;** Returned value:		none
;** 
;******************************************************************************/

modifyPixel
	STMFD SP!, {R4-R8,LR}
	
	MOV R0,R8 		;copy I to R0 for function
	BL indexToCoordinates;(r7=I,r6=W,r5=H)=>R11=X,R12=Y
	
	SUB R11,#1	;X--
	SUB R12,#1	;Y--
	LDR R9,=0	;n=0
	LDR R10,=0	;e=0
	LDR R2,=0	;column=0
	LDR R3,=0	;row=0

	;FOR LOOP ITERATES THROUGH PIXELS SURROUNDING I,
	;MULTIPLIES EACH BY THE CORRESPONDING ELEMENT OF THE CONVOLUTION MATRIX
	;STORES THE MODIFIED PIXEL TO THE STACK
forRow
	CMP R3,#3
	BEQ endForRow
forColumn
	CMP R2,#3	;WHILE COLUMN<3
	BEQ endForColumn
	;TEST IF PIXEL IS OUT OF BOUNDS
	;IF TRUE, DON'T STORE PIXEL.ELEMENT TO STACK
	CMP R11, #0
	BLT outOfBounds
	CMP R12, #0
	BLT outOfBounds
	CMP R11, R6
	BGE outOfBounds
	CMP R12, R5
	BGE outOfBounds
	
	ADD R9, #1	;n++
	BL pixelXelement;(R11=X,R12=Y,R10=e)=> pushes pixel.element to stack
	
outOfBounds
	ADD R10,#1	;e++
	ADD R11,#1	;X++
	ADD R2,#1	;column index++
	B forColumn
endForColumn
	SUB R2,#3 	;col = col-3
	SUB R11,#3	;X=X-3
	ADD R12,#1	;Y++
	ADD R3,#1	;row index++
	B forRow
endForRow


	LDR R1, =0 ;R=0
	LDR R2, =0 ;G=0
	LDR R3, =0 ;B=0
	
	LDR R12, =DIVISION
	STRB R9, [R12,#1]	;
	;FOR THE STACKED PIXELS,
	;ADD THE MODIFIED R,G,B VALUES TO 3 SEPARATE REGISTERS
forStackedPixels
 	CMP R9, #0
	BEQ endForStackedPixels
	SUB R9, #1
	LDMFD SP!, {R0}
	BL popAndAdd	;pop next pixel from stack, add its RGB elements to R1,R2,R3"
	B forStackedPixels
endForStackedPixels
	
	;IF DIVISION = TRUE, GET AVERAGE OF SUMMED PIXELS
	LDR R12, =DIVISION
	LDRB R9, [R12]	;R9 = DIVISION BOOLEAN
	
	;IF DIVISION = FLASE, SKIP DIVISION
	CMP R9, #0
	BEQ skipDivision
	
	LDRB R9,[R12,#1]
	BL divideRGBbyn
skipDivision
	
	;ENSURE THE R,G,B COLOUR VALUES ARE WITHIN RANGE 0-255
	BL keepRGBInRange
	
	;REPLACE ORIGINAL PIXEL WITH THE MODIFIED VALUES
	;BL coordinatesToIndex;(should take R11,R12,R5,R6 as inputs)=>I' in R0
	LDR R11,=4
	MUL R0,R11,R8 ;R0-I*4
	ADD R0, R0, R4 ;R0 = A+I*4
	;STORES MODIFIED RGBs IN PIXELS[I]
	STRB R1,[R0]
	STRB R2,[R0,#1]
	STRB R3,[R0,#2]
	
	LDMFD SP!,{R4-R8,PC}
	
	
;/******************************************************************************
;** Function name:		IndexToCoordinates
;**
;** Descriptions:		returns the coordinates of the pixel with index I
;**
;** parameters:			R5  = Height of image	
;**						R6  = Width of image
;**						R0  = Pixel Index
;**						
;**
;** Returned value:		R11=X, R12 = Y
;** 
;******************************************************************************/
	
indexToCoordinates;(I,W,H) takes index I in R0, returns coordinates of pixels[I]: X, Y (R1,R12)
	STMFD SP!, {R4-R10,LR}
	
	MOV R11, R0
	LDR R12, =0

while
	CMP R11, R6 		;WHILE X(I)>W
	BLT endwhile
	ADD R12,R12,#1
	SUB R11,R11,R6 		;X=X-W
	B while
endwhile
	
	LDMFD SP!, {R4-R10,PC}

;/******************************************************************************
;** Function name:		CoordinatesToIndex
;**
;** Descriptions:		returns the Index of the pixel corresponding to 
;**						coordinates X,Y
;**
;** parameters:			R6  = Width of image
;**						R11 = X coordinate of pixel
;**						R12 = Y coordinate of pixel
;**						
;**
;** Returned value:		R0 = Index
;** 
;******************************************************************************/

coordinatesToIndex;(X,Y,W,H)returns one register, R0 = I' = X + W*Y
	STMFD SP!, {R4-R10,LR}
	
	MUL R0, R12, R6
	ADD R0, R0, R11
	
	LDMFD SP!, {R4-R10,PC}

;/******************************************************************************
;** Function name:		pixelXelement
;**
;** Descriptions:		multiplies pixel I by corresponding element in the C.Matrix, 
;**						and pushes the new pixel to the stack
;**
;** parameters:			R10   = e convolution matrix element index
;**						R11 = X coordinate of pixel
;**						R12 = Y coordinate of pixel
;**						
;**
;** Returned value:		none
;** 
;******************************************************************************/



pixelXelement;()
	STMFD SP!, {R2-R12,LR}
	
	;LOAD MATRIX ELEMENT
	LDR R8,=4
	MOV R9,R10 
	MUL R10,R9,R8 ;R10=E*4
	LDR R9, =MATRIX
	LDR R10, [R9,R10] ;R10 = e
	
	;LOAD PIXEL[I']
	BL coordinatesToIndex
	MOV  R9, R0
	MUL R0, R9, R8 ; R0 = I'*4
	LDR R9,[R4,R0] ; R9 = PIXEL
	
	;LOAD RGB BYTES TO R1,R2,R3 RESPECTIVELY
	AND R1, R9, #0X000000FF
	AND R2, R9, #0X0000FF00
	AND R3, R9, #0X00FF0000
	
	LSR R2, R2, #8	;B=BYTE SIZE
	LSR R3, R3, #16	;C=BYTE SIZE
	
	MOV R0,R1
	MUL R1,R0,R10 			;R*e
	
	MOV R0,R2
	MUL R2,R0,R10 			;G*e
	
	MOV R0,R3
	MUL R3,R0,R10 			;B*e
	
	BL keepRGBInRange
	
	LSL R2,R2,#8			;GREEN BYTE MOVES 8 BITS RIGHT
	LSL R3,R3,#16			;BLUE BYTE MOVES 8*2 BITS RIGHT
	
	ADD R1,R1,R2
	ADD R1,R1,R3
	
	LDMFD SP!, {R2-R12}		;RETURN REGISTERS TO ORIGINAL STATE, 
	LDMFD SP!, {R0} 		;STORE LR IN R0
	
	STR R1, [SP,#-4]!		;STORE MODIFIED PIXEL' TO STACK
	
	MOV PC, R0
	

;/******************************************************************************
;** Function name:		popAndAdd

;**
;** Descriptions:		pops word from stack, adds its first 3 bytes in R1,R2,R3 respectively
;**
;** parameters:			none
;**
;** Returned value:		none
;** 
;******************************************************************************/

popAndAdd	;pop next pixel from stack, add its RGB elements to R1,R2,R3
	
	;LOAD RGB BYTES TO R10,R11,R12 RESPECTIVELY
	AND R10, R0, #0X000000FF
	AND R11, R0, #0X0000FF00
	AND R12, R0, #0X00FF0000
	
	LSR R11, R11, #8		;B=BYTE SIZE
	LSR R12, R12, #16		;C=BYTE SIZE

	ADD R1,R10
	ADD R2,R11
	ADD R3,R12
	
	MOV PC, LR
;/******************************************************************************
;** Function name:		keepRGBInRange
;**
;** Descriptions:		ensures R/G/B colour values are within range 0-255
;**
;** parameters:			R1=R,R2=G,R3=B
;**
;** Returned value:		none
;** 
;******************************************************************************/

keepRGBInRange;
	STMFD SP!, {R4-R12,LR}
	
	CMP R1, #0			;Ensure colour value is within 
	LDRLT R1, =0		;range 0-255
	CMP R1, #255
	LDRGT R1, =255
	
	CMP R2, #0			;Ensure colour value is within 
	LDRLT R2, =0		;range 0-255
	CMP R2, #255
	LDRGT R2, =255
	
	CMP R3, #0			;Ensure colour value is within 
	LDRLT R3, =0		;range 0-255
	CMP R3, #255
	LDRGT R3, =255
	
	
	LDMFD SP!, {R4-R12,PC}

;/******************************************************************************
;** Function name:		divideRGBbyn
;**
;** Descriptions:		divides 3 colour bytes by n
;**
;** parameters:			R1=R,R2=G,R3=B
;**						R9=n
;** Returned value:		R,G,B /n quotients in R1,R2,R3
;** 
;******************************************************************************/

divideRGBbyn;(n=R9)
	STMFD SP!, {R4-R12,LR}
	
	MOV R7, R1		;move sum of Rs to R7 
	BL getQuotient_Cdivn;(R, n); returns R/n in R8 
	MOV R1, R0
	
	MOV R7, R2
	BL getQuotient_Cdivn;(G, n); returns G/n in R8 
	MOV R2, R0
	
	MOV R7, R3
	BL getQuotient_Cdivn;(B, n); returns B/n in R8
	MOV R3, R0
	
	LDMFD SP!, {R4-R12,PC}
;/******************************************************************************
;** Function name:		getQuotient_Cdivn
;**
;** Descriptions:		Divides the input number(a colour byte) by n
;**
;** parameters:			R7=colour
;**						R9=n
;** Returned value:		R0 = quotient of R7/R9
;** 
;******************************************************************************/

getQuotient_Cdivn
	STMFD SP!, {LR,R4-R12}
	LDR R8,=0		;quotient=0
while_divide
	CMP R7,R9		;while colour>n 
	BLT endWhile_divide
	ADD R8,R8,#1	;quotient++
	SUB R7, R7, R9 	;colour-n
	B while_divide 
endWhile_divide
	MOV R0,R8
	LDMFD SP!, {R4-R12,PC}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		
	AREA	TestData, DATA, READWRITE
	
MATRIX	DCD 1,1,1,1,1,1,1,1,1	;9*9 convolution matrix
DIVISION DCB 1,0 				;division =boolean;N=0
ITERATIONS EQU 1		;number of iterations of program

	END	