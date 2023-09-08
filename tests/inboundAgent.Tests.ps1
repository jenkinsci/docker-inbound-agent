Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:AGENT_IMAGE = Get-EnvOrDefault 'AGENT_IMAGE' ''
$global:BUILD_CONTEXT = Get-EnvOrDefault 'BUILD_CONTEXT' ''
$global:version = Get-EnvOrDefault 'VERSION' ''

$items = $global:AGENT_IMAGE.Split("-")

# Remove the 'jdk' prefix (3 first characters)
$global:JAVAMAJORVERSION = $items[0].Remove(0,3)
$global:WINDOWSFLAVOR = $items[1]
$global:WINDOWSVERSIONTAG = $items[2]

# TODO: make this name unique for concurency
$global:CONTAINERNAME = 'pester-jenkins-inbound-agent-{0}' -f $global:AGENT_IMAGE

$global:CONTAINERSHELL="powershell.exe"
if($global:WINDOWSFLAVOR -eq 'nanoserver') {
    $global:CONTAINERSHELL = "pwsh.exe"
}

# Uncomment to help debugging when working on this script
Write-Host "= DEBUG: global vars"
Get-Variable -Scope Global | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }

Cleanup($global:CONTAINERNAME)
Cleanup("nmap")
CleanupNetwork("jnlp-network")

BuildNcatImage($global:WINDOWSVERSIONTAG)

Describe "[$global:AGENT_IMAGE] build image" {
    It 'builds image' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --build-arg version=${global:version} --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg JAVA_MAJOR_VERSION=${global:JAVAMAJORVERSION} --tag=${global:AGENT_IMAGE} --file ./windows/${global:WINDOWSFLAVOR}/Dockerfile ${global:BUILD_CONTEXT}"
        $exitCode | Should -Be 0
    }
}

Describe "[$global:AGENT_IMAGE] check default user account" {
    BeforeAll {
        docker run --detach --tty --name "$global:CONTAINERNAME" "$global:AGENT_IMAGE" -Cmd "$global:CONTAINERSHELL"
        $LASTEXITCODE | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'has a password that never expires' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if((net user jenkins | Select-String -Pattern 'Password expires') -match 'Never') { exit 0 } else { net user jenkins ; exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'has password policy of "not required"' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if((net user jenkins | Select-String -Pattern 'Password required') -match 'No') { exit 0 } else { net user jenkins ; exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:AGENT_IMAGE] image has jenkins-agent.ps1 in the correct location" {
    BeforeAll {
        docker run --detach --tty --name "$global:CONTAINERNAME" "$global:AGENT_IMAGE" -Cmd "$global:CONTAINERSHELL"
        $LASTEXITCODE | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'has jenkins-agent.ps1 in C:/ProgramData/Jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if(Test-Path 'C:/ProgramData/Jenkins/jenkins-agent.ps1') { exit 0 } else { exit 1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:AGENT_IMAGE] custom build args" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
        # Old version used to test overriding the build arguments.
        # This old version must have the same tag suffixes as the current windows images (`-jdk11-nanoserver` etc.), and the same Windows version (2019, 2022, etc.)
        $TEST_VERSION = "3148.v532a_7e715ee3"
        $PARENT_IMAGE_VERSION_SUFFIX = "3"
        $ARG_TEST_VERSION = "${TEST_VERSION}-${PARENT_IMAGE_VERSION_SUFFIX}"
        $customImageName = "custom-${global:AGENT_IMAGE}"
    }

    It 'builds image with arguments' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --build-arg version=${ARG_TEST_VERSION} --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg JAVA_MAJOR_VERSION=${global:JAVAMAJORVERSION} --build-arg WINDOWS_FLAVOR=${global:WINDOWSFLAVOR} --tag=${customImageName} --file=./windows/${global:WINDOWSFLAVOR}/Dockerfile ${global:BUILD_CONTEXT}"
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name $global:CONTAINERNAME $customImageName -Cmd $global:CONTAINERSHELL"
        $exitCode | Should -Be 0
        Is-ContainerRunning "$global:CONTAINERNAME" | Should -BeTrue
    }

    It "has the correct agent.jar version" {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -c `"java -cp C:/ProgramData/Jenkins/agent.jar hudson.remoting.jnlp.Main -version`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $TEST_VERSION
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
        Pop-Location -StackName 'agent'
    }
}

Describe "[$global:AGENT_IMAGE] image starts jenkins-agent.ps1 correctly (slow test)" {
    It 'connects to the nmap container' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "network create --driver nat jnlp-network"
        # Launch the netcat utility, listening at port 5000 for 30 sec
        # bats will capture the output from netcat and compare the first line
        # of the header of the first HTTP request with the expected one
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name nmap --network=jnlp-network nmap:latest ncat.exe -w 30 -l 5000"
        $exitCode | Should -Be 0
        Is-ContainerRunning "nmap" | Should -BeTrue

        # get the ip address of the nmap container
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" nmap"
        $exitCode | Should -Be 0
        $nmap_ip = $stdout.Trim()

        # run Jenkins agent which tries to connect to the nmap container at port 5000
        $secret = "aaa"
        $name = "bbb"
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --network=jnlp-network --name $global:CONTAINERNAME $global:AGENT_IMAGE -Url http://${nmap_ip}:5000 $secret $name"
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue

        $exitCode, $stdout, $stderr = Run-Program 'docker' 'wait nmap'
        $exitCode, $stdout, $stderr = Run-Program 'docker' 'logs nmap'
        $exitCode | Should -Be 0
        $stdout | Should -Match "GET /tcpSlaveAgentListener/ HTTP/1.1`r"
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
        Cleanup("nmap")
        CleanupNetwork("jnlp-network")
    }
}

Describe "[$global:AGENT_IMAGE] passing JVM options (slow test)" {
    It "shows the java version ${global:JAVAMAJORVERSION} with --show-version" {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "network create --driver nat jnlp-network"
        # Launch the netcat utility, listening at port 5000 for 30 sec
        # bats will capture the output from netcat and compare the first line
        # of the header of the first HTTP request with the expected one
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name nmap --network=jnlp-network nmap:latest ncat.exe -w 30 -l 5000"
        $exitCode | Should -Be 0
        Is-ContainerRunning "nmap" | Should -BeTrue

        # get the ip address of the nmap container
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" nmap"
        $exitCode | Should -Be 0
        $nmap_ip = $stdout.Trim()

        # run Jenkins agent which tries to connect to the nmap container at port 5000
        $secret = "aaa"
        $name = "bbb"
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --network=jnlp-network --name $global:CONTAINERNAME $global:AGENT_IMAGE -Url http://${nmap_ip}:5000 -JenkinsJavaOpts `"--show-version`" $secret $name"
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
        $exitCode, $stdout, $stderr = Run-Program 'docker' "logs $global:CONTAINERNAME"
        $exitCode | Should -Be 0
        $stdout | Should -Match "OpenJDK Runtime Environment Temurin-${global:JAVAMAJORVERSION}"
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
        Cleanup("nmap")
        CleanupNetwork("jnlp-network")
    }
}
