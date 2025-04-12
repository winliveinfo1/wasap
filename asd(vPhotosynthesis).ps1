Clear-Host
$SS = @"
██████╗ ██╗  ██╗ ██████╗ ████████╗ ██████╗ ███████╗██╗   ██╗███╗   ██╗████████╗██╗  ██╗███████╗███████╗██╗███████╗
██╔══██╗██║  ██║██╔═══██╗╚══██╔══╝██╔═══██╗██╔════╝╚██╗ ██╔╝████╗  ██║╚══██╔══╝██║  ██║██╔════╝██╔════╝██║██╔════╝
██████╔╝███████║██║   ██║   ██║   ██║   ██║███████╗ ╚████╔╝ ██╔██╗ ██║   ██║   ███████║█████╗  ███████╗██║███████╗
██╔═══╝ ██╔══██║██║   ██║   ██║   ██║   ██║╚════██║  ╚██╔╝  ██║╚██╗██║   ██║   ██╔══██║██╔══╝  ╚════██║██║╚════██║
██║     ██║  ██║╚██████╔╝   ██║   ╚██████╔╝███████║   ██║   ██║ ╚████║   ██║   ██║  ██║███████╗███████║██║███████║
╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚══════╝
"@
Write-Host $SS -ForegroundColor Green

# Define URLs y rutas para herramientas externas
$pecmdUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/PECmd.exe"
$xxstringsUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/xxstrings64.exe"
$pecmdPath = "$env:TEMP\PECmd.exe"
$xxstringsPath = "$env:TEMP\xxstrings64.exe"

Invoke-WebRequest -Uri $pecmdUrl -OutFile $pecmdPath
Invoke-WebRequest -Uri $xxstringsUrl -OutFile $xxstringsPath

# Toma tiempo de inicio de sesión
$logonTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

# ================== PREFETCH ANALYSIS ==================
$prefetchFolder = "C:\Windows\Prefetch"
$files = Get-ChildItem -Path $prefetchFolder -Filter *.pf
$filteredFiles = $files | Where-Object {
    ($_.Name -match "java|javaw") -and ($_.LastWriteTime -gt $logonTime)
}

if ($filteredFiles.Count -gt 0) {
    Write-Host "PF files found after logon time.." -ForegroundColor Gray
    $filteredFiles | ForEach-Object {
        Write-Host "`n$($_.FullName)" -ForegroundColor DarkCyan
        $pecmdOutput = & $pecmdPath -f $_.FullName
        $pecmdOutput | ForEach-Object {
            $line = $_ -replace '\\VOLUME{(.+?)}', 'C:' -replace '^\d+: ', ''
            try {
                if ((Get-Content $line -First 1 -ErrorAction SilentlyContinue) -match 'PK\x03\x04') {
                    if ($line -notmatch "\.jar$") {
                        Write-Host "File .jar modified extension: $line " -ForegroundColor DarkRed
                    } else {
                        Write-Host "Valid .jar file: $line" -ForegroundColor DarkGreen
                    }
                }
            } catch {
                if ($line -match "\.jar$") {
                    Write-Host "File .jar deleted maybe: $line" -ForegroundColor DarkYellow
                }
            }
            if ($line -match "\.jar$" -and !(Test-Path $line)) {
                Write-Host "File .jar deleted maybe: $line" -ForegroundColor DarkYellow
            }
        }
    }
} else {
    Write-Host "No java-related PF files after logon found." -ForegroundColor Red
}

# ================== MEMORY STRING ANALYSIS ==================
function Search-JarInProcessMemory {
    param([string]$serviceName)
    Write-Host "`nSearching for $serviceName PID..." -ForegroundColor Gray
    $pid = (Get-CimInstance Win32_Service | Where-Object { $_.Name -eq $serviceName }).ProcessId
    $result = & $xxstringsPath -p $pid -raw | findstr /C:"-jar"
    if ($result) {
        Write-Host "Strings found in $serviceName memory:" -ForegroundColor DarkYellow
        $result | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No '-jar' strings found in $serviceName." -ForegroundColor Red
    }
}
Search-JarInProcessMemory -serviceName 'DcomLaunch'
Search-JarInProcessMemory -serviceName 'PlugPlay'

# ================== BAM REGISTRY PARSER ==================
Write-Host "`nParsing BAM Registry Entries..." -ForegroundColor Cyan
$sw = [Diagnostics.Stopwatch]::StartNew()

if (!(Get-PSDrive -Name HKLM -PSProvider Registry)) {
    Try { New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE }
    Catch { Write-Host "Error Mounting HKEY_Local_Machine"; exit }
}
$bv = ("bam", "bam\State")
Try {
    $Users = foreach ($ii in $bv) {
        Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($ii)\UserSettings\" | Select-Object -ExpandProperty PSChildName
    }
} Catch {
    Write-Host "Error Parsing BAM Key. Likely unsupported Windows Version"
    exit
}

$rpath = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\", "HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\")
$UserInfo = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation"
$UserBias = -([convert]::ToInt32($UserInfo.ActiveTimeBias))
$UserDay = -([convert]::ToInt32($UserInfo.DaylightBias))
$UserTime = $UserInfo.TimeZoneKeyName

$Bam = foreach ($Sid in $Users) {
    foreach ($rp in $rpath) {
        $BamItems = Get-Item -Path "$($rp)UserSettings\$Sid" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property
        try {
            $objSID = New-Object System.Security.Principal.SecurityIdentifier($Sid)
            $User = $objSID.Translate([System.Security.Principal.NTAccount]).Value
        } catch { $User = "" }

        foreach ($Item in $BamItems) {
            $Key = (Get-ItemProperty -Path "$($rp)UserSettings\$Sid" -ErrorAction SilentlyContinue).$Item
            if ($Key.length -eq 24) {
                $Hex = [System.BitConverter]::ToString($Key[7..0]) -replace "-", ""
                $TimeUTC = [DateTime]::FromFileTimeUtc([Convert]::ToInt64($Hex, 16))
                $TImeUser = $TimeUTC.AddMinutes($UserBias).ToString("s")
                $TimeLocal = $TimeUTC.ToLocalTime().ToString("o")
                $PathParts = $Item -split "\\"
                $App = $PathParts[-1]
                $PathVol = $Item.Substring(23)

                [PSCustomObject]@{
                    'Examiner Time' = $TimeLocal
                    'Last Execution Time (UTC)' = $TimeUTC.ToString("u")
                    'Last Execution User Time' = $TImeUser
                    Application = $App
                    Path = "(Vol$($Item.Substring(15, 1))) $PathVol"
                    User = $User
                    Sid = $Sid
                    rpath = $rp
                }
            }
        }
    }
}

$Bam | Out-GridView -Title "BAM entries: $($Bam.Count) - TimeZone: $UserTime Bias: $UserBias Daylight: $UserDay"
$sw.Stop()
Write-Host "Elapsed Time: $($sw.Elapsed.TotalMinutes) minutes" -ForegroundColor Yellow