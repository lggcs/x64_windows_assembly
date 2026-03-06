; SysInspect.asm - System Information Tool in x64 Assembly
; Build: nasm -f win64 SysInspect.asm -o SysInspect.obj
;        link /ENTRY:Start /SUBSYSTEM:CONSOLE /LARGEADDRESSAWARE:NO SysInspect.obj kernel32.lib user32.lib advapi32.lib iphlpapi.lib psapi.lib

default rel

STD_OUTPUT_HANDLE   EQU -11
TH32CS_SNAPPROCESS  EQU 0x00000002
PROCESS_QUERY_INFO  EQU 0x0400
PROCESS_VM_READ     EQU 0x0010
PROCESS_MEMORY_COUNTERS_SIZE EQU 72

; Service constants
SC_MANAGER_CONNECT             EQU 0x0001
SC_MANAGER_ENUMERATE_SERVICE   EQU 0x0004
SC_MANAGER_ALL_ACCESS          EQU 0xF003F
SERVICE_WIN32                  EQU 0x00000030
SERVICE_STATE_ALL              EQU 0x00000003
SERVICE_ACTIVE                 EQU 0x00000001
ENUM_SERVICE_STATUS_SIZE       EQU 72

extern GetStdHandle
extern WriteFile
extern ExitProcess
extern GetTickCount64
extern GetComputerNameA
extern GetUserNameA
extern GetSystemInfo
extern GlobalMemoryStatusEx
extern GetLogicalDriveStringsA
extern GetDriveTypeA
extern GetDiskFreeSpaceExA
extern GetAdaptersAddresses
extern CreateToolhelp32Snapshot
extern Process32First
extern Process32Next
extern OpenProcess
extern GetProcessMemoryInfo
extern CloseHandle
extern GetTickCount64
extern GetWindowsDirectoryA
extern GetSystemDirectoryA
extern GetTempPathA
extern RtlGetVersion
extern RegOpenKeyExA
extern RegQueryValueExA
extern RegCloseKey
extern RegEnumKeyExA
extern OpenSCManagerA
extern EnumServicesStatusA
extern CloseServiceHandle
extern GetLastError

global Start

; Structures
struc SYSTEM_INFO
    .wProcessorArchitecture:  resw 1
    .wReserved:               resw 1
    .dwPageSize:              resd 1
    .lpMinimumApplicationAddress: resq 1
    .lpMaximumApplicationAddress: resq 1
    .dwActiveProcessorMask:   resq 1
    .dwNumberOfProcessors:    resd 1
    .dwProcessorType:         resd 1
    .dwAllocationGranularity: resd 1
    .wProcessorLevel:         resw 1
    .wProcessorRevision:      resw 1
endstruc

struc MEMORYSTATUSEX
    .dwLength:                resd 1
    .dwMemoryLoad:            resd 1
    .ullTotalPhys:            resq 1
    .ullAvailPhys:            resq 1
    .ullTotalPageFile:        resq 1
    .ullAvailPageFile:        resq 1
    .ullTotalVirtual:         resq 1
    .ullAvailVirtual:         resq 1
    .ullAvailExtendedVirtual: resq 1
endstruc

; Constants for GetAdaptersAddresses
GAA_FLAG_SKIP_ANYCAST       EQU 0x0002
GAA_FLAG_SKIP_MULTICAST     EQU 0x0010
GAA_FLAG_SKIP_DNS_SERVER    EQU 0x0080

IF_TYPE_ETHERNET_CSMACD     EQU 6
IF_TYPE_IEEE80211           EQU 71

; IfOperStatus enum
IfOperStatusUp              EQU 1
IfOperStatusDown            EQU 2

; SOCKET_ADDRESS structure
struc SOCKET_ADDRESS
    .lpSockaddr:            resq 1              ; 0 (8 bytes pointer)
    .iSockaddrLength:       resd 1              ; 8 (4 bytes)
endstruc

; IP_ADAPTER_ADDRESSES structure (simplified for our needs)
struc IP_ADAPTER_ADDRESSES
    .Length:                resd 1              ; 0 (4 bytes, union with Alignment)
    .IfIndex:               resd 1              ; 4 (4 bytes)
    .Next:                  resq 1              ; 8 (8 bytes pointer)
    .AdapterName:           resq 1              ; 16 (8 bytes pointer to char*)
    .FirstUnicastAddress:   resq 1              ; 24 (8 bytes pointer)
    .FirstAnycastAddress:   resq 1              ; 32 (8 bytes pointer)
    .FirstMulticastAddress: resq 1              ; 40 (8 bytes pointer)
    .FirstDnsServerAddress: resq 1              ; 48 (8 bytes pointer)
    .DnsSuffix:             resq 1              ; 56 (8 bytes pointer to wchar*)
    .Description:           resq 1              ; 64 (8 bytes pointer to wchar*)
    .FriendlyName:          resq 1              ; 72 (8 bytes pointer to wchar*)
    .PhysicalAddress:       resb 8              ; 80 (8 bytes) - MAC address bytes
    .PhysicalAddressLength: resd 1              ; 88 (4 bytes)
    .Flags:                 resd 1              ; 92 (4 bytes)
    .Mtu:                   resd 1              ; 96 (4 bytes)
    .IfType:                resd 1              ; 100 (4 bytes)
    .OperStatus:            resd 1              ; 104 (4 bytes) - THIS IS KEY
endstruc

; IP_ADAPTER_UNICAST_ADDRESS (simplified)
struc IP_ADAPTER_UNICAST_ADDRESS
    .Length:                resd 1              ; 0
    .Flags:                 resd 1              ; 4
    .Next:                  resq 1              ; 8
    .Address:               resb SOCKET_ADDRESS_size ; 16
    ; Onward is PrefixOrigin, SuffixOrigin, DadState, etc.
endstruc

; SOCKADDR_IN for IPv4
struc SOCKADDR_IN
    .sin_family:            resw 1              ; 0 (2 bytes)
    .sin_port:              resw 1              ; 2 (2 bytes)
    .sin_addr:              resd 1              ; 4 (4 bytes - the IP address!)
    .sin_zero:              resb 8              ; 8 (padding)
endstruc

struc PROCESSENTRY32
    .dwSize:                  resd 1          ; 0 (4 bytes)
    .cntUsage:                resd 1          ; 4 (4 bytes)
    .th32ProcessID:           resd 1          ; 8 (4 bytes)
    .th32DefaultHeapID:       resq 1          ; 12 (8 bytes - ULONG_PTR)
    .th32ModuleID:            resd 1          ; 20 (4 bytes)
    .cntThreads:              resd 1          ; 24 (4 bytes)
    .th32ParentProcessID:     resd 1          ; 28 (4 bytes)
    .pcPriClassBase:          resq 1          ; 32 (8 bytes - LONG_PTR!)
    .dwFlags:                 resd 1          ; 40 (4 bytes)
    .szExeFile:               resb 260        ; 44
endstruc

PROCESSENTRY32_SIZE EQU 304

struc PROCESS_MEMORY_COUNTERS
    .cb:                      resd 1
    .PageFaultCount:          resd 1
    .PeakWorkingSetSize:      resq 1
    .WorkingSetSize:          resq 1
    .QuotaPeakPagedPoolUsage: resq 1
    .QuotaPagedPoolUsage:     resq 1
    .QuotaPeakNonPagedPoolUsage: resq 1
    .QuotaNonPagedPoolUsage:  resq 1
    .PagefileUsage:           resq 1
    .PeakPagefileUsage:       resq 1
