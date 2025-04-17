Write-Host ""
Write-Host " ██████╗ ██╗  ██╗ ██████╗ ██╗   ██╗██╗     " -ForegroundColor Red
Write-Host "██╔════╝ ██║  ██║██╔═══██╗██║   ██║██║     " -ForegroundColor Red
Write-Host "██║  ███╗███████║██║   ██║██║   ██║██║     " -ForegroundColor Red
Write-Host "██║   ██║██╔══██║██║   ██║██║   ██║██║     " -ForegroundColor Red
Write-Host "╚██████╔╝██║  ██║╚██████╔╝╚██████╔╝███████╗" -ForegroundColor Red
Write-Host " ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝" -ForegroundColor Red
Write-Host ""
Write-Host "By ZACK (Ghoul Interview Team)" -ForegroundColor Red

$minecraftPath = "$env:APPDATA\.minecraft"
$usernameCachePath = Join-Path -Path $minecraftPath -ChildPath "usernamecache.json"
$userCachePath = Join-Path -Path $minecraftPath -ChildPath "usercache.json"

if (Test-Path $minecraftPath) {
    if (Test-Path $usernameCachePath) {
        $usernameCacheContent = Get-Content -Path $usernameCachePath -Raw | ConvertFrom-Json
        $otherUsernames = $usernameCacheContent | ForEach-Object {
            $_.PSObject.Properties.Value
        } | Where-Object { $_ -match '^[A-Za-z0-9_]+$' } | Select-Object -Unique

        Write-Host "Otras cuentas encontradas en usernamecache.json:" -ForegroundColor White
        $otherUsernames | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        Write-Host ""
    }
    else {
        Write-Host "El archivo usernamecache.json no existe en la carpeta .minecraft" -ForegroundColor White
        Write-Host ""
    }

    if (Test-Path $userCachePath) {
        $userCacheContent = Get-Content -Path $userCachePath -Raw | ConvertFrom-Json
        $otherAccounts = $userCacheContent | Select-Object -ExpandProperty "name" | Select-Object -Unique

        Write-Host "Otras cuentas encontradas en usercache.json:" -ForegroundColor White
        $otherAccounts | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }
    else {
        Write-Host "El archivo usercache.json no existe en la carpeta .minecraft" -ForegroundColor White
    }
}
else {
    Write-Host "La carpeta .minecraft no existe en la ruta: $minecraftPath" -ForegroundColor White
}
