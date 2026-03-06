; Bouncing Transparent PNG Window - x64 NASM Assembly
; PNG and Icon embedded directly in binary
; Creates a layered window with transparent PNG that bounces around screen
; Press ESC to close
; Drag window and release to throw it - physics based bounce!

default rel

; === Constants ===
CS_HREDRAW          EQU 2
CS_VREDRAW          EQU 1
WS_POPUP            EQU 80000000h
WS_VISIBLE          EQU 10000000h
WM_DESTROY          EQU 2
WM_CLOSE            EQU 10h
WM_TIMER            EQU 0113h
WM_KEYDOWN          EQU 100h
WM_LBUTTONDOWN      EQU 201h
WM_LBUTTONUP        EQU 202h
WM_MOUSEMOVE        EQU 200h
VK_ESCAPE           EQU 1Bh
ULW_ALPHA           EQU 2
AC_SRC_OVER         EQU 0
AC_SRC_ALPHA        EQU 1
SM_CXSCREEN         EQU 0
SM_CYSCREEN         EQU 1
GMEM_MOVEABLE       EQU 2
GMEM_ZEROINIT       EQU 40h
GHND                EQU (GMEM_MOVEABLE | GMEM_ZEROINIT)
IMAGE_ICON          EQU 1
LR_DEFAULTCOLOR     EQU 0

; === External symbols ===
extern GetModuleHandleA
extern LoadImageA
extern ExitProcess
extern PostQuitMessage
extern GetMessageA
extern TranslateMessage
extern DispatchMessageA
extern SetTimer
extern KillTimer
extern GetSystemMetrics
extern RegisterClassExA
extern CreateWindowExA
extern DefWindowProcA
extern LoadCursorA
extern LoadIconA
extern GetDC
extern ReleaseDC
extern CreateCompatibleDC
extern DeleteDC
extern SelectObject
extern DeleteObject
extern UpdateLayeredWindow
extern GetCursorPos
extern SetCapture
extern ReleaseCapture
extern SetFocus
extern DestroyWindow
extern GdiplusStartup
extern GdiplusShutdown
extern GdipCreateBitmapFromStream
extern GdipCreateHBITMAPFromBitmap
extern GdipGetImageWidth
extern GdipGetImageHeight
extern GdipDisposeImage
extern GlobalAlloc
extern GlobalLock
extern GlobalUnlock
extern GlobalFree
extern CreateStreamOnHGlobal

global Start

; === Data Section ===
section .data
    align 16

    WindowName     db "BouncePNG", 0
    ClassName      db "BouncePNGWin", 0

    ; GdiplusStartupInput structure
    align 16
    gdiplusInput:
        dd 1                      ; GdiplusVersion
        dq 0                      ; DebugEventCallback
        dd 0                      ; SuppressBackgroundThread
        dd 0                      ; SuppressExternalCodeExt

    ; BLENDFUNCTION
    align 4
    bfBlend:
        db AC_SRC_OVER
        db 0
        db 255
        db AC_SRC_ALPHA

    ; WNDCLASSEXA structure (80 bytes)
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

    ; SIZE structure
    align 4
    sizeWndStorage:
        dd 0
        dd 0

    ; POINT for destination
    align 4
    ptDstStorage:
        dd 0
        dd 0

    ; POINT for source
    align 4
    ptSrcStorage:
        dd 0
        dd 0

    ; POINT for GetCursorPos
    align 4
    cursorPt:
        dd 0
        dd 0

; === Embedded PNG Section ===
section .data
align 16
EmbeddedPNG_Start:
    incbin "354975.png"
EmbeddedPNG_End:

EmbeddedPNG_Size dd EmbeddedPNG_End - EmbeddedPNG_Start