endstruc

MEMORYSTATUSEX_SIZE   EQU 64
OSVERSIONINFO_SIZE    EQU 156
IP_ADAPTER_INFO_SIZE  EQU 640
MAX_ADAPTERS          EQU 10

; RTL_OSVERSIONINFOW structure for RtlGetVersion
struc RTL_OSVERSIONINFOW
    .dwOSVersionInfoSize:     resd 1    ; 0
    .dwMajorVersion:          resd 1    ; 4
    .dwMinorVersion:          resd 1    ; 8
    .dwBuildNumber:           resd 1    ; 12
    .dwPlatformId:            resd 1    ; 16
    .szCSDVersion:            resb 128  ; 20
endstruc

; ENUM_SERVICE_STATUS structure for service enumeration
struc ENUM_SERVICE_STATUS
    .lpServiceName:   resq 1    ; pointer to service name string
    .lpDisplayName:   resq 1    ; pointer to display name string
    .ServiceStatus:              ; SERVICE_STATUS structure (28 bytes)
        .dwServiceType:             resd 1
        .dwCurrentState:            resd 1
        .dwControlsAccepted:        resd 1
        .dwWin32ExitCode:           resd 1
        .dwServiceSpecificExitCode: resd 1
        .dwCheckPoint:              resd 1
        .dwWaitHint:                resd 1
endstruc

; Service states
SERVICE_STOPPED          EQU 0x00000001
SERVICE_START_PENDING    EQU 0x00000002
SERVICE_STOP_PENDING     EQU 0x00000003
SERVICE_RUNNING          EQU 0x00000004
SERVICE_CONTINUE_PENDING EQU 0x00000005
SERVICE_PAUSE_PENDING    EQU 0x00000006
SERVICE_PAUSED           EQU 0x00000007

section .data
    szTitle      db 13, 10, "  ===============================================================" , 13, 10
                 db "              SysInspect - System Information Tool", 13, 10
                 db "              Written in x64 Assembly (NASM)", 13, 10
                 db "  ===============================================================" , 13, 10, 13, 10, 0
    szSep        db "  ---------------------------------------------------------------", 13, 10, 0
    szSepDouble  db "  ===============================================================" , 13, 10, 0
    szNewline    db 13, 10, 0
    szSpace      db "  ", 0
    szGB         db " GB", 0
    szMB         db " MB", 0
    szPct        db "%", 0
    szDot        db ".", 0
    szColon      db ": ", 0
    szDash       db " - ", 0
    
    ; Section titles
    szSecSys     db 13, 10, "  [SYSTEM INFORMATION]", 13, 10, 0
    szSecOS      db 13, 10, "  [OPERATING SYSTEM]", 13, 10, 0
    szSecCPU     db 13, 10, "  [CPU & ARCHITECTURE]", 13, 10, 0
    szSecMem     db 13, 10, "  [MEMORY]", 13, 10, 0
    szSecDisk    db 13, 10, "  [STORAGE]", 13, 10, 0
    szSecMB      db 13, 10, "  [MOTHERBOARD]", 13, 10, 0
    szSecGPU     db 13, 10, "  [GPU]", 13, 10, 0
    szSecNet     db 13, 10, "  [NETWORK ADAPTERS]", 13, 10, 0
    szSecProc    db 13, 10, "  [TOP PROCESSES BY MEMORY]", 13, 10, 0
    szSecSvc     db 13, 10, "  [RUNNING SERVICES]", 13, 10, 0
    
    ; Labels
    lblComputer  db "  Computer Name", 0
    lblUser      db "  User Name", 0
    lblDomain    db "  Domain/Workgroup", 0
    lblCPU       db "  Processor Cores", 0
    lblCPUName   db "  Processor Name: ", 0
    lblArch      db "  Architecture", 0
    lblOSName    db "  Windows Version", 0
    lblOSBuild   db "  Build Number", 0
    lblProductKey db "  Product Key: ", 0
    lblMemTotal  db "  Total RAM", 0
    lblMemFree   db "  Available RAM", 0
    lblMemUsed   db "  Memory Load", 0
    lblPageTotal db "  Total Page File", 0
    lblPageFree  db "  Available Page File", 0
    lblUptime    db "  System Uptime", 0
    lblDrive     db "  Drive ", 0
    lblDiskTotal db "  Total: ", 0
    lblDiskFree  db "  Free: ", 0
    lblMBManuf   db "  Manufacturer: ", 0
    lblMBProduct db "  Product: ", 0
    lblMBSerial  db "  Serial: ", 0
    lblGPU       db "  Graphics Card: ", 0
    lblDays      db "d ", 0
    lblHours     db "h ", 0
    lblMins      db "m ", 0
    lblSecs      db "s", 0
    lblAdapter   db "    Adapter", 0
    lblIP        db "    IP Address", 0
    lblMAC       db "    MAC Address", 0
    lblType      db "    Type", 0
    
    ; Drive type strings
    szDriveFixed    db " [Fixed]", 0
    szDriveRemovable db " [Removable]", 0
    szDriveNetwork  db " [Network]", 0
    szDriveUnknown  db " [Unknown]", 0
    szAccessDenied  db "  Access denied", 13, 10, 0
    
    ; Values
    archAMD64    db "x64 (AMD/Intel)", 0
    archARM64    db "ARM64", 0
    archUnknown  db "Unknown", 0
    
    ; Network types
    netTypeEthernet db "Ethernet", 0
    netTypeWifi     db "Wireless", 0
    netTypeOther    db "Other", 0
    
    ; Status strings
    szNotConnected  db "Not connected", 0
    szConnected     db "Connected", 0
    szDisconnected  db "Disconnected", 0
    szNotAssigned   db "0.0.0.0", 0
    szUnknown       db "Unknown", 0
    szServicesFound db " Windows services found", 13, 10, 0
    szServicePlaceholder db "  Run as Administrator to view services", 13, 10, 0
    szStatus        db "    Status", 0

    ; Registry keys for motherboard info
    regHwKey      db "HARDWARE\DESCRIPTION\System\BIOS", 0
    regManuf      db "BaseBoardManufacturer", 0
    regProduct    db "BaseBoardProduct", 0
    regSerial     db "BaseBoardSerialNumber", 0
    regGPUKey     db "SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}", 0
    regGPUVal     db "DriverDesc", 0
    gpuSubkey0000 db "0001", 0        ; GPU is typically in 0001

    ; CPU info from registry
    regCPUKey     db "HARDWARE\DESCRIPTION\System\CentralProcessor\0", 0
    regCPUName    db "ProcessorNameString", 0

    ; Windows Product Key registry
    regWinKey     db "SOFTWARE\Microsoft\Windows NT\CurrentVersion", 0
    regDigitalPid db "DigitalProductId", 0

    ; Base-24 characters for product key decoding
    keyChars      db "BCDFGHJKMPQRTVWXY2346789", 0

