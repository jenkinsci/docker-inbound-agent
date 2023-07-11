[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $Build = '',
    [String] $DockerAgentVersion = '3131.vf2b_b_798b_ce99-4',
    [String] $BuildNumber = '1',
    [switch] $PushVersions = $false
    # [switch] $PushVersions = $false,
    # [switch] $DisableEnvProps = $false
)

$ErrorActionPreference ='Stop'
$Repository = 'inbound-agent'
$Organization = 'jenkins'
$AgentType = 'windows-2019'

# TODO: not needed? Commented for now, env.props contains DOCKER_AGENT_VERSION in docker-agent
# if(!$DisableEnvProps) {
#     Get-Content env.props | ForEach-Object {
#         $items = $_.Split("=")
#         if($items.Length -eq 2) {
#             $name = $items[0].Trim()
#             $value = $items[1].Trim()
#             Set-Item -Path "env:$($name)" -Value $value
#         }
#     }
# }

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organization = $env:DOCKERHUB_ORGANISATION
}

if(![String]::IsNullOrWhiteSpace($env:DOCKER_AGENT_VERSION)) {
    $DockerAgentVersion = $env:DOCKER_AGENT_VERSION
}

if(![String]::IsNullOrWhiteSpace($env:AGENT_TYPE)) {
    $AgentType = $env:AGENT_TYPE
}

# Check for required commands
Function Test-CommandExists {
    # From https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
    Param (
        [String] $command
    )

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if(Get-Command $command){
            Write-Debug "$command exists"
        }
    }
    Catch {
        "$command does not exist"
    }
    Finally {
        $ErrorActionPreference=$oldPreference
    }
}

# # this is the jdk version that will be used for the 'bare tag' images, e.g., jdk8-windowsservercore-1809 -> windowsserver-1809
# $defaultJdk = '11'
$builds = @{}
$env:DOCKER_AGENT_VERSION = "$DockerAgentVersion"
$env:WINDOWS_VERSION_NAME = $AgentType.replace('windows-', 'ltsc')
$env:NANOSERVER_VERSION_NAME = $env:WINDOWS_VERSION_NAME
$env:WINDOWS_VERSION_TAG = $env:WINDOWS_VERSION_NAME
$env:NANOSERVER_VERSION_TAG = $env:WINDOWS_VERSION_NAME
# We need to keep the `jdkN-nanoserver-1809` images for now, cf https://github.com/jenkinsci/docker-agent/issues/451
if ($AgentType -eq 'windows-2019') {
    $env:NANOSERVER_VERSION_TAG = 1809
    $env:NANOSERVER_VERSION_NAME = 1809
}
$ProgressPreference = 'SilentlyContinue' # Disable Progress bar for faster downloads

Test-CommandExists "docker"
Test-CommandExists "docker-compose"
Test-CommandExists "yq"

$baseDockerCmd = 'docker-compose --file=build-windows.yaml'
$baseDockerBuildCmd = '{0} build --parallel --pull' -f $baseDockerCmd

Invoke-Expression "$baseDockerCmd config --services" 2>$null | ForEach-Object {
    $image = '{0}-{1}' -f $_, $env:WINDOWS_VERSION_NAME
    # Special case for nanoserver-1809 images
    $image = $image.replace('nanoserver-ltsc2019', 'nanoserver-1809')
    $items = $image.Split("-")
    # Remove the 'jdk' prefix (3 first characters)
    $jdkMajorVersion = $items[0].Remove(0,3)
    $windowsType = $items[1]
    $windowsVersion = $items[2]
    
    $baseImage = "${windowsType}-${windowsVersion}"
    $versionTag = "${DockerAgentVersion}-${BuildNumber}-${image}"
    $tags = @( $image, $versionTag )
    # TODO: keep it here too? (from docker-agent)
    # if($jdkMajorVersion -eq "$defaultJdk") {
    #     $tags += $baseImage
    # }

    Write-Host "New Windows image to build ($image): ${Organization}/${Repository}:${baseImage} with JDK ${jdkMajorVersion}"

    $builds[$image] = @{
        'Tags' = $tags;
    }
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    Write-Host "= BUILD: Building image ${Build}..."
    $dockerBuildCmd = '{0} {1}' -f $baseDockerBuildCmd, $Build
    Invoke-Expression $dockerBuildCmd
    Write-Host "= BUILD: Finished building image ${Build}"
} else {
    Write-Host "= BUILD: Building all images..."
    Invoke-Expression $baseDockerBuildCmd
    Write-Host "= BUILD: Finished building all image"
}

if($lastExitCode -ne 0) {
    exit $lastExitCode
}

