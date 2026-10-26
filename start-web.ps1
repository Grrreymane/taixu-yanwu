param([switch]$NoBrowser)
$ErrorActionPreference='Stop'
$projectRoot=$PSScriptRoot
$gameUrl='http://127.0.0.1:4187/'
function Test-GameReady {
 try {
  $response=Invoke-WebRequest -Uri $gameUrl -UseBasicParsing -TimeoutSec 1
  return $response.StatusCode -eq 200 -and $response.Content -match 'index\.js'
 } catch { return $false }
}
if(-not (Test-GameReady)){
 if(-not (Test-Path -LiteralPath (Join-Path $projectRoot 'build\web\index.html'))){
  throw 'Web build is missing. Run build-web.ps1 first.'
 }
 $nodePath=(Get-Command node -ErrorAction Stop).Source
 $serverLog=Join-Path $projectRoot 'build\server.log'
 $serverErrorLog=Join-Path $projectRoot 'build\server-error.log'
 $serverProcess=Start-Process -FilePath $nodePath -ArgumentList ('"'+(Join-Path $projectRoot 'server.mjs')+'"') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $serverLog -RedirectStandardError $serverErrorLog
 $ready=$false
 for($attempt=0;$attempt -lt 20;$attempt++){
  if(Test-GameReady){$ready=$true;break}
  $serverProcess.Refresh()
  if($serverProcess.HasExited){break}
  Start-Sleep -Milliseconds 150
 }
 if(-not $ready){
  $details=Get-Content -LiteralPath $serverErrorLog -Tail 8 -ErrorAction SilentlyContinue
  throw ("Game server could not start. See $serverErrorLog`n"+($details -join "`n"))
 }
}
Write-Output ("Game ready: "+$gameUrl)
if(-not $NoBrowser){Start-Process $gameUrl}
