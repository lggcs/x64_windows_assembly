@echo off
echo Building burger_bounce.exe...

:: Save current directory and get the parent (nasm-3.01 directory)
set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."

:: Assemble with NASM (run from burger_bounce directory for incbin paths)
cd /d "%SCRIPT_DIR%"
..\nasm.exe -f win64 burger_bounce.asm -o burger_bounce.obj
if %ERRORLEVEL% neq 0 (
    echo Assembly failed!
    exit /b 1
)

:: Compile resource file
"..\msvc\Windows Kits\10\bin\10.0.26100.0\x64\rc.exe" /nologo /r /fo burger_bounce.res burger_bounce.rc
if %ERRORLEVEL% neq 0 (
    echo Resource compilation failed!
    exit /b 1
)

:: Link with MSVC linker (relative to root directory)
cd /d "%ROOT_DIR%"
"msvc\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\link.exe" /ENTRY:Start /SUBSYSTEM:WINDOWS /LIBPATH:"msvc\Windows Kits\10\Lib\10.0.26100.0\um\x64" /LIBPATH:"msvc\Windows Kits\10\Lib\10.0.26100.0\ucrt\x64" kernel32.lib user32.lib gdi32.lib ole32.lib gdiplus.lib burger_bounce\burger_bounce.obj burger_bounce\burger_bounce.res /OUT:burger_bounce\burger_bounce.exe
if %ERRORLEVEL% neq 0 (
    echo Link failed!
    cd /d "%SCRIPT_DIR%"
    exit /b 1
)

cd /d "%SCRIPT_DIR%"
echo Build successful! burger_bounce.exe created.

:: Run
if "%1"=="run" (
    start "" burger_bounce.exe
)