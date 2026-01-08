# Carpeta actual desde donde se ejecuta el script
$logDir = (Get-Location).Path

# Rutas de los logs
$susLog = Join-Path $logDir "ComandosSospechosos.txt"
$genLog = Join-Path $logDir "ComandosGenerales.txt"

# Limpiar logs anteriores
"" | Out-File $susLog
"" | Out-File $genLog

# Comandos sospechosos
$suspiciousPatterns = @(
    "fsutil", "sc stop", "reg delete", "assign letter", "type", "-framerate", "powershell"
)

# Procesos a analizar
$targetProcesses = @("DiagTrack", "MsMpEng")

foreach ($procName in $targetProcesses) {
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue

    if ($null -eq $proc) {
        $msg = "[!] Proceso ${procName} no está en ejecución.`n"
        Write-Host $msg -ForegroundColor Yellow
        Add-Content -Path $genLog -Value $msg
        continue
    }

    $header = "`n[+] Analizando proceso: ${procName} (PID: $($proc.Id))`n"
    Write-Host $header -ForegroundColor Cyan
    Add-Content -Path $genLog -Value $header

    # Obtener módulos cargados
    $modules = $proc.Modules | ForEach-Object { $_.FileName } | Out-String

    # Obtener eventos recientes
    $events = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4688} -MaxEvents 100 |
        Where-Object { $_.Message -like "*${procName}*" } |
        Select-Object -ExpandProperty Message

    $found = $false

    foreach ($pattern in $suspiciousPatterns) {
        if ($modules -match $pattern -or $events -match $pattern) {
            $alert = "[!] Comando sospechoso encontrado en ${procName}: '${pattern}'"
            Write-Host $alert -ForegroundColor Red
            Add-Content -Path $susLog -Value $alert
            Add-Content -Path $genLog -Value $alert
            $found = $true
        }
    }

    if (-not $found) {
        $ok = "[✓] No se encontraron comandos sospechosos en ${procName}."
        Write-Host $ok -ForegroundColor Green
        Add-Content -Path $genLog -Value $ok
    }

    # Agregar resumen de módulos y eventos al log general
    Add-Content -Path $genLog -Value "`n--- Módulos cargados ---`n$modules"
    Add-Content -Path $genLog -Value "`n--- Eventos recientes ---`n$($events -join "`n")"
}

Write-Host "`n[✔] Análisis completado. Logs guardados en: $logDir" -ForegroundColor Magenta