; HKEY_LOCAL_MACHINE = 0x80000002
HKEY_LOCAL_MACHINE EQU 0x80000002

    ; Process header
    procHeader   db "  PID        Memory     Name", 13, 10, 0

    ; Error messages
    errNoAdapters db "    No network adapters found", 0
    errNoProcesses db "    No processes found", 0
    errNoServices  db "    Unable to enumerate services", 0

    ; Service state strings
    svcRunning    db "  [Running] ", 0
    svcStopped    db "  [Stopped] ", 0
    svcPaused     db "  [Paused]  ", 0
    svcUnknown    db "  [?]       ", 0

section .bss
    hStdOut         resq 1
    bytesWritten    resq 1
    sysInfo         resb SYSTEM_INFO_size
    memStatus       resb 64
    osInfo          resb 156
    computerName    resb 256
    computerNameLen resd 1
    userName        resb 256
    userNameLen     resd 1
    buffer          resb 256
    buffer2         resb 256
    drivesBuffer    resb 1024
    regBuffer       resb 256        ; for registry values
    hKey            resq 1
    hKey2           resq 1            ; second key handle for GPU subkey
    regSize         resd 1
    regType         resd 1
    diskTotal       resq 1
    diskFree        resq 1
    adaptersBuffer  resb 131072     ; larger buffer for GetAdaptersAddresses
    adapterSize     resq 1          ; must be qword for GetAdaptersAddresses
    processEntry    resb PROCESSENTRY32_size
    processMem      resb PROCESS_MEMORY_COUNTERS_size
    topProcesses    resb 10 * 280    ; 10 processes, each 280 bytes (PID + memory + name)
    servicesBuffer  resb 65536       ; for services enumeration
    bytesNeeded     resd 1
    servicesCount   resd 1
    hScManager      resq 1
    gpuSubkey       resb 64           ; GPU subkey name (0000, 0001, etc.)
    gpuSubkeyLen    resd 1
    digitalPid      resb 164          ; DigitalProductId binary data
    productKey      resb 30           ; Decoded product key (25 chars + dashes + null)

section .text

; ===== ENTRY POINT =====
Start:
    sub     rsp, 40
    
    ; Get stdout
    mov     ecx, STD_OUTPUT_HANDLE
    call    GetStdHandle
    mov     [hStdOut], rax
    
    ; Title
    lea     rcx, [szTitle]
    call    Print
    
    ; ==========================================
    ; SYSTEM INFORMATION
    ; ==========================================
    lea     rcx, [szSecSys]
    call    Print
    lea     rcx, [szSep]
    call    Print
    
    ; Computer name
    mov     dword [computerNameLen], 255
    lea     rcx, [computerName]
    lea     rdx, [computerNameLen]
    call    GetComputerNameA
    
    lea     rcx, [lblComputer]
    call    PrintLabel
    lea     rcx, [computerName]
    call    Print
    
    ; User name
    mov     dword [userNameLen], 255
    lea     rcx, [userName]
    lea     rdx, [userNameLen]
    call    GetUserNameA
    
    lea     rcx, [lblUser]
    call    PrintLabel
    lea     rcx, [userName]
    call    Print
    
    ; ==========================================
    ; OPERATING SYSTEM
    ; ==========================================
    lea     rcx, [szSecOS]
    call    Print
    lea     rcx, [szSep]
    call    Print
    
    ; System info
    lea     rcx, [sysInfo]
    call    GetSystemInfo
    
    ; OS Version using RtlGetVersion (gets real version on Win10+)
    mov     dword [osInfo], 156       ; RTL_OSVERSIONINFOW size
    lea     rcx, [osInfo]
    call    RtlGetVersion
    
    ; Build Windows version string
    lea     rcx, [lblOSName]
    call    PrintLabel
    
    ; Major.Minor.Build
    mov     eax, [osInfo + 4]         ; dwMajorVersion
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szDot]
    call    Print

    mov     eax, [osInfo + 8]         ; dwMinorVersion
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szDot]
    call    Print

    mov     eax, [osInfo + 12]        ; dwBuildNumber
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print

    ; Interpret version - detect Windows 10 vs 11
    ; Windows 10: Major=10, Minor=0, Build < 22000
    ; Windows 11: Major=10, Minor=0, Build >= 22000
    mov     eax, [osInfo + 4]         ; major
    cmp     eax, 10
    je      .check_win11
    cmp     eax, 6
    jne     .version_done
    mov     eax, [osInfo + 8]         ; minor
    cmp     eax, 3
    je      .is_win81
    cmp     eax, 2
    je      .is_win8
    cmp     eax, 1
    je      .is_win7
    jmp     .version_done

.check_win11:
    mov     eax, [osInfo + 12]        ; build number
    cmp     eax, 22000
    jge     .is_win11
    ; Windows 10
    lea     rcx, [szNewline]
    call    Print
    mov     eax, "  (W"
    mov     [buffer], eax
    mov     eax, "indo"
    mov     [buffer+4], eax
    mov     eax, "ws 1"
    mov     [buffer+8], eax
    mov     dword [buffer+12], "0) "
    mov     byte [buffer+16], 0
    lea     rcx, [buffer]
    call    Print
    jmp     .version_done

.is_win11:
    lea     rcx, [szNewline]
    call    Print
    mov     eax, "  (W"
    mov     [buffer], eax
    mov     eax, "indo"
    mov     [buffer+4], eax
    mov     eax, "ws 1"
    mov     [buffer+8], eax
    mov     dword [buffer+12], "1) "
    mov     byte [buffer+16], 0
    lea     rcx, [buffer]
    call    Print
    jmp     .version_done
.is_win81:
    lea     rcx, [szNewline]
    call    Print
    mov     eax, "  (W"
    mov     [buffer], eax
    mov     eax, "indo"
    mov     [buffer+4], eax
    mov     eax, "ws 8"
    mov     [buffer+8], eax
    mov     dword [buffer+12], ".1) "
    mov     byte [buffer+16], 0
    lea     rcx, [buffer]
    call    Print
    jmp     .version_done
.is_win8:
    lea     rcx, [szNewline]
    call    Print
    mov     eax, "  (W"
    mov     [buffer], eax
    mov     eax, "indo"
    mov     [buffer+4], eax
    mov     eax, "ws 8"
    mov     [buffer+8], eax
    mov     word [buffer+12], ") "
    mov     byte [buffer+14], 0
    lea     rcx, [buffer]
    call    Print
    jmp     .version_done
.is_win7:
    lea     rcx, [szNewline]
    call    Print
    mov     eax, "  (W"
    mov     [buffer], eax
    mov     eax, "indo"
    mov     [buffer+4], eax
    mov     eax, "ws 7"
    mov     [buffer+8], eax
    mov     word [buffer+12], ") "
    mov     byte [buffer+14], 0
    lea     rcx, [buffer]
    call    Print
    
.version_done:
    lea     rcx, [szNewline]
    call    Print

    ; ==========================================
    ; WINDOWS PRODUCT KEY
    ; ==========================================
    ; Read DigitalProductId from registry and decode it
    ; The key is stored in HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DigitalProductId
    sub     rsp, 48
    mov     rcx, HKEY_LOCAL_MACHINE
    lea     rdx, [regWinKey]
    xor     r8d, r8d
    mov     r9d, 0x00020019          ; KEY_READ
    lea     rax, [hKey]
    mov     [rsp + 32], rax
    call    RegOpenKeyExA

    test    eax, eax
    jnz     .product_key_fail

    ; Query DigitalProductId
    mov     rcx, [hKey]
    lea     rdx, [regDigitalPid]
    xor     r8d, r8d
    lea     r9, [regType]
    lea     rax, [digitalPid]
    mov     [rsp + 32], rax
    mov     dword [regSize], 164
    lea     rax, [regSize]
    mov     [rsp + 40], rax
    call    RegQueryValueExA

    test    eax, eax
    jnz     .product_key_close

    ; Decode the product key
    ; The key is encoded in bytes 52-66 of DigitalProductId
    ; Algorithm: decode 15 bytes into 25 base-24 characters
    call    DecodeProductKey

    ; Print the key
    lea     rcx, [lblProductKey]
    call    Print
    lea     rcx, [productKey]
    call    Print
    lea     rcx, [szNewline]
    call    Print