function Test-Image {
    param (
        $ImageName
    )

    Write-Host "= TEST: Testing image ${ImageName}:"

    $env:AGENT_IMAGE = $ImageName
    $serviceName = $ImageName.SubString(0, $ImageName.LastIndexOf('-'))
    $env:BUILD_CONTEXT = Invoke-Expression "$baseDockerCmd config" 2>$null |  yq -r ".services.${serviceName}.build.context"
    # TODO: review build number removal (?)
    # $env:VERSION = "$DockerAgentVersion-$BuildNumber"
    $env:VERSION = $DockerAgentVersion

    Write-Host "= TEST: image folder ${env:BUILD_CONTEXT}, version ${env:VERSION}"

    if(Test-Path ".\target\$ImageName") {
        Remove-Item -Recurse -Force ".\target\$ImageName"
    }
    New-Item -Path ".\target\$ImageName" -Type Directory | Out-Null
    $configuration.TestResult.OutputPath = ".\target\$ImageName\junit-results.xml"
    $TestResults = Invoke-Pester -Configuration $configuration
    if ($TestResults.FailedCount -gt 0) {
        Write-Host "There were $($TestResults.FailedCount) failed tests in $ImageName"
        $testFailed = $true
    } else {
        Write-Host "There were $($TestResults.PassedCount) passed tests out of $($TestResults.TotalCount) in $ImageName"
    }
    Remove-Item env:\AGENT_IMAGE
    Remove-Item env:\BUILD_CONTEXT
    Remove-Item env:\VERSION
}

if($target -eq "test") {
    Write-Host "= TEST: Starting test harness"

    # Only fail the run afterwards in case of any test failures
    $testFailed = $false
    $mod = Get-InstalledModule -Name Pester -MinimumVersion 5.3.0 -MaximumVersion 5.3.3 -ErrorAction SilentlyContinue
    if($null -eq $mod) {
        Write-Host "= TEST: Pester 5.3.x not found: installing..."
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
    Write-Host "= TEST: Setting up Pester environment..."
    $configuration = [PesterConfiguration]::Default
    $configuration.Run.PassThru = $true
    $configuration.Run.Path = '.\tests'
    $configuration.Run.Exit = $true
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputFormat = 'JUnitXml'
    $configuration.Output.Verbosity = 'Diagnostic'
    $configuration.CodeCoverage.Enabled = $false

    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        Test-Image $Build
    } else {
        Write-Host "= TEST: Testing all images"
        foreach($image in $builds.Keys) {
            Test-Image $image
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

# TODO: dry mode?
function Publish-Image {
    param (
        [String] $Build,
        [String] $ImageName
    )
    # foreach($tag in $builds[$ImageName]['Tags']) {
    #     $fullImageName = '{0}/{1}:{2}' -f $Organization, $Repository, $tag
    #     $cmd = "docker tag {0} {1}" -f $ImageName, $tag
    Write-Host "= PUBLISH: Tagging $Build => full name = $ImageName"
    docker tag "$Build" "$ImageName"

    Write-Host "= PUBLISH: Publishing $ImageName..."
    docker push "$ImageName"
}


if($target -eq "publish") {
    # Only fail the run afterwards in case of any issues when publishing the docker images
    $publishFailed = 0
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        foreach($tag in $Builds[$Build]['Tags']) {
            Publish-Image  "$Build" "${Organization}/${Repository}:${tag}"
            if($lastExitCode -ne 0) {
                $publishFailed = 1
            }

            if($PushVersions) {
                $buildTag = "$DockerAgentVersion-$BuildNumber-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$DockerAgentVersion-$BuildNumber"
                }
                Publish-Image "$Build" "${Organization}/${Repository}:${buildTag}"
                if($lastExitCode -ne 0) {
                    $publishFailed = 1
                }
            }
        }
    } else {
        foreach($b in $builds.Keys) {
            foreach($tag in $Builds[$b]['Tags']) {
                Publish-Image "$b" "${Organization}/${Repository}:${tag}"
                if($lastExitCode -ne 0) {
                    $publishFailed = 1
                }

                if($PushVersions) {
                    $buildTag = "$DockerAgentVersion-$BuildNumber-$tag"
                    if($tag -eq 'latest') {
                        $buildTag = "$DockerAgentVersion-$BuildNumber"
                    }
                    Publish-Image "$b" "${Organization}/${Repository}:${buildTag}"
                    if($lastExitCode -ne 0) {
                        $publishFailed = 1
                    }
                }
            }
        }
    }

    # Fail if any issues when publising the docker images
    if($publishFailed -ne 0) {
        Write-Error "Publish failed!"
        exit 1
    }
}

if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
