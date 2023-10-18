.386
.model flat, stdcall
.stack 10448576
option casemap:none

; ========== LIBRERIAS =============
include masm32\include\windows.inc 
include masm32\include\kernel32.inc
include masm32\include\user32.inc
includelib masm32\lib\kernel32.lib
includelib masm32\lib\user32.lib
include masm32\include\gdi32.inc
includelib masm32\lib\Gdi32.lib
include masm32\include\msimg32.inc
includelib masm32\lib\msimg32.lib
include masm32\include\winmm.inc
includelib masm32\lib\winmm.lib
include masm32\include\msvcrt.inc
includelib masm32\lib\msvcrt.lib

; ================ PROTOTIPOS ======================================
; Delcaramos los prototipos que no están declarados en las librerias
; (Son funciones que nosotros hicimos)
main			proto
credits			proto	:DWORD
playMusic		proto
joystickError	proto
WinMain			proto	:DWORD, :DWORD, :DWORD, :DWORD

; =========================================== DECLARACION DE VARIABLES =====================================================
.data
; ==========================================================================================================================
; =============================== VARIABLES QUE NORMALMENTE NO VAN A TENER QUE CAMBIAR =====================================
; ==========================================================================================================================
className				db			"ProyectoEnsamblador",0		; Se usa para declarar el nombre del "estilo" de la ventana.
windowHandler			dword		?							; Un HWND auxiliar
windowClass				WNDCLASSEX	<>							; Aqui es en donde registramos la "clase" de la ventana.
windowMessage			MSG			<>							; Sirve pare el ciclo de mensajes (los del WHILE infinito)
clientRect				RECT		<>							; Un RECT auxilar, representa el área usable de la ventana
windowContext			HDC			?							; El contexto de la ventana
layer					HBITMAP		?							; El lienzo, donde dibujaremos cosas
layerContext			HDC			?							; El contexto del lienzo
auxiliarLayer			HBITMAP		?							; Un lienzo auxiliar
auxiliarLayerContext	HBITMAP		?							; El contexto del lienzo auxiliar
clearColor				HBRUSH		?							; El color de limpiado de pantalla
windowPaintstruct		PAINTSTRUCT	<>							; El paintstruct de la ventana.
joystickInfo			JOYINFO		<>							; Información sobre el joystick
; Mensajes de error:
errorTitle				byte		'Error',0
joystickErrorText		byte		'No se pudo inicializar el joystick',0
; ==========================================================================================================================
; ========================================== VARIABLES QUE PROBABLEMENTE QUIERAN CAMBIAR ===================================
; ==========================================================================================================================
; El título de la ventana

windowTitle				db			"Plantilla Ensamblador",0
; El ancho de la venata CON TODO Y LA BARRA DE TITULO Y LOS MARGENES
windowWidth				DWORD		800
; El alto de la ventana CON TODO Y LA BARRA DE TITULO Y LOS MARGENES
windowHeight			DWORD		1280							
; Un string, se usa como título del messagebox NOTESE QUE TRAS ESCRIBIR EL STRING, SE LE CONCATENA UN 0
messageBoxTitle			byte		'Creditos:',0	
; Se usa como texto de un mensaje, el 10 es para hacer un salto de linea
; (Ya que 10 es el valor ascii de \n)
messageBoxText			byte		'Desarrollado por: Alberto Flores',10,'Gracias por jugar <3',0
; El nombre de la música a reproducir.
; Asegúrense de que sea .wav
musicFilename			byte		'rola.wav',0
; El manejador de la imagen a manuplar, pueden agregar tantos como necesiten.
image					HBITMAP		?
; El nombre de la imagen a cargar
imageFilename			byte		'mund.bmp',0


xOrigen sdword 674
yOrigen sdword 611

yFondo sdword 350

xPlayer sdword 300
yPlayer sdword 750

RectPlayer RECT <>
RectMueble1 RECT <>
RectMueble2 RECT <>
RectMueble3 RECT <>
RectCol RECT <>
RectUP RECT <>


xMueble1 sdword 300
yMueble1 sdword -150

xMueble2 sdword 32
yMueble2 sdword -400

xMueble3 sdword 600
yMueble3 sdword -750

Hearths sdword 224
xvida sdword 1
yvida sdword 0
Sizelife sdword 100

xStart sdword 780
yStart sdword 1220

