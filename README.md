# x64 Windows Assembly Projects

A collection of x64 Windows assembly programs written in NASM syntax.

## Projects

| Project | Description |
|---------|-------------|
| `helloworld.asm` | Bouncing "Hello World" text with color-changing animation |
| `guidemo.asm` | Windows GUI controls demo showcasing various UI components |
| `SysInspect.asm` | System information tool (processes, memory, network, services) |
| `burger_bounce/` | Transparent PNG window with physics-based bouncing animation |

## Requirements

### Assembler
- **NASM** - The Netwide Assembler (x64 version)
  - Download: https://www.nasm.us/

### Linker & SDK
- **Microsoft Visual C++ Build Tools** or **Visual Studio** with:
  - MSVC linker (`link.exe`)
  - Windows SDK (for import libraries)

### Required Libraries
All projects link against standard Windows libraries:

| Library | Purpose |
|---------|---------|
| `kernel32.lib` | Core Windows API |
| `user32.lib` | Window management, input |
| `gdi32.lib` | Graphics device interface |
| `advapi32.lib` | Registry, services, security |
| `psapi.lib` | Process status |
| `iphlpapi.lib` | IP helper (network info) |
| `gdiplus.lib` | GDI+ (PNG loading) |
| `ole32.lib` | COM support |
| `comctl32.lib` | Common controls |

## Building

### Simple Projects (Console/GUI)

```batch
:: Assemble
nasm -f win64 <filename>.asm -o <filename>.obj

:: Link (console)
link /ENTRY:Start /SUBSYSTEM:CONSOLE <filename>.obj kernel32.lib user32.lib

:: Link (GUI)
link /ENTRY:Start /SUBSYSTEM:WINDOWS <filename>.obj kernel32.lib user32.lib gdi32.lib
```

### burger_bounce

See [`burger_bounce/README.md`](burger_bounce/README.md) for detailed build instructions.

```batch
cd burger_bounce
build.bat
```

## Project Details

### helloworld.asm
A simple window with bouncing "Hello World!" text that changes color when hitting screen edges.

**Build:**
```batch
nasm -f win64 helloworld.asm -o helloworld.obj
link /ENTRY:Start /SUBSYSTEM:WINDOWS helloworld.obj kernel32.lib user32.lib gdi32.lib
```

### guidemo.asm
Demonstrates various Windows GUI controls including buttons, edit boxes, list boxes, and scrollbars.

**Build:**
```batch
nasm -f win64 guidemo.asm -o guidemo.obj
link /ENTRY:Start /SUBSYSTEM:WINDOWS guidemo.obj kernel32.lib user32.lib gdi32.lib comctl32.lib
```

### SysInspect.asm
A comprehensive system information tool displaying:
- Computer and user name
- CPU and memory info
- Disk drives and space
- Network adapters
- Running processes with memory usage
- Windows services

**Build:**
```batch
nasm -f win64 SysInspect.asm -o SysInspect.obj
link /ENTRY:Start /SUBSYSTEM:CONSOLE SysInspect.obj kernel32.lib user32.lib advapi32.lib iphlpapi.lib psapi.lib
```
