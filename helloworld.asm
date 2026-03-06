; Bouncing Hello World

; === Constants ===
CS_HREDRAW          EQU 2
CS_VREDRAW          EQU 1
WS_OVERLAPPEDWINDOW EQU 0CF0000h
WM_DESTROY          EQU 2
WM_PAINT            EQU 0Fh
WM_TIMER            EQU 0113h
COLOR_WINDOW        EQU 5
SW_SHOWNORMAL       EQU 1
TRANSPARENT         EQU 1
WHITE_BRUSH         EQU 0

; === External symbols ===
extern GetModuleHandleA
extern RegisterClassExA
extern CreateWindowExA
extern DefWindowProcA
extern GetMessageA
extern TranslateMessage
extern DispatchMessageA
extern ExitProcess
extern PostQuitMessage
extern LoadCursorA
extern LoadIconA
extern GetStockObject
extern BeginPaint
extern EndPaint
extern TextOutA
extern ShowWindow
extern UpdateWindow
extern SetTextColor
extern SetBkMode
extern SetTimer
extern KillTimer
extern InvalidateRect
extern GetClientRect
extern FillRect
extern PatBlt
extern GetDC
extern ReleaseDC

global Start

; === Data Section ===
section .data
    WindowName     db "Bouncing Hello World", 0
    ClassName      db "BHW", 0
    HelloText      db "Hello World!", 0
    TextLen        equ 12
    
    ; 8 colors (BGR format)
    Colors:
        dd 000000FFh  ; Red
        dd 000080FFh  ; Orange
        dd 0000FFFFh  ; Yellow
        dd 0000FF00h  ; Green
        dd 00FFFF00h  ; Cyan
        dd 00FF0000h  ; Blue
        dd 00800080h  ; Purple
        dd 00FF00FFh  ; Magenta

; === WNDCLASSEXA Structure ===
    align 16
    wndclass:
        dd 80
        dd CS_HREDRAW | CS_VREDRAW
        dq 0
        dd 0
        dd 0
        dq 0
        dq 0
        dq 0
        dq 0
        dq 0
        dq 0
        dq 0

section .bss
    hInstance       resq 1
    hWnd            resq 1
    msg             resb 48
    save_hWnd       resq 1
    save_uMsg       resq 1
    save_wParam     resq 1
    save_lParam     resq 1
    ps              resb 72
    hDC             resq 1
    ColorIndex      resd 1
    
    ; Position and velocity
    PosX            resd 1
    PosY            resd 1
    VelX            resd 1
    VelY            resd 1
    
    ; Window dimensions
    WindowWidth     resd 1
    WindowHeight    resd 1
    
    ; RECT structure for GetClientRect (16 bytes)
    rect            resb 16

section .text

