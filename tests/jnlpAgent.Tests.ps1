Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$AGENT_IMAGE='jenkins-jnlp-agent'
$AGENT_CONTAINER='pester-jenkins-jnlp-agent'
$SHELL="powershell.exe"

$FOLDER = Get-EnvOrDefault 'FOLDER' ''
$VERSION = Get-EnvOrDefault 'VERSION' '4.0.1-1'

$REAL_FOLDER=Resolve-Path -Path "$PSScriptRoot/../${FOLDER}"

if(($FOLDER -match '^(?<jdk>[0-9]+)[\\/](?<flavor>.+)$') -and (Test-Path $REAL_FOLDER)) {
    $JDK = $Matches['jdk']
    $FLAVOR = $Matches['flavor']
} else {
    Write-Error "Wrong folder format or folder does not exist: $FOLDER"
    exit 1
}

if($FLAVOR -match "nanoserver") {
    $AGENT_IMAGE += "-nanoserver"
    $AGENT_CONTAINER += "-nanoserver-1809"
    $SHELL = "pwsh.exe"
}

if($JDK -eq "11") {
    $AGENT_IMAGE += ":jdk11"
    $AGENT_CONTAINER += "-jdk11"
} else {
    $AGENT_IMAGE += ":latest"
}

Cleanup($AGENT_CONTAINER)
Cleanup("nmap")
CleanupNetwork("jnlp-network")

BuildNcatImage

Describe "[$JDK $FLAVOR] build image" {
    BeforeAll {
      Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
    }

    It 'builds image' {
      $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build --build-arg VERSION=$VERSION -t $AGENT_IMAGE $FOLDER"
      $exitCode | Should -Be 0
    }

    AfterAll {
      Pop-Location -StackName 'agent'
    }
}

Describe "[$JDK $FLAVOR] image has jenkins-agent.ps1 in the correct location" {
    BeforeAll {
        & docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" $SHELL
        Is-ContainerRunning $AGENT_CONTAINER | Should -BeTrue
    }

    It 'has jenkins-agent.ps1 in C:/ProgramData/Jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"if(Test-Path C:/ProgramData/Jenkins/jenkins-agent.ps1) { exit 0 } else { exit 1}`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($AGENT_CONTAINER)
    }
}

Describe "[$JDK $FLAVOR] image starts jenkins-agent.ps1 correctly (slow test)" {
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
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -dit --network=jnlp-network --name $AGENT_CONTAINER $AGENT_IMAGE -Url http://${nmap_ip}:5000 -Secret aaa -Name bbb"
        $exitCode | Should -Be 0
        Is-ContainerRunning $AGENT_CONTAINER | Should -BeTrue

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' 'wait nmap'
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' 'logs nmap'
        $exitCode | Should -Be 0
        $stdout | Should -Match "GET /tcpSlaveAgentListener/ HTTP/1.1`r"
    }

    AfterAll {
        Cleanup($AGENT_CONTAINER)
        Cleanup("nmap")
        CleanupNetwork("jnlp-network")
    }
}

Describe "[$JDK $FLAVOR] build args" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
    }

    It 'uses build args correctly' {
        #$TEST_VERSION="3.36"
        $TEST_VERSION="4.3"
        $TEST_USER="foo"

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build --build-arg VERSION=${TEST_VERSION}-1 --build-arg user=$TEST_USER -t $AGENT_IMAGE $FOLDER"
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -dit --name $AGENT_CONTAINER -P $AGENT_IMAGE $SHELL"
        $exitCode | Should -Be 0
        Is-ContainerRunning "$AGENT_CONTAINER" | Should -BeTrue

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -c `"java -cp C:/ProgramData/Jenkins/agent.jar hudson.remoting.jnlp.Main -version`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $TEST_VERSION

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -c `"(Get-ChildItem env:\ | Where-Object { `$_.Name -eq 'USERNAME' }).Value`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $TEST_USER
    }

    AfterAll {
        Pop-Location -StackName 'agent'
    }
}