section .bss
    hInstance       resq 1
    hWnd            resq 1
    hdcScreen       resq 1
    hdcMem          resq 1
    hBitmap         resq 1
    hOldBitmap      resq 1
    gdiplusToken    resq 1
    gpBitmap        resq 1
    pIStream        resq 1
    hGlobal         resq 1

    msg             resb 48

    ImgWidth        resd 1
    ImgHeight       resd 1
    ScreenWidth     resd 1
    ScreenHeight    resd 1

    PosX            resd 1
    PosY            resd 1
    VelX            resd 1
    VelY            resd 1

    ; Drag state
    IsDragging      resd 1
    DragStartWinX   resd 1
    DragStartWinY   resd 1
    DragStartMouseX resd 1
    DragStartMouseY resd 1
    PrevMouseX      resd 1
    PrevMouseY      resd 1

section .text

; === Entry Point ===
Start:
    sub     rsp, 56

    ; Initialize GDI+
    lea     rcx, [gdiplusToken]
    lea     rdx, [gdiplusInput]
    xor     r8d, r8d
    call    GdiplusStartup
    test    eax, eax
    jnz     Exit

    ; Get module handle
    xor     ecx, ecx
    call    GetModuleHandleA
    mov     [hInstance], rax

    ; Get screen dimensions
    xor     ecx, ecx
    call    GetSystemMetrics
    mov     [ScreenWidth], eax

    mov     ecx, 1
    call    GetSystemMetrics
    mov     [ScreenHeight], eax

    ; === Load PNG from embedded memory using IStream ===
    ; Allocate movable memory
    mov     ecx, GHND
    mov     eax, [EmbeddedPNG_Size]
    mov     rdx, rax
    call    GlobalAlloc
    test    rax, rax
    jz      CleanupGDI
    mov     [hGlobal], rax

    ; Lock and copy PNG data
    mov     rcx, rax
    call    GlobalLock
    test    rax, rax
    jz      CleanupGlobal

    ; Fast copy using rep movsb
    mov     rdi, rax
    mov     rsi, EmbeddedPNG_Start
    mov     ecx, [EmbeddedPNG_Size]
    movsxd  rcx, ecx
    rep     movsb

    ; Unlock memory
    mov     rcx, [hGlobal]
    call    GlobalUnlock

    ; Create IStream from HGLOBAL
    mov     rcx, [hGlobal]
    xor     edx, edx
    lea     r8, [pIStream]
    call    CreateStreamOnHGlobal
    test    eax, eax
    jnz     CleanupGlobal

    ; Create GDI+ bitmap from stream
    mov     rcx, [pIStream]
    lea     rdx, [gpBitmap]
    call    GdipCreateBitmapFromStream
    test    eax, eax
    jnz     CleanupStream

    ; Get image dimensions
    mov     rcx, [gpBitmap]
    lea     rdx, [ImgWidth]
    call    GdipGetImageWidth

    mov     rcx, [gpBitmap]
    lea     rdx, [ImgHeight]
    call    GdipGetImageHeight

    ; Get screen DC
    xor     ecx, ecx
    call    GetDC
    mov     [hdcScreen], rax

    ; Create memory DC
    mov     rcx, rax
    call    CreateCompatibleDC
    mov     [hdcMem], rax

    ; Create HBITMAP from GDI+ bitmap
    mov     rcx, [gpBitmap]
    lea     rdx, [hBitmap]
    xor     r8d, r8d
    call    GdipCreateHBITMAPFromBitmap
    test    eax, eax
    jnz     CleanupDC

    ; Select bitmap into memory DC
    mov     rcx, [hdcMem]
    mov     rdx, [hBitmap]
    call    SelectObject
    mov     [hOldBitmap], rax

    ; === Free resources we no longer need ===
    ; Release screen DC (no longer needed)
    mov     rcx, [hdcScreen]
    xor     edx, edx
    call    ReleaseDC
    mov     qword [hdcScreen], 0

    ; Dispose GDI+ bitmap (we have the HBITMAP now)
    mov     rcx, [gpBitmap]
    call    GdipDisposeImage
    mov     qword [gpBitmap], 0

    ; Release IStream
    mov     rcx, [pIStream]
    mov     rax, [rcx]
    mov     rax, [rax + 16]
    call    rax
    mov     qword [pIStream], 0

    ; Free HGLOBAL (PNG data copy)
    mov     rcx, [hGlobal]
    call    GlobalFree
    mov     qword [hGlobal], 0

    ; === Shutdown GDI+ - no longer needed ===
    mov     rcx, [gdiplusToken]
    call    GdiplusShutdown
    mov     qword [gdiplusToken], 0

    ; Initialize position and velocity
    mov     dword [PosX], 100
    mov     dword [PosY], 100
    mov     dword [VelX], 5
    mov     dword [VelY], 4

    ; Initialize drag state
    mov     dword [IsDragging], 0

    ; Store size for layered window
    mov     eax, [ImgWidth]
    mov     [sizeWndStorage], eax
    mov     eax, [ImgHeight]
    mov     [sizeWndStorage + 4], eax

    ; Set up window class
    lea     rbx, [wndclass]
    lea     rax, [WndProc]
    mov     qword [rbx + 8], rax
    mov     rax, [hInstance]
    mov     qword [rbx + 24], rax

    ; Load icon from resource
    mov     rcx, [hInstance]
    mov     edx, 1
    mov     r8d, IMAGE_ICON
    mov     r9d, 32
    mov     dword [rsp + 32], 32
    mov     dword [rsp + 40], LR_DEFAULTCOLOR
    call    LoadImageA
    test    rax, rax
    jz      .use_default_icon
    mov     qword [rbx + 32], rax
    jmp     .got_icon
