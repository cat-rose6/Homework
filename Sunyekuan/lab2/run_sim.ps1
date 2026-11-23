param([string]$VivadoBin)

$ErrorActionPreference = 'Stop'
if (-not $VivadoBin) {
    $xvlogOnPath = Get-Command xvlog.bat -ErrorAction SilentlyContinue
    if ($xvlogOnPath) {
        $VivadoBin = Split-Path -Parent $xvlogOnPath.Source
    } else {
        throw 'Add Vivado to PATH or specify its bin directory with -VivadoBin.'
    }
}
$tools = @{}
foreach ($name in 'xvlog', 'xelab', 'xsim') {
    $tools[$name] = (Get-Item -LiteralPath (Join-Path $VivadoBin "$name.bat")).FullName
}

function Invoke-XSimTool([string]$Name, [string[]]$ToolArgs) {
    & $tools[$Name] @ToolArgs
    if ($LASTEXITCODE -ne 0) { throw "$Name exited with code $LASTEXITCODE" }
}

$build = Join-Path ([IO.Path]::GetTempPath()) ('risc_lec07_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$results = Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $build, $results -Force | Out-Null
foreach ($folder in 'rtl', 'sim', 'program') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $folder) -Destination $build -Recurse
}

Push-Location -LiteralPath $build
$savedArchitecture = $env:PROCESSOR_ARCHITECTURE
try {
    if (-not $savedArchitecture -and [System.Environment]::Is64BitOperatingSystem) {
        $env:PROCESSOR_ARCHITECTURE = 'AMD64'
    }
    $rtl = @(Get-ChildItem -LiteralPath 'rtl' -Filter '*.v' | Sort-Object Name | ForEach-Object { 'rtl/' + $_.Name })
    Invoke-XSimTool 'xvlog' $rtl
    Invoke-XSimTool 'xvlog' @('sim/tb_ai_core_top.v', '-log', 'xvlog_tb.log')
    Invoke-XSimTool 'xelab' @('work.tb_ai_core_top', '-mt', '2', '-debug', 'typical', '-s', 'lec07_risc')
    Invoke-XSimTool 'xsim' @('lec07_risc', '-tclbatch', 'sim/waves.tcl', '-wdb', 'lec07_risc.wdb', '-log', 'simulate.log')
    if (-not (Select-String -LiteralPath 'simulate.log' -SimpleMatch 'PASS: neuron program and core checks' -Quiet)) {
        throw "Simulation did not report PASS. Log: $build/simulate.log"
    }
    foreach ($file in 'xvlog.log', 'xvlog_tb.log', 'xelab.log', 'simulate.log', 'lec07_risc.wdb') {
        Copy-Item -LiteralPath $file -Destination $results -Force
    }
} finally {
    $env:PROCESSOR_ARCHITECTURE = $savedArchitecture
    Pop-Location
}
