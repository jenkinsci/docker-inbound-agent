[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $AdditionalArgs = '',
    [String] $Build = '',
    [String] $VersionTag = '4.3-2',
    [switch] $PushVersions = $false
)

$Repository = 'inbound-agent'
$Organization = 'jenkins'

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organization = $env:DOCKERHUB_ORGANISATION
}

$builds = @{
    'jdk8' = @{
        'Folder' = '8\windowsservercore-1809';
        'Tags' = @( "windowsservercore-1809", "jdk8-windowsservercore-1809-jdk8" );
    };
    'jdk11' = @{
        'Folder' = '11\windowsservercore-1809';
        'Tags' = @( "jdk11-windowsservercore-1809" );
    };
    'nanoserver' = @{
        'Folder' = '8\nanoserver-1809';
        'Tags' = @( "nanoserver-1809", "jdk8-nanoserver-1809" );
    };
    'nanoserver-jdk11' = @{
        'Folder' = '11\nanoserver-1809';
        'Tags' = @( "jdk11-nanoserver-1809" );
    };
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    foreach($tag in $builds[$Build]['Tags']) {
        Copy-Item -Path 'jenkins-agent.ps1' -Destination (Join-Path $builds[$Build]['Folder'] 'jenkins-agent.ps1') -Force
        Write-Host "Building $Build => tag=$tag"
        $cmd = "docker build -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $tag, $AdditionalArgs, $builds[$Build]['Folder']
        Invoke-Expression $cmd

        if($PushVersions) {
            $buildTag = "$VersionTag-$tag"
            if($tag -eq 'latest') {
                $buildTag = "$VersionTag"
            }
            Write-Host "Building $Build => tag=$buildTag"
            $cmd = "docker build -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $buildTag, $AdditionalArgs, $builds[$Build]['Folder']
            Invoke-Expression $cmd
        }
    }
} else {
    foreach($b in $builds.Keys) {
        Copy-Item -Path 'jenkins-agent.ps1' -Destination (Join-Path $builds[$b]['Folder'] 'jenkins-agent.ps1') -Force
        foreach($tag in $builds[$b]['Tags']) {
            Write-Host "Building $b => tag=$tag"
            $cmd = "docker build -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $tag, $AdditionalArgs, $builds[$b]['Folder']
            Invoke-Expression $cmd

            if($PushVersions) {
                $buildTag = "$VersionTag-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$VersionTag"
                }
                Write-Host "Building $Build => tag=$buildTag"
                $cmd = "docker build -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $buildTag, $AdditionalArgs, $builds[$b]['Folder']
                Invoke-Expression $cmd
            }
        }
    }
}

if($lastExitCode -ne 0) {
    exit $lastExitCode
}

if($Target -eq "test") {
    $mod = Get-InstalledModule -Name Pester -MinimumVersion 4.9.0 -ErrorAction SilentlyContinue
    if($null -eq $mod) {
        $module = "c:\Program Files\WindowsPowerShell\Modules\Pester"
        takeown /F $module /A /R
        icacls $module /reset
        icacls $module /grant Administrators:'F' /inheritance:d /T
        Remove-Item -Path $module -Recurse -Force -Confirm:$false
        Install-Module -Force -Name Pester -MinimumVersion 4.9.0
    }

    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        $env:FOLDER = $builds[$Build]['Folder']
        $env:VERSION = "$RemotingVersion-$BuildNumber"
        Invoke-Pester -Path tests -EnableExit
        Remove-Item env:\FOLDER
    } else {
        foreach($b in $builds.Keys) {
            $env:FOLDER = $builds[$b]['Folder']
            $env:VERSION = "$RemotingVersion-$BuildNumber"
            Invoke-Pester -Path tests -EnableExit
            Remove-Item env:\FOLDER
        }
    }
}

if($Target -eq "publish") {
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        foreach($tag in $Builds[$Build]['Tags']) {
            Write-Host "Publishing $Build => tag=$tag"
            $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
            Invoke-Expression $cmd

            if($PushVersions) {
                $buildTag = "$VersionTag-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$VersionTag"
                }
                Write-Host "Publishing $Build => tag=$buildTag"
                $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $buildTag
                Invoke-Expression $cmd
            }
        }
    } else {
        foreach($b in $builds.Keys) {
            foreach($tag in $Builds[$b]['Tags']) {
                Write-Host "Publishing $b => tag=$tag"
                $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
                Invoke-Expression $cmd

                if($PushVersions) {
                    $buildTag = "$VersionTag-$tag"
                    if($tag -eq 'latest') {
                        $buildTag = "$VersionTag"
                    }
                    Write-Host "Publishing $Build => tag=$buildTag"
                    $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $buildTag
                    Invoke-Expression $cmd
                }
            }
        }
    }
}


if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
