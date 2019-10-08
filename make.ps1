[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $target = "build",
    [String] $TagPrefix = 'latest',
    [String] $AdditionalArgs = '',
    [String] $Build = ''
)

$Repository = 'jnlp-agent'
$Organization = 'jenkins'

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organization = $env:DOCKERHUB_ORGANISATION
}

$builds = @{
    'default' = @{'Dockerfile' = 'Dockerfile-windows' ; 'TagSuffix' = '-windows' };
    'jdk11' = @{'DockerFile' = 'Dockerfile-windows-jdk11'; 'TagSuffix' = '-windows-jdk11' };
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    Write-Host "Building $Build => tag=$TagPrefix$($builds[$Build]['TagSuffix'])"
    $cmd = "docker build -f {0} -t {1}/{2}:{3}{4} {5} ." -f $builds[$Build]['Dockerfile'], $Organization, $Repository, $TagPrefix, $builds[$Build]['TagSuffix'], $AdditionalArgs
    Invoke-Expression $cmd
} else {
    Write-Host "Building all variants"
    foreach($b in $builds.Keys) {
        Write-Host "Building $b => tag=$TagPrefix$($builds[$b]['TagSuffix'])"
        $cmd = "docker build -f {0} -t {1}/{2}:{3}{4} {5} ." -f $builds[$b]['Dockerfile'], $Organization, $Repository, $TagPrefix, $builds[$b]['TagSuffix'], $AdditionalArgs
        Invoke-Expression $cmd
    }
}

if($lastExitCode -ne 0) {
    exit $lastExitCode
}

if($target -eq "publish") {
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        Write-Host "Publishing $Build => tag=$TagPrefix$($builds[$Build]['TagSuffix'])"
        $cmd = "docker push {0}/{1}:{2}{3}" -f $Organization, $Repository, $TagPrefix, $builds[$Build]['TagSuffix']
        Invoke-Expression $cmd
    } else {
        foreach($b in $builds.Keys) {
            Write-Host "Publishing $b => tag=$TagPrefix$($builds[$b]['TagSuffix'])"
            $cmd = "docker push {0}/{1}:{2}{3}" -f $Organization, $Repository, $TagPrefix, $builds[$b]['TagSuffix']
            Invoke-Expression $cmd
        }
    }
}

if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
