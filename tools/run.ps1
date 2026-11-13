# Windows PowerShell 5.1 runner. No PowerShell 7 or additional modules required.
param([string]$Action = 'help')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
Set-Location (Split-Path -Parent $PSScriptRoot)
$Utf8 = New-Object System.Text.UTF8Encoding($false)
function Read-Text([string]$Path) { return $Utf8.GetString([IO.File]::ReadAllBytes($Path)) }
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $Utf8) }
function LF([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Say([string]$Text) { Write-Host $Text }

if ($Action -eq 'help') {
    Say @'
make check     Java / RARS / input / output / memory checks
make examples  Run the five example files (seven cases)
make test-a    Check editable regions, RV32I forms and Task A behavior
make test-b    Check Task B output AND post-run array memory
make test      Run BOTH A and B, even if A fails
make all       check + examples (succeeds with unfinished tasks)
make gui       Open RARS; select ONE source file and use 32-bit / Default
make clean     Remove this runner's build/run.* directories only
Edit tasks/pseudo_task.s and tasks/array_task.s inside BEGIN/END markers.
Distributed tasks are UNFINISHED: test-a, test-b and test must fail.
PASS is a check result, not a grade. See README for Japanese instructions.
'@
    exit 0
}
if ($Action -eq 'clean') {
    if (Test-Path -LiteralPath 'build') {
        Get-ChildItem -LiteralPath 'build' -Directory -Filter 'run.*' | ForEach-Object {
            if (!(($_.Attributes -band [IO.FileAttributes]::ReparsePoint)) -and
                (Test-Path -LiteralPath (Join-Path $_.FullName '.compsys-ex03-run'))) {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force
            }
        }
    }
    Say 'CLEAN: managed logs and temporary files removed; sources and tools kept'
    exit 0
}
if ($Action -notin @('check','examples','test-a','test-b','test','all','gui')) { Say "Unknown target: $Action"; exit 2 }
[IO.Directory]::CreateDirectory((Join-Path (Get-Location).Path 'build')) | Out-Null
$Work = Join-Path (Join-Path (Get-Location).Path 'build') ('run.' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($Work) | Out-Null
Write-Text (Join-Path $Work '.compsys-ex03-run') ''
Say "Logs: $Work"

function Quote-Argument([string]$Value) {
    # Windows CommandLineToArgvW quoting; no shell evaluation.
    return '"' + ([regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1')) + '"'
}
function Bounded([string]$Directory, [string]$StdinText, [string]$Executable, [string[]]$Argv) {
    [IO.Directory]::CreateDirectory($Directory) | Out-Null
    Write-Text (Join-Path $Directory 'start.txt') ([DateTime]::UtcNow.ToString('o'))
    Write-Text (Join-Path $Directory 'argv.txt') (($Executable + "`n") + ($Argv -join "`n") + "`n")
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $Executable
    $psi.Arguments = (($Argv | ForEach-Object { Quote-Argument $_ }) -join ' ')
    $psi.WorkingDirectory = (Get-Location).Path
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = New-Object Diagnostics.Process
    $proc.StartInfo = $psi
    $outputStream = $null; $errorStream = $null; $stdoutTask = $null; $stderrTask = $null
    $started = $false; $code = 2; $limit = ''
    try {
        $outputStream = [IO.File]::Open((Join-Path $Directory 'stdout.txt'), 'CreateNew', 'Write', 'ReadWrite')
        $errorStream = [IO.File]::Open((Join-Path $Directory 'stderr.txt'), 'CreateNew', 'Write', 'ReadWrite')
        $started = $proc.Start()
        Write-Text (Join-Path $Directory 'pid.txt') ([string]$proc.Id)
        $stdoutTask = $proc.StandardOutput.BaseStream.CopyToAsync($outputStream)
        $stderrTask = $proc.StandardError.BaseStream.CopyToAsync($errorStream)
        $proc.StandardInput.Write($StdinText)
        $proc.StandardInput.Close()
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while (!$proc.WaitForExit(100)) {
            if ($clock.Elapsed.TotalSeconds -ge 20) { $limit = 'wall-time limit (20 seconds)'; break }
            if ($outputStream.Length -gt 1048576 -or $errorStream.Length -gt 1048576) { $limit = 'output size limit'; break }
        }
        if ($limit) { if (!$proc.HasExited) { $proc.Kill() }; $proc.WaitForExit(); $code = 124 }
        else { $proc.WaitForExit(); $code = $proc.ExitCode }
        $stdoutTask.GetAwaiter().GetResult(); $stderrTask.GetAwaiter().GetResult()
    } catch {
        Write-Text (Join-Path $Directory 'host-error.txt') $_.Exception.Message
        $code = 2
    } finally {
        if ($started -and !$proc.HasExited) { $proc.Kill(); $proc.WaitForExit() }
        if ($stdoutTask) { try { $stdoutTask.GetAwaiter().GetResult() } catch {} }
        if ($stderrTask) { try { $stderrTask.GetAwaiter().GetResult() } catch {} }
        if ($outputStream) { $outputStream.Dispose() }; if ($errorStream) { $errorStream.Dispose() }
        $proc.Dispose()
        if ($limit) { Write-Text (Join-Path $Directory 'limit.txt') $limit }
        Write-Text (Join-Path $Directory 'exit.txt') ([string]$code)
        Write-Text (Join-Path $Directory 'end.txt') ([DateTime]::UtcNow.ToString('o'))
    }
    return $code
}

function Resolve-Executable([string]$Candidate) {
    if (Test-Path -LiteralPath $Candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $Candidate).Path }
    if ($Candidate.IndexOfAny([char[]]'\/') -ge 0) { throw "Executable not found: $Candidate" }
    $cmd = Get-Command -Name $Candidate -CommandType Application -ErrorAction Stop | Select-Object -First 1
    return $cmd.Source
}
function Environment-Check {
    if ($env:JAVA) { $from = 'JAVA'; $candidate = $env:JAVA }
    elseif ($env:JAVA_HOME) { $from = 'JAVA_HOME'; $candidate = Join-Path $env:JAVA_HOME 'bin\java.exe' }
    else { $from = 'PATH'; $candidate = 'java.exe' }
    try { $script:Java = Resolve-Executable $candidate } catch { Say "[ENV-JAVA] FAIL via ${from}: $candidate"; return $false }
    Say "Java source: $from`nJava executable: $Java"
    $dir = Join-Path $Work 'java-version'
    if ((Bounded $dir '' $Java @('-version')) -ne 0) { Say '[ENV-JAVA] FAIL: cannot run Java'; return $false }
    $banner = (Read-Text (Join-Path $dir 'stdout.txt')) + (Read-Text (Join-Path $dir 'stderr.txt'))
    Say $banner
    if ($banner -notmatch 'version "(1\.)?(\d+)') { Say '[ENV-JAVA] FAIL: version not recognised'; return $false }
    if ([int]$Matches[2] -lt 8) { Say '[ENV-JAVA] FAIL: Java 8 or later required'; return $false }
    $userHome = $env:USERPROFILE
    if (!$userHome) { $userHome = [Environment]::GetFolderPath('UserProfile') }
    if ($env:RARS_JAR) { $from = 'RARS_JAR'; $candidate = $env:RARS_JAR }
    elseif ($env:COMPSYS_TOOLS) { $from = 'COMPSYS_TOOLS'; $candidate = Join-Path $env:COMPSYS_TOOLS 'rars1_6.jar' }
    else { $from = 'HOME'; $candidate = Join-Path $userHome 'compsys-tools\rars1_6.jar' }
    if (!(Test-Path -LiteralPath $candidate -PathType Leaf)) {
        Say "[ENV-RARS] FAIL via ${from}: $candidate`nExpected default: $userHome\compsys-tools\rars1_6.jar"; return $false
    }
    $script:Jar = (Resolve-Path -LiteralPath $candidate).Path
    Say "RARS source: $from`nRARS JAR: $Jar"
    $actual = (Get-FileHash -LiteralPath $Jar -Algorithm SHA256).Hash.ToLowerInvariant()
    $expected = (Read-Text 'tools/rars.sha256').Trim()
    if ($actual -cne $expected) { Say "[ENV-SHA] FAIL: expected $expected; actual $actual"; return $false }
    Say "RARS v1.6 SHA-256: $actual"
    $versionDir = Join-Path $Work 'rars-version'
    if ((Bounded $versionDir '' $Java @('-Dfile.encoding=UTF-8','-jar',$Jar,'h')) -ne 0) { Say '[ENV-RARS] FAIL: cannot run RARS'; return $false }
    $rarsBanner = LF (Read-Text (Join-Path $versionDir 'stdout.txt'))
    if ($rarsBanner -notmatch '(?m)^RARS 1\.6  ') { Say '[ENV-RARS] FAIL: cannot confirm RARS 1.6'; return $false }
    Say ($rarsBanner.Split([char]10)[0])
    return $true
}

function Rars([string]$Directory, [string]$StdinText, [string]$Phase, [string[]]$Options) {
    $argv = @('-Dfile.encoding=UTF-8','-Xmx128m','-jar',$Jar,'nc','me','ae11','se12','mc','Default','sm','100000') + $Options
    $code = Bounded $Directory $StdinText $Java $argv
    $diag = LF (Read-Text (Join-Path $Directory 'stderr.txt'))
    $out = LF (Read-Text (Join-Path $Directory 'stdout.txt'))
    Write-Text (Join-Path $Directory 'stdout.lf') $out
    Write-Text (Join-Path $Directory 'stderr.lf') $diag
    if ($code -ne 0 -or $diag -match '(?m)(^Error|^Warning|Exception|terminated due|maximum step|Invalid|nothing to dump|Error while)') {
        Say "[RUN] FAIL: $Directory (exit $code)`n$diag"; return $false
    }
    if ($Phase -eq 'run' -and $diag -notmatch '(?m)^Program terminated by calling exit$') {
        Say "[RUN] FAIL: normal Exit was not observed`n$diag"; return $false
    }
    return $true
}

function Read-Memory([string]$Path, [int]$Count) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "dump missing: $Path" }
    $text = LF (Read-Text $Path)
    $lines = $text.Split([char]10)
    if ($lines.Count -ne $Count + 1 -or $lines[-1] -cne '') { throw 'malformed dump or wrong word count' }
    $values = @()
    for ($i = 0; $i -lt $Count; $i++) {
        if ($lines[$i] -notmatch '^[0-9a-fA-F]{8}$') { throw 'malformed memory word' }
        $value = [Convert]::ToInt64($lines[$i],16)
        if ($value -ge 2147483648) { $value -= 4294967296 }
        $values += $value
    }
    return ,$values
}
function Compare-Output([string]$Id, [string]$Expected, [string]$Actual) {
    $pass = $Expected -ceq $Actual
    if ($pass) { Say "[$Id] PASS stdout: $($Actual.Replace("`n",'\n'))" }
    else { Say "[$Id] FAIL stdout; expected: $($Expected.Replace("`n",'\n')); actual: $($Actual.Replace("`n",'\n'))" }
    return $pass
}
function Check {
    $dir = Join-Path $Work 'check'; $dump = Join-Path $Work 'check.hex'
    if (!(Rars $dir "41`n" 'run' @('dump','0x10010000-0x10010004','HexText',$dump,'tools/check.s'))) { return $false }
    if (!(Compare-Output 'CHECK-IO' '42' (Read-Text (Join-Path $dir 'stdout.lf')))) { return $false }
    try { $values = Read-Memory $dump 1 } catch { Say "[CHECK-MEMORY] FAIL: $_"; return $false }
    if ($values[0] -ne 42) { Say '[CHECK-MEMORY] FAIL'; return $false }
    Say '[CHECK-MEMORY] PASS post-run 0x10010000 = 42 (initial value 0)'
    return $true
}

$Cases = @((LF (Read-Text 'tests/cases.tsv')).Split([char]10) | Where-Object { $_ -and !($_.StartsWith('#')) } | ForEach-Object {
    $f = $_.Split([char]9)
    if ($f.Count -ne 5) { throw 'Malformed test data' }
    [pscustomobject]@{Group=$f[0]; Id=$f[1]; Source=$f[2]; Stdin=$f[3]; Expected=$f[4]}
})
function Cases-Run([string]$Group) {
    $pass = $true
    foreach ($case in $Cases | Where-Object { $_.Group -ceq $Group }) {
        $dir = Join-Path $Work $case.Id
        $text = if ($case.Stdin -ceq '-') { '' } else { $case.Stdin.Replace('\n',"`n") }
        $expected = $case.Expected.Replace('\n',"`n")
        if (Rars $dir $text 'run' @($case.Source)) {
            if (!(Compare-Output $case.Id $expected (Read-Text (Join-Path $dir 'stdout.lf')))) { $pass = $false }
        } else { Say "[$($case.Id)] FAIL execution"; $pass = $false }
    }
    return $pass
}

function Parse-Regions([string]$Text, [string[]]$Markers) {
    $stage = 0; $outer = ''; $np = ''; $ops = @(); $bodyLines = 0
    foreach ($line in (LF $Text).Split([char]10)) {
        $markerIndex = [Array]::IndexOf($Markers, $line)
        if ($markerIndex -ge 0) {
            if ($markerIndex -ne $stage) { throw 'marker order or duplication' }
            $stage++; $outer += $line + "`n"; continue
        }
        $inside = $stage % 2 -eq 1
        if (!$inside) { $outer += $line + "`n" }
        $code = ($line -split '#',2)[0].Trim(); $labels = ''
        while ($code -match '^([A-Za-z_.$][A-Za-z0-9_.$]*\s*:)\s*(.*)$') {
            $labels += $Matches[1] + "`n"; $code = $Matches[2].Trim()
        }
        if ($inside) {
            $np += $line + "`n"
            if ($code) { $bodyLines++; $ops += ($code -split '[\s,]+')[0] }
        } else {
            $np += $labels
            if ($code.StartsWith('.')) { $np += $code + "`n" }
            elseif ($code) { $np += "addi zero, zero, 0`n" }
        }
    }
    if ($stage -ne $Markers.Count) { throw 'marker missing' }
    return [pscustomobject]@{Outer=$outer; Np=$np; Ops=$ops; BodyLines=$bodyLines}
}
function Scope-Check([string]$Kind) {
    if ($Kind -ceq 'A') { $markers = @('# BEGIN NEG','# END NEG','# BEGIN BLE','# END BLE'); $ref='tests/pseudo.original.s'; $src='tasks/pseudo_task.s' }
    else { $markers = @('# BEGIN TODO','# END TODO'); $ref='tests/array.original.s'; $src='tasks/array_task.s' }
    $original = Parse-Regions (Read-Text $ref) $markers
    $current = Parse-Regions (Read-Text $src) $markers
    if ($original.Outer -cne $current.Outer) { throw 'protected lines differ' }
    Say "[$Kind-SCOPE] PASS: markers and protected lines match"
    return $current
}
function Task-A {
    try { $parsed = Scope-Check 'A' } catch { Say "[A-SCOPE] FAIL: $_"; return $false }
    $allowed = 'lui auipc jal jalr beq bne blt bge bltu bgeu lb lh lw lbu lhu sb sh sw addi slti sltiu xori ori andi slli srli srai add sub sll slt sltu xor srl sra or and fence ecall ebreak'.Split(' ')
    $instructions = $true
    foreach ($op in $parsed.Ops) {
        if ($op -cnotin $allowed) { Say "[A-RV32I] FAIL: $op is not an RV32I basic instruction"; $instructions = $false }
    }
    if ('neg' -cin $parsed.Ops -or 'ble' -cin $parsed.Ops) { Say '[A-STATE] UNFINISHED: neg / ble has not been replaced' }
    if ($instructions) {
        $source = Join-Path $Work 'a-np.s'; Write-Text $source $parsed.Np
        $instructions = Rars (Join-Path $Work 'a-np') '' 'assemble' @('a','np',$source)
        if ($instructions) { Say '[A-RV32I] PASS basic instruction forms (np on extracted regions)' }
        else { Say '[A-RV32I] FAIL pseudo / invalid operand form' }
    }
    $behavior = Cases-Run 'A'
    $pass = $instructions -and $behavior
    if ($pass) { Say '[A] PASS' } else { Say '[A] FAIL / UNFINISHED (scope, instructions, behavior)' }
    return $pass
}
function Task-B {
    try { $parsed = Scope-Check 'B' } catch { Say "[B-SCOPE] FAIL: $_"; return $false }
    if ($parsed.BodyLines -eq 0) { Say '[B-STATE] UNFINISHED: TODO has no executable code' }
    $pass = $true
    foreach ($case in $Cases | Where-Object { $_.Group -ceq 'B' }) {
        $prefix = Join-Path $Work $case.Id
        $lines = (LF (Read-Text $case.Source)).Split([char]10)
        $found = 0
        for ($i=0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -ceq 'A: .word 7, -2, 5, -8, 3, -1') { $lines[$i]='A: .word '+$case.Stdin; $found++ }
        }
        if ($found -ne 1) { Say "[$($case.Id)-LAYOUT] FAIL data definition"; return $false }
        Write-Text ($prefix+'.s') ($lines -join "`n")
        $initial = @($case.Stdin.Split(',') | ForEach-Object { [long]$_ })
        $expectedMemory = @($initial | ForEach-Object { [Math]::Abs($_) })
        $sum = ($expectedMemory | Measure-Object -Sum).Sum
        $expected = ($expectedMemory -join ' ') + "`n" + $sum + "`n"
        if (!(Rars ($prefix+'-assemble') '' 'assemble' @('a','dump','0x10010000-0x10010018','HexText',($prefix+'.initial.hex'),($prefix+'.s')))) { $pass=$false; continue }
        try { $actualInitial = Read-Memory ($prefix+'.initial.hex') 6 } catch { Say "[$($case.Id)-LAYOUT] FAIL: $_"; $pass=$false; continue }
        if (($actualInitial -join ',') -cne ($initial -join ',')) { Say "[$($case.Id)-LAYOUT] FAIL initial A layout"; $pass=$false; continue }
        Say "[$($case.Id)-LAYOUT] PASS A = 0x10010000, six words"
        if (!(Rars ($prefix+'-run') '' 'run' @('dump','0x10010000-0x10010018','HexText',($prefix+'.after.hex'),($prefix+'.s')))) { $pass=$false; continue }
        if (!(Compare-Output ($case.Id+'-OUTPUT') $expected (Read-Text (Join-Path ($prefix+'-run') 'stdout.lf')))) { $pass=$false }
        try { $actualMemory = Read-Memory ($prefix+'.after.hex') 6 } catch { Say "[$($case.Id)-MEMORY] FAIL: $_"; $pass=$false; continue }
        if (($actualMemory -join ',') -ceq ($expectedMemory -join ',')) { Say "[$($case.Id)-MEMORY] PASS $($actualMemory -join ' ')" }
        else { Say "[$($case.Id)-MEMORY] FAIL expected: $($expectedMemory -join ' '); actual: $($actualMemory -join ' ')"; $pass=$false }
    }
    if ($pass) { Say '[B] PASS' } else { Say '[B] FAIL / UNFINISHED' }
    return $pass
}

try {
    if (!(Environment-Check)) { exit 2 }
    switch ($Action) {
        'check' { $pass = Check }
        'examples' { $pass = Cases-Run 'EX' }
        'all' { $pass = Check; if ($pass) { $pass = Cases-Run 'EX' } }
        'test-a' { $pass = Task-A }
        'test-b' { $pass = Task-B }
        'test' { $aPass = Task-A; $bPass = Task-B; $pass = $aPass -and $bPass; Say "[TEST] A=$aPass B=$bPass (True=PASS, False=FAIL/UNFINISHED)" }
        'gui' { & $Java '-Dfile.encoding=UTF-8' '-jar' $Jar; exit $LASTEXITCODE }
    }
    $result = if ($pass) { 0 } else { 1 }
    Say "Runner exit: $result; logs: $Work"
    exit $result
} catch { Say "[HOST] FAIL: $_"; exit 2 }
