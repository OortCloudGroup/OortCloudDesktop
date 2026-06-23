param(
    [string]$Version,

    [string]$InstallerPath = "OortCloudDesktop_Setup.exe",

    [string]$JsonPath = "index.json"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

function Resolve-ProjectPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $projectRoot $Path
}

function Get-TargetVersion {
    param(
        [string]$InputVersion,

        [Parameter(Mandatory = $true)]
        [object]$Index
    )

    if (-not [string]::IsNullOrWhiteSpace($InputVersion)) {
        return $InputVersion.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($Index.version)) {
        throw "请通过 -Version 传入版本号，或先在 index.json 中填写 version 字段"
    }

    return $Index.version.Trim()
}

try {
    $resolvedInstallerPath = Resolve-ProjectPath -Path $InstallerPath
    $resolvedJsonPath = Resolve-ProjectPath -Path $JsonPath

    if (-not (Test-Path -LiteralPath $resolvedInstallerPath -PathType Leaf)) {
        throw "安装包不存在：$resolvedInstallerPath"
    }

    if (-not (Test-Path -LiteralPath $resolvedJsonPath -PathType Leaf)) {
        throw "index.json 文件不存在：$resolvedJsonPath"
    }

    $index = Get-Content -Raw -LiteralPath $resolvedJsonPath | ConvertFrom-Json
    $targetVersion = Get-TargetVersion -InputVersion $Version -Index $index

    if ($targetVersion -notmatch "^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$") {
        throw "版本号格式不正确：$targetVersion"
    }

    $installerInfo = Get-Item -LiteralPath $resolvedInstallerPath
    $sha256Hash = (Get-FileHash -LiteralPath $resolvedInstallerPath -Algorithm SHA256).Hash.ToLower()
    $releaseTime = [DateTimeOffset]::Now.ToString("yyyy-MM-ddTHH:mm:sszzz")

    # 更新发布信息字段
    $index.version = $targetVersion
    $index.releaseTime = $releaseTime
    $index.installerUrl = $index.installerUrl -replace "/download/v[^/]+/", "/download/v$targetVersion/"
    $index.installerSha256 = $sha256Hash
    $index.installerSize = $installerInfo.Length

    $json = $index | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($resolvedJsonPath, $json, [System.Text.UTF8Encoding]::new($false))

    Write-Host "更新完成：$resolvedJsonPath"
    Write-Host "版本号：$targetVersion"
    Write-Host "发布时间：$releaseTime"
    Write-Host "安装包大小：$($installerInfo.Length)"
    Write-Host "SHA256：$sha256Hash"
}
catch {
    Write-Error "更新 index.json 失败：$($_.Exception.Message)"
    exit 1
}