.use_default_icon:
    xor     ecx, ecx
    mov     edx, 32512
    call    LoadIconA
    mov     qword [rbx + 32], rax
.got_icon:

    ; Load cursor
    xor     ecx, ecx
    mov     edx, 32512
    call    LoadCursorA
    mov     qword [rbx + 40], rax

    lea     rax, [ClassName]
    mov     qword [rbx + 64], rax

    ; Register window class
    lea     rcx, [wndclass]
    call    RegisterClassExA
    test    eax, eax
    jz      CleanupDC

    ; Create layered window (need 96 bytes: 32 shadow + 64 for params 5-12)
    ; Plus align to 16-byte: need rsp-8-X ≡ 0 (mod 16), so X=104
    sub     rsp, 104
    mov     ecx, 80008h
    lea     rdx, [ClassName]
    xor     r8d, r8d
    mov     r9d, WS_POPUP | WS_VISIBLE
    mov     eax, [PosX]
    mov     dword [rsp + 32], eax
    mov     eax, [PosY]
    mov     dword [rsp + 40], eax
    mov     eax, [ImgWidth]
    mov     dword [rsp + 48], eax
    mov     eax, [ImgHeight]
    mov     dword [rsp + 56], eax
    mov     qword [rsp + 64], 0
    mov     qword [rsp + 72], 0
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    add     rsp, 104
    mov     [hWnd], rax
    test    rax, rax
    jz      CleanupDC

    ; Initial draw
    call    DoUpdateLayeredWindow

    ; Set timer (16ms ~ 60 FPS)
    mov     rcx, [hWnd]
    mov     edx, 1
    mov     r8d, 16
    xor     r9d, r9d
    call    SetTimer

    ; Set keyboard focus to receive key events
    mov     rcx, [hWnd]
    call    SetFocus

    ; Message loop
MsgLoop:
    lea     rcx, [msg]
    xor     edx, edx
    xor     r8d, r8d
    xor     r9d, r9d
    call    GetMessageA
    test    eax, eax
    jle     ExitLoop

    lea     rcx, [msg]
    call    TranslateMessage

    lea     rcx, [msg]
    call    DispatchMessageA
    jmp     MsgLoop

ExitLoop:
    mov     rcx, [hWnd]
    mov     edx, 1
    call    KillTimer

CleanupDC:
    mov     rcx, [hdcMem]
    mov     rdx, [hOldBitmap]
    test    rdx, rdx
    jz      .skip1
    call    SelectObject
.skip1:
    mov     rcx, [hBitmap]
    test    rcx, rcx
    jz      .skip2
    call    DeleteObject
