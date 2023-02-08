[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $AdditionalArgs = '',
    [String] $Build = '',
    [String] $VersionTag = '3071.v7e9b_0dc08466-1',
    [String] $DockerAgentVersion = '3107.v665000b_51092-2',
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

# this is the jdk version that will be used for the 'bare tag' images, e.g., jdk8-windowsservercore-1809 -> windowsserver-1809
$defaultBuild = '11'
$builds = @{}

Get-ChildItem -Recurse -Include windows -Directory | ForEach-Object {
    Get-ChildItem -Directory -Path $_ | Where-Object { Test-Path (Join-Path $_.FullName "Dockerfile") } | ForEach-Object {
        $dir = $_.FullName.Replace((Get-Location), "").TrimStart("\")
        $items = $dir.Split("\")
        $jdkVersion = $items[0]
        $baseImage = $items[2]
        $basicTag = "jdk${jdkVersion}-${baseImage}"
        $tags = @( $basicTag )
        if($jdkVersion -eq $defaultBuild) {
            $tags += $baseImage
        }

        $builds[$basicTag] = @{
            'Folder' = $dir;
            'Tags' = $tags;
        }
    }
}

$exitCodes = 0
if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    foreach($tag in $builds[$Build]['Tags']) {
        Copy-Item -Path 'jenkins-agent.ps1' -Destination (Join-Path $builds[$Build]['Folder'] 'jenkins-agent.ps1') -Force
        Write-Host "Building $Build => tag=$tag"
        $cmd = "docker build --build-arg 'version={0}' -t {1}/{2}:{3} {4} {5}" -f $DockerAgentVersion, $Organization, $Repository, $tag, $AdditionalArgs, $builds[$Build]['Folder']
        Invoke-Expression $cmd
        $exitCodes += $lastExitCode

        if($PushVersions) {
            $buildTag = "$VersionTag-$tag"
            if($tag -eq 'latest') {
                $buildTag = "$VersionTag"
            }
            Write-Host "Building $Build => tag=$buildTag"
            $cmd = "docker build --build-arg 'version={0}' -t {1}/{2}:{3} {4} {5}" -f $DockerAgentVersion, $Organization, $Repository, $buildTag, $AdditionalArgs, $builds[$Build]['Folder']
            Invoke-Expression $cmd
            $exitCodes += $lastExitCode
        }
    }
} else {
    foreach($b in $builds.Keys) {
        Copy-Item -Path 'jenkins-agent.ps1' -Destination (Join-Path $builds[$b]['Folder'] 'jenkins-agent.ps1') -Force
        foreach($tag in $builds[$b]['Tags']) {
            Write-Host "Building $b => tag=$tag"
            $cmd = "docker build --build-arg 'version={0}' -t {1}/{2}:{3} {4} {5}" -f $DockerAgentVersion, $Organization, $Repository, $tag, $AdditionalArgs, $builds[$b]['Folder']
            Invoke-Expression $cmd
            $exitCodes += $lastExitCode

            if($PushVersions) {
                $buildTag = "$VersionTag-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$VersionTag"
                }
                Write-Host "Building $Build => tag=$buildTag"
                $cmd = "docker build --build-arg 'version={0}' -t {1}/{2}:{3} {4} {5}" -f $DockerAgentVersion, $Organization, $Repository, $buildTag, $AdditionalArgs, $builds[$b]['Folder']
                Invoke-Expression $cmd
                $exitCodes += $lastExitCode
            }
        }
    }
}

if($exitCodes -ne 0) {
    Write-Host "Image build stage failed!"
    exit 1
} else {
    Write-Host "Image build stage passed!"
}

if($Target -eq "test") {
    # Only fail the run afterwards in case of any test failures
    $testFailed = $false

    $mod = Get-InstalledModule -Name Pester -MinimumVersion 5.3.0 -MaximumVersion 5.3.3 -ErrorAction SilentlyContinue
    if($null -eq $mod) {
        $module = "c:\Program Files\WindowsPowerShell\Modules\Pester"
        if(Test-Path $module) {
            takeown /F $module /A /R
            icacls $module /reset
            icacls $module /grant Administrators:'F' /inheritance:d /T
            Remove-Item -Path $module -Recurse -Force -Confirm:$false
        }
        Install-Module -Force -Name Pester -MaximumVersion 5.3.3
    }

    Import-Module Pester
    $configuration = [PesterConfiguration]::Default
    $configuration.Run.PassThru = $true
    $configuration.Run.Path = '.\tests'
    $configuration.Run.Exit = $true
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputFormat = 'JUnitXml'
    $configuration.Output.Verbosity = 'Diagnostic'
    $configuration.CodeCoverage.Enabled = $false

    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        $folder = $builds[$Build]['Folder']
        $env:FOLDER = $builds[$Build]['Folder']
        $env:VERSION = $DockerAgentVersion

        if(Test-Path ".\target\$folder") {
            Remove-Item -Recurse -Force ".\target\$folder"
        }
        New-Item -Path ".\target\$folder" -Type Directory | Out-Null
        $configuration.TestResult.OutputPath = ".\target\$folder\junit-results.xml"
        $TestResults = Invoke-Pester -Configuration $configuration
        if ($TestResults.FailedCount -gt 0) {
            Write-Host "There were $($TestResults.FailedCount) failed tests in $Build"
            $testFailed = $true
        } else {
            Write-Host "There were $($TestResults.PassedCount) passed tests out of $($TestResults.TotalCount) in $Build"
        }

        Remove-Item env:\FOLDER
    } else {
        foreach($b in $builds.Keys) {
            $folder = $builds[$b]['Folder']
            $env:FOLDER = $folder
            $env:VERSION = $DockerAgentVersion
            if(Test-Path ".\target\$folder") {
                Remove-Item -Recurse -Force ".\target\$folder"
            }
            New-Item -Path ".\target\$folder" -Type Directory | Out-Null
            $configuration.TestResult.OutputPath = ".\target\$folder\junit-results.xml"
            $TestResults = Invoke-Pester -Configuration $configuration
            if ($TestResults.FailedCount -gt 0) {
                Write-Host "There were $($TestResults.FailedCount) failed tests in $Build"
                $testFailed = $true
            } else {
                Write-Host "There were $($TestResults.PassedCount) passed tests out of $($TestResults.TotalCount) in $Build"
            }
            Remove-Item env:\FOLDER
        }
    }

    # Fail if any test failures
    if($testFailed -ne $false) {
        Write-Error "Test stage failed!"
        exit 1
    } else {
        Write-Host "Test stage passed!"
    }
}

