. './konfiguration.ps1'

#region: test framework
function Banner {
    param (
        [string]$Text
    )

    Write-Host "`n$($Text.ToUpper().PadRight(78))" `
        -ForegroundColor Black `
        -BackgroundColor Green
}

function Describe {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Description,

        [Parameter(Mandatory, Position=1)]
        [scriptblock]$TestScript
    )

    Write-Host "`n $($Description.ToUpper())" `
        -ForegroundColor Green `
        -BackgroundColor Black

    try {
        & $TestScript
    } catch {
        Write-Host "Failed to run the tests" `
            -ForegroundColor Red `
            -BackgroundColor Black
    }
}

function Test {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Description,

        [Parameter(Mandatory=$true)]
        [scriptblock]$AssertionLogic,

        [Parameter(Mandatory=$true)]
        $Expected,

        [scriptblock]$Comparison = { param($a, $b) $a -eq $b }
    )

    Write-Host "   $Description"

    try {
        $Actual = & $AssertionLogic
    } catch {
        $Actual = $null
    }

    if (& $Comparison $Actual $Expected) {
        Write-Host "     PASS" `
            -ForegroundColor Blue
    } else {
        Write-Host "     FAIL" `
            -ForegroundColor Red -NoNewline

        Write-Host " Expected '$Expected' but got '$Actual'" `
            -ForegroundColor Yellow
    }
}
#endregion: test framework

Banner "Starting"

Describe "Testing Get-PackageVersion" {

    Test `
        -Description "Get full package version" `
        -AssertionLogic { Get-PackageVersion -Name "julia" } `
        -Expected "1.12.6"

    Test `
        -Description "Get short package version" `
        -AssertionLogic { Get-PackageVersion -Name "julia" -Full $false } `
        -Expected "1.12"
}

Describe "Testing Get-PackageVersionedUrl" {

    Test `
        -Description "Get single field URL for Node" `
        -AssertionLogic { Get-PackageVersionedUrl -Name "node" } `
        -Expected 'https://nodejs.org/dist/v24.11.0/node-v24.11.0-win-x64.zip'

    Test `
        -Description "Get multiple field URL for Julia" `
        -AssertionLogic { Get-PackageVersionedUrl -Name "julia" } `
        -Expected 'https://julialang-s3.julialang.org/bin/winnt/x64/1.12/julia-1.12.6-win64.zip'
}

Banner "End"
