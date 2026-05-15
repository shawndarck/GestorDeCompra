$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$server = Join-Path $PSScriptRoot "price_search_server.mjs"
$envFile = Join-Path $PSScriptRoot "pricesec.env.ps1"

Write-Host "Iniciando PriceSec local search service..."
Write-Host "Si una tienda pide login, inicia sesion en la ventana de Chrome que se abre y vuelve a comparar."

Set-Location $root
if (Test-Path $envFile) {
  Write-Host "Cargando configuracion local privada: $envFile"
  . $envFile
}
node $server