Start:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 32
    
    ; Initialize position and velocity
    mov     dword [rel PosX], 100
    mov     dword [rel PosY], 100
    mov     dword [rel VelX], 3
    mov     dword [rel VelY], 2
    
    xor     ecx, ecx
    call    GetModuleHandleA
    mov     [rel hInstance], rax
    
    lea     rbx, [rel wndclass]
    lea     rax, [rel WndProc]
    mov     qword [rbx + 8], rax
    mov     rax, [rel hInstance]
    mov     qword [rbx + 24], rax
    
    xor     ecx, ecx
    mov     edx, 32512
    call    LoadIconA
    mov     qword [rbx + 32], rax
    
    xor     ecx, ecx
    mov     edx, 32512
    call    LoadCursorA
    mov     qword [rbx + 40], rax
    
    mov     ecx, COLOR_WINDOW + 1
    call    GetStockObject
    mov     qword [rbx + 48], rax
    
    lea     rax, [rel ClassName]
    mov     qword [rbx + 64], rax
    
    lea     rcx, [rel wndclass]
    call    RegisterClassExA
    test    rax, rax
    jz      Exit
    
    sub     rsp, 64
    
    xor     ecx, ecx
    lea     rdx, [rel ClassName]
    lea     r8, [rel WindowName]
    mov     r9d, WS_OVERLAPPEDWINDOW
    
    mov     dword [rsp + 32], 100
    mov     dword [rsp + 40], 100
    mov     dword [rsp + 48], 800
    mov     dword [rsp + 56], 600
    mov     qword [rsp + 64], 0
    mov     qword [rsp + 72], 0
    mov     rax, [rel hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    
    call    CreateWindowExA
    
    add     rsp, 64
    
    mov     [rel hWnd], rax
    test    rax, rax
    jz      Exit
    
    ; SetTimer (16ms ~ 60 FPS)
    mov     rcx, rax
    xor     edx, edx
    mov     r8d, 16
    xor     r9d, r9d
    call    SetTimer
    
    mov     rcx, [rel hWnd]
    mov     edx, SW_SHOWNORMAL
    call    ShowWindow
    
    mov     rcx, [rel hWnd]
    call    UpdateWindow

MsgLoop:
    lea     rcx, [rel msg]
    xor     edx, edx
    xor     r8d, r8d
    xor     r9d, r9d
    call    GetMessageA
    
    test    eax, eax
    jle     ExitApp
    
    lea     rcx, [rel msg]
    call    TranslateMessage
    
    lea     rcx, [rel msg]
    call    DispatchMessageA
    
    jmp     MsgLoop

ExitApp:
Exit:
    xor     eax, eax
    leave
    call    ExitProcess

WndProc:
    mov     [rel save_hWnd], rcx
    mov     [rel save_uMsg], rdx
    mov     [rel save_wParam], r8
    mov     [rel save_lParam], r9
    
    push    rbp
    mov     rbp, rsp
    sub     rsp, 48
    
    mov     eax, [rel save_uMsg]
    cmp     eax, WM_DESTROY
    je      OnDestroy
    cmp     eax, WM_PAINT
    je      OnPaint
    cmp     eax, WM_TIMER
    je      OnTimer
    
    mov     rcx, [rel save_hWnd]
    mov     rdx, [rel save_uMsg]
    mov     r8, [rel save_wParam]
    mov     r9, [rel save_lParam]
    call    DefWindowProcA
    jmp     WndReturn

OnDestroy:
    mov     rcx, [rel save_hWnd]
    xor     edx, edx
    call    KillTimer
    
    xor     ecx, ecx
    call    PostQuitMessage
    xor     eax, eax
    jmp     WndReturn

OnTimer:
    ; Get window client area
    mov     rcx, [rel save_hWnd]
    lea     rdx, [rel rect]
    call    GetClientRect
    
    ; Width = right - left
    mov     eax, [rel rect + 8]
    sub     eax, [rel rect]
    mov     [rel WindowWidth], eax
    
    ; Height = bottom - top
    mov     eax, [rel rect + 12]
    sub     eax, [rel rect + 4]
    mov     [rel WindowHeight], eax
    
    ; Update X position
    mov     eax, [rel PosX]
    add     eax, [rel VelX]
    mov     [rel PosX], eax
    
    ; Check X bounds - bounce off right wall
    mov     edx, [rel WindowWidth]
    sub     edx, 80                     ; Approximate text width
    cmp     eax, edx
    jle     CheckXLeft
    
    ; Hit right wall - reverse and clamp
    neg     dword [rel VelX]
    mov     eax, edx
    mov     [rel PosX], eax
    call    ChangeColor
    jmp     UpdateY
    
CheckXLeft:
    cmp     eax, 0
    jge     UpdateY
    ; Hit left wall
    neg     dword [rel VelX]
    mov     dword [rel PosX], 0
    call    ChangeColor

UpdateY:
    ; Update Y position
    mov     eax, [rel PosY]
    add     eax, [rel VelY]
    mov     [rel PosY], eax
    
    ; Check Y bounds - bounce off bottom wall
    mov     edx, [rel WindowHeight]
    sub     edx, 20                     ; Approximate text height
    cmp     eax, edx
    jle     CheckYTop
    
    ; Hit bottom wall
    neg     dword [rel VelY]
    mov     eax, edx
    mov     [rel PosY], eax
    call    ChangeColor
    jmp     DoInvalidate
    
CheckYTop:
    cmp     eax, 0
    jge     DoInvalidate
    ; Hit top wall
    neg     dword [rel VelY]
    mov     dword [rel PosY], 0
    call    ChangeColor

DoInvalidate:
    mov     rcx, [rel save_hWnd]
    xor     edx, edx
    mov     r8d, 1                      ; bErase = TRUE
    call    InvalidateRect
    
    xor     eax, eax
    jmp     WndReturn

ChangeColor:
    push    rax
    mov     eax, [rel ColorIndex]
    inc     eax
    and     eax, 7
    mov     [rel ColorIndex], eax
    pop     rax
    ret

OnPaint:
    mov     rcx, [rel save_hWnd]
    lea     rdx, [rel ps]
    call    BeginPaint
    mov     [rel hDC], rax
    
    ; Get client rect for filling
    push    rax
    mov     rcx, [rel save_hWnd]
    lea     rdx, [rel rect]
    call    GetClientRect
    pop     rax
    
    ; Fill background with white
    mov     rcx, [rel hDC]
    lea     rdx, [rel rect]
    mov     r8d, WHITE_BRUSH
    call    GetStockObject
    mov     r8, rax
    mov     rcx, [rel hDC]
    lea     rdx, [rel rect]
    call    FillRect
    
    ; Set transparent background for text
    mov     rcx, [rel hDC]
    mov     edx, TRANSPARENT
    call    SetBkMode
    
    ; Set text color
    mov     rcx, [rel hDC]
    mov     eax, [rel ColorIndex]
    and     eax, 7
    shl     eax, 2
    lea     rdx, [rel Colors]
    mov     edx, [rdx + rax]
    call    SetTextColor
    
    ; Draw text at current position
    mov     rcx, [rel hDC]
    mov     edx, [rel PosX]
    mov     r8d, [rel PosY]
    lea     r9, [rel HelloText]
    mov     dword [rsp + 32], TextLen
    call    TextOutA
    
    mov     rcx, [rel save_hWnd]
    lea     rdx, [rel ps]
    call    EndPaint
    
    xor     eax, eax
    jmp     WndReturn

WndReturn:
    leave
    ret