.product_key_close:
    mov     rcx, [hKey]
    call    RegCloseKey
    add     rsp, 48
    jmp     .product_key_done

.product_key_fail:
    add     rsp, 48

.product_key_done:
    ; ==========================================
    ; CPU & ARCHITECTURE
    ; ==========================================
    lea     rcx, [szSecCPU]
    call    Print
    lea     rcx, [szSep]
    call    Print

    ; CPU Name (from registry - HARDWARE\DESCRIPTION\System\CentralProcessor\0\ProcessorNameString)
    lea     rcx, [lblCPUName]
    call    Print

    ; RegOpenKeyExA(HKEY_LOCAL_MACHINE, "HARDWARE\DESCRIPTION\System\CentralProcessor\0", 0, KEY_READ, &hKey)
    sub     rsp, 48
    mov     rcx, HKEY_LOCAL_MACHINE   ; predefined handle
    lea     rdx, [regCPUKey]          ; subkey path
    xor     r8d, r8d                  ; ulOptions = 0
    mov     r9d, 0x00020019           ; KEY_READ access
    lea     rax, [hKey]               ; result handle
    mov     [rsp + 32], rax
    call    RegOpenKeyExA

    test    eax, eax
    jnz     .cpu_name_failed

    ; RegQueryValueExA(hKey, "ProcessorNameString", NULL, &type, buffer, &size)
    mov     rcx, [hKey]               ; key handle
    lea     rdx, [regCPUName]         ; value name
    xor     r8d, r8d                  ; reserved = 0
    lea     r9, [regType]             ; type result
    lea     rax, [regBuffer]          ; buffer for data
    mov     [rsp + 32], rax
    mov     dword [regSize], 256
    lea     rax, [regSize]
    mov     [rsp + 40], rax
    call    RegQueryValueExA

    test    eax, eax
    jnz     .cpu_close_key

    ; Print the CPU name (it's a REG_SZ, but may have leading spaces)
    lea     rsi, [regBuffer]
    movzx   eax, byte [rsi]
    cmp     al, ' '
    jne     .cpu_print_name
.trim_loop:
    inc     rsi
    movzx   eax, byte [rsi]
    cmp     al, ' '
    je      .trim_loop

.cpu_print_name:
    mov     rcx, rsi
    call    Print

.cpu_close_key:
    ; Close key
    mov     rcx, [hKey]
    call    RegCloseKey
    add     rsp, 48
    jmp     .cpu_done

.cpu_name_failed:
    add     rsp, 48
    lea     rcx, [szUnknown]
    call    Print

.cpu_done:
    lea     rcx, [szNewline]
    call    Print

    ; CPU cores
    lea     rcx, [lblCPU]
    call    PrintLabel
    mov     eax, [sysInfo + SYSTEM_INFO.dwNumberOfProcessors]
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szNewline]
    call    Print

    ; Architecture
    lea     rcx, [lblArch]
    call    PrintLabel
    movzx   eax, word [sysInfo + SYSTEM_INFO.wProcessorArchitecture]
    lea     rcx, [archUnknown]
    cmp     ax, 9
    jne     .notamd
    lea     rcx, [archAMD64]
    jmp     .printarch
.notamd:
    cmp     ax, 12
    jne     .printarch
    lea     rcx, [archARM64]
.printarch:
    call    Print
    lea     rcx, [szNewline]
    call    Print
    
    ; ==========================================
    ; MEMORY
    ; ==========================================
    lea     rcx, [szSecMem]
    call    Print
    lea     rcx, [szSep]
    call    Print
    
    mov     dword [memStatus], MEMORYSTATUSEX_SIZE
    lea     rcx, [memStatus]
    call    GlobalMemoryStatusEx
    
    ; Total RAM
    lea     rcx, [lblMemTotal]
    call    PrintLabel
    mov     rax, [memStatus + 8]
    shr     rax, 30
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szGB]
    call    Print
    lea     rcx, [szNewline]
    call    Print
    
    ; Free RAM
    lea     rcx, [lblMemFree]
    call    PrintLabel
    mov     rax, [memStatus + 16]
    shr     rax, 30
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szGB]
    call    Print
    lea     rcx, [szNewline]
    call    Print
    
    ; Memory load with progress bar
    lea     rcx, [lblMemUsed]
    call    PrintLabel
    movzx   eax, byte [memStatus + 4]
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szPct]
    call    Print
    
    ; Simple progress bar
    lea     rcx, [szNewline]
    call    Print
    call    PrintSpaces
    lea     rcx, [buffer]
    mov     word [rcx], "[ "
    call    Print
    
    movzx   eax, byte [memStatus + 4]    ; percent
    mov     ecx, 20                       ; 20 bars max
    mul     ecx
    mov     ecx, 100
    div     ecx                           ; eax = bars filled
    
    mov     ecx, eax
    mov     edx, 20
    sub     edx, eax                      ; edx = bars empty
    
.fill_bar:
    test    ecx, ecx
    jle     .empty_bar
    push    rcx
    push    rdx
    lea     rcx, [buffer]
    mov     byte [rcx], '#'
    mov     byte [rcx+1], 0
    call    Print
    pop     rdx
    pop     rcx
    dec     ecx
    jmp     .fill_bar
    
.empty_bar:
    test    edx, edx
    jle     .bar_done
    push    rdx
    lea     rcx, [buffer]
    mov     byte [rcx], '-'
    mov     byte [rcx+1], 0
    call    Print
    pop     rdx
    dec     edx
    jmp     .empty_bar
    
.bar_done:
    lea     rcx, [buffer]
    mov     word [rcx], " ]"
    mov     byte [rcx+2], 0
    call    Print
    lea     rcx, [szNewline]
    call    Print
    
    ; Page file
    lea     rcx, [lblPageTotal]
    call    PrintLabel
    mov     rax, [memStatus + 24]          ; ullTotalPageFile
    shr     rax, 20                        ; to MB
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szMB]
    call    Print
    lea     rcx, [szNewline]
    call    Print
    
    ; ==========================================
    ; STORAGE
    ; ==========================================
    lea     rcx, [szSecDisk]
    call    Print
    lea     rcx, [szSep]
    call    Print
    
    ; Just show C: drive to avoid crashes with drive enumeration
    lea     rcx, [lblDrive]
    call    Print
    mov     byte [buffer], 'C'
    mov     byte [buffer+1], ':'
    mov     byte [buffer+2], '\'
    mov     byte [buffer+3], 0
    
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szDriveFixed]
    call    Print
    lea     rcx, [szNewline]
    call    Print
    
    ; Get disk space for C:\
    lea     rcx, [buffer]
    lea     rdx, [diskFree]
    lea     r8, [diskTotal]
    xor     r9, r9
    call    GetDiskFreeSpaceExA
    
    test    eax, eax
    jz      .storage_done
    
    ; Total
    lea     rcx, [lblDiskTotal]
    call    Print
    mov     rax, [diskTotal]
    shr     rax, 30
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szGB]
    call    Print
    lea     rcx, [szNewline]
    call    Print
    
    ; Free
    lea     rcx, [lblDiskFree]
    call    Print
    mov     rax, [diskFree]
    shr     rax, 30
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szGB]
    call    Print
    lea     rcx, [szNewline]
    call    Print