.skip2:
    mov     rcx, [hdcMem]
    test    rcx, rcx
    jz      .skip3
    call    DeleteDC
.skip3:
    mov     rcx, [gpBitmap]
    test    rcx, rcx
    jz      CleanupStream
    call    GdipDisposeImage

CleanupStream:
    ; Release IStream via vtable: pIStream->lpVtbl->Release(pIStream)
    mov     rcx, [pIStream]
    test    rcx, rcx
    jz      CleanupGlobal
    mov     rax, [rcx]
    mov     rax, [rax + 16]
    call    rax

CleanupGlobal:
    mov     rcx, [hGlobal]
    test    rcx, rcx
    jz      CleanupGDI
    call    GlobalFree

CleanupGDI:
    mov     rcx, [gdiplusToken]
    test    rcx, rcx
    jz      Exit
    call    GdiplusShutdown

Exit:
    xor     eax, eax
    add     rsp, 56
    call    ExitProcess

; === DoUpdateLayeredWindow ===
DoUpdateLayeredWindow:
    sub     rsp, 88

    mov     eax, [PosX]
    mov     [ptDstStorage], eax
    mov     eax, [PosY]
    mov     [ptDstStorage + 4], eax

    mov     rcx, [hWnd]
    xor     edx, edx
    lea     r8, [ptDstStorage]
    lea     r9, [sizeWndStorage]
    mov     rax, [hdcMem]
    mov     qword [rsp + 32], rax
    lea     rax, [ptSrcStorage]
    mov     qword [rsp + 40], rax
    mov     dword [rsp + 48], 0
    lea     rax, [bfBlend]
    mov     qword [rsp + 56], rax
    mov     dword [rsp + 64], ULW_ALPHA
    call    UpdateLayeredWindow

    add     rsp, 88
    ret

; === Window Procedure ===
WndProc:
    sub     rsp, 72

    cmp     edx, WM_DESTROY
    je      .destroy
    cmp     edx, WM_CLOSE
    je      .close
    cmp     edx, WM_TIMER
    je      .timer
    cmp     edx, WM_KEYDOWN
    je      .keydown
    cmp     edx, WM_LBUTTONDOWN
    je      .lbuttondown
    cmp     edx, WM_LBUTTONUP
    je      .lbuttonup
    cmp     edx, WM_MOUSEMOVE
    je      .mousemove

    call    DefWindowProcA
    jmp     .done

.close:
    mov     rcx, [hWnd]
    call    DestroyWindow
    xor     eax, eax
    jmp     .done

.destroy:
    xor     ecx, ecx
    call    PostQuitMessage
    xor     eax, eax
    jmp     .done

.keydown:
    cmp     r8d, VK_ESCAPE
    jne     .key_done
    mov     rcx, [hWnd]
    call    DestroyWindow
.key_done:
    xor     eax, eax
    jmp     .done

.lbuttondown:
    mov     dword [IsDragging], 1
    mov     eax, [PosX]
    mov     [DragStartWinX], eax
    mov     eax, [PosY]
    mov     [DragStartWinY], eax
    lea     rcx, [cursorPt]
    call    GetCursorPos
    mov     eax, [cursorPt]
    mov     [DragStartMouseX], eax
    mov     [PrevMouseX], eax
    mov     eax, [cursorPt + 4]
    mov     [DragStartMouseY], eax
    mov     [PrevMouseY], eax
    mov     dword [VelX], 0
    mov     dword [VelY], 0
    mov     rcx, [hWnd]
    call    SetCapture
    xor     eax, eax
    jmp     .done

.mousemove:
    cmp     dword [IsDragging], 0
    je      .mousemove_done
    lea     rcx, [cursorPt]
    call    GetCursorPos
    mov     eax, [cursorPt]
    mov     ecx, eax
    sub     ecx, [PrevMouseX]
    imul    ecx, 3
    cmp     ecx, 30
    jle     .clamp_vx_neg
    mov     ecx, 30
