@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
:: Tiến trình nhịp gõ (gọi lại file này với __beat) giữ tiêu đề "AnhCuoi Beat" để TASKKILL cuối file tìm được.
IF "%~1"=="__beat" (title AnhCuoi Beat) ELSE (title Anh Cuoi)
color 0F

:: Chạy Ảnh Cưới trên Windows: php\php.exe (đóng gói sẵn).
:: Link công khai (https://xxxx.jagame.vn) do WEB tự quản — script chỉ chạy PHP, tải cloudflared lần
:: đầu và gõ /health mỗi phút để web tự xin link / bật lại tunnel.
::
:: QUY TẮC ĐƯỜNG DẪN (R2-03): thư mục cài đặt có thể chứa dấu cách, ( ) & hoặc chữ có dấu, ví dụ
:: "anhcuoi-windows (1)". Vì vậy: gán bằng SET "X=..." (có ngoặc kép), KHÔNG dùng %X% chứa đường dẫn bên trong
:: khối ( ... ) — ở đó dùng !X! (mở rộng trễ) hoặc tách thành IF ... GOTO. Đường dẫn truyền cho php.exe là
:: đường dẫn TƯƠNG ĐỐI sau khi cd vào thư mục web (php.exe không nhận chắc chắn tham số có chữ có dấu).
:: Hạn chế còn lại: thư mục có dấu chấm than (!) không được hỗ trợ (mở rộng trễ nuốt ký tự này).

SET "SCRIPT_DIR=%~dp0"
SET "SELF=%~f0"

:: ── Cập nhật từ trang quản trị (Docs/cap-nhat.md) ──────────────────────────
:: cmd đọc file .bat theo từng dòng KHI ĐANG CHẠY nên web không thay .bat tại chỗ mà để bản mới ở database\.update\bat\
:: — áp ở đây, khi chưa chạy gì. Thay chính file này thì chạy luôn bản mới trong CÙNG khối ( ... ) (cmd đọc trọn khối
:: trước khi chạy, không đọc tiếp file đã đổi). MOVE lỗi thì chạy tiếp bản cũ, không lặp.
IF "%~1"=="__beat" GOTO upd_done
IF EXIST "!SCRIPT_DIR!database\.update\bat\reset_win.bat" MOVE /Y "!SCRIPT_DIR!database\.update\bat\reset_win.bat" "!SCRIPT_DIR!reset_win.bat" >nul 2>&1
IF NOT DEFINED ANHCUOI_KEEPALIVE IF EXIST "!SCRIPT_DIR!database\.update\bat\keepalive_win.bat" MOVE /Y "!SCRIPT_DIR!database\.update\bat\keepalive_win.bat" "!SCRIPT_DIR!keepalive_win.bat" >nul 2>&1
IF EXIST "!SCRIPT_DIR!database\.update\bat\run_window.bat" (
    MOVE /Y "!SCRIPT_DIR!database\.update\bat\run_window.bat" "!SELF!" >nul 2>&1 && "!SELF!" %*
)
:upd_done

:: ── Bố cục: RELEASE (phẳng) hay DEV (Web\ + Tools\ tách) ─────────────────
IF EXIST "!SCRIPT_DIR!router.php" GOTO layout_release
FOR %%I IN ("!SCRIPT_DIR!..") DO SET "ROOT_DIR=%%~fI"
SET "WEB_ROOT=!ROOT_DIR!\Web\"
SET "PHP_DIR=!ROOT_DIR!\Tools\php"
SET "PHP_REL=..\Tools\php"
SET "CF_TOOL_DIR=!ROOT_DIR!\Tools\cloudflared"
GOTO layout_done
:layout_release
SET "WEB_ROOT=!SCRIPT_DIR!"
SET "PHP_DIR=!SCRIPT_DIR!php"
SET "PHP_REL=php"
SET "CF_TOOL_DIR=!SCRIPT_DIR!cloudflared"
:layout_done
SET "PHP_EXE=!PHP_DIR!\php.exe"
SET "CF_BIN=!CF_TOOL_DIR!\cloudflared.exe"
SET "CF_CONF_DIR=!WEB_ROOT!cloudflared"
SET "DB_DIR=!WEB_ROOT!database"

:: Tiến trình nền tự gọi lại chính file này (xem cuối file).
IF "%~1"=="__beat" GOTO beat

IF NOT EXIST "!PHP_EXE!" (
    echo [LOI] Khong tim thay php.exe: !PHP_EXE!
    echo       Hay giai nen lai day du goi anhcuoi-windows.zip.
    pause
    exit /b 2
)

:: ── Visual C++ Runtime (D22): php.exe/php8.dll cần VCRUNTIME140.dll. Máy Windows mới cài có thể chưa có ──
CALL :vc_check
IF NOT DEFINED VC_OK CALL :vc_install
IF NOT DEFINED VC_OK GOTO vc_fail

IF NOT EXIST "!CF_CONF_DIR!" mkdir "!CF_CONF_DIR!"
IF NOT EXIST "!DB_DIR!\sessions" mkdir "!DB_DIR!\sessions"
IF NOT EXIST "!WEB_ROOT!uploads\photos" mkdir "!WEB_ROOT!uploads\photos"

:: ── Chọn cổng: 8686 bận thì lùi 8687/8688 (mỗi dòng một lệnh, không khối lồng — chạy đúng cả khi file LF)
SET "PORT="
SET "PBUSY="
FOR /F "delims=" %%i IN ('netstat -ano ^| findstr ":8686 " ^| findstr "LISTENING"') DO SET PBUSY=1
IF NOT DEFINED PBUSY SET PORT=8686
SET "PBUSY="
IF NOT DEFINED PORT FOR /F "delims=" %%i IN ('netstat -ano ^| findstr ":8687 " ^| findstr "LISTENING"') DO SET PBUSY=1
IF NOT DEFINED PORT IF NOT DEFINED PBUSY SET PORT=8687
SET "PBUSY="
IF NOT DEFINED PORT FOR /F "delims=" %%i IN ('netstat -ano ^| findstr ":8688 " ^| findstr "LISTENING"') DO SET PBUSY=1
IF NOT DEFINED PORT IF NOT DEFINED PBUSY SET PORT=8688
IF NOT DEFINED PORT echo [LOI] Ca 3 cong 8686, 8687, 8688 deu ban. Dong bot cua so Anh Cuoi cu roi mo lai.
IF NOT DEFINED PORT pause
IF NOT DEFINED PORT exit /b 1
>"!DB_DIR!\.app_port" <nul set /p =!PORT!
DEL /Q "!DB_DIR!\.public_url" >nul 2>&1
:: R3-07: dấu .ensure_at của lần chạy trước (keepalive chạy lại sau 5 s) còn mới -> nhịp /health đầu bị bỏ qua,
:: link chết thêm ~1 phút. Mới khởi động thì luôn cho web bật tunnel ngay.
DEL /Q "!CF_CONF_DIR!\.ensure_at" >nul 2>&1

:: ── cloudflared.exe (web tự bật tunnel; ở đây chỉ bảo đảm có chương trình) ───
:: Đường dẫn đưa cho PowerShell qua biến môi trường ($env:CF_BIN): không vỡ khi có ' ( ) & trong tên thư mục.
IF NOT EXIST "!CF_BIN!" (
    echo   Dang tai cloudflared.exe ^(lan dau^)...
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile $env:CF_BIN -UseBasicParsing } catch { Write-Host 'Tai that bai' }"
)

