param(
 [string]$GodotPath=$env:GODOT_BIN,
 [string]$WebTemplatesPath=$env:GODOT_WEB_TEMPLATES,
 [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
$projectRoot=$PSScriptRoot
$legacyTools=Join-Path (Split-Path $projectRoot -Parent) 'tools\godot'

if($GodotPath){
 $godotCommand=Get-Command $GodotPath -CommandType Application -ErrorAction SilentlyContinue
 if(-not $godotCommand){throw "Cannot find Godot: $GodotPath"}
 $godotExe=$godotCommand.Source
}else{
 $godotCommand=Get-Command godot, godot4 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
 if($godotCommand){$godotExe=$godotCommand.Source}
 else{$godotExe=Join-Path $legacyTools 'Godot_v4.7.2-stable_win64_console.exe'}
 if(-not (Test-Path -LiteralPath $godotExe -PathType Leaf)){
  throw 'Godot was not found. Pass -GodotPath, set GODOT_BIN, or add Godot to PATH.'
 }
}

if(-not $WebTemplatesPath){
 $bundledTemplates=Join-Path (Split-Path $godotExe -Parent) 'web-templates'
 if(Test-Path -LiteralPath $bundledTemplates -PathType Container){$WebTemplatesPath=$bundledTemplates}
}
if($WebTemplatesPath){
 $WebTemplatesPath=(Resolve-Path -LiteralPath $WebTemplatesPath -ErrorAction Stop).Path
 $debugTemplate=Join-Path $WebTemplatesPath 'web_nothreads_debug.zip'
 $releaseTemplate=Join-Path $WebTemplatesPath 'web_nothreads_release.zip'
 foreach($template in @($debugTemplate,$releaseTemplate)){
  if(-not (Test-Path -LiteralPath $template -PathType Leaf)){throw "Missing Web template: $template"}
 }
}
if($CheckOnly){
 Write-Output ("Godot: "+$godotExe)
 if($WebTemplatesPath){Write-Output ("Web templates: "+$WebTemplatesPath)}
 else{Write-Output 'Web templates: installed Godot export templates'}
 return
}

$webRoot=Join-Path $projectRoot 'build\web'
New-Item -ItemType Directory -Path $webRoot -Force | Out-Null
$presetPath=Join-Path $projectRoot 'export_presets.cfg'
$originalPreset=$null
try{
 if($WebTemplatesPath){
  # Keep machine-specific paths out of the repository and restore exact bytes.
  $originalPreset=[IO.File]::ReadAllBytes($presetPath)
  $presetText=[IO.File]::ReadAllText($presetPath)
  $presetText=[regex]::Replace($presetText,'(?m)^custom_template/debug=[^\r\n]*',{
   'custom_template/debug="'+$debugTemplate.Replace('\','/')+'"'
  })
  $presetText=[regex]::Replace($presetText,'(?m)^custom_template/release=[^\r\n]*',{
   'custom_template/release="'+$releaseTemplate.Replace('\','/')+'"'
  })
  [IO.File]::WriteAllText($presetPath,$presetText,[Text.UTF8Encoding]::new($false))
 }
 & $godotExe --headless --path $projectRoot --import
 if($LASTEXITCODE -ne 0){throw 'Godot资源导入失败'}
 & $godotExe --headless --path $projectRoot --export-release Web
 if($LASTEXITCODE -ne 0){throw 'Godot网页构建失败'}
}finally{
 if($null -ne $originalPreset){[IO.File]::WriteAllBytes($presetPath,$originalPreset)}
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\fonts\loading-ui.woff2') -Destination (Join-Path $webRoot 'loading-ui.woff2') -Force
foreach($asset in Get-ChildItem -LiteralPath $webRoot -File){
 if($asset.Extension -in '.wasm','.pck','.js'){
  $inputStream=[IO.File]::OpenRead($asset.FullName)
  $outputStream=[IO.File]::Create($asset.FullName+'.gz')
  $gzipStream=[IO.Compression.GZipStream]::new($outputStream,[IO.Compression.CompressionLevel]::Optimal)
  try{$inputStream.CopyTo($gzipStream)}finally{$gzipStream.Dispose();$outputStream.Dispose();$inputStream.Dispose()}
 }
}
Write-Output 'Godot网页构建完成。运行启动网页试玩.cmd即可。'
