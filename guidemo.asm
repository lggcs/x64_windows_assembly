; Windows GUI Controls Demo - x64 NASM Assembly
; Assemble: nasm -f win64 guidemo.asm -o guidemo.obj
; Link: link /ENTRY:Start /SUBSYSTEM:WINDOWS /LARGEADDRESSAWARE:NO guidemo.obj kernel32.lib user32.lib gdi32.lib comctl32.lib

default rel

; === Constants ===
CS_HREDRAW          EQU 2
CS_VREDRAW          EQU 1
WS_OVERLAPPEDWINDOW EQU 0CF0000h
WS_CHILD            EQU 40000000h
WS_VISIBLE          EQU 10000000h
WS_BORDER           EQU 800000h
WS_CLIPSIBLINGS     EQU 4000000h
WS_VSCROLL          EQU 200000h
WS_HSCROLL          EQU 100000h
WM_DESTROY          EQU 2
WM_CREATE           EQU 1
WM_COMMAND          EQU 111h
WM_NOTIFY           EQU 4Eh
WM_SETTEXT          EQU 0Ch
WM_VSCROLL          EQU 115h
WM_HSCROLL          EQU 114h
COLOR_WINDOW        EQU 5
SW_SHOWNORMAL       EQU 1
SW_HIDE             EQU 0
SW_SHOW             EQU 5

; Scrollbar constants
SB_CTL              EQU 2
SB_VERT             EQU 1
SB_HORZ             EQU 0
SB_LINEUP           EQU 0
SB_LINEDOWN         EQU 1
SB_PAGEUP           EQU 2
SB_PAGEDOWN         EQU 3
SB_THUMBPOSITION    EQU 4
SB_THUMBTRACK       EQU 5
SB_TOP              EQU 6
SB_BOTTOM           EQU 7
SIF_RANGE           EQU 1
SIF_PAGE            EQU 2
SIF_POS             EQU 4
SIF_TRACKPOS        EQU 10h

; Button styles
BS_PUSHBUTTON       EQU 0
BS_AUTOCHECKBOX     EQU 3
BS_AUTORADIOBUTTON  EQU 9
BS_GROUPBOX         EQU 7

; Edit styles
ES_NUMBER           EQU 2000h

; Tab control messages
TCM_INSERTITEMA     EQU 1307h
TCM_GETCURSEL       EQU 130Bh

; TCITEM mask
TCIF_TEXT           EQU 1

; NMHDR codes
TCN_SELCHANGE       EQU 0FFFFFDD9h    ; -551 (TCN_FIRST - 1)

; Control IDs
ID_BUTTON           EQU 101
ID_CHECKBOX1        EQU 102
ID_CHECKBOX2        EQU 103
ID_RADIO1           EQU 104
ID_RADIO2           EQU 105
ID_EDITBOX          EQU 106
ID_EDITNUM          EQU 107
ID_CLEARBTN         EQU 113
ID_TABCTRL          EQU 114

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
extern ShowWindow
extern UpdateWindow
extern SendMessageA
extern MessageBoxA
extern InitCommonControlsEx
extern SetScrollInfo
extern GetScrollInfo
extern InvalidateRect

global Start

; === Data Section ===
section .data
    WindowName     db "GUI Controls Demo", 0
    ClassName      db "GUICtrlDemo", 0
    
    szButton       db "BUTTON", 0
    szEdit         db "EDIT", 0
    szStatic       db "STATIC", 0
    szTabCtrl      db "SysTabControl32", 0
    
    btnClick       db "Click Me!", 0
    btnClear       db "Clear", 0
    chkOption1     db "Option 1", 0
    chkOption2     db "Option 2", 0
    radChoice1     db "Choice A", 0
    radChoice2     db "Choice B", 0
    grpButtons     db "Buttons", 0
    grpInputs      db "Inputs", 0
    lblTextInput   db "Text Input:", 0
    lblNumInput    db "Number Input:", 0
    
    msgClicked     db "Button was clicked!", 0
    msgCaption     db "GUI Demo", 0
    
    ; Tab labels
    tab1Label      db "Buttons", 0
    tab2Label      db "Inputs", 0
    tab3Label      db "About", 0
    
    aboutText      db "GUI Controls Demo", 13, 10, 13, 10
                   db "Written in x64 NASM Assembly", 13, 10, 13, 10
                   db "Features:", 13, 10
                   db "- Tab Control", 13, 10
                   db "- Buttons & Checkboxes", 13, 10
                   db "- Radio Buttons", 13, 10
                   db "- Edit Controls", 0