echo ========================================
echo   Anh Cuoi
echo   May nay : http://localhost:!PORT!   ^(quan tri: /admin^) - trinh duyet se tu mo
echo   Internet: link rieng xxxx.jagame.vn tu tao sau khi cai dat xong
echo   Dong cua so nay de dung
echo ========================================
echo.

:: Nhịp gõ /health mỗi phút (cửa sổ thu nhỏ riêng, tự thoát khi file cờ bị xóa).
:: !SELF! (mở rộng trễ) thay cho %~f0: đường dẫn có & không bị cmd tách lệnh. Tiến trình con thừa kế
:: ANHCUOI_NO_BROWSER (keepalive_win.bat đặt khi chạy lại) -> không mở thêm tab trình duyệt.
echo running> "!CF_CONF_DIR!\beat.run"
START "AnhCuoi Beat" /MIN cmd /c ""!SELF!" __beat "!PORT!""

cd /d "!WEB_ROOT!"
SET PHP_CLI_SERVER_WORKERS=4
"!PHP_EXE!" -c "!PHP_REL!\php.ini" -d curl.cainfo="!PHP_REL!\extras\ssl\cacert.pem" -d openssl.cafile="!PHP_REL!\extras\ssl\cacert.pem" -d date.timezone=Asia/Ho_Chi_Minh -d max_input_vars=5000 -S localhost:!PORT! router.php

:: ── PHP thoát: dừng nhịp gõ, tắt tunnel do web bật (cửa sổ tiêu đề "AnhCuoi Tunnel") ─
DEL /Q "!CF_CONF_DIR!\beat.run" >nul 2>&1
TASKKILL /F /T /FI "WINDOWTITLE eq AnhCuoi Beat*" >nul 2>&1
TASKKILL /F /T /FI "WINDOWTITLE eq AnhCuoi Tunnel*" >nul 2>&1
DEL /Q "!CF_CONF_DIR!\web_tunnel.pid" "!DB_DIR!\.public_url" >nul 2>&1
pause
EXIT /B 0

:: ── Visual C++ Runtime ─────────────────────────────────────────────────────
:: vc_check: đặt VC_OK=1 nếu có VCRUNTIME140.dll bản 64-bit. cmd 32-bit trên Windows 64-bit thấy System32
:: là SysWOW64 (bản 32-bit, không dùng được cho php.exe 64-bit) -> khi đó xem qua Sysnative.
:: R3-06: có file DLL CHƯA đủ — máy có sẵn VC++ 2015 (14.0) cũ thì PHP 8.2 từ chối chạy ("... 14.0 is not
:: compatible with this PHP build linked with 14.29"). Vì vậy khi đã thấy DLL, chạy thử "php -n -v": mã lỗi khác 0,
:: có chữ "not compatible" hoặc không in ra "PHP x.y" -> coi như thiếu runtime (VC_OK rỗng -> :vc_install cài đè).
:: Kiểm file TRƯỚC khi chạy thử để máy thiếu hẳn DLL không bật hộp thoại lỗi của Windows. Thêm ~0,1 s khi đủ runtime.
:vc_check
SET "VC_OK="
SET "VC_DLL="
IF EXIST "!PHP_DIR!\vcruntime140.dll" SET "VC_DLL=1"
IF EXIST "%SystemRoot%\Sysnative\cmd.exe" GOTO vc_check_wow
IF EXIST "%SystemRoot%\System32\vcruntime140.dll" SET "VC_DLL=1"
GOTO vc_check_run
:vc_check_wow
IF EXIST "%SystemRoot%\Sysnative\vcruntime140.dll" SET "VC_DLL=1"
:vc_check_run
IF NOT DEFINED VC_DLL GOTO :eof
SET "VC_LOG=%TEMP%\anhcuoi_php_v.txt"
DEL /Q "!VC_LOG!" >nul 2>&1
"!PHP_EXE!" -n -v >"!VC_LOG!" 2>&1
:: Mã lỗi nạp DLL của Windows là số ÂM (0xC0000135...) -> so NEQ 0, không dùng "IF ERRORLEVEL 1".
IF !ERRORLEVEL! NEQ 0 GOTO vc_check_bad
findstr /I /C:"not compatible" "!VC_LOG!" >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO vc_check_bad
findstr /B /C:"PHP " "!VC_LOG!" >nul 2>&1
IF ERRORLEVEL 1 GOTO vc_check_bad
SET "VC_OK=1"
DEL /Q "!VC_LOG!" >nul 2>&1
GOTO :eof
:vc_check_bad
echo   [CANH BAO] PHP chua chay duoc voi bo thu vien Visual C++ hien co tren may:
IF EXIST "!VC_LOG!" type "!VC_LOG!"
DEL /Q "!VC_LOG!" >nul 2>&1
GOTO :eof

:: vc_install: tải vc_redist.x64.exe (curl.exe, không có thì PowerShell) về %TEMP%, chạy và CHỜ xong, kiểm lại.
:vc_install
SET "VC_URL=https://aka.ms/vs/17/release/vc_redist.x64.exe"
SET "VC_FILE=%TEMP%\vc_redist.x64.exe"
echo.
echo ========================================
echo   May thieu hoac co ban cu cua bo thu vien Microsoft Visual C++ (can cho PHP).
echo   Dang tai ve va cai - khi Windows hoi, hay bam Yes.
echo ========================================
DEL /Q "!VC_FILE!" >nul 2>&1
where curl.exe >nul 2>&1
IF ERRORLEVEL 1 GOTO vc_dl_ps
curl.exe -fL --retry 2 --connect-timeout 20 -o "!VC_FILE!" "!VC_URL!"
IF ERRORLEVEL 1 DEL /Q "!VC_FILE!" >nul 2>&1
IF EXIST "!VC_FILE!" GOTO vc_run
:vc_dl_ps
powershell -NoProfile -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $env:VC_URL -OutFile $env:VC_FILE } catch { exit 1 }"
IF ERRORLEVEL 1 DEL /Q "!VC_FILE!" >nul 2>&1
IF NOT EXIST "!VC_FILE!" GOTO :eof
:vc_run
echo   Dang cai Microsoft Visual C++ Redistributable...
START "" /WAIT "!VC_FILE!" /install /passive /norestart
CALL :vc_check
IF DEFINED VC_OK echo   Da cai xong. Dang chay Anh Cuoi...
GOTO :eof

:: Mã thoát 2 = lỗi cần người dùng xử lý: keepalive_win.bat dừng hẳn thay vì chạy lại liên tục.
:vc_fail
echo.
echo [LOI] Chua cai duoc Microsoft Visual C++ Redistributable (can cho PHP).
echo       Tai tay va cai file nay: https://aka.ms/vs/17/release/vc_redist.x64.exe
echo       Cai xong roi bam dup run_window.bat lan nua.
pause
exit /b 2

:: ── Nhịp gõ: web tự xin link xxxx.jagame.vn / bật lại tunnel khi cần ─────
:beat
SET "BEAT_PORT=%~2"
:: Chờ PHP sẵn sàng (tối đa ~20 giây): lần gõ /health đầu tiên bật tunnel ngay (R3-07), kể cả lần chạy lại.
SET /A BEAT_TRY=0
:beat_wait
timeout /t 1 /nobreak >nul
SET /A BEAT_TRY+=1
curl.exe -s -o nul --max-time 2 http://localhost:!BEAT_PORT!/health >nul 2>&1
IF ERRORLEVEL 1 IF !BEAT_TRY! LSS 20 GOTO beat_wait
:: Lần chạy lại do keepalive (ANHCUOI_NO_BROWSER=1): không mở thêm tab trình duyệt (R2-32).
IF NOT DEFINED ANHCUOI_NO_BROWSER START "" "http://localhost:!BEAT_PORT!/"
:: /health lúc chờ chỉ có --max-time 2 -> vào vòng lặp gõ lại ngay 1 lần đủ thời gian (không đợi 60 s).
:beat_loop
IF NOT EXIST "!CF_CONF_DIR!\beat.run" EXIT /B 0
curl.exe -s -o nul --max-time 60 "http://localhost:!BEAT_PORT!/health?beat=1" >nul 2>&1
IF ERRORLEVEL 1 powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 60 'http://localhost:!BEAT_PORT!/health?beat=1' | Out-Null } catch {}"
timeout /t 60 /nobreak >nul
GOTO beat_loop
