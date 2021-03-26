TITLE Low-level I/O procedures
; Author: Daniel Sarran
; Description:	Program requests user input for 10 integers, where each
;				integer is small enough to fit inside a 32-bit register.
;				Each entry is validated for size (not greater than 32-bit),
;				and numerical digits (with exception of the first character
;				Which can be a +/- to denote sign. Each user input string is 
;				converted to integer via ASCII character arithmetic. The 10
;				inputs are stored to a global buffer, where each integer is 
;				converted back to string, printed to user, as well as the sum
;				and rounded (down) average.
;

INCLUDE Irvine32.inc

; -----------------------------------------------------------------------------
; Name: mGetString
;
; Macro prompts user for input, stores input up to size 'count' to buffer. 
; Stores number of bytes read from unser into 'charsEntered' parameter.
;
; Preconditions: 
;	Prompt is a string.
;	Input will only be stored up to length 'count'.
;	Count is a positive integer.
;	charsEntered is type DWORD.
;
; Postconditions: 
;	None.
;
; Receives:
;	prompt			= string pointer, prompts user prior to ReadString
;	buffer			= array buffer pointer to store user string
;	count			= integer pointer, integer value is positive
;	charsEntered	= integer pointer, will be overwritten after read
;
; Returns: 
;	charsEntered	= number of bytes read by ReadString
;	buffer			= stored user input string
; -----------------------------------------------------------------------------
mGetString MACRO prompt_ref, buffer_ref, count, bytesRead_ref
	PUSHAD

	mov		edx, prompt_ref
	call	WriteString

	mov		edx, buffer_ref
	mov		ecx, count
	call	ReadString
	mov		edi, bytesRead_ref
	mov		[edi], eax

	POPAD
ENDM

; -----------------------------------------------------------------------------
; Name: mDisplayString
;
; Macro receives a string pointer, and prints the string to user.
;
; Preconditions: 
;	The 'string' parameter is a string.
;
; Postconditions: 
;	None.
;
; Receives:
;	string			= string (BYTE array)
;
; Returns: 
;	None
; -----------------------------------------------------------------------------
mDisplayString MACRO string
	PUSH	edx

	mov		edx, string
	call	WriteString

	POP		edx
ENDM

; Constants
INPUT_SIZE = 256
INPUT_COUNT = 10
MAX_INTEGER = 2147483647
MIN_INTEGER = -2147483648

.data
; Introduction procedure data labels
programTitle	BYTE	"Designing Low-Level I/O Procedures:",13,10,
						"Written by Daniel Sarran",13,10,13,10,0
programDesc		BYTE	"Please provide 10 signed decimal integers.",13,10,
						"Each number needs to be small enough to fit inside",
						" a signed 32 bit value. After you have finished inputting ",
						"the raw numbers I will display a list of the integers,",
						" their sum, and their average value.",13,10,13,10,0

; Fill Array procedure data labels
userPrompt		BYTE	"Please enter a signed number: ",0
userString		BYTE	INPUT_SIZE DUP(?)
error			BYTE	"    (Invalid input, please try again.)",13,10,0
numericVal		DWORD	?
numValuesArray	DWORD	INPUT_COUNT DUP(0)
parenDelimiter	BYTE	") ",0

; Extra Credit 1 data labels
subtotalText	BYTE	"    Subtotal:  ",0

; Print Array procedure data labels
arrayText		BYTE	"You entered the following numbers: ",13,10,0
delimiter		BYTE	", ",0


; Print Sum procedure data labels
sumText			BYTE	"The sum of these numbers is: ",0
sum				SDWORD	0

; Print Average procedure data labels
averageText		BYTE	"The rounded average is (floor/ round down): ",0
average			SDWORD	0

; Goodbye procedure data labels
programEnd		BYTE	"Thank you and goodbye!",13,10,0

.code
; -----------------------------------------------------------------------------
; Program Hierarchy:
;
; main
;	|__introduction
;	|
;	|__fillIntegerArray
;	|	|
;	|	|__ReadVal
;	|	|	|
;	|	|   |__WriteVal (EC 1: numbering line of user input)
;	|	|	|
;	|	|	|__mGetString
;	|	|
;	|	|__printSum (EC 1: running subtotal)
;	|	
;	|__printArray
;	|	|
;	|	|__WriteVal
;	|	|	|
;	|	|   |__mDisplayString (user's integer)
;	|	|
;	|	|__mDisplayString (delimiter between integers)
;	|
;	|__printSum
;	|	|
;	|	|__mDisplayString (sum of integers)
;	|
;	|__printAverage
;	|	|
;	|	|__mDisplayString (average of integers)
;	|
;	|__goodbye
;
; -----------------------------------------------------------------------------
main PROC
	; -------------------------------------------------------------------------
	; Introduction:
	; Introduce title, author, and description of program
	; -------------------------------------------------------------------------
	PUSH	OFFSET programTitle
	PUSH	OFFSET programDesc
	call	introduction

	; -------------------------------------------------------------------------
	; Fill Array:
	; (1) Get *valid* integers from user
	; (2) Convert user strings to integers
	; (3) Store integers into array via register indirect addressing
	; -------------------------------------------------------------------------
	PUSH	OFFSET subtotalText
	PUSH	OFFSET parenDelimiter
	PUSH	OFFSET numValuesArray
	PUSH	OFFSET userString
	PUSH	OFFSET error
	PUSH	OFFSET numericVal
	PUSH	OFFSET userPrompt
	call	fillArray

	; -------------------------------------------------------------------------
	; Print Array:
	; Read integers from array, convert to string, and print to user
	; -------------------------------------------------------------------------
	PUSH	OFFSET arrayText
	PUSH	OFFSET numValuesArray
	PUSH	OFFSET delimiter
	call	printArray
	
	; -------------------------------------------------------------------------
	; Print Sum:
	; Calculate sum of values, convert to string, and print to user
	; -------------------------------------------------------------------------
	PUSH	OFFSET sum
	PUSH	OFFSET sumText
	PUSH	OFFSET numValuesArray
	call	printSum

	; -------------------------------------------------------------------------
	; Print Average:
	; Calculate average (round down integer), convert to string, print to user
	; -------------------------------------------------------------------------	
	PUSH	OFFSET sum
	PUSH	OFFSET average
	PUSH	OFFSET averageText
	call	printAverage

	; -------------------------------------------------------------------------
	; Goodbye:
	; Farewell greeting to user, end of program
	; -------------------------------------------------------------------------	
	PUSH	OFFSET programEnd
	call	goodbye

	Invoke ExitProcess,0	; exit to operating system
main ENDP

; -----------------------------------------------------------------------------
; Name: introduction
;
; Introduces program, author, and description of program to user.
;
; Preconditions: 
;	Received parameters via runtime stack are strings.
;
; Postconditions: 
;	None.
;
; Receives:
;	[ebp+12]		= string, program title/author
;	[ebp+8]			= string, program description
;
; Returns: 
;	None.
; -----------------------------------------------------------------------------
introduction PROC
	PUSH	ebp
	mov		ebp, esp
	PUSH	edx

	mDisplayString	[ebp + 12]
	mDisplayString	[ebp + 8]

	POP		edx
	POP		ebp
	RET		8
introduction ENDP

; -----------------------------------------------------------------------------
; Name: fillArray
;
; Receives user inputs, converts the strings to integers, stores to array.
; The user inputs are validated per the 'ReadVal' procedure.
;
; Local variables:	
;	'line':	numbering of user input #
;	'subtotal': the running subtotal of user integers
;
; Preconditions: 
;	The array is of type SDWORD as resultant integers may be positive or 
;	negative. Parameter types listed in "receives" section.
;
; Postconditions: 
;	None.
;
; Receives:
;	[ebp + 32]		= string, subtotalText pointer
;	[ebp + 28]		= string, parenDelimiter pointer
;	[ebp + 24]		= SDWORD array, numValuesArray pointer
;	[ebp + 20]		= BYTE array (buffer), userString pointer
;	[ebp + 16]		= string, error pointer
;	[ebp + 12]		= DWORD, numericVal pointer
;	[ebp + 8]		= string, userPrompt pointer
;
; Returns: 
;	numValuesArray	= generated array of 10 user integers
; -----------------------------------------------------------------------------
fillArray PROC
	LOCAL	line:DWORD,
			subtotal:SDWORD		
	PUSHAD

	mov		ecx, INPUT_COUNT
	mov		edi, [ebp + 24]
	mov		line, 1
	lea		edx, line
	
	; -------------------------------------------------------------------------
	; Loop to receive user input & store to array, iterate INPUT_COUNT times
	; -------------------------------------------------------------------------
	_inputConvertAndStoreLoop:
	PUSH	edx
	PUSH	[ebp + 28]
	PUSH	[ebp + 20]
	PUSH	[ebp + 16]
	PUSH	[ebp + 12]
	PUSH	[ebp + 8]
	call	ReadVal			; ReadVal uses WriteVal to print the line numbering

	; -------------------------------------------------------------------------
	; Store the converted numeric values into next index of numValuesArray
	; -------------------------------------------------------------------------
	mov		ebx, [ebp + 12]
	mov		eax, [ebx]
	inc		esi
	inc		line
	STOSD

	; -------------------------------------------------------------------------
	; Print the running subtotal so far, printSum uses WriteVal
	; -------------------------------------------------------------------------
	PUSH	subtotal
	PUSH	[ebp + 32]
	PUSH	[ebp + 24]
	call	printSum

	LOOP	_inputConvertAndStoreLoop

	call	crlf

	POPAD
	ret		28
fillArray ENDP

; -----------------------------------------------------------------------------
; Name: printArray
;
; Traverse array and call 'WriteVal' to convert integer array into strings,
; before printing to user.
;
; Preconditions: 
;	The array is of type SDWORD and already filled with integers.
;
; Postconditions: 
;	None.
;
; Receives:
;	[ebp+16]	= string, arrayText pointer
;	[ebp+12]	= SDWORD array, numValuesArray pointer
;	[ebp+8]		= string, delimiter (the ', ' between numbers printed)
;
; Returns: 
;	None.
; -----------------------------------------------------------------------------
printArray PROC
	PUSH	ebp
	mov		ebp, esp
	PUSHAD

	; -------------------------------------------------------------------------
	; Print brief description of array being printed
	; -------------------------------------------------------------------------
	mDisplayString	[ebp + 16]
	
	; -------------------------------------------------------------------------
	; Traverse array, use WriteVal for conversion of 'integer -> string', print 
	; string values to user
	; -------------------------------------------------------------------------
	mov		ecx, INPUT_COUNT
	mov		esi, [ebp + 12]

	_printLoop:
	PUSH	esi					; array printout calls WriteVal to print number
	call	WriteVal

	cmp		ecx, 1				; last element does not have a delimiter
	je		_end

	mDisplayString	[ebp + 8]	; delimiter prints comma between integers
	add		esi, 4
	LOOP	_printLoop

	_end:
	call	crlf
	call	crlf
	POPAD
	POP		ebp
	ret		12
printArray ENDP


; -----------------------------------------------------------------------------
; Name: printSum
;
; Calculates the sum of integers in array, and prints this sum to user along 
; with a brief description.
;
; Preconditions: 
;	The array is of type SDWORD and has already been filled with integers.
;	The array is of length INPUT_COUNT.
;
; Postconditions: 
;	none.
;
; Receives:
;	[ebp+16]	= SDWORD integer pointer	sum (output parameter)
;	[ebp+12]	= string pointer			description of sum
;	[ebp+8]		= SDWORD array pointer		array of integer elements
;
; Returns: 
;	sum			= sum of elements in array
; -----------------------------------------------------------------------------
printSum PROC
	PUSH	ebp
	mov		ebp, esp
	PUSHAD	

	; -------------------------------------------------------------------------
	; Print description of sum
	; -------------------------------------------------------------------------
	mDisplayString	[ebp + 12]

	; -------------------------------------------------------------------------
	; Calculate sum of array values
	; -------------------------------------------------------------------------
	; Setup loop, source and destination registers, initialize sum to 0
	mov		edi, [ebp + 16]
	mov		ebx, 0		
	mov		[edi], ebx	; initialize sum to 0
	mov		esi, [ebp + 8]
	mov		ecx, INPUT_COUNT
	CLD
	_calculateSum:
	LODSD
	add		ebx, eax
	LOOP	_calculateSum

	; -------------------------------------------------------------------------
	; Store sum value in memory
	; -------------------------------------------------------------------------
	mov		[edi], ebx

	; -------------------------------------------------------------------------
	; Print sum value to user
	; -------------------------------------------------------------------------
	PUSH	edi
	call	WriteVal

	call	crlf
	call	crlf
	POPAD
	POP		ebp
	ret		12
printSum ENDP

; -----------------------------------------------------------------------------
; Name: printAverage
;
; Calculates the rounded down/ floor average of integers in array, and prints
; this average to user along with a brief description.
;
; Preconditions: 
;	The array is of type SDWORD and has already been filled with integers.
;	The array is of length INPUT_COUNT.
;
; Postconditions: 
;	None.
;
; Receives:
;	[ebp+16]	= SDWORD integer pointer	sum
;	[ebp+12]	= SDWORD integer pointer	average (output parameter)
;	[ebp+8]		= string pointer			description of average
;
; Returns: 
;	average		= average of elements in array
; -----------------------------------------------------------------------------
printAverage PROC
	PUSH	ebp
	mov		ebp, esp
	PUSHAD

	; -------------------------------------------------------------------------
	; Print description of average
	; -------------------------------------------------------------------------
	mDisplayString	[ebp + 8]

	; -------------------------------------------------------------------------
	; Calculate average of array values, rounded down
	; -------------------------------------------------------------------------	
	mov		esi, [ebp + 16]
	mov		eax, [esi]
	cdq
	mov		ebx, INPUT_COUNT
	idiv	ebx

	; -------------------------------------------------------------------------
	; Store average value in memory
	; -------------------------------------------------------------------------
	mov		edi, [ebp + 12]
	mov		[edi], eax

	; -------------------------------------------------------------------------
	; Print average value to user
	; -------------------------------------------------------------------------
	PUSH	[ebp + 12]
	call	WriteVal
	
	call	crlf
	call	crlf
	POPAD
	POP		ebp
	ret 12
printAverage ENDP


; -----------------------------------------------------------------------------
; Name: ReadVal
;
; Prompts user for integer, executes data validation on received input string.
; If the input string is invalid, discards input and prompts for input again.
; Valid input is converted from string to integer as part of validation loop.
;
; Validation Rules:
; 1) Non-numeric characters are invalid
;	e.g. 0-9 valid
;	e.g. 'a'-'z', 'A'-'Z', special characters, etc. invalid
;
; 2) Leading 0s, +, or - special characters are valid
;	e.g. '000123' -> 123
;	e.g. '+23' -> 23
;	e.g. '-10001' -> -10001
;	Note: a single "+" or "-" with no integer is invalid
;	Note: multiple "+/-" or non-leading "+/-" characters are invalid
;
; 3) Integers entered must fit within a 32-bit SDWORD
;	e.g. greater than constant MAX_INTEGER
;	e.g. less than constant MIN_INTEGER
;
; Local Variables:
;	'bytesRead': stores the number of bytes read following user input
;	'integer': stores the integer value during conversion of string to int
;	'isNegative': used as a "flag" 
;		- 0, clear - integer is positive
;		- 1, set - integer is negative
;
; Preconditions: 
;	BYTE array buffer [ebp + 20] is at least of size INPUT_SIZE
;
; Postconditions: 
;	none.
;
; Receives:
;	[ebp + 28]		= DWORD integer pointer	line numbering counter for inputs
;	[ebp + 24]		= string pointer		symbols following line number
;	[ebp + 20]		= BYTE array pointer	buffer to store user input
;	[ebp + 16]		= string pointer		error message
;	[ebp + 12]		= DWORD integer pointer	numeric conversion (output parameter)
;	[ebp + 8]		= string pointer		prompt message for input
;
; Returns: 
;	numericVal		= converted numeric value of user input string
; -----------------------------------------------------------------------------
ReadVal PROC
	LOCAL	bytesRead:DWORD, 
			integer:DWORD, 
			isNegative:BYTE, 
			character:DWORD
	PUSHAD
	mov		esi, [ebp + 20]

	; -------------------------------------------------------------------------
	; Validation loop: 
	; 1) Prompt for input 
	; 2) Check for invalid characters
	; 3) Convert input string to integer, & validate integer value
	; -------------------------------------------------------------------------
	_promptInput:
	xor		eax, eax
	lea		ebx, bytesRead

	; Input line numbering
	PUSH	[ebp + 28]			
	call	WriteVal

	; Characters after line numbering (e.g. 1), 2) or  1., 2. etc)
	mDisplayString	[ebp + 24]

	; -------------------------------------------------------------------------
	; 1) Prompt for input 
	; -------------------------------------------------------------------------
	mGetString	[ebp+8], esi, INPUT_SIZE, ebx

	; -------------------------------------------------------------------------
	; 2) During conversion, check for invalid characters
	;	a. Leading sign can be '+', '-', or '0' through '9'
	;	b. Remaining characters are '0' - '9' only
	; -------------------------------------------------------------------------
	LODSB					; load first byte of user input into AL
	mov		integer, 0
	mov		isNegative, 0
	mov		ecx, bytesRead
	CLD
	
	; -------------------------------------------------------------------------
	; 2) a. Leading sign can be '+', '-', or '0' through '9'
	; -------------------------------------------------------------------------
	cmp		AL, 2Bh			; 2Bh is ASCII hex for '+'
	je		_leadingPlus
	cmp		AL, 2Dh			; 2Dh is ASCII hex for '-'
	je		_leadingMinus
	jmp		_firstChar

	; If first char is sign, must be followed by an integer - otherwise invalid
	_leadingPlus:
	cmp		bytesRead, 2
	jb		_error
	sub		ecx, 1
	jmp		_loopUserInput
	_leadingMinus:
	cmp		bytesRead, 2
	jb		_error
	mov		isNegative, 1
	sub		ecx, 1

	; -------------------------------------------------------------------------
	; 2) b. Remaining characters are '0' - '9' only
	; -------------------------------------------------------------------------	
	_loopUserInput:
		xor		eax, eax
		xor		ebx, ebx
		xor		edx, edx
		LODSB
		
		_firstChar:
		; 30h is hex value for ASCII '0' character
		cmp		AL, 30h		
		jl		_error
		; 39h is hex value for ASCII '9' character
		cmp		AL, 39h		
		jg		_error

		; ---------------------------------------------------------------------
		; 3) Convert input string to integer & validate integer value
		; 
		;	Conversion algorithm:
		;	integer = 10 * integer + (character - 48d)
		; ---------------------------------------------------------------------
		mov		character, eax
		mov		eax, integer
		mov		ebx, 10
		imul	ebx				; integer = integer * 10 (imul for SDWORD range)

		; Since integer should be SDWORD size, upper 32 bits should be clear
		; following multiplication (e.g. edx is still clear, no overflow)
		cmp		edx, 0
		jnz		_error
		add		eax, character 	; integer = integer + char
		sub		eax, 30h		; integer = integer - 48
		mov		integer, eax
		LOOP	_loopUserInput

	jmp		_storeNumericValue
	; Validation error: display error message and re-prompt for input
	_error:					
	mDisplayString	[ebp + 16]
	jmp		_promptInput

	; -------------------------------------------------------------------------
	; Store numeric value now that string has been validated & converted.
	; There are two cases: (1) integer is positive (2) integer is negative.
	; -------------------------------------------------------------------------
	_storeNumericValue:
	cmp		isNegative, 1
	je		_storeNegativeNumericValue

	; Store positive numeric value, as long as it is not too large for SDWORD
	cmp		eax, MAX_INTEGER
	ja		_error
	mov		eax, integer
	mov		edi, [ebp+12]
	mov		[edi], eax
	jmp		_end

	; Store negative numeric value, as long as it is not too small for SDWORD
	_storeNegativeNumericValue:
	mov		eax, integer
	neg		eax
	cmp		eax, MIN_INTEGER
	jb		_error
	mov		edi, [ebp+12]
	mov		[edi], eax

	_end:
	POPAD
	RET		24
ReadVal ENDP

; -----------------------------------------------------------------------------
; Name: WriteVal
;
; WriteVal receives an integer and converts it into a string representation of
; that integer in ASCII digits.
;
; For negative integers, we flag an "isNegative" local variable
; and treat the number as a positive number during conversion. Once
; conversion is complete, we review the "isNegative flag" to prepend the
; negative sign.
;
; Local Variables:
;	'convertedString': intermediate step of int-to-string conversion where string
;		representation is in reverse order of integer to print
;	'isNegative': used as a "flag"
;		- 0, clear - integer is positive
;		- 1, set - integer is negative
;	'integerLength': stores the length of integer during conversion to string
;	'resultString': final resulting string from int-to-string conversion
;
; Preconditions: 
;	[ebp + 8] is of type SDWORD.
;
; Postconditions: 
;	None.
;
; Receives:
;	[ebp+8]		= SDWORD integer pointer	integer value to print to user
;
; Returns: 
;	None.
; -----------------------------------------------------------------------------
WriteVal PROC
	LOCAL	convertedString[INPUT_SIZE]:BYTE, 
			isNegative:BYTE, 
			integerLength:DWORD,
			resultString[INPUT_SIZE]:BYTE
	PUSHAD
	; Setup source register, pass value at address to eax
	mov		esi, [ebp + 8]
	mov		eax, [esi]

	; -------------------------------------------------------------------------
	; Determine sign of the integer, by default "isNegative" flag is clear (0)
	; -------------------------------------------------------------------------
	mov		isNegative, 0
	cmp		eax, 0
	jl		_negativeInteger
	jmp		_beginConversion
	; Set "isNegative" flag, negative integer
	_negativeInteger:
	neg		eax
	mov		isNegative, 1

	; -------------------------------------------------------------------------
	; Integer to ASCII digit conversion
	;
	;	Conversion algorithm:
	;	- Divide integer by 10
	;	- Convert remainder to its ASCII equivalent, e.g. 0 -> '0'
	;	- Append ASCII digit to string
	;	- Increment integerLength
	;	- Repeat until quotient is 0
	; -------------------------------------------------------------------------
	_beginConversion:
	; Setup source register, reset integer length to 0
	lea		edi, convertedString
	mov		integerLength, 0
	CLD
	_divideUntilZero:
	xor		edx, edx
	cdq
	mov		ebx, 10
	; Divide integer by 10
	idiv	ebx
	; Convert remainder to its ASCII equivalent
	add		edx, 30h
	; Append ASCII digit
	PUSH	eax
	mov		eax, edx
	STOSB
	POP		eax
	; Increment integerLength
	inc		integerLength
	cmp		eax, 0
	; Repeat until quotient is 0
	jnz		_divideUntilZero

	; -------------------------------------------------------------------------
	; Prepend negative sign, if integer was negative
	; Reverse the converted string
	;	(Since conversion algorithm results in "backwards" string)
	; -------------------------------------------------------------------------
	; Setup loop, source, and destination registers
	mov		ecx, integerLength
	lea		esi, convertedString
	add		esi, ecx
	sub		esi, 1
	lea		edi, resultString
	; Prepend negative sign, if integer was negative
	cmp		isNegative, 1
	jnz		_revLoop
	mov		eax, 2Dh
	STOSB
	; Reverse the string
	_revLoop:
	STD
	LODSB
	CLD
	STOSB
	LOOP   _revLoop

	; -------------------------------------------------------------------------
	; Add terminating "null character" 0 to string
	; -------------------------------------------------------------------------
	mov		eax, 0
	STOSB

	; -------------------------------------------------------------------------
	; Print to user
	; -------------------------------------------------------------------------
	lea		esi, resultString
	mDisplayString		esi

	POPAD
	RET		4
WriteVal ENDP


; -----------------------------------------------------------------------------
; Name: goodbye
;
; Farewell message to user.
;
; Preconditions: 
;	Received parameter is a string (BYTE array).
;
; Postconditions: 
;	None.
;
; Receives:
;	[ebp+16]	= string pointer			farewell message
;
; Returns: 
;	None.
; -----------------------------------------------------------------------------
goodbye PROC
	PUSH	ebp
	mov		ebp, esp

	mDisplayString	[ebp + 8]

	call	crlf
	call	crlf
	POP		ebp
	ret		4
goodbye ENDP

END main