.clamp_vx_neg:
    cmp     ecx, -30
    jge     .store_vx
    mov     ecx, -30
.store_vx:
    mov     [VelX], ecx
    mov     eax, [cursorPt + 4]
    mov     ecx, eax
    sub     ecx, [PrevMouseY]
    imul    ecx, 3
    cmp     ecx, 30
    jle     .clamp_vy_neg
    mov     ecx, 30
.clamp_vy_neg:
    cmp     ecx, -30
    jge     .store_vy
    mov     ecx, -30
.store_vy:
    mov     [VelY], ecx
    mov     eax, [cursorPt]
    mov     [PrevMouseX], eax
    mov     eax, [cursorPt + 4]
    mov     [PrevMouseY], eax
    mov     eax, [cursorPt]
    sub     eax, [DragStartMouseX]
    add     eax, [DragStartWinX]
    test    eax, eax
    jns     .check_right_x
    xor     eax, eax
.check_right_x:
    mov     edx, [ScreenWidth]
    sub     edx, [ImgWidth]
    cmp     eax, edx
    jle     .store_winx
    mov     eax, edx
.store_winx:
    mov     [PosX], eax
    mov     eax, [cursorPt + 4]
    sub     eax, [DragStartMouseY]
    add     eax, [DragStartWinY]
    test    eax, eax
    jns     .check_bottom_y
    xor     eax, eax
.check_bottom_y:
    mov     edx, [ScreenHeight]
    sub     edx, [ImgHeight]
    cmp     eax, edx
    jle     .store_winy
    mov     eax, edx
.store_winy:
    mov     [PosY], eax
    call    DoUpdateLayeredWindow
.mousemove_done:
    xor     eax, eax
    jmp     .done

.lbuttonup:
    cmp     dword [IsDragging], 0
    je      .mouseup_done
    mov     dword [IsDragging], 0
    call    ReleaseCapture
    mov     eax, [VelX]
    test    eax, eax
    jns     .check_min_vx
    neg     eax
.check_min_vx:
    cmp     eax, 2
    jge     .check_vy
    mov     eax, [PosX]
    and     eax, 1
    jz      .set_vx_neg
    mov     dword [VelX], 4
    jmp     .check_vy
.set_vx_neg:
    mov     dword [VelX], -4
.check_vy:
    mov     eax, [VelY]
    test    eax, eax
    jns     .check_min_vy
    neg     eax
.check_min_vy:
    cmp     eax, 2
    jge     .mouseup_done
    mov     eax, [PosY]
    and     eax, 1
    jz      .set_vy_neg
    mov     dword [VelY], 3
    jmp     .mouseup_done
.set_vy_neg:
    mov     dword [VelY], -3
.mouseup_done:
    xor     eax, eax
    jmp     .done

.timer:
    cmp     dword [IsDragging], 0
    jne     .timer_done
    push    rbx
    push    rsi
    mov     eax, [PosX]
    mov     ebx, [VelX]
    add     eax, ebx
    mov     [PosX], eax
    mov     esi, [ScreenWidth]
    sub     esi, [ImgWidth]
    cmp     eax, esi
    jle     .check_left
    neg     dword [VelX]
    mov     [PosX], esi
    jmp     .update_y
.check_left:
    test    eax, eax
    jns     .update_y
    neg     dword [VelX]
    mov     dword [PosX], 0
.update_y:
    mov     eax, [PosY]
    mov     ebx, [VelY]
    add     eax, ebx
    mov     [PosY], eax
    mov     esi, [ScreenHeight]
    sub     esi, [ImgHeight]
    cmp     eax, esi
    jle     .check_top
    neg     dword [VelY]
    mov     [PosY], esi
    jmp     .do_update
.check_top:
    test    eax, eax
    jns     .do_update
    neg     dword [VelY]
    mov     dword [PosY], 0
.do_update:
    call    DoUpdateLayeredWindow
    pop     rsi
    pop     rbx
.timer_done:
    xor     eax, eax
    jmp     .done

.done:
    add     rsp, 72
    ret