.storage_done:

    ; ==========================================
    ; GPU INFO
    ; ==========================================
    lea     rcx, [szSecGPU]
    call    Print
    lea     rcx, [szSep]
    call    Print

    ; Read GPU from registry
    ; HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0001
    lea     rcx, [lblGPU]
    call    Print

    ; Open parent key - need 48 bytes (32 shadow + 16 for params 5-6)
    sub     rsp, 48
    mov     rcx, HKEY_LOCAL_MACHINE
    lea     rdx, [regGPUKey]
    xor     r8d, r8d
    mov     r9d, 0x00020019           ; KEY_READ
    lea     rax, [hKey]
    mov     [rsp + 32], rax
    call    RegOpenKeyExA

    test    eax, eax
    jnz     .gpu_fail

    ; Open subkey "0001"
    mov     rcx, [hKey]
    lea     rdx, [gpuSubkey0000]      ; "0001"
    xor     r8d, r8d
    mov     r9d, 0x00020019
    lea     rax, [hKey2]
    mov     [rsp + 32], rax
    call    RegOpenKeyExA

    test    eax, eax
    jnz     .gpu_close_parent

    ; Query DriverDesc (6 params)
    mov     rcx, [hKey2]
    lea     rdx, [regGPUVal]          ; "DriverDesc"
    xor     r8d, r8d
    lea     r9, [regType]
    lea     rax, [regBuffer]
    mov     [rsp + 32], rax           ; 5th param: lpData
    mov     dword [regSize], 256
    lea     rax, [regSize]
    mov     [rsp + 40], rax           ; 6th param: lpcbData
    call    RegQueryValueExA

    test    eax, eax
    jnz     .gpu_close_subkey

    ; Print GPU name
    lea     rcx, [regBuffer]
    call    Print

.gpu_close_subkey:
    mov     rcx, [hKey2]
    call    RegCloseKey

.gpu_close_parent:
    mov     rcx, [hKey]
    call    RegCloseKey
    add     rsp, 48
    jmp     .gpu_done

.gpu_fail:
    add     rsp, 48
    lea     rcx, [szUnknown]
    call    Print

.gpu_done:
    lea     rcx, [szNewline]
    call    Print

    ; ==========================================
    ; MOTHERBOARD INFO
    ; ==========================================
    lea     rcx, [szSecMB]
    call    Print
    lea     rcx, [szSep]
    call    Print

    ; Read motherboard manufacturer from registry
    ; HARDWARE\DESCRIPTION\System\BIOS\BaseBoardManufacturer
    lea     rcx, [lblMBManuf]
    call    Print

    sub     rsp, 48
    mov     rcx, HKEY_LOCAL_MACHINE
    lea     rdx, [regHwKey]          ; "HARDWARE\DESCRIPTION\System\BIOS"
    xor     r8d, r8d
    mov     r9d, 0x00020019          ; KEY_READ
    lea     rax, [hKey]
    mov     [rsp + 32], rax
    call    RegOpenKeyExA

    test    eax, eax
    jnz     .mb_manuf_failed

    ; Query BaseBoardManufacturer
    mov     rcx, [hKey]
    lea     rdx, [regManuf]          ; "BaseBoardManufacturer"
    xor     r8d, r8d
    lea     r9, [regType]
    lea     rax, [regBuffer]
    mov     [rsp + 32], rax
    mov     dword [regSize], 256
    lea     rax, [regSize]
    mov     [rsp + 40], rax
    call    RegQueryValueExA

    test    eax, eax
    jnz     .mb_manuf_close

    ; Print manufacturer
    lea     rcx, [regBuffer]
    call    Print
    jmp     .mb_manuf_close

.mb_manuf_failed:
    lea     rcx, [szUnknown]
    call    Print

.mb_manuf_close:
    mov     rcx, [hKey]
    call    RegCloseKey
    add     rsp, 48
    lea     rcx, [szNewline]
    call    Print

    ; Read motherboard product from registry
    lea     rcx, [lblMBProduct]
    call    Print

    sub     rsp, 48
    mov     rcx, HKEY_LOCAL_MACHINE
    lea     rdx, [regHwKey]
    xor     r8d, r8d
    mov     r9d, 0x00020019
    lea     rax, [hKey]
    mov     [rsp + 32], rax
    call    RegOpenKeyExA

    test    eax, eax
    jnz     .mb_product_failed

    ; Query BaseBoardProduct
    mov     rcx, [hKey]
    lea     rdx, [regProduct]        ; "BaseBoardProduct"
    xor     r8d, r8d
    lea     r9, [regType]
    lea     rax, [regBuffer]
    mov     [rsp + 32], rax
    mov     dword [regSize], 256
    lea     rax, [regSize]
    mov     [rsp + 40], rax
    call    RegQueryValueExA

    test    eax, eax
    jnz     .mb_product_close

    ; Print product
    lea     rcx, [regBuffer]
    call    Print
    jmp     .mb_product_close

.mb_product_failed:
    lea     rcx, [szUnknown]
    call    Print

.mb_product_close:
    mov     rcx, [hKey]
    call    RegCloseKey
    add     rsp, 48
    lea     rcx, [szNewline]
    call    Print
    
    ; ==========================================
    ; NETWORK
    ; ==========================================
    lea     rcx, [szSecNet]
    call    Print
    lea     rcx, [szSep]
    call    Print

    ; Initialize adapter size (128KB should be enough)
    mov     qword [adapterSize], 131072

    ; GetAdaptersAddresses(Family=AF_UNSPEC=0, Flags, Reserved=NULL, AdapterAddresses, SizePointer)
    ; RCX = Family (0 = AF_UNSPEC)
    ; RDX = Flags
    ; R8 = Reserved (NULL)
    ; R9 = AdapterAddresses buffer
    ; [RSP+32] = SizePointer
    sub     rsp, 48                         ; shadow space + 1 stack param
    mov     rcx, 0                          ; Family = AF_UNSPEC
    mov     rdx, GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER
    xor     r8d, r8d                        ; Reserved = NULL
    lea     r9, [adaptersBuffer]            ; AdapterAddresses
    lea     rax, [adapterSize]
    mov     [rsp + 32], rax                 ; SizePointer on stack
    call    GetAdaptersAddresses
    add     rsp, 48

    test    eax, eax
    jnz     .no_adapters

    lea     rbx, [adaptersBuffer]           ; current adapter pointer
    xor     r12d, r12d                      ; adapter count