Kms byte 12 dup (0)
Puntuacion sdword 0
TopRecord sdword 0

Play sdword 0
xPause sdword 0
yPause sdword 0

Random1 sdword 0
Fijo sdword 300

; =============== MACROS ===================
RGB MACRO red, green, blue
	exitm % blue shl 16 + green shl 8 + red
endm 

.code

main proc
	invoke crt_time,0
	invoke crt_srand, eax
	; El programa comienza aquí.
	; Le pedimos a un hilo que reprodusca la música

	invoke	CreateThread, 0, 0, playMusic, 0, 0, 0

	; Obtenemos nuestro HINSTANCE.
	; NOTA IMPORTANTE: Las funciones de WinAPI normalmente ponen el resultado de sus funciones en el registro EAX
	invoke	GetModuleHandleA, NULL   
	; Mandamos a llamar a WinMain
	; Noten que, como GetModuleHandleA nos regresa nuestro HINSTANCE y los resultados de las funciones de WinAPI
	; suelen estar en EAX, entonces puedo pasar a EAX como el HINSTANCE
	invoke	WinMain, eax, NULL, NULL, SW_SHOWDEFAULT
	; Cierra el programa
	invoke ExitProcess,0
main endp

; Este es el WinMain, donde se crea la ventana y se hace el ciclo de mensajes.
WinMain proc hInstance:dword, hPrevInst:dword, cmdLine:dword, cmdShow:DWORD
	; ============== INICIALIZACION DE LA CLASE ====================
	; Establecemos nuestro callback procedure, que en este caso se llama WindowCallback
	mov		windowClass.lpfnWndProc, OFFSET WindowCallback
	; Tenemos que decir el tamaño de nuestra estructura, si no se lo dicen no se podrá crear la ventana.
	mov		windowClass.cbSize, SIZEOF WNDCLASSEX
	; Le asignamos nuestro HINSTANCE
	mov		eax, hInstance
	mov		windowClass.hInstance, eax
	; Asignamos el nombre de nuestra "clase"
	mov		windowClass.lpszClassName, OFFSET className
	; Registramos la clase
	invoke RegisterClassExA, addr windowClass                      
    
	; ========== CREACIÓN DE LA VENATANA =============
	; Creamos la ventana.
	; Le asignamos los estilos para que se pueda crear pero que NO se pueda alterar su tamaño, maximizar ni minimizar
	xor		ebx, ebx
	mov		ebx, WS_OVERLAPPED
	or		ebx, WS_CAPTION
	or		ebx, WS_SYSMENU
	invoke CreateWindowExA, NULL, ADDR className, ADDR windowTitle, ebx, CW_USEDEFAULT, CW_USEDEFAULT, windowWidth, windowHeight, NULL, NULL, hInstance, NULL
    ; Guardamos el resultado en una variable auxilar y mostramos la ventana.
	mov		windowHandler, eax
    invoke ShowWindow, windowHandler,cmdShow               
    invoke UpdateWindow, windowHandler                    

	; ============= EL CICLO DE MENSAJES =======================
    invoke	GetMessageA, ADDR windowMessage, NULL, 0, 0
	.WHILE eax != 0                                  
        invoke	TranslateMessage, ADDR windowMessage
        invoke	DispatchMessageA, ADDR windowMessage
		invoke	GetMessageA, ADDR windowMessage, NULL, 0, 0
   .ENDW
    mov eax, windowMessage.wParam
	ret
WinMain endp


; El callback de la ventana.
; La mayoria de la lógica de su proyecto se encontrará aquí.
; (O desde aquí se mandarán a llamar a otras funciones)
WindowCallback proc handler:dword, message:dword, wParam:dword, lParam:dword
	.IF message == WM_CREATE
		; Lo que sucede al crearse la ventana.
		; Normalmente se usa para inicializar variables.
		; Obtiene las dimenciones del área de trabajo de la ventana.
		invoke	GetClientRect, handler, addr clientRect
		; Obtenemos el contexto de la ventana.
		invoke	GetDC, handler
		mov		windowContext, eax
		; Creamos un bitmap del tamaño del área de trabajo de nuestra ventana.
		invoke	CreateCompatibleBitmap, windowContext, clientRect.right, clientRect.bottom
		mov		layer, eax
		; Y le creamos un contexto
		invoke	CreateCompatibleDC, windowContext
		mov		layerContext, eax
		; Liberamos windowContext para poder trabajar con lo demás
		invoke	ReleaseDC, handler, windowContext
		; Le decimos que el contexto layerContext le pertenece a layer
		invoke	SelectObject, layerContext, layer
		invoke	DeleteObject, layer
		; Asignamos un color de limpiado de pantalla
		invoke	CreateSolidBrush, RGB(0,0,0)
		mov		clearColor, eax
		;Cargamos la imagen
		invoke	LoadImage, NULL, addr imageFilename, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE
		mov		image, eax
		; Habilitamos el joystick
		invoke	joyGetNumDevs
		.IF eax == 0
			invoke joystickError	
		.ELSE
			invoke	joyGetPos, JOYSTICKID1, addr joystickInfo
			.IF eax != JOYERR_NOERROR
				;invoke joystickError
			.ELSE
				invoke	joySetCapture, handler, JOYSTICKID1, NULL, FALSE
				.IF eax != 0
					;invoke joystickError
				.ENDIF
			.ENDIF
		.ENDIF
		; Habilita el timer
		invoke	SetTimer, handler, 100, 100, NULL

		;invoke TransparentBlt, auxiliarLayerContext, xMueble1, yMueble1, 150, 300, layerContext, 645, 133, 158, 130, 00000FF00h

		mov RectMueble1.left, 300
		mov RectMueble1.top, 1250
		mov RectMueble1.right, 300+158
		mov RectMueble1.bottom, 1250+280

		;Mueble2
		;invoke TransparentBlt, auxiliarLayerContext, xMueble2, yMueble2, 150, 250, layerContext, 580, 289, 100, 100, 00000FF00h

		mov RectMueble2.left, 32
		mov RectMueble2.top, 1250
		mov RectMueble2.right, -32+100
		mov RectMueble2.bottom, 1250+200

		;Mueble 3
		;invoke TransparentBlt, auxiliarLayerContext, xMueble3, yMueble3, 150, 250, layerContext, 740, 314, 115, 121, 00000FF00h

		mov RectMueble3.left, 600
		mov RectMueble3.top, 1240
		mov RectMueble3.right, 600+115
		mov RectMueble3.bottom, 1240+200

		mov RectPlayer.left, 300
		mov RectPlayer.top, 750
		mov RectPlayer.right, 266+226
		mov RectPlayer.bottom,750+265

		mov RectUP.left, 330
		mov RectUP.top, -1000
		mov RectUP.right, 330 + 105
		mov RectUP.bottom, -1000 + 110


	.ELSEIF message == WM_PAINT
		; El proceso de dibujado
		; Iniciamos nuestro windowContext
		invoke	BeginPaint, handler, addr windowPaintstruct
		mov		windowContext, eax
		; Creamos un bitmap auxilar. Esto es, para evitar el efecto de parpadeo
		invoke	CreateCompatibleBitmap, layerContext, clientRect.right, clientRect.bottom
		mov		auxiliarLayer, eax
		; Le creamos su contetxo
		invoke	CreateCompatibleDC, layerContext
		mov		auxiliarLayerContext, eax
		; Lo asociamos
		invoke	SelectObject, auxiliarLayerContext, auxiliarLayer
		invoke	DeleteObject, auxiliarLayer
		; Llenamos nuestro auxiliar con nuestro color de borrado, sirve para limpiar la pantalla
		invoke	FillRect, auxiliarLayerContext, addr clientRect, clearColor
		; Elegimos la imagen
		invoke	SelectObject, layerContext, image

		; Aquí pueden poner las cosas que deseen dibujar
				;								X,	  Y, ancho, largo			X,	  Y, ANCHO, LARGO, COLOR INVISIBLE
				;								Pantalla					|			Bitmap
		;Fondo
		invoke TransparentBlt, auxiliarLayerContext,0,0, 780, 1220, layerContext, 1396, yFondo, 523, 350, 00000FF00h
		;Personaje
		invoke TransparentBlt, auxiliarLayerContext, RectPlayer.left, RectPlayer.top, 150, 250, layerContext, xOrigen, yOrigen, 226, 272, 00000FF00h
		;Mueble1
		invoke TransparentBlt, auxiliarLayerContext, RectMueble1.left, RectMueble1.top, 150, 300, layerContext, 645, 133, 158, 130, 00000FF00h
		;Mueble2
		invoke TransparentBlt, auxiliarLayerContext, RectMueble2.left, RectMueble2.top, 150, 250, layerContext, 580, 289, 100, 100, 00000FF00h
		;Mueble 3
		invoke TransparentBlt, auxiliarLayerContext, RectMueble3.left, RectMueble3.top, 150, 250, layerContext, 740, 314, 115, 121, 00000FF00h
		;Corazones
		invoke TransparentBlt, auxiliarLayerContext, 625, 20,Sizelife, 100, layerContext, 33, 79, Hearths,110, 00000FF00h
		;Corazon extra
		invoke TransparentBlt, auxiliarLayerContext, RectUP.left, RectUP.top,100, 100, layerContext, 254, 79, 105,110, 00000FF00h
		;Inicio
		invoke TransparentBlt, auxiliarLayerContext, 0, 0, xStart, yStart, layerContext, 0, 588, 225, 491, 00000FF00h
		;Death
		invoke TransparentBlt, auxiliarLayerContext, 0, 0, xvida, yvida, layerContext, 243, 588, 225, 491, 00000FF00h
		;Pause
		invoke TransparentBlt, auxiliarLayerContext, 0, 0, xPause, yPause, layerContext, 0, 225, 228, 356, 00000FF00h

		.IF Play== 1


		sub yFondo, 1
		.IF yFondo <= 1
		mov yFondo, 350
		.ENDIF

		mov eax, RectPlayer.left
		add eax, 226
		mov RectPlayer.right, eax
		mov eax, RectPlayer.top
		add eax, 272
		mov RectPlayer.bottom, eax

		Invoke IntersectRect, addr RectCol, addr RectPlayer, addr RectMueble1
		.IF eax != 0
		sub Sizelife, 50
		sub Hearths, 112
		mov RectMueble1.top, 1280
		mov RectMueble1.bottom, 1280+130
		.ENDIF

		Invoke IntersectRect, addr RectCol, addr RectPlayer, addr RectMueble2
		.IF eax != 0
		sub Sizelife, 50
		sub Hearths, 112
		mov RectMueble2.top, 1250
		mov RectMueble2.bottom, 1250+200
		.ENDIF

		Invoke IntersectRect, addr RectCol, addr RectPlayer, addr RectMueble3
		.IF eax != 0
		sub Sizelife, 50
		sub Hearths, 112
		mov RectMueble3.top, 1250
		mov RectMueble3.bottom, 1250+200
		.ENDIF

		
		Invoke IntersectRect, addr RectCol, addr RectPlayer, addr RectUP
		.IF eax != 0
		mov Sizelife, 100
		mov Hearths, 224
		add Puntuacion, 50
		mov RectUP.top, 1250
		mov RectUP.bottom, 1250 + 110
		.ENDIF


		;Health ----------------------------------------------------------------------------------------------------

		.IF Hearths <= 0
		mov edx, Puntuacion
		sub Puntuacion, 1
		.IF edx > TopRecord
		mov TopRecord, edx
		.ENDIF
		add xvida, 778
		mov yvida, 1280


		invoke crt__itoa, TopRecord, addr Kms, 10
		invoke TextOutA, auxiliarLayerContext, 350, 350, addr Kms, 12

		.ENDIF

		.IF xvida >= 780
		invoke KillTimer, handler, 100
		.ENDIF

		;RANDOM NUMBER GENERATOR ------------------------------------------------------------------------------------

		xor eax, eax
		xor ebx, ebx
		xor edx, edx
		invoke crt_rand
		mov ebx, 3
		div bx
		mov Random1, edx
		mov eax, Random1

		;mov eax, 0
		mov eax, eax
		mov ebx, Fijo
		mul ebx
		.IF eax == 0
		add eax, 34
		.ENDIF
		

		add xOrigen, 229
		.IF xOrigen >= 674+687
		mov xOrigen, 674
		.ENDIF

		;obstacles advance -----------------------------------------------------------------------------------------

		add RectMueble1.top, 10
		add RectMueble1.bottom, 10
		mov ebx, RectMueble1.top
		mov yMueble1, ebx
		.IF yMueble1 >= 1100
		mov RectMueble1.top, -380
		mov RectMueble1.bottom, -380+280
		mov yMueble1, -380
		mov RectMueble1.left, eax
		mov RectMueble1.right, eax
		add RectMueble1.right, 158
		.ENDIF

		xor ebx,ebx
		add RectMueble2.top, 10
		add RectMueble2.bottom, 10
		mov ebx, RectMueble2.top
		mov yMueble2, ebx
		.IF yMueble2 >= 1100
		mov RectMueble2.top, -650
		mov RectMueble2.bottom, -650+200
		mov yMueble2, -400
		mov RectMueble2.left, eax
		mov RectMueble2.right, eax
		add RectMueble2.right, 100
		.ENDIF

		xor ebx,ebx
		add RectMueble3.top, 10
		add RectMueble3.bottom, 10
		mov ebx, RectMueble3.top
		mov yMueble3, ebx
		.IF yMueble3 >= 1100
		mov RectMueble3.top, -850
		mov RectMueble3.bottom, -850 + 200
		mov yMueble3, -400
		mov RectMueble3.left, eax
		mov RectMueble3.right, eax
		add RectMueble3.right, 200
		.ENDIF

		xor ebx,ebx
		add RectUP.top, 5
		add RectUP.bottom, 5
		mov ebx, RectUP.top
		mov yMueble2, ebx
		.IF yMueble2 >= 1100
		mov RectUP.top, -890
		mov RectUP.bottom, -890+110
		mov yMueble2, -400
		mov RectUP.left, eax
		mov RectUP.right, eax
		add RectUP.right, 100 + 105
		.ENDIF

		;Score --------------------------------------------------------------------------------------------------------------- 
		

		add Puntuacion, 1
		invoke crt__itoa, Puntuacion, addr Kms, 10
		invoke TextOutA, auxiliarLayerContext, 0, 0, addr Kms, 12
		

		.ENDIF

		; Ya que terminamos de dibujarlas, las mostramos en pantalla
		invoke	BitBlt, windowContext, 0, 0, clientRect.right, clientRect.bottom, auxiliarLayerContext, 0, 0, SRCCOPY
		invoke  EndPaint, handler, addr windowPaintstruct
		; Es MUY importante liberar los recursos al terminar de usuarlos, si no se liberan la aplicación se quedará trabada con el tiempo
		invoke	DeleteDC, windowContext
		invoke	DeleteDC, auxiliarLayerContext


		;Controls-------------------------------------------------------------------------------------------------------------------------

	.ELSEIF message == WM_KEYDOWN
		; Lo que hace cuando una tecla se presiona
		; Deben especificar las teclas de acuerdo a su código ASCII
		; Pueden consultarlo aquí: https://elcodigoascii.com.ar/
		; Movemos wParam a EAX para que AL contenga el valor ASCII de la tecla presionada.
		mov	eax, wParam
		; Esto es un ejemplo: Si presionamos la tecla P mostrará los créditos

		.IF al == 32
		mov xStart, 0
		mov yStart, 0
		mov Play, 1

				.ELSEIF al == 72
			invoke KillTimer, handler, 100
			invoke SetTimer, handler, 100, 1, NULL
			.IF al == 00
			invoke SetTimer, handler, 100, 100, NULL
			.ENDIF

			.ELSEIF al == 65
			xor eax, eax
		 sub RectPlayer.left, 285
		 mov eax, RectPlayer.left
		 mov xPlayer, eax
			.IF xPlayer <=32
			mov RectPlayer.left, 32
			.ENDIF

			.ELSEIF al == 68
		add RectPlayer.left, 285
			.IF RectPlayer.left >= 532
			mov RectPlayer.left, 585
			.ENDIF

			 .ELSEIF al == 87
		 sub RectPlayer.top, 50
		 	.IF RectPlayer.top <= 50
			mov RectPlayer.top, 50
			.ENDIF

			.ELSEIF al == 83
		 add RectPlayer.top, 50
		 	.IF RectPlayer.top >= 750
			mov RectPlayer.top, 750
			.ENDIF

			;-- Restart --
			.ELSEIF al == 82
			invoke SetTimer, handler, 100, 100, NULL
			mov xvida, 0
			mov yvida, 0
			mov Hearths, 224
			mov Sizelife, 100
			mov RectMueble1.top, 1200
			mov RectMueble1.bottom, 1200+280
			mov RectMueble2.top, 1600
			mov RectMueble2.bottom, 1600+200
			mov RectMueble3.top, 1250
			mov RectMueble3.bottom, 1250+200
			mov RectUP.top, 1200
			mov RectUP.bottom, 1200 + 470
			mov Puntuacion, 0
			mov xPause, 0
			mov yPause, 0
			
			

		.ELSEIF al==80
			invoke	credits, handler

		.ELSEIF al == 27
		add xPause, 779
		mov yPause, 1250
		.IF xPause >= 780
		invoke KillTimer, handler, 100
		.ENDIF
		.IF al == 00
		invoke SetTimer, handler, 100, 100, NULL
		mov xPause, 0
		mov yPause, 0
		.ENDIF

		.ELSEIF al == 88
		 invoke PostQuitMessage, NULL
		.ENDIF




	.ELSEIF message == MM_JOY1MOVE
		; Lo que pasa cuando mueves la palanca del joystick
		xor	ebx, ebx
		xor edx, edx
		mov	edx, lParam
		mov bx, dx
		and	dx, 0
		ror edx, 16
		; En este punto, BX contiene la coordenada de la palanca en x
		; Y DX la coordenada y
		; Las coordenadas se dan relativas al la esquina superior izquierda de la palanca.
		; En escala del 0 a 0FFFFh
		; Lo que significa que si la palanca está en medio, la coordenada en X será 07FFFh
		; Y la coordenada Y también.
		; Lo máximo hacia arriba es 0 en Y
		; Lo máximo hacia abajo en FFFF en Y
		; Lo máximo hacia la derecha es FFFF en X
		; Lo máximo hacia la izquierda es 0 en X
		; Si la palanca no está en ningún extremo, será un valor intermedio
		; Este es un ejemplo: Si la palanca está al máximo a la derecha, mostrará los créditos
		.IF bx == 0FFFFh
			invoke credits, handler
		.ENDIF 
	.ELSEIF message == MM_JOY1BUTTONDOWN
		; Lo que hace cuando presionas un botón del joystick
		; Pueden comparar que botón se presionó haciendo un AND
		xor	ebx, ebx
		mov	ebx, wParam
		and	ebx, JOY_BUTTON1
		; Esto es un ejemplo, si presionamos el botón 1 del joystick, mostrará los créditos
		.IF	ebx != 0
			invoke credits, handler
		.ENDIF
	.ELSEIF message == WM_TIMER
		; Lo que hace cada tick (cada vez que se ejecute el timer)
		invoke	InvalidateRect, handler, NULL, FALSE
	.ELSEIF message == WM_DESTROY
		; Lo que debe suceder al intentar cerrar la ventana.   
        invoke PostQuitMessage, NULL
    .ENDIF
	; Este es un fallback.
	; NOTA IMPORTANTE: Normalmente WinAPI espera que se le regrese ciertos valores dependiendo del mensaje que se esté procesando.
	; Como varia mucho entre mensaje y mensaje, entonces DefWindowProcA se encarga de regresar el mensaje predeterminado como si las cosas
	; fueran con normalidad. Pero en realidad pueden devolver otras cosas y el comportamiento de WinAPI cambiará.
	; (Por ejemplo, si regresan -1 en EAX al procesar WM_CREATE, la ventana no se creará)
    invoke DefWindowProcA, handler, message, wParam, lParam      
    ret
WindowCallback endp

; Reproduce la música
playMusic proc
	xor		ebx, ebx
	mov		ebx, SND_FILENAME
	or		ebx, SND_LOOP
	or		ebx, SND_ASYNC
	invoke	PlaySound, addr musicFilename, NULL, ebx
	ret
playMusic endp

; Muestra el error del joystick
joystickError proc
	xor		ebx, ebx
	mov		ebx, MB_OK
	or		ebx, MB_ICONERROR
	invoke	MessageBoxA, NULL, addr joystickErrorText, addr errorTitle, ebx
	ret
joystickError endp

; Muestra los créditos
credits	proc handler:DWORD
	; Estoy matando al timer para que no haya problemas al mostrar el Messagebox.
	; Veanlo como un sistema de pausa
	invoke KillTimer, handler, 100
	xor ebx, ebx
	mov ebx, MB_OK
	or	ebx, MB_ICONINFORMATION
	invoke	MessageBoxA, handler, addr messageBoxText, addr messageBoxTitle, ebx
	; Volvemos a habilitar el timer
	invoke SetTimer, handler, 100, 100, NULL
	ret
credits endp

end main