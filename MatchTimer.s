	AREA	MatchTimer, CODE, READONLY
	IMPORT	main
	EXPORT	start

VICIntSelect	EQU	0xFFFFF00C
VICIntEnable	EQU	0xFFFFF010
VICVectAddr0	EQU	0xFFFFF100
VICVectPri0	EQU	0xFFFFF200
VICVectAddr	EQU	0xFFFFFF00

PINSEL4		EQU	0xE002C010
EXTINT		EQU	0xE01FC140
EXTMODE		EQU	0xE01FC148
EXTPOLAR	EQU	0xE01FC14C



PINSEL1		EQU	0xE002C004

T0TCR		EQU	0xE0004004
T0CTCR		EQU	0xE0004070
T0MR0		EQU	0xE0004018
T0MCR		EQU	0xE0004014
T0PR		EQU	0xE000400C
T0IR		EQU	0xE0004000
	
T1TCR		EQU	0xE0008004
T1CTCR		EQU	0xE0008070;
T1MR0		EQU	0xE0008018
T1MCR		EQU	0xE0008014;
T1PR		EQU	0xE000800C;
T1IR		EQU	0xE0008000	

DACR		EQU	0xE006C000
	
volume 		EQU 	1023
	

secondTIMER0interrupt	DCB	0
	
	
start	
	
	;BUTTON INITIALISATION //taken directly from button.uvproj, because the function should be exactly the same
	; Enable P2.10 for EINT0
	LDR	R5, =PINSEL4
	LDR	R6, [R5]	
	BIC	R6, #(0x03 << 20)
	ORR	R6, #(0x01 << 20)
	STR	R6, [R5]
	
	; Set edge-sensitive mode for EINT0
	LDR	R5, =EXTMODE
	LDR	R6, [R5]
	ORR	R6, #1
	STRB	R6, [R5]
	
	; Set rising-edge mode for EINT0
	LDR	R5, =EXTPOLAR
	LDR	R6, [R5]
	BIC	R6, #1
	STRB	R6, [R5]
	
	; Reset EINT0
	LDR	R5, =EXTINT
	MOV	R6, #1
	STRB	R6, [R5]
	

	
	;
	; Configure push button (Vector 0x14) interrupt handler
	;

	MOV	R3, #14			; vector = 14;
	MOV	R4, #1			; vmask = 1;
	MOV	R4, R4, LSL R3		; vmask = vmask << vector;

	
	; VICIntSelect - Set Vector 0x14 for IRQ (clear bit 14)
	LDR	R5, =VICIntSelect	; addr = VICIntSelect;
	LDR	R6, [R5]		; tmp = Memory.Word(addr);		
	BIC	R6, R6, R4		; Clear bit for Vector 0x14
	STR	R6, [R5]		; Memory.Word(addr) = tmp;
	
	; Set Priority to lowest (15)
	LDR	R5, =VICVectPri0	; addr = VICVectPri0;
	MOV	R6, #0xF		; pri = 15;
	STR	R6, [R5, R3, LSL #2]	; Memory.Word(addr + vector * 4); = pri;
	
	; Set handler address
	LDR	R5, =VICVectAddr0	; addr = VICVectAddr0;
	LDR	R6, =ButtonHandler	; handler = address of ButtonHandler;
	STR	R6, [R5, R3, LSL #2]	; Memory.Word(addr + vector * 4) = handler;

	
	; VICIntEnable
	LDR	R5, =VICIntEnable	; addr = VICVectEnable;
	STR	R4, [R5]		; enable interrupts for vector 0x14

	
		

	
	
	
	;TIMER0 INITIALISATION //Copied directly from Timer.uvproj
	
	;
	; Configure TIMER0 for 1 second interrupts
	;
	
	; Stop and reset TIMER0 using Timer Control Register
	; Set bit 0 of TCR to 0 to diasble TIMER
	; Set bit 1 of TCR to 1 to reset TIMER
	
	LDR	R5, =T0TCR
	LDR	R6, =0x2
	STRB	R6, [R5]

	; Clear any previous TIMER0 interrupt by writing 0xFF to the TIMER0
	; Interrupt Register (T0IR)
	LDR	R5, =T0IR
	LDR	R6, =0xFF
	STRB	R6, [R5]

	; Set timer mode using Count Timer Control Register
	; Set bits 0 and 1 of CTCR to 00
	; for timer mode
	LDR	R5, =T0CTCR
	LDR	R6, =0x00
	STRB	R6, [R5]

	; Set match register for 10 sec using Match Register
	; Assuming a 12Mhz clock, set MR to 12,000,000
	LDR	R5, =T0MR0
	LDR	R6, =42000000
	STR	R6, [R5]

	; Interrupt and restart on match using Match Control Register
	; Set bit 0 of MCR to 1 to turn on interrupts
	; Set bit 1 of MCR to 1 to reset counter to 0 after every match
	; Set bit 2 of MCR to 0 to leave the counter enabled after match
	LDR	R5, =T0MCR
	LDR	R6, =0x03
	STRH	R6, [R5]

	; Turn off prescaling using Prescale Register
	; (prescaling is only needed to measure long intervals)
	LDR	R5, =T0PR
	LDR	R6, =0
	STR	R6, [R5]

	;
	; Configure VIC for TIMER0 interrupts
	;

	; Useful VIC vector numbers and masks for following code
	LDR	R3, =4			; vector 4
	LDR	R4, =(1 << 4) 	; bit mask for vector 4
	
	; VICIntSelect - Clear bit 4 of VICIntSelect register to cause
	; channel 4 (TIMER0) to raise IRQs (not FIQs)
	LDR	R5, =VICIntSelect	; addr = VICVectSelect;
	LDR	R6, [R5]		; tmp = Memory.Word(addr);		
	BIC	R6, R6, R4		; Clear bit for Vector 0x04
	STR	R6, [R5]		; Memory.Word(addr) = tmp;
	
	; Set Priority for VIC channel 4 (TIMER0) to lowest (15) by setting
	; VICVectPri4 to 15. Note: VICVectPri4 is the element at index 4 of an
	; array of 4-byte values that starts at VICVectPri0.
	; i.e. VICVectPri4=VICVectPri0+(4*4)
	LDR	R5, =VICVectPri0	; addr = VICVectPri0;
	MOV	R6, #15			; pri = 15;
	STR	R6, [R5, R3, LSL #2]	; Memory.Word(addr + vector * 4); = pri;
	
	; Set Handler routine address for VIC channel 4 (TIMER0) to address of
	; our handler routine (TimerHandler). Note: VICVectAddr4 is the element
	; at index 4 of an array of 4-byte values that starts at VICVectAddr0.
	; i.e. VICVectAddr4=VICVectAddr0+(4*4)
	LDR	R5, =VICVectAddr0	; addr = VICVectAddr0;
	LDR	R6, =TIMER0Handler	; handler = address of TimerHandler;
	STR	R6, [R5, R3, LSL #2]	; Memory.Word(addr + vector * 4) = handler

	
	; Enable VIC channel 4 (TIMER0) by writing a 1 to bit 4 of VICIntEnable
	LDR	R5, =VICIntEnable	; addr = VICIntEnable;
	STR	R4, [R5]		; enable Timers for vector 0x4
	
	
	
	
	
	
	;TIMER1 INITIALISATION	//taken directly from buzzer.uvproj, 	(except I changed addresses from TIMER0 -> TIMER1, etc)
	
	;
	; Configure TIMER1 to generate frequency for middle C
	;
	
	; Stop and reset TIMER0
	LDR	R5, =T1TCR
	LDR	R6, =0x2
	STRB	R6, [R5]

	; Set timer mode
	LDR	R5, =T1CTCR
	LDR	R6, =0x00
	STRB	R6, [R5]

	; Set match register for 1 sec
	LDR	R5, =T1MR0 ;//IS THAT ZERO AT THE END DEPENDANT ON THE TIMER DEVICE?
	LDR	R6, =22934 ;  12MHz / (261.626Hz * 2)
	STR	R6, [R5]

	; Configure to interrupt and restart on match
	LDR	R5, =T1MCR
	LDR	R6, =0x03
	STRH	R6, [R5]

	; Set prescale = 1 (no prescaling)
	LDR	R5, =T1PR
	LDR	R6, =0		; Set to (wanted prescale - 1)
	STR	R6, [R5]	
	
	; NOTE: We won't start TIMER1 until the TIMER0 interrupt is called
	;       (See TIMER0 interrupt handler)
	
	
	;
	; Configure VIC for TIMER 1 (table 7-116 in User manual, VIC channel # is 5 and bit mask is 0x0000 0020
	;
	
	; Just some useful values
	LDR	R3, =5			; vector 5
	LDR	R4, =2			;
	MOV	R4, R4, LSL #4 		; vector mask (IMPORTANT!!!!! THIS WAS MODIFIED FROM THE ORIGINAL BECUASE i THINK THE MASK SHOULD EQUAL 0x20
	
	; VICIntSelect - Set Vector 0x04 for IRQ (clear bit 5)
	LDR	R5, =VICIntSelect	; addr = VICVectSelect;
	LDR	R6, [R5]		; tmp = Memory.Word(addr);		
	BIC	R6, R6, R4		; Clear bit for Vector 0x05
	STR	R6, [R5]		; Memory.Word(addr) = tmp;
	
	; Set Priority to lowest (15)
	LDR	R5, =VICVectPri0	; addr = VICVectPri0;
	MOV	R6, #0xF		; pri = 15;
	STR	R6, [R5, R3, LSL #2]	; Memory.Word(addr + vector * 4); = pri;
	
	; Set handler address
	LDR	R5, =VICVectAddr0	; addr = VICVectAddr0;
	LDR	R6, =TIMER1Handler	; handler = address of TIMER1Handler;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!(make sure the handler label is called this)
	STR	R6, [R5, R3, LSL #2]	; Memory.Word(addr + vector * 4) = handler

	; VICIntEnable
	LDR	R5, =VICIntEnable	; addr = VICIntEnable;
	STR	R4, [R5]		; enable Timers for vector 0x5
	
	
	
	
	;BUZZER INITIALISATION
	
	;
	; Configure DAC	(Digital to Audio Converter)
	;

	; Configure pin P0.26 for AOUT (DAC analog out)
	LDR	R5, =PINSEL1
	LDR	R6, [R5]
	BIC	R6, R6, #(0x03 << 20)
	ORR	R6, R6, #(0x02 << 20)
	STR	R6, [R5]

	; DAC is always on so no further configuration required
	
	
	
	
	;START TIMER0
	
	LDR R5, =T0TCR
	LDR R6, = 0x00	;reset count, enable timer
	STRB R6, [R5]
	

	
stop	B	stop


	;interrupt handlers go here
	
ButtonHandler	;NOT COPIED, WRITTEN

	SUB LR, LR, #4
	
	STMFD SP!, {R0-R12,LR}
	LDR R5, =T0TCR
	LDR R6, [R5]
	
	;whatever state the first bit of TOTCR is in, invert it (bit-1 = enable/disable)
	EOR R6, R6, #1
	
	STRB R6, [R5]
	
	
	LDR R5, =VICVectAddr
	MOV R6, #0
	STR R6, [R5]
	
	LDMFD SP!, {R0-R12, PC}^
	
TIMER0Handler	;not copied, written
	
	SUB	LR, LR, #4		; Adjust return address
	
	STMFD	sp!, {r0-r12, LR}	; save registers
	
	LDR R0, =secondTIMER0interrupt
	CMP R0, #1
	BEQ TIMER0Handler2

	;start TIMER1 (TIMER1 handler will sound the buzzer)
	LDR R5, =T1TCR	
	LDR R6, =0x01
	STRB R6, [R5]
	

	;;reset TIMER0 count value, and stop the timer (ACTUALLY, THIS SHOULD HAVE ALREADY BEEN DONE BY THE MATCH REGISTER I THINK! see TIMER0 initialisation)
	LDR	R5, =T0TCR
	LDR	R6, =0x2
	STRB	R6, [R5]
	
	
	;;change own match register,
	
	; Set match register for 5 seconds using Match Register
	; Assuming a 12Mhz clock, set MR to 60'000'000
	LDR	R5, =T0MR0
	LDR	R6, = 60000000
	STR	R6, [R5]
	
	
	
	; Interrupt and restart on match using Match Control Register
	; Set bit 0 of MCR to 1 to turn on interrupts
	; Set bit 1 of MCR to 1 to reset counter to 0 after every match
	; Set bit 2 of MCR to 1 to leave the counter disabled after match	//IMPORTANT!!!!!!! YOU MAY WANT TO CHANGE THIS, DEPENDING ON END HANDLER
	LDR	R5, =T0MCR
	LDR	R6, =0x07	;MCR = 0x...0111
	STRH	R6, [R5]
	
	LDR R5, =secondTIMER0interrupt	;secondTIMER0interrupt = true
	LDR R4, =1
	STRB R4, [R5]
	
	
	;So what should happen now is, TIMER0 will run again for 5 seconds, 
	;while the periodic interrupts of TIMER1 causes the buzzer to sound.
	;After 5 seconds, TIMER0 will throw an interrupt request, but this time will skip the first handler, and 
	;move on to the second handler (below).
	;This second handler disables TIMER0 and TIMER1,
	;then terminates the program (B stop)
	B skipNextSection
	
TIMER0Handler2	
	
	;disable TIMER0
	LDR	R5, =T0TCR
	LDR	R6, =0x2
	STRB	R6, [R5]
	
	;disable TIMER1
	LDR	R5, =T1TCR
	LDR	R6, =0x2
	STRB	R6, [R5]
	
	;TERMINATE PROGRAM
	;
	; Clear source of interrupt by writing 0 to VICVectAddr
	;
	
	LDR	R5, =VICVectAddr
	MOV	R6, #0		
	STR	R6, [R5]
	
	B stop
	
	
	
skipNextSection
	;;end of TIMER0Handler function
	
	;
	; Clear source of interrupt by writing 0 to VICVectAddr
	;
	
	LDR	R5, =VICVectAddr
	MOV	R6, #0		
	STR	R6, [R5]	
	
	
	;
	; Return
	;
	LDMFD	sp!, {r0-r12, PC}^	; restore register and CPSR

	
	

TIMER1Handler	;COPIED DIRECTLY FROM buzz.uvproj, adjusted relevant TIMER0 code to TIMER1 code
	
	SUB	LR, LR, #4		; Adjust return address
	STMFD	sp!, {r0-r12, LR}	; save registers
	
	;
	; Reset TIMER1 interrupt by writing 0xFF to T1IR
	;
	LDR	R5, =T1IR
	MOV	R6, #0xFF
	STRB	R6, [R5]
	
	
	;
	; Change analog output to cause square wave signal
	; If signal is currently high, send it low. If its low, send it high
	;
	
	; Load the current DAC output value
	LDR	R5, =DACR
	LDR	R6, [R5]
	
	; Mask out all but bits 15...6
	LDR	R7, =0x0000FFC0
	AND	R6, R6, R7
	
	CMP	R6, #0			; if (DACR == 0)
	BNE	high			; {
	LDR	R6, =(volume << 6)	;  DACR = volume << 6
	B	endif			; }
high					; else {
	LDR	R6, =0			;  DACR = 0
endif					; }
	STR	R6, [R5]		; store new DACR


	;
	; Clear source of interrupt by writing 0 to VICVectAddr
	;
	
	LDR	R5, =VICVectAddr
	MOV	R6, #0		
	STR	R6, [R5]	
	
	
	;
	; Return
	;
	LDMFD	sp!, {r0-r12, PC}^	; restore register and CPSR
	


	END	
	