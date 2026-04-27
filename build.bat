@echo off
setlocal EnableDelayedExpansion

set "XEDK=C:\Program Files (x86)\Microsoft Xbox 360 SDK"
set "PPU_AS=C:\usr\local\cell\host-win32\ppu\bin\ppu-lv2-as.exe"
set "PPU_LD=C:\usr\local\cell\host-win32\ppu\bin\ppu-lv2-ld.exe"

if not exist "!XEDK!\" (
    echo Error: Xbox 360 XDK not found at: !XEDK!
    exit /b 1
)

set "PATH=!XEDK!\bin\win32;%PATH%"
set "INCLUDE=!XEDK!\include\xbox;!XEDK!\include\xbox\sys;!XEDK!\include\win32"
set "LIB=!XEDK!\lib\xbox"

set "SRC=%~dp0ShitShadowBoot"
set "ROOT=%~dp0"
set "OUT=%~dp0build"

if not exist "!OUT!" mkdir "!OUT!"

rem -----------------------------------------------------------------------
"!PPU_AS!" "!ROOT!HvxShadowBoot.asm" -o "!OUT!\HvxShadowBoot.o"
if errorlevel 1 goto :error
"!PPU_LD!" -r -o "!OUT!\HvxShadowBoot_reloc.o" "!OUT!\HvxShadowBoot.o"
if errorlevel 1 goto :error
"!PPU_LD!" --oformat binary -Ttext 0 -e HvxSymtab -o "!OUT!\HvxShadowBoot.bin" "!OUT!\HvxShadowBoot_reloc.o"
if errorlevel 1 goto :error
del "!OUT!\HvxShadowBoot.o" "!OUT!\HvxShadowBoot_reloc.o"

rem -----------------------------------------------------------------------
set "PYTHON=C:\Users\Lennert\AppData\Local\Programs\Python\Python312\python.exe"
"!PYTHON!" "!ROOT!bin2h.py" "!OUT!\HvxShadowBoot.bin" "!SRC!\HvxShadowBoot.h"
if errorlevel 1 goto :error

rem -----------------------------------------------------------------------
cl.exe /nologo /W3 /EHsc /MT /O2 /Gy /D_XBOX ^
    /I"!XEDK!\include\xbox" /I"!XEDK!\include\xbox\sys" /I"!XEDK!\include\win32" ^
    /Fo"!OUT!/" /c ^
    "!SRC!\ShitShadowBoot.cpp" ^
    "!SRC!\Freeboot.cpp"
if errorlevel 1 goto :error

link.exe /nologo /subsystem:xbox ^
    /out:"!OUT!\ShitShadowBoot.exe" ^
    "!OUT!\ShitShadowBoot.obj" ^
    "!OUT!\Freeboot.obj" ^
    xapilib.lib xboxkrnl.lib
if errorlevel 1 goto :error

imagexex.exe /in:"!OUT!\ShitShadowBoot.exe" /out:"!OUT!\ShitShadowBoot.xex"
if errorlevel 1 goto :error

echo.
echo Build succeeded: build\ShitShadowBoot.xex
endlocal
exit /b 0

:error
echo.
echo Build failed.
endlocal
exit /b 1