.adapter_loop:
    test    rbx, rbx
    jz      .adapters_done

    ; Check if adapter is UP (OperStatus == 1)
    mov     eax, [rbx + IP_ADAPTER_ADDRESSES.OperStatus]
    cmp     eax, IfOperStatusUp
    jne     .skip_adapter                    ; Skip disconnected adapters

    inc     r12d

    ; Print adapter number
    lea     rcx, [szNewline]
    call    Print
    call    PrintSpaces
    lea     rcx, [buffer]
    mov     byte [rcx], '#'
    mov     byte [rcx+1], 0
    call    Print
    mov     eax, r12d
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [szNewline]
    call    Print

    ; Description (it's a wchar* pointer, need to convert)
    lea     rcx, [lblAdapter]
    call    PrintLabel
    mov     rax, [rbx + IP_ADAPTER_ADDRESSES.Description]
    test    rax, rax
    jz      .desc_unknown
    ; Description is wide char (UTF-16), convert to ASCII
    lea     rdi, [buffer]
    mov     rsi, rax
.desc_convert:
    movzx   eax, word [rsi]
    test    ax, ax
    jz      .desc_done
    mov     [rdi], al
    inc     rsi
    inc     rsi
    inc     rdi
    jmp     .desc_convert
.desc_done:
    mov     byte [rdi], 0
    lea     rcx, [buffer]
    call    Print
    jmp     .desc_printed
.desc_unknown:
    lea     rcx, [szUnknown]
    call    Print
.desc_printed:
    lea     rcx, [szNewline]
    call    Print

    ; Status
    lea     rcx, [szStatus]
    call    PrintLabel
    lea     rcx, [szConnected]
    call    Print
    lea     rcx, [szNewline]
    call    Print

    ; IP Address from FirstUnicastAddress - need to iterate to find IPv4
    lea     rcx, [lblIP]
    call    PrintLabel

    mov     r14, [rbx + IP_ADAPTER_ADDRESSES.FirstUnicastAddress]
    ; r14 = current unicast address pointer

.ip_find_ipv4:
    test    r14, r14
    jz      .ip_no_address

    ; r14 points to IP_ADAPTER_UNICAST_ADDRESS
    ; The Address field contains lpSockaddr (pointer to SOCKADDR)
    mov     rcx, [r14 + IP_ADAPTER_UNICAST_ADDRESS.Address + SOCKET_ADDRESS.lpSockaddr]
    test    rcx, rcx
    jz      .ip_next_unicast

    ; Check if it's IPv4 (sin_family == AF_INET = 2)
    cmp     word [rcx + SOCKADDR_IN.sin_family], 2
    je      .ip_found_ipv4

.ip_next_unicast:
    mov     r14, [r14 + IP_ADAPTER_UNICAST_ADDRESS.Next]
    jmp     .ip_find_ipv4

.ip_found_ipv4:
    ; Get the IP address from sin_addr
    mov     eax, [rcx + SOCKADDR_IN.sin_addr]
    test    eax, eax
    jz      .ip_no_address

    ; Convert IP to string (network byte order)
    lea     rdi, [buffer]
    call    FormatIPAddress
    lea     rcx, [buffer]
    call    Print
    jmp     .ip_done

.ip_no_address:
    lea     rcx, [szNotConnected]
    call    Print
.ip_done:
    lea     rcx, [szNewline]
    call    Print

    ; MAC Address - PhysicalAddress is at offset 84, length at offset 80
    lea     rcx, [lblMAC]
    call    PrintLabel

    mov     eax, [rbx + IP_ADAPTER_ADDRESSES.PhysicalAddressLength]
    test    eax, eax
    jz      .mac_unknown
    cmp     eax, 6
    jb      .mac_unknown

    lea     rdi, [buffer]
    lea     rsi, [rbx + IP_ADAPTER_ADDRESSES.PhysicalAddress]
    
    movzx   eax, byte [rsi]
    call    FormatMACByte
    mov     byte [rdi], ':'
    inc     rdi
    movzx   eax, byte [rsi + 1]
    call    FormatMACByte
    mov     byte [rdi], ':'
    inc     rdi
    movzx   eax, byte [rsi + 2]
    call    FormatMACByte
    mov     byte [rdi], ':'
    inc     rdi
    movzx   eax, byte [rsi + 3]
    call    FormatMACByte
    mov     byte [rdi], ':'
    inc     rdi
    movzx   eax, byte [rsi + 4]
    call    FormatMACByte
    mov     byte [rdi], ':'
    inc     rdi
    movzx   eax, byte [rsi + 5]
    call    FormatMACByte
    mov     byte [rdi], 0

    lea     rcx, [buffer]
    call    Print
    jmp     .mac_done

.mac_unknown:
    lea     rcx, [szUnknown]
    call    Print
.mac_done:
    lea     rcx, [szNewline]
    call    Print

    ; Adapter type
    lea     rcx, [lblType]
    call    PrintLabel
    mov     eax, [rbx + IP_ADAPTER_ADDRESSES.IfType]
    lea     rcx, [netTypeOther]
    cmp     eax, IF_TYPE_ETHERNET_CSMACD
    jne     .not_ethernet
    lea     rcx, [netTypeEthernet]
    jmp     .print_type
.not_ethernet:
    cmp     eax, IF_TYPE_IEEE80211
    jne     .print_type
    lea     rcx, [netTypeWifi]
.print_type:
    call    Print
    lea     rcx, [szNewline]
    call    Print

.skip_adapter:
    ; Next adapter
    mov     rbx, [rbx + IP_ADAPTER_ADDRESSES.Next]
    jmp     .adapter_loop

.no_adapters:
    lea     rcx, [errNoAdapters]
    call    Print
    lea     rcx, [szNewline]
    call    Print
    
.adapters_done:

    ; ==========================================
    ; TOP PROCESSES
    ; ==========================================
    lea     rcx, [szSecProc]
    call    Print
    lea     rcx, [szSep]
    call    Print
    
    ; Create snapshot
    mov     ecx, TH32CS_SNAPPROCESS
    xor     edx, edx
    call    CreateToolhelp32Snapshot

    mov     rbx, rax              ; save snapshot handle
    cmp     rax, -1
    je      .process_done

    ; Initialize process entry
    mov     dword [processEntry], PROCESSENTRY32_SIZE

    ; Get first process
    mov     rcx, rbx
    lea     rdx, [processEntry]
    call    Process32First

    test    eax, eax
    jz      .close_snap

    mov     r12d, 0               ; process count

.proc_loop:
    inc     r12d
    cmp     r12d, 20
    jg      .close_snap

    ; Print "  PID: Name"
    lea     rcx, [szSpace]
    call    Print
    lea     rcx, [szSpace]
    call    Print

    ; PID
    mov     eax, [processEntry + 8]    ; th32ProcessID
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    
    ; Padding after PID
    mov     r13, rax                   ; length of PID string
.pid_pad_loop:
    cmp     r13, 8
    jge     .pid_done_pad
    lea     rcx, [szSpace]
    call    Print
    inc     r13
    jmp     .pid_pad_loop
    
.pid_done_pad:
    ; Print process name
    lea     rcx, [processEntry + 44]   ; szExeFile
    call    Print

    lea     rcx, [szNewline]
    call    Print

    ; Get next process
    mov     rcx, rbx
    lea     rdx, [processEntry]
    call    Process32Next

    test    eax, eax
    jnz     .proc_loop

.close_snap:
    mov     rcx, rbx
    call    CloseHandle

.process_done:

    ; ==========================================
    ; RUNNING SERVICES
    ; ==========================================
    lea     rcx, [szSecSvc]
    call    Print
    lea     rcx, [szSep]
    call    Print

    ; Open service manager
    sub     rsp, 64                  ; enough for 8 params
    xor     rcx, rcx                 ; lpMachineName (NULL = local)
    xor     rdx, rdx                 ; lpDatabaseName (NULL = default)
    xor     r8d, r8d                 ; dwDesiredAccess
    mov     r9d, SC_MANAGER_ENUMERATE_SERVICE
    call    OpenSCManagerA

    test    rax, rax
    jz      .services_failed

    mov     [hScManager], rax

    ; Enumerate services - EnumServicesStatusA has 8 params
    ; First call with NULL buffer to get size needed
    mov     rcx, [hScManager]        ; hSCManager
    mov     edx, SERVICE_WIN32       ; dwServiceType
    mov     r8d, SERVICE_ACTIVE      ; dwServiceState (active = running)
    xor     r9d, r9d                 ; lpServices = NULL
    mov     qword [rsp + 32], 0      ; cbBufSize = 0
    lea     rax, [bytesNeeded]
    mov     [rsp + 40], rax          ; pcbBytesNeeded
    lea     rax, [servicesCount]
    mov     [rsp + 48], rax          ; lpServicesReturned
    mov     qword [rsp + 56], 0      ; lpResumeHandle
    call    EnumServicesStatusA

    ; Check if we need more buffer (ERROR_MORE_DATA = 234)
    call    GetLastError
    cmp     eax, 234                 ; ERROR_MORE_DATA is expected
    je      .services_got_size
    cmp     eax, 0
    jne     .services_access_denied

.services_got_size:
    ; Check bytesNeeded
    mov     eax, [bytesNeeded]
    test    eax, eax
    jz      .services_close

    ; Now call with proper buffer and size
    mov     rcx, [hScManager]
    mov     edx, SERVICE_WIN32
    mov     r8d, SERVICE_ACTIVE
    lea     r9, [servicesBuffer]
    mov     rax, [bytesNeeded]
    mov     [rsp + 32], rax          ; cbBufSize
    lea     rax, [bytesNeeded]
    mov     [rsp + 40], rax
    lea     rax, [servicesCount]
    mov     [rsp + 48], rax
    mov     qword [rsp + 56], 0
    call    EnumServicesStatusA

    ; Check servicesCount
    mov     eax, [servicesCount]
    test    eax, eax
    jz      .services_close

    ; Iterate through services - show only running ones
    xor     r12d, r12d               ; counter for displayed services
    lea     r13, [servicesBuffer]    ; current service pointer
    mov     r14d, [servicesCount]    ; total services

.services_loop:
    test    r14d, r14d
    jz      .services_close

    ; Check service state
    ; ENUM_SERVICE_STATUS: lpServiceName(8), lpDisplayName(8), SERVICE_STATUS(28)
    ; SERVICE_STATUS: dwServiceType(4), dwCurrentState(4), ...
    ; dwCurrentState is at offset 8+8+4 = 20
    mov     eax, [r13 + 20]          ; dwCurrentState
    cmp     eax, SERVICE_RUNNING
    jne     .services_next

    ; Print running service
    push    r12
    push    r13
    push    r14
    sub     rsp, 40

    lea     rcx, [svcRunning]
    call    Print

    ; Print service name (pointer at offset 0)
    mov     rcx, [r13]
    call    Print

    lea     rcx, [szNewline]
    call    Print

    add     rsp, 40
    pop     r14
    pop     r13
    pop     r12

    inc     r12d
    cmp     r12d, 20                 ; limit to 20 services
    jae     .services_close

.services_next:
    ; Each ENUM_SERVICE_STATUS is approximately 72 bytes (8+8+28 = 44, but aligned larger)
    ; ActuallyENUM_SERVICE_STATUSA is: 2 pointers (16 bytes) + SERVICE_STATUS (28 bytes) = 44 bytes
    ; But strings are stored after the array, so we just increment by structure size
    add     r13, 44                  ; size of ENUM_SERVICE_STATUSA structure
    dec     r14d
    jmp     .services_loop

.services_close:
    mov     rcx, [hScManager]
    call    CloseServiceHandle
    add     rsp, 64
    jmp     .services_done

.services_access_denied:
    ; Close handle and show access denied message
    mov     rcx, [hScManager]
    call    CloseServiceHandle
    add     rsp, 64
    lea     rcx, [szServicePlaceholder]
    call    Print
    jmp     .services_done

.services_failed:
    add     rsp, 64
    lea     rcx, [errNoServices]
    call    Print
    lea     rcx, [szNewline]
    call    Print

.services_done:

    ; ==========================================
    ; UPTIME & FOOTER
    ; ==========================================
    lea     rcx, [szNewline]
    call    Print
    lea     rcx, [lblUptime]
    call    PrintLabel
    
    call    GetTickCount64
    
    ; Convert ms to seconds
    xor     rdx, rdx
    mov     rcx, 1000
    div     rcx
    
    ; Days
    mov     rcx, 86400
    xor     rdx, rdx
    div     rcx
    push    rdx
    
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [lblDays]
    call    Print
    
    ; Hours
    pop     rax
    mov     rcx, 3600
    xor     rdx, rdx
    div     rcx
    push    rdx
    
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [lblHours]
    call    Print
    
    ; Minutes
    pop     rax
    mov     ecx, 60
    xor     edx, edx
    div     ecx
    push    rdx
    
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [lblMins]
    call    Print
    
    ; Seconds
    pop     rax
    lea     rcx, [buffer]
    call    IntToStr
    lea     rcx, [buffer]
    call    Print
    lea     rcx, [lblSecs]
    call    Print
    
    ; Footer
    lea     rcx, [szNewline]
    call    Print
    lea     rcx, [szNewline]
    call    Print
    lea     rcx, [szSepDouble]
    call    Print
    
    add     rsp, 40
    xor     ecx, ecx
    jmp     ExitProcess

; ===== HELPER FUNCTIONS =====

; Print label with colon
PrintLabel:
    sub     rsp, 56
    push    rbx
    mov     rbx, rcx
    
    ; Print the label
    mov     rcx, rbx
    call    Print
    
    ; Print colon
    lea     rcx, [szColon]
    call    Print
    
    pop     rbx
    add     rsp, 56
    ret

; Print 4 spaces
PrintSpaces:
    sub     rsp, 56
    lea     rcx, [buffer]
    mov     dword [rcx], "    "
    mov     byte [rcx+4], 0
    call    Print
    add     rsp, 56
    ret

; Convert byte to hex string
; Input: AL = byte, RDI = destination buffer
ByteToHex:
    push    rax
    push    rcx
    push    rdx
    
    mov     ah, al
    shr     al, 4
    call     .nibble
    mov     [rdi], al
    inc     rdi
    mov     al, ah
    and     al, 0x0F
    call     .nibble
    mov     [rdi], al
    inc     rdi
    
    pop     rdx
    pop     rcx
    pop     rax
    ret
    
.nibble:
    cmp     al, 10
    jl      .digit
    add     al, 'A' - 10
    ret
.digit:
    add     al, '0'
    ret

; FormatMACByte - convert byte to 2 hex chars in RDI
FormatMACByte:
    push    rax
    push    rcx
    
    mov     ah, al
    shr     al, 4
    cmp     al, 10
    jl      .high_digit
    add     al, 'A' - 10
    jmp     .high_done
.high_digit:
    add     al, '0'
.high_done:
    mov     [rdi], al
    inc     rdi
    
    mov     al, ah
    and     al, 0x0F
    cmp     al, 10
    jl      .low_digit
    add     al, 'A' - 10
    jmp     .low_done
.low_digit:
    add     al, '0'
.low_done:
    mov     [rdi], al
    inc     rdi

    pop     rcx
    pop     rax
    ret

; ===== PRINT STRING =====
; rcx = string pointer
Print:
    push    rax
    push    rdx
    push    r8
    push    r9
    push    rsi
    push    rdi
    sub     rsp, 40
    
    mov     rsi, rcx
    xor     edi, edi
    
.strlen:
    cmp     byte [rsi + rdi], 0
    je      .write
    inc     edi
    jmp     .strlen
    
.write:
    test    edi, edi
    jz      .done
    
    mov     rcx, [hStdOut]
    mov     rdx, rsi
    mov     r8d, edi
    lea     r9, [bytesWritten]
    mov     qword [rsp + 32], 0
    call    WriteFile
    
.done:
    add     rsp, 40
    pop     rdi
    pop     rsi
    pop     r9
    pop     r8
    pop     rdx
    pop     rax
    ret

; ===== DECODE WINDOWS PRODUCT KEY =====
; Decodes DigitalProductId (bytes 52-66) into product key string
; Input: digitalPid buffer contains the binary data
; Output: productKey buffer contains the decoded key string
DecodeProductKey:
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 56                 ; extra space for temp buffer

    ; keyChars = "BCDFGHJKMPQRTVWXY2346789"
    lea     rsi, [keyChars]

    ; Product key is in digitalPid bytes 52-66 (15 bytes)
    lea     rdi, [digitalPid + 52]

    ; Use stack as temp buffer for 25 chars
    lea     r15, [rsp + 8]          ; temp buffer on stack

    ; Decode 25 characters from the 15 bytes
    ; We work backwards through the key: character 24 downto 0
    mov     r12d, 24                ; character index (24 to 0)

.decode_loop:
    ; Divide the 15-byte number by 24
    ; We need to do multi-byte division
    xor     edx, edx                ; remainder = 0
    mov     ecx, 15                 ; byte counter

.divide_loop:
    ; Process each byte from end to start
    movzx   eax, byte [rdi + rcx - 1]  ; get byte
    ; eax = (eax + remainder * 256) / 24
    ; remainder = (eax + remainder * 256) % 24
    movzx   ebx, dl                 ; save remainder
    shl     ebx, 8                  ; remainder * 256
    add     eax, ebx                ; eax = byte + remainder * 256
    xor     edx, edx
    mov     ebx, 24
    div     ebx                     ; eax = quotient, edx = remainder
    mov     [rdi + rcx - 1], al     ; store quotient back
    dec     ecx
    jnz     .divide_loop

    ; edx now contains the character index in base-24
    movzx   eax, dl                 ; character index
    mov     bl, [rsi + rax]         ; get character from keyChars
    mov     [r15 + r12], bl         ; store in temp buffer (we decode backwards)
    dec     r12d
    jns     .decode_loop            ; continue until index < 0

    ; Now build final key with dashes
    ; Format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
    ; Copy from temp buffer to productKey with dashes
    lea     rdi, [productKey]       ; destination
    mov     rsi, r15                ; source (temp buffer)
    xor     ecx, ecx                ; source index
    xor     edx, edx                ; dest index

.insert_loop:
    cmp     ecx, 25
    jae     .insert_done

    ; Check if we need a dash before this character
    ; Dashes after chars at positions 4, 10, 16, 22 (when inserting, after dest pos 5, 11, 17, 23)
    cmp     ecx, 5
    je      .need_dash
    cmp     ecx, 10
    je      .need_dash
    cmp     ecx, 15
    je      .need_dash
    cmp     ecx, 20
    je      .need_dash
    jmp     .no_dash

.need_dash:
    mov     byte [rdi + rdx], '-'
    inc     edx

.no_dash:
    mov     al, [rsi + rcx]
    mov     [rdi + rdx], al
    inc     ecx
    inc     edx
    jmp     .insert_loop

.insert_done:
    mov     byte [rdi + rdx], 0     ; null terminator

    add     rsp, 56
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ===== INT TO STRING =====
; eax = value, rcx = buffer
IntToStr:
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    sub     rsp, 32
    
    mov     rdi, rcx
    mov     esi, eax
    
    test    esi, esi
    jnz     .convert
    
    mov     word [rdi], '0'
    jmp     .done
    
.convert:
    xor     ebx, ebx
    mov     eax, esi

.count:
    inc     ebx
    xor     edx, edx
    mov     ecx, 10
    div     ecx
    test    eax, eax
    jnz     .count

    mov     byte [rdi + rbx], 0
    mov     eax, esi

.write:
    xor     edx, edx
    mov     ecx, 10
    div     ecx
    add     dl, '0'
    dec     rbx
    mov     [rdi + rbx], dl
    test    eax, eax
    jnz     .write

.done:
    add     rsp, 32
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ===== FORMAT IP ADDRESS =====
; Input: EAX = IP address in network byte order (e.g., 0x3F02000A for 10.0.2.63)
;             In memory: byte[0]=10, byte[1]=0, byte[2]=2, byte[3]=63 (on little-endian x86)
;        RDI = destination buffer
; Output: Buffer contains dotted decimal string like "10.0.2.63"
FormatIPAddress:
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    r12
    push    r13
    
    mov     r12d, eax               ; save IP in r12d
    mov     r13, rdi                ; save buffer pointer in r13
    
    ; Network byte order - on x86 (little-endian):
    ; First octet is LSB, second is bits 8-15, etc.
    
    ; First octet (LSB)
    movzx   eax, r12b
    mov     rcx, r13
    call    IntToStr
    ; Find end of string
    mov     rdi, r13
    xor     ecx, ecx
.find_end1:
    cmp     byte [rdi + rcx], 0
    je      .found_end1
    inc     ecx
    jmp     .find_end1
.found_end1:
    add     rdi, rcx
    mov     byte [rdi], '.'
    inc     rdi
    
    ; Second octet (bits 8-15)
    mov     eax, r12d
    shr     eax, 8
    and     eax, 0xFF
    mov     rcx, rdi
    call    IntToStr
    ; Find end
    xor     ecx, ecx
.find_end2:
    cmp     byte [rdi + rcx], 0
    je      .found_end2
    inc     ecx
    jmp     .find_end2
.found_end2:
    add     rdi, rcx
    mov     byte [rdi], '.'
    inc     rdi
    
    ; Third octet (bits 16-23)
    mov     eax, r12d
    shr     eax, 16
    and     eax, 0xFF
    mov     rcx, rdi
    call    IntToStr
    ; Find end
    xor     ecx, ecx
.find_end3:
    cmp     byte [rdi + rcx], 0
    je      .found_end3
    inc     ecx
    jmp     .find_end3
.found_end3:
    add     rdi, rcx
    mov     byte [rdi], '.'
    inc     rdi
    
    ; Fourth octet (MSB, bits 24-31)
    mov     eax, r12d
    shr     eax, 24
    and     eax, 0xFF
    mov     rcx, rdi
    call    IntToStr
    
    pop     r13
    pop     r12
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret