@echo off
ECHO "MuseScore build"

SET ARTIFACTS_DIR=build.artifacts
SET BUILD_NUMBER=""
SET TELEMETRY_TRACK_ID=""
SET SENTRY_SERVER_KEY=""
SET TARGET_PROCESSOR_BITS=64
SET BUILD_WIN_PORTABLE=OFF
SET BUILD_UI_MU4=OFF		# not used, only for easier synchronization and compatibility

:GETOPTS
IF /I "%1" == "-n" SET BUILD_NUMBER=%2& SHIFT
IF /I "%1" == "-b" SET TARGET_PROCESSOR_BITS=%2& SHIFT
IF /I "%1" == "--telemetry" SET TELEMETRY_TRACK_ID=%2& SHIFT
IF /I "%1" == "--sentrykey" SET SENTRY_SERVER_KEY=%2& SHIFT
IF /I "%1" == "--portable" SET BUILD_WIN_PORTABLE=%2& SHIFT
IF /I "%1" == "--build_mu4" SET BUILD_UI_MU4=%2& SHIFT
SHIFT
IF NOT "%1" == "" GOTO GETOPTS

IF %BUILD_NUMBER% == "" ( ECHO "error: not set BUILD_NUMBER" & EXIT /b 1)
IF NOT %TARGET_PROCESSOR_BITS% == 64 (
    IF NOT %TARGET_PROCESSOR_BITS% == 32 (
        ECHO "error: not set TARGET_PROCESSOR_BITS, must be 32 or 64, current TARGET_PROCESSOR_BITS: %TARGET_PROCESSOR_BITS%"
        EXIT /b 1
    )
)

SET /p BUILD_MODE=<%ARTIFACTS_DIR%\env\build_mode.env
SET "MUSESCORE_BUILD_CONFIG=dev"
IF %BUILD_MODE% == devel ( SET "MUSESCORE_BUILD_CONFIG=dev" ) ELSE (
IF %BUILD_MODE% == nightly ( SET "MUSESCORE_BUILD_CONFIG=dev" ) ELSE (
IF %BUILD_MODE% == testing ( SET "MUSESCORE_BUILD_CONFIG=testing" ) ELSE (
IF %BUILD_MODE% == stable  ( SET "MUSESCORE_BUILD_CONFIG=release" ) ELSE (
    ECHO "error: unknown BUILD_MODE: %BUILD_MODE%"
    EXIT /b 1
))))

SET URL_IS_SET=1
IF %SENTRY_SERVER_KEY% == "" ( SET URL_IS_SET=0)
IF %SENTRY_SERVER_KEY% == "''" ( SET URL_IS_SET=0)

IF %URL_IS_SET% EQU 1 (
    SET "CRASH_LOG_SERVER_URL=https://sentry.musescore.org/api/2/minidump/?sentry_key=%SENTRY_SERVER_KEY%"
) ELSE (
    SET CRASH_LOG_SERVER_URL=
)

ECHO "MUSESCORE_BUILD_CONFIG: %MUSESCORE_BUILD_CONFIG%"
ECHO "BUILD_NUMBER: %BUILD_NUMBER%"
ECHO "TARGET_PROCESSOR_BITS: %TARGET_PROCESSOR_BITS%"
ECHO "TELEMETRY_TRACK_ID: %TELEMETRY_TRACK_ID%"
ECHO "CRASH_LOG_SERVER_URL: %CRASH_LOG_SERVER_URL%"
ECHO "BUILD_WIN_PORTABLE: %BUILD_WIN_PORTABLE%"
ECHO "BUILD_UI_MU4: %BUILD_UI_MU4%"

XCOPY "C:\musescore_dependencies" %CD% /E /I /Y
ECHO "Finished copy dependencies"

SET GENERATOR_NAME=Visual Studio 17 2022
SET MSCORE_STABLE_BUILD="TRUE"

:: TODO We need define paths during image creation
SET "JACK_DIR=C:\Program Files (x86)\Jack"

IF %TARGET_PROCESSOR_BITS% == 32 ( 
    :: SET "QT_DIR=C:\Qt\5.9.9"
    :: SET "PATH=%QT_DIR%\msvc2015\bin;%JACK_DIR%;%PATH%"
    :: for some strange reason the above doesn't work
    SET "PATH=C:\Qt\5.9.9\msvc2015\bin;%JACK_DIR%;%PATH%"
) ELSE (
    :: SET "QT_DIR=C:\Qt\5.15.2"
    :: SET "PATH=%QT_DIR%\msvc2019_64\bin;%JACK_DIR%;%PATH%"
    :: for some strange reason the above doesn't work
    SET "PATH=C:\Qt\5.15.2\msvc2019_64\bin;%JACK_DIR%;%PATH%"
)

bash ./build/ci/tools/make_revision_env.sh 
SET /p MUSESCORE_REVISION=<%ARTIFACTS_DIR%\env\build_revision.env
ECHO "MUSESCORE_REVISION: %MUSESCORE_REVISION%"

CALL msvc_build.bat relwithdebinfo %TARGET_PROCESSOR_BITS% %BUILD_NUMBER% || exit \b 1
CALL msvc_build.bat installrelwithdebinfo %TARGET_PROCESSOR_BITS% %BUILD_NUMBER% || exit \b 1


bash ./build/ci/tools/make_release_channel_env.sh -c %MUSESCORE_BUILD_CONFIG%
bash ./build/ci/tools/make_version_env.sh %BUILD_NUMBER%
bash ./build/ci/tools/make_branch_env.sh
bash ./build/ci/tools/make_datetime_env.sh
