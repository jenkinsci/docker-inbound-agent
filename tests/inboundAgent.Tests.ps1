Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:AGENT_IMAGE='jenkins-inbound-agent'
$global:AGENT_CONTAINER='pester-jenkins-inbound-agent'
$global:SHELL="powershell.exe"

$global:FOLDER = Get-EnvOrDefault 'FOLDER' ''
$global:VERSION = Get-EnvOrDefault 'VERSION' '4.9-1'

$REAL_FOLDER=Resolve-Path -Path "$PSScriptRoot/../${global:FOLDER}"

if(($global:FOLDER -match '^(?<jdk>[0-9]+)[\\/](?<flavor>.+)$') -and (Test-Path $REAL_FOLDER)) {
    $global:JDK = $Matches['jdk']
    $global:FLAVOR = $Matches['flavor']
} else {
    Write-Error "Wrong folder format or folder does not exist: $global:FOLDER"
    exit 1
}

if($global:FLAVOR -match "nanoserver-(\d+)") {
    $global:AGENT_IMAGE += "-nanoserver"
    $global:AGENT_CONTAINER += "-nanoserver-$($Matches[1])"
    $global:SHELL = "pwsh.exe"
}

if($global:JDK -eq "17") {
    $global:AGENT_IMAGE += ":jdk17"
    $global:AGENT_CONTAINER += "-jdk17"
} else {
    $global:AGENT_IMAGE += ":latest"
}

Cleanup($global:AGENT_CONTAINER)
Cleanup("nmap")
CleanupNetwork("jnlp-network")

BuildNcatImage

Describe "[$global:JDK $global:FLAVOR] build image" {
    BeforeAll {
      Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
    }

    It 'builds image' {
      $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build --build-arg VERSION=$global:VERSION -t $global:AGENT_IMAGE $global:FOLDER"
      $exitCode | Should -Be 0
    }

    AfterAll {
      Pop-Location -StackName 'agent'
    }
}

Describe "[$global:JDK $global:FLAVOR] check default user account" {
    BeforeAll {
        docker run -d -it --name "$global:AGENT_CONTAINER" -P "$global:AGENT_IMAGE" -Cmd "$global:SHELL"
        $LASTEXITCODE | Should -Be 0
        Is-ContainerRunning $global:AGENT_CONTAINER | Should -BeTrue
    }

    It 'has a password that never expires' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"if((net user jenkins | Select-String -Pattern 'Password expires') -match 'Never') { exit 0 } else { net user jenkins ; exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'has password policy of "not required"' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"if((net user jenkins | Select-String -Pattern 'Password required') -match 'No') { exit 0 } else { net user jenkins ; exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:AGENT_CONTAINER)
    }
}

Describe "[$global:JDK $global:FLAVOR] image has jenkins-agent.ps1 in the correct location" {
    BeforeAll {
        & docker run -dit --name "$global:AGENT_CONTAINER" -P "$global:AGENT_IMAGE" -Cmd $global:SHELL
        Is-ContainerRunning $global:AGENT_CONTAINER | Should -BeTrue
    }

    It 'has jenkins-agent.ps1 in C:/ProgramData/Jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"if(Test-Path 'C:/ProgramData/Jenkins/jenkins-agent.ps1') { exit 0 } else { exit 1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:AGENT_CONTAINER)
    }
}

Describe "[$global:JDK $global:FLAVOR] image starts jenkins-agent.ps1 correctly (slow test)" {
    It 'connects to the nmap container' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "network create --driver nat jnlp-network"
        # Launch the netcat utility, listening at port 5000 for 30 sec
        # bats will capture the output from netcat and compare the first line
        # of the header of the first HTTP request with the expected one
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -dit --name nmap --network=jnlp-network nmap:latest ncat.exe -w 30 -l 5000"
        $exitCode | Should -Be 0
        Is-ContainerRunning "nmap" | Should -BeTrue

        # get the ip address of the nmap container
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" nmap"
        $exitCode | Should -Be 0
        $nmap_ip = $stdout.Trim()

        # run Jenkins agent which tries to connect to the nmap container at port 5000
        $secret = "aaa"
        $name = "bbb"
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -dit --network=jnlp-network --name $global:AGENT_CONTAINER $global:AGENT_IMAGE -Url http://${nmap_ip}:5000 $secret $name"
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:AGENT_CONTAINER | Should -BeTrue

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' 'wait nmap'
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' 'logs nmap'
        $exitCode | Should -Be 0
        $stdout | Should -Match "GET /tcpSlaveAgentListener/ HTTP/1.1`r"
    }

    AfterAll {
        Cleanup($global:AGENT_CONTAINER)
        Cleanup("nmap")
        CleanupNetwork("jnlp-network")
    }
}