; INITCOMMONCONTROLSEX structure
    align 16
    iccex:
        dd 8
        dd 0FFFFFFFFh

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

; TCITEMA structure (x64 - must include dwStateMask and padding)
    align 16
    tcitem:
        dd TCIF_TEXT           ; mask (offset 0)
        dd 0                   ; dwState (offset 4)
        dd 0                   ; dwStateMask (offset 8)
        dd 0                   ; padding for alignment (offset 12)
        dq 0                   ; pszText (offset 16, set at runtime)
        dd 0                   ; cchTextMax (offset 24)
        dd 0                   ; iImage (offset 28)
        dq 0                   ; lParam (offset 32)

; SCROLLINFO structure for SetScrollInfo/GetScrollInfo
    align 16
    scrollinfo:
        dd 28                  ; cbSize (28 bytes)
        dd 0                   ; fMask (set at runtime)
        dd 0                   ; nMin
        dd 0                   ; nMax
        dd 0                   ; nPage
        dd 0                   ; nPos
        dd 0                   ; nTrackPos

section .bss
    hInstance       resq 1
    hWnd            resq 1
    hTabCtrl        resq 1
    hEditBox        resq 1
    hEditNum        resq 1
    
    ; Page 1 controls
    hPage1Group     resq 1
    hBtnClick       resq 1
    hBtnClear       resq 1
    hChk1           resq 1
    hChk2           resq 1
    hRad1           resq 1
    hRad2           resq 1
    
    ; Page 2 controls
    hPage2Group     resq 1
    hLblText        resq 1
    hLblNum         resq 1
    
    ; Page 3 controls
    hLblAbout       resq 1
    
    msg             resb 48
    save_hWnd       resq 1
    save_uMsg       resq 1
    save_wParam     resq 1
    save_lParam     resq 1
    currentTab      resd 1
    scrollPos       resd 1
    maxScrollPos    resd 1

section .text

Start:
    sub     rsp, 40
    
    ; Initialize common controls
    lea     rcx, [iccex]
    call    InitCommonControlsEx
    
    xor     ecx, ecx
    call    GetModuleHandleA
    mov     [hInstance], rax
    
    lea     rbx, [wndclass]
    lea     rax, [WndProc]
    mov     qword [rbx + 8], rax
    mov     rax, [hInstance]
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
    
    lea     rax, [ClassName]
    mov     qword [rbx + 64], rax
    
    lea     rcx, [wndclass]
    call    RegisterClassExA
    test    rax, rax
    jz      Exit
    
    sub     rsp, 96
    xor     ecx, ecx
    lea     rdx, [ClassName]
    lea     r8, [WindowName]
    mov     r9d, WS_OVERLAPPEDWINDOW | WS_VSCROLL
    mov     dword [rsp + 32], 100
    mov     dword [rsp + 40], 100
    mov     dword [rsp + 48], 500
    mov     dword [rsp + 56], 420
    mov     qword [rsp + 64], 0
    mov     qword [rsp + 72], 0
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    add     rsp, 96
    
    mov     [hWnd], rax
    test    rax, rax
    jz      Exit
    
    mov     rcx, rax
    mov     edx, SW_SHOWNORMAL
    call    ShowWindow
    
    mov     rcx, [hWnd]
    call    UpdateWindow

MsgLoop:
    lea     rcx, [msg]
    xor     edx, edx
    xor     r8d, r8d
    xor     r9d, r9d
    call    GetMessageA
    test    eax, eax
    jle     ExitApp
    
    lea     rcx, [msg]
    call    TranslateMessage
    
    lea     rcx, [msg]
    call    DispatchMessageA
    jmp     MsgLoop

ExitApp:
    xor     eax, eax
Exit:
    add     rsp, 40
    call    ExitProcess

WndProc:
    mov     [save_hWnd], rcx
    mov     [save_uMsg], rdx
    mov     [save_wParam], r8
    mov     [save_lParam], r9
    
    push    rbp
    mov     rbp, rsp
    sub     rsp, 96
    
    mov     eax, [save_uMsg]
    cmp     eax, WM_DESTROY
    je      OnDestroy
    cmp     eax, WM_CREATE
    je      OnCreate
    cmp     eax, WM_COMMAND
    je      OnCommand
    cmp     eax, WM_NOTIFY
    je      OnNotify
    cmp     eax, WM_VSCROLL
    je      OnVScroll
    
    mov     rcx, [save_hWnd]
    mov     rdx, [save_uMsg]
    mov     r8, [save_wParam]
    mov     r9, [save_lParam]
    call    DefWindowProcA
    jmp     WndReturn

OnCreate:
    ; === Tab Control ===
    xor     ecx, ecx
    lea     rdx, [szTabCtrl]
    xor     r8d, r8d
    mov     r9d, WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS
    mov     dword [rsp + 32], 5
    mov     dword [rsp + 40], 5
    mov     dword [rsp + 48], 470
    mov     dword [rsp + 56], 370
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], ID_TABCTRL
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hTabCtrl], rax
    
    ; Insert Tab 1 "Buttons"
    mov     qword [tcitem + 16], tab1Label
    mov     rcx, [hTabCtrl]
    mov     edx, TCM_INSERTITEMA
    xor     r8d, r8d
    lea     r9, [tcitem]
    call    SendMessageA
    
    ; Insert Tab 2 "Inputs"
    mov     qword [tcitem + 16], tab2Label
    mov     rcx, [hTabCtrl]
    mov     edx, TCM_INSERTITEMA
    mov     r8d, 1
    lea     r9, [tcitem]
    call    SendMessageA
    
    ; Insert Tab 3 "About"
    mov     qword [tcitem + 16], tab3Label
    mov     rcx, [hTabCtrl]
    mov     edx, TCM_INSERTITEMA
    mov     r8d, 2
    lea     r9, [tcitem]
    call    SendMessageA
    
    ; ===== PAGE 1: Buttons =====
    ; Group Box
    xor     ecx, ecx
    lea     rdx, [szButton]
    lea     r8, [grpButtons]
    mov     r9d, WS_CHILD | WS_VISIBLE | BS_GROUPBOX
    mov     dword [rsp + 32], 10
    mov     dword [rsp + 40], 35
    mov     dword [rsp + 48], 450
    mov     dword [rsp + 56], 320
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], 0
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hPage1Group], rax
    
    ; Click Me Button
    xor     ecx, ecx
    lea     rdx, [szButton]
    lea     r8, [btnClick]
    mov     r9d, WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 65
    mov     dword [rsp + 48], 100
    mov     dword [rsp + 56], 35
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], ID_BUTTON
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hBtnClick], rax
    
    ; Clear Button
    xor     ecx, ecx
    lea     rdx, [szButton]
    lea     r8, [btnClear]
    mov     r9d, WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON
    mov     dword [rsp + 32], 150
    mov     dword [rsp + 40], 65
    mov     dword [rsp + 48], 80
    mov     dword [rsp + 56], 35
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], ID_CLEARBTN
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hBtnClear], rax
    
    ; Checkbox 1
    xor     ecx, ecx
    lea     rdx, [szButton]
    lea     r8, [chkOption1]
    mov     r9d, WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 115
    mov     dword [rsp + 48], 120
    mov     dword [rsp + 56], 25
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], ID_CHECKBOX1
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hChk1], rax
    
    ; Checkbox 2
    xor     ecx, ecx
    lea     rdx, [szButton]
    lea     r8, [chkOption2]
    mov     r9d, WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 145
    mov     dword [rsp + 48], 120
    mov     dword [rsp + 56], 25
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], ID_CHECKBOX2
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hChk2], rax
    
    ; Radio Button 1
    xor     ecx, ecx
    lea     rdx, [szButton]
    lea     r8, [radChoice1]
    mov     r9d, WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 180
    mov     dword [rsp + 48], 120
    mov     dword [rsp + 56], 25
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], ID_RADIO1
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hRad1], rax
    
    ; Radio Button 2
    xor     ecx, ecx
    lea     rdx, [szButton]
    lea     r8, [radChoice2]
    mov     r9d, WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 210
    mov     dword [rsp + 48], 120
    mov     dword [rsp + 56], 25
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], ID_RADIO2
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hRad2], rax
    
    ; ===== PAGE 2: Inputs (hidden initially) =====
    ; Group Box
    xor     ecx, ecx
    lea     rdx, [szButton]
    lea     r8, [grpInputs]
    mov     r9d, WS_CHILD | BS_GROUPBOX
    mov     dword [rsp + 32], 10
    mov     dword [rsp + 40], 35
    mov     dword [rsp + 48], 450
    mov     dword [rsp + 56], 320
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], 0
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hPage2Group], rax
    
    ; Text Input Label
    xor     ecx, ecx
    lea     rdx, [szStatic]
    lea     r8, [lblTextInput]
    mov     r9d, WS_CHILD
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 65
    mov     dword [rsp + 48], 100
    mov     dword [rsp + 56], 25
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], 0
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hLblText], rax
    
    ; Text Input Edit Box
    xor     ecx, ecx
    lea     rdx, [szEdit]
    xor     r8d, r8d
    mov     r9d, WS_CHILD | WS_BORDER
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 90
    mov     dword [rsp + 48], 300
    mov     dword [rsp + 56], 28
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], ID_EDITBOX
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hEditBox], rax
    
    ; Number Input Label
    xor     ecx, ecx
    lea     rdx, [szStatic]
    lea     r8, [lblNumInput]
    mov     r9d, WS_CHILD
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 135
    mov     dword [rsp + 48], 100
    mov     dword [rsp + 56], 25
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], 0
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hLblNum], rax
    
    ; Number Input Edit Box
    xor     ecx, ecx
    lea     rdx, [szEdit]
    xor     r8d, r8d
    mov     r9d, WS_CHILD | WS_BORDER | ES_NUMBER
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 160
    mov     dword [rsp + 48], 150
    mov     dword [rsp + 56], 28
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], ID_EDITNUM
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hEditNum], rax
    
    ; ===== PAGE 3: About (hidden initially) =====
    xor     ecx, ecx
    lea     rdx, [szStatic]
    lea     r8, [aboutText]
    mov     r9d, WS_CHILD
    mov     dword [rsp + 32], 30
    mov     dword [rsp + 40], 50
    mov     dword [rsp + 48], 420
    mov     dword [rsp + 56], 280
    mov     rax, [save_hWnd]
    mov     qword [rsp + 64], rax
    mov     qword [rsp + 72], 0
    mov     rax, [hInstance]
    mov     qword [rsp + 80], rax
    mov     qword [rsp + 88], 0
    call    CreateWindowExA
    mov     [hLblAbout], rax

    ; === Initialize Scrollbar ===
    mov     dword [scrollPos], 0
    mov     dword [maxScrollPos], 100
    mov     dword [scrollinfo + 4], SIF_RANGE | SIF_PAGE | SIF_POS  ; fMask
    mov     dword [scrollinfo + 8], 0                               ; nMin
    mov     dword [scrollinfo + 12], 100                            ; nMax (scroll range)
    mov     dword [scrollinfo + 16], 10                             ; nPage (visible portion)
    mov     dword [scrollinfo + 20], 0                              ; nPos (current position)
    mov     rcx, [save_hWnd]
    mov     edx, SB_VERT
    lea     r8, [scrollinfo]
    mov     r9d, 1                  ; fRedraw = TRUE
    call    SetScrollInfo

    ; Initialize - Page 1 visible
    mov     dword [currentTab], 0
    call    UpdateTabVisibility
    xor     eax, eax
    jmp     WndReturn

OnNotify:
    ; lParam points to NMHDR structure
    ; NMHDR on x64: hwndFrom(8), idFrom(8), code(4) -> code at offset 16
    mov     rax, [save_lParam]
    mov     eax, [rax + 16]         ; code field at offset 16

    cmp     eax, TCN_SELCHANGE
    jne     NotifyDone

    ; Get currently selected tab
    mov     rcx, [hTabCtrl]
    mov     edx, TCM_GETCURSEL
    xor     r8d, r8d
    xor     r9d, r9d
    call    SendMessageA

    mov     [currentTab], eax
    call    UpdateTabVisibility

NotifyDone:
    xor     eax, eax
    jmp     WndReturn

; === Helper: Update tab visibility based on currentTab ===
UpdateTabVisibility:
    sub     rsp, 40

    ; --- Hide Page 1 controls ---
    mov     rcx, [hPage1Group]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hBtnClick]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hBtnClear]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hChk1]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hChk2]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hRad1]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hRad2]
    mov     edx, SW_HIDE
    call    ShowWindow

    ; --- Hide Page 2 controls ---
    mov     rcx, [hPage2Group]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hLblText]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hEditBox]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hLblNum]
    mov     edx, SW_HIDE
    call    ShowWindow
    mov     rcx, [hEditNum]
    mov     edx, SW_HIDE
    call    ShowWindow

    ; --- Hide Page 3 controls ---
    mov     rcx, [hLblAbout]
    mov     edx, SW_HIDE
    call    ShowWindow

    ; --- Show appropriate page based on currentTab ---
    cmp     dword [currentTab], 0
    je      .showPage1
    cmp     dword [currentTab], 1
    je      .showPage2
    jmp     .showPage3

.showPage1:
    mov     rcx, [hPage1Group]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hBtnClick]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hBtnClear]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hChk1]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hChk2]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hRad1]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hRad2]
    mov     edx, SW_SHOW
    call    ShowWindow
    jmp     .done

.showPage2:
    mov     rcx, [hPage2Group]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hLblText]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hEditBox]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hLblNum]
    mov     edx, SW_SHOW
    call    ShowWindow
    mov     rcx, [hEditNum]
    mov     edx, SW_SHOW
    call    ShowWindow
    jmp     .done

.showPage3:
    mov     rcx, [hLblAbout]
    mov     edx, SW_SHOW
    call    ShowWindow

.done:
    add     rsp, 40
    ret

OnCommand:
    mov     eax, [save_wParam]
    and     eax, 0FFFFh
    
    cmp     eax, ID_BUTTON
    jne     CheckClear
    xor     ecx, ecx
    lea     rdx, [msgClicked]
    lea     r8, [msgCaption]
    xor     r9d, r9d
    call    MessageBoxA
    jmp     CmdDone

CheckClear:
    cmp     eax, ID_CLEARBTN
    jne     CmdDone
    mov     rcx, [hEditBox]
    mov     edx, WM_SETTEXT
    xor     r8d, r8d
    xor     r9d, r9d
    call    SendMessageA
    mov     rcx, [hEditNum]
    mov     edx, WM_SETTEXT
    xor     r8d, r8d
    xor     r9d, r9d
    call    SendMessageA

CmdDone:
    xor     eax, eax
    jmp     WndReturn

; === WM_VSCROLL Handler ===
OnVScroll:
    ; wParam LOWORD = scroll request, HIWORD = thumb position
    mov     rax, [save_wParam]
    mov     ecx, eax                ; ECX = LOWORD(wParam) = scroll request
    shr     eax, 16                 ; EAX = HIWORD(wParam) = thumb position (if applicable)

    ; Get current scroll position
    mov     edx, [scrollPos]

    cmp     ecx, SB_LINEUP
    je      .scrollLineUp
    cmp     ecx, SB_LINEDOWN
    je      .scrollLineDown
    cmp     ecx, SB_PAGEUP
    je      .scrollPageUp
    cmp     ecx, SB_PAGEDOWN
    je      .scrollPageDown
    cmp     ecx, SB_THUMBTRACK
    je      .scrollThumbTrack
    cmp     ecx, SB_THUMBPOSITION
    je      .scrollThumbPosition
    cmp     ecx, SB_TOP
    je      .scrollTop
    cmp     ecx, SB_BOTTOM
    je      .scrollBottom
    jmp     .done

.scrollLineUp:
    dec     edx
    jmp     .updatePos

.scrollLineDown:
    inc     edx
    jmp     .updatePos

.scrollPageUp:
    sub     edx, 10                 ; Page size
    jmp     .updatePos

.scrollPageDown:
    add     edx, 10
    jmp     .updatePos

.scrollThumbTrack:
.scrollThumbPosition:
    mov     edx, eax                ; Position from wParam HIWORD
    jmp     .updatePos

.scrollTop:
    xor     edx, edx                ; Position = 0
    jmp     .updatePos

.scrollBottom:
    mov     edx, [maxScrollPos]      ; Position = max
    jmp     .updatePos

.updatePos:
    ; Clamp position to valid range
    cmp     edx, 0
    jge     .checkMax
    xor     edx, edx
.checkMax:
    mov     eax, [maxScrollPos]
    cmp     edx, eax
    jle     .setPosition
    mov     edx, eax

.setPosition:
    mov     [scrollPos], edx

    ; Update scrollbar
    mov     dword [scrollinfo + 4], SIF_POS
    mov     [scrollinfo + 20], edx
    mov     rcx, [save_hWnd]
    mov     edx, SB_VERT
    lea     r8, [scrollinfo]
    mov     r9d, 1                  ; fRedraw = TRUE
    call    SetScrollInfo

    ; Invalidate window to trigger repaint (for visual feedback)
    mov     rcx, [save_hWnd]
    xor     edx, edx                 ; NULL rect = entire window
    xor     r8d, r8d                 ; bErase = FALSE
    call    InvalidateRect

.done:
    xor     eax, eax
    jmp     WndReturn

OnDestroy:
    xor     ecx, ecx
    call    PostQuitMessage
    xor     eax, eax
    jmp     WndReturn

WndReturn:
    leave
    ret