[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $Build = '',
    [String] $VersionTag = '3071.v7e9b_0dc08466-1',
    [String] $DockerAgentVersion = '3107.v665000b_51092-13',
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

# TODO: use docker-compose / tooling like with docker-agent
$images = 'jdk11-nanoserver-1809', 'jdk11-windowsservercore-ltsc2019', 'jdk17-nanoserver-1809', 'jdk17-windowsservercore-ltsc2019'
Foreach($image in $images) {
    $items = $image.Split('-')
    # Remove the 'jdk' prefix (3 first characters)
    $jdkMajorVersion = $items[0].Remove(0,3)
    $windowsFlavor = $items[1]
    $windowsVersion = $items[2]
    $baseImage = "${windowsFlavor}-${windowsVersion}"
    $dir = "windows/${baseImage}"

    Write-Host "New windows image to build: jenkins/jenkins:${baseImage} with JDK ${jdkMajorVersion} in ${dir}"

    $tags = @( $image )
    if($jdkMajorVersion -eq $defaultBuild) {
        $tags += $baseImage
    }

    $builds[$image] = @{
        'Folder' = $dir;
        'Tags' = $tags;
        'JdkMajorVersion' = $jdkMajorVersion;
    }
}

function Build-Image {
    param (
        [String] $Build,
        [String] $ImageName,
        [String] $RemotingVersion,
        [String] $JdkMajorVersion,
        [String] $Folder
    )

    Write-Host "Building $Build with name $imageName"
    docker build --build-arg "version=${RemotingVersion}" --build-arg "JAVA_MAJOR_VERSION=${JdkMajorVersion}" --tag="${ImageName}" --file="${Folder}/Dockerfile" ./
}

$exitCodes = 0
if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    foreach($tag in $builds[$Build]['Tags']) {
        Build-Image -Build $Build -ImageName "${Organization}/${Repository}:${tag}" -RemotingVersion $DockerAgentVersion -JdkMajorVersion $builds[$Build]['JdkMajorVersion'] -Folder $builds[$Build]['Folder']
        $exitCodes += $lastExitCode

        if($PushVersions) {
            $buildTag = "$VersionTag-$tag"
            if($tag -eq 'latest') {
                $buildTag = "$VersionTag"
            }
            Build-Image -Build $Build -ImageName "${Organization}/${Repository}:${buildTag}" -RemotingVersion $DockerAgentVersion -JdkMajorVersion $builds[$Build]['JdkMajorVersion'] -Folder $builds[$Build]['Folder']
            $exitCodes += $lastExitCode
        }
    }
} else {
    foreach($b in $builds.Keys) {
        foreach($tag in $builds[$b]['Tags']) {
            Build-Image -Build $Build -ImageName "${Organization}/${Repository}:${tag}" -RemotingVersion $DockerAgentVersion -JdkMajorVersion $builds[$b]['JdkMajorVersion'] -Folder $builds[$b]['Folder']
            $exitCodes += $lastExitCode

            if($PushVersions) {
                $buildTag = "$VersionTag-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$VersionTag"
                }
                Build-Image -Build $Build -ImageName "${Organization}/${Repository}:${buildTag}" -RemotingVersion $DockerAgentVersion -JdkMajorVersion $builds[$b]['JdkMajorVersion'] -Folder $builds[$b]['Folder']
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
        $env:AGENT_IMAGE = $Build
        $env:FOLDER = $folder
        $env:JAVA_MAJOR_VERSION = $builds[$Build]['JdkMajorVersion']
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
        Remove-Item env:\AGENT_IMAGE
        Remove-Item env:\FOLDER
        Remove-Item env:\JAVA_MAJOR_VERSION
        Remove-Item env:\VERSION
    } else {
        foreach($b in $builds.Keys) {
            $folder = $builds[$b]['Folder']
            $env:AGENT_IMAGE = $b
            $env:FOLDER = $folder
            $env:JAVA_MAJOR_VERSION = $builds[$Build]['JdkMajorVersion']
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
            Remove-Item env:\AGENT_IMAGE
            Remove-Item env:\FOLDER
            Remove-Item env:\JAVA_MAJOR_VERSION
            Remove-Item env:\VERSION
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