Describe "[$global:JDK $global:FLAVOR] build args" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
        # Old version used to test overriding the build arguments.
        # This old version must have the same tag suffixes as the current 4 windows images (`-jdk11-nanoserver` etc.)
        $TEST_VERSION="3046.v38db_38a_b_7a_86"
        $DOCKER_AGENT_VERSION_SUFFIX="1"
        $TEST_USER="foo"
        $ARG_TEST_VERSION="${TEST_VERSION}-${DOCKER_AGENT_VERSION_SUFFIX}"
    }

    It 'builds image with arguments' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build --build-arg version=${ARG_TEST_VERSION} --build-arg user=$TEST_USER -t $global:AGENT_IMAGE $global:FOLDER"
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -dit --name $global:AGENT_CONTAINER -P $global:AGENT_IMAGE -Cmd $global:SHELL"
        $exitCode | Should -Be 0
        Is-ContainerRunning "$global:AGENT_CONTAINER" | Should -BeTrue
    }

    It "has the correct agent.jar version" {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -c `"java -cp C:/ProgramData/Jenkins/agent.jar hudson.remoting.jnlp.Main -version`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $TEST_VERSION
    }

    It "has the correct (overridden) user account and the container is running as that user" {
        # check that the user exists and is the user the container is running as
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -c `"(Get-ChildItem env:\ | Where-Object { `$_.Name -eq 'USERNAME' }).Value`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $TEST_USER
    }

    It "has the correct password policy for overridden user account" {
        # check that $TEST_USER's password never expires and that password is NOT required to login
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"if((net user $TEST_USER | Select-String -Pattern 'Password expires') -match 'Never') { exit 0 } else { net user $TEST_USER ; exit -1 }`""
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"if((net user $TEST_USER | Select-String -Pattern 'Password required') -match 'No') { exit 0 } else { net user $TEST_USER ; exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:AGENT_CONTAINER)
        Pop-Location -StackName 'agent'
    }
}


Describe "[$global:JDK $global:FLAVOR] passing JVM options (slow test)" {
    It "shows the java version with --show-version" {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "network create --driver nat jnlp-network"
        # Launch the netcat utility, listening at port 5000 for 30 sec
        # bats will capture the output from netcat and compare the first line
        # of the header of the first HTTP request with the expected one
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -dit --name nmap --network=jnlp-network nmap:latest ncat.exe -w 30 -l 5000"
        $exitCode | Should -Be 0
        Is-ContainerRunning "nmap" | Should -BeTrue

        # get the ip address of the nmap container
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" nmap"
        $exitCode | Should -Be 0
        $nmap_ip = $stdout.Trim()

        # run Jenkins agent which tries to connect to the nmap container at port 5000
        $secret = "aaa"
        $name = "bbb"
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -dit --network=jnlp-network --name $global:AGENT_CONTAINER $global:AGENT_IMAGE -Url http://${nmap_ip}:5000 -JenkinsJavaOpts `"--show-version`" $secret $name"
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:AGENT_CONTAINER | Should -BeTrue
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "logs $global:AGENT_CONTAINER"
        $exitCode | Should -Be 0
        $stdout | Should -Match "OpenJDK Runtime Environment Temurin-${global:JDK}"
    }

    AfterAll {
        Cleanup($global:AGENT_CONTAINER)
        Cleanup("nmap")
        CleanupNetwork("jnlp-network")
    }
}