$exitCodes = 0
if($Target -eq "publish") {
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        foreach($tag in $Builds[$Build]['Tags']) {
            Write-Host "Publishing $Build => tag=$tag"
            $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
            Invoke-Expression $cmd
            $exitCodes += $lastExitCode

            if($PushVersions) {
                $buildTag = "$VersionTag-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$VersionTag"
                }
                Write-Host "Publishing $Build => tag=$buildTag"
                $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $buildTag
                Invoke-Expression $cmd
                $exitCodes += $lastExitCode
            }
        }
    } else {
        foreach($b in $builds.Keys) {
            foreach($tag in $Builds[$b]['Tags']) {
                Write-Host "Publishing $b => tag=$tag"
                $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
                Invoke-Expression $cmd
                $exitCodes += $lastExitCode

                if($PushVersions) {
                    $buildTag = "$VersionTag-$tag"
                    if($tag -eq 'latest') {
                        $buildTag = "$VersionTag"
                    }
                    Write-Host "Publishing $Build => tag=$buildTag"
                    $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $buildTag
                    Invoke-Expression $cmd
                    $exitCodes += $lastExitCode
                }
            }
        }
    }

    if($exitCodes -ne 0) {
        Write-Error "Publish stage failed!"
    } else {
        Write-Host "Publish stage passed!"
    }
}

exit $exitCodes
