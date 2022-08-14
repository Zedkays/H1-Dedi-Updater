param (
    [Parameter(HelpMessage = "Do not prompt for any user input")]
    [switch]$Silent = $False,

    [Parameter(HelpMessage = "Clean unneeded files listed in _delete.txt after update")]
    [switch]$Clean = $False,

    [Parameter(HelpMessage = "Only update releases in the verified stream")]
    [switch]$Verified = $False,

    [Parameter(HelpMessage = "Directory to install to")]
    [ValidateScript({
        if (-Not($_ | Test-Path))
        {
            throw "File or folder does not exist"
        } return $true
    })]
    [System.IO.FileInfo]$Directory
)

Write-Output "======================================="
Write-Output " H1 Server Updater                     "
Write-Output " by Zedkays                            "
Write-Output " Original Script by IW4MAdmin          "
Write-Output "======================================="

$stopwatch = [system.diagnostics.stopwatch]::StartNew()
$repoName = "h1-mod/h1-mod"
$assetPattern = "h1-mod*.exe"

if ($Verified)
{
    $releasesUri = "https://api.github.com/repos/$repoName/releases/latest"
}

else
{
    $releasesUri = "https://api.github.com/repos/$repoName/releases"
}

Write-Output "Retrieving latest version info..."

$releaseInfo = (Invoke-WebRequest $releasesUri | ConvertFrom-Json) | Select -First 1
$asset = $releaseInfo.assets | Where-Object name -like $assetPattern | Select -First 1
$downloadUri = $asset.browser_download_url
$filename = Split-Path $downloadUri -leaf

Write-Output "The latest version is $( $releaseInfo.tag_name ) released $( $releaseInfo.published_at )"

if (!$Silent)
{
    $stopwatch.Stop()
    Write-Warning "H1-Mod.exe will be updated. Are you sure you want to continue?" -WarningAction Inquire
    $stopwatch.Start()
}

Write-Output "Downloading update. This might take a moment..."

$fileDownload = Invoke-WebRequest -Uri $downloadUri
if ($fileDownload.StatusDescription -ne "OK")
{
    throw "Could not update H1-Mod. ($fileDownload.StatusDescription)"
}

$remoteHash = $fileDownload.Headers['Content-MD5']
$decodedHash = [System.BitConverter]::ToString([System.Convert]::FromBase64String($remoteHash)).replace('-', '')
$directoryPath = Get-Location
$fullPath = "$directoryPath\$filename"
$outputFile = [System.IO.File]::Open($fullPath, 2)
$stream = [System.IO.BinaryWriter]::new($outputFile)

if ($Directory)
{
    $outputDir = $Directory
}

else
{
    $outputDir = Get-Location
}

try
{
    $stream.Write($fileDownload.Content)
}
finally
{
    $stream.Dispose()
}

$localHash = (Get-FileHash -Path $fullPath -Algorithm MD5).Hash

if ($localHash -ne $decodedHash)
{
    throw "Failed to update. File hashes don't match!"
}

Write-Output "Extracting $filename to $outputDir"

if ($Clean)
{
    Write-Output "Running post-update clean..."
    $DeleteList = Get-Content -Path ./_delete.txt
    ForEach ($file in $DeleteList)
    {
        Write-Output "Deleting $file"
        Remove-Item -Path $file
    }
}


$stopwatch.Stop()
$executionTime = [math]::Round($stopwatch.Elapsed.TotalSeconds, 0)

Write-Output "Update completed successfully in $executionTime seconds!"
