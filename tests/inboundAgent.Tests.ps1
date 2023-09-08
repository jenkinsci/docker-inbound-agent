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

# Test fix "exadecimal value 0x1B, is an invalid character." ref https://github.com/PowerShell/PowerShell/issues/10809
$env:__SuppressAnsiEscapeSequences = 1

# Uncomment to help debugging when working on this script
Write-Host "= DEBUG: global vars"
Get-Variable -Scope Global | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }
Write-Host "= DEBUG: env vars"
Get-ChildItem Env: | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }

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
        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --build-arg version=${ARG_TEST_VERSION} --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg JAVA_MAJOR_VERSION=${global:JAVAMAJORVERSION} --build-arg WINDOWS_FLAVOR=${global:WINDOWSFLAVOR} --build-arg CONTAINER_SHELL=${global:CONTAINERSHELL} --tag=${customImageName} --file=./windows/${global:WINDOWSFLAVOR}/Dockerfile ${global:BUILD_CONTEXT}"
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

# === TODO: uncomment test later, see error log below
# === this test passes on a Windows machine

# Describe "[$global:AGENT_IMAGE] passing JVM options (slow test)" {
#     It "shows the java version ${global:JAVAMAJORVERSION} with --show-version" {
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "network create --driver nat jnlp-network"
#         # Launch the netcat utility, listening at port 5000 for 30 sec
#         # bats will capture the output from netcat and compare the first line
#         # of the header of the first HTTP request with the expected one
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name nmap --network=jnlp-network nmap:latest ncat.exe -w 30 -l 5000"
#         $exitCode | Should -Be 0
#         Is-ContainerRunning "nmap" | Should -BeTrue

#         # get the ip address of the nmap container
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" nmap"
#         $exitCode | Should -Be 0
#         $nmap_ip = $stdout.Trim()

#         # run Jenkins agent which tries to connect to the nmap container at port 5000
#         $secret = "aaa"
#         $name = "bbb"
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --network=jnlp-network --name $global:CONTAINERNAME $global:AGENT_IMAGE -Url http://${nmap_ip}:5000 -JenkinsJavaOpts `"--show-version`" $secret $name"
#         $exitCode | Should -Be 0
#         Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "logs $global:CONTAINERNAME"
#         $exitCode | Should -Be 0
#         $stdout | Should -Match "OpenJDK Runtime Environment Temurin-${global:JAVAMAJORVERSION}"
#     }

#     AfterAll {
#         Cleanup($global:CONTAINERNAME)
#         Cleanup("nmap")
#         CleanupNetwork("jnlp-network")
#     }
# }


# === Corresponding error log:

# Running tests from 'inboundAgent.Tests.ps1'
# Describing [jdk17-windowsservercore-1809] build image
# cmd = docker, params = build --build-arg version=3148.v532a_7e715ee3-3 --build-arg "WINDOWS_VERSION_TAG=1809" --build-arg JAVA_MAJOR_VERSION=17 --tag=jdk17-windowsservercore-1809 --file ./windows/windowsservercore/Dockerfile C:\Jenkins\agent\workspace\ging_docker-inbound-agent_PR-396
#   [+] builds image 572ms (378ms|195ms)
# cmd = docker.exe, params = inspect -f "{{.State.Running}}" pester-jenkins-inbound-agent-jdk17-windowsservercore-1809

# Describing [jdk17-windowsservercore-1809] check default user account
# cmd = docker, params = exec pester-jenkins-inbound-agent-jdk17-windowsservercore-1809 powershell.exe -C "if((net user jenkins | Select-String -Pattern 'Password expires') -match 'Never') { exit 0 } else { net user jenkins ; exit -1 }"
#   [+] has a password that never expires 4.55s (4.55s|5ms)
# cmd = docker, params = exec pester-jenkins-inbound-agent-jdk17-windowsservercore-1809 powershell.exe -C "if((net user jenkins | Select-String -Pattern 'Password required') -match 'No') { exit 0 } else { net user jenkins ; exit -1 }"
#   [+] has password policy of "not required" 2.74s (2.73s|3ms)
# cmd = docker.exe, params = inspect -f "{{.State.Running}}" pester-jenkins-inbound-agent-jdk17-windowsservercore-1809

# Describing [jdk17-windowsservercore-1809] image has jenkins-agent.ps1 in the correct location
# cmd = docker, params = exec pester-jenkins-inbound-agent-jdk17-windowsservercore-1809 powershell.exe -C "if(Test-Path 'C:/ProgramData/Jenkins/jenkins-agent.ps1') { exit 0 } else { exit 1 }"
#   [+] has jenkins-agent.ps1 in C:/ProgramData/Jenkins 4.35s (4.27s|85ms)

# Describing [jdk17-windowsservercore-1809] image starts jenkins-agent.ps1 correctly (slow test)
# cmd = docker, params = network create --driver nat jnlp-network
# cmd = docker, params = run --detach --tty --name nmap --network=jnlp-network nmap:latest ncat.exe -w 30 -l 5000
# cmd = docker.exe, params = inspect -f "{{.State.Running}}" nmap
# cmd = docker, params = inspect --format "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" nmap
# cmd = docker, params = run --detach --tty --network=jnlp-network --name pester-jenkins-inbound-agent-jdk17-windowsservercore-1809 jdk17-windowsservercore-1809 -Url http://172.23.176.67:5000 aaa bbb
# cmd = docker.exe, params = inspect -f "{{.State.Running}}" pester-jenkins-inbound-agent-jdk17-windowsservercore-1809
# cmd = docker, params = wait nmap
# cmd = docker, params = logs nmap
#   [+] connects to the nmap container 89.43s (89.43s|8ms)

# Describing [jdk17-windowsservercore-1809] custom build args
# cmd = docker, params = build --build-arg version=3148.v532a_7e715ee3-3 --build-arg "WINDOWS_VERSION_TAG=1809" --build-arg JAVA_MAJOR_VERSION=17 --build-arg WINDOWS_FLAVOR=windowsservercore --build-arg CONTAINER_SHELL=powershell.exe --tag=custom-jdk17-windowsservercore-1809 --file=./windows/windowsservercore/Dockerfile C:\Jenkins\agent\workspace\ging_docker-inbound-agent_PR-396
# cmd = docker, params = run --detach --tty --name pester-jenkins-inbound-agent-jdk17-windowsservercore-1809 custom-jdk17-windowsservercore-1809 -Cmd powershell.exe
# cmd = docker.exe, params = inspect -f "{{.State.Running}}" pester-jenkins-inbound-agent-jdk17-windowsservercore-1809
#   [+] builds image with arguments 11.3s (11.3s|5ms)
# cmd = docker, params = exec pester-jenkins-inbound-agent-jdk17-windowsservercore-1809 powershell.exe -c "java -cp C:/ProgramData/Jenkins/agent.jar hudson.remoting.jnlp.Main -version"
#   [+] has the correct agent.jar version 2.25s (2.25s|5ms)

# Describing [jdk17-windowsservercore-1809] passing JVM options (slow test)
# cmd = docker, params = network create --driver nat jnlp-network
# cmd = docker, params = run --detach --tty --name nmap --network=jnlp-network nmap:latest ncat.exe -w 30 -l 5000
# cmd = docker.exe, params = inspect -f "{{.State.Running}}" nmap
# cmd = docker, params = inspect --format "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" nmap
# cmd = docker, params = run --detach --tty --network=jnlp-network --name pester-jenkins-inbound-agent-jdk17-windowsservercore-1809 jdk17-windowsservercore-1809 -Url http://172.23.254.19:5000 -JenkinsJavaOpts "--show-version" aaa bbb
# cmd = docker.exe, params = inspect -f "{{.State.Running}}" pester-jenkins-inbound-agent-jdk17-windowsservercore-1809
# cmd = docker, params = logs pester-jenkins-inbound-agent-jdk17-windowsservercore-1809
#   [-] shows the java version 17 with --show-version 24.36s (24.35s|11ms)
#    Expected regular expression 'OpenJDK Runtime Environment Temurin-17' to match '
#    ', but it did not match.
#    at $stdout | Should -Match "OpenJDK Runtime Environment Temurin-${global:JAVAMAJORVERSION}", C:\Jenkins\agent\workspace\ging_docker-inbound-agent_PR-396\tests\inboundAgent.Tests.ps1:173
#    at <ScriptBlock>, C:\Jenkins\agent\workspace\ging_docker-inbound-agent_PR-396\tests\inboundAgent.Tests.ps1:173
# Tests completed in 219.22s
# Tests Passed: 7, Failed: 1, Skipped: 0 NotRun: 0
# System.Management.Automation.MethodInvocationException: Exception calling "WriteAttributeString" with "2" argument(s): "'exadecimal value 0x1B, is an invalid character." ---> System.ArgumentException: 'exadecimal value 0x1B, is an invalid character.
#    at System.Xml.XmlUtf8RawTextWriter.InvalidXmlChar(Int32 ch, Byte* pDst, Boolean entitize)
#    at System.Xml.XmlUtf8RawTextWriter.WriteAttributeTextBlock(Char* pSrc, Char* pSrcEnd)
#    at System.Xml.XmlUtf8RawTextWriter.WriteString(String text)
#    at System.Xml.XmlWellFormedWriter.WriteString(String text)
#    at System.Xml.XmlWriter.WriteAttributeString(String localName, String value)
#    at CallSite.Target(Closure , CallSite , XmlWriter , String , Object )
#    --- End of inner exception stack trace ---
#    at System.Management.Automation.ExceptionHandlingOps.CheckActionPreference(FunctionContext funcContext, Exception exception)
#    at System.Management.Automation.Interpreter.ActionCallInstruction`2.Run(InterpretedFrame frame)
#    at System.Management.Automation.Interpreter.EnterTryCatchFinallyInstruction.Run(InterpretedFrame frame)
#    at System.Management.Automation.Interpreter.EnterTryCatchFinallyInstruction.Run(InterpretedFrame frame)
#    at System.Management.Automation.Interpreter.Interpreter.Run(InterpretedFrame frame)
#    at System.Management.Automation.Interpreter.LightLambda.RunVoid1[T0](T0 arg0)
#    at System.Management.Automation.PSScriptCmdlet.RunClause(Action`1 clause, Object dollarUnderbar, Object inputToProcess)
#    at System.Management.Automation.PSScriptCmdlet.DoEndProcessing()
#    at System.Management.Automation.CommandProcessorBase.Complete()
# at Write-JUnitTestCaseMessageElements, C:\Program Files\WindowsPowerShell\Modules\Pester\5.3.3\Pester.psm1: line 16460
# at Write-JUnitTestCaseAttributes, C:\Program Files\WindowsPowerShell\Modules\Pester\5.3.3\Pester.psm1: line 16452
# at Write-JUnitTestCaseElements, C:\Program Files\WindowsPowerShell\Modules\Pester\5.3.3\Pester.psm1: line 16424
# at Write-JUnitTestSuiteElements, C:\Program Files\WindowsPowerShell\Modules\Pester\5.3.3\Pester.psm1: line 16385
# at Write-JUnitReport, C:\Program Files\WindowsPowerShell\Modules\Pester\5.3.3\Pester.psm1: line 16269
# at Export-XmlReport, C:\Program Files\WindowsPowerShell\Modules\Pester\5.3.3\Pester.psm1: line 16005
# at Export-PesterResults, C:\Program Files\WindowsPowerShell\Modules\Pester\5.3.3\Pester.psm1: line 15863
# at Invoke-Pester<End>, C:\Program Files\WindowsPowerShell\Modules\Pester\5.3.3\Pester.psm1: line 5263
# at Test-Image, C:\Jenkins\agent\workspace\ging_docker-inbound-agent_PR-396\build.ps1: line 130
# at <ScriptBlock>, C:\Jenkins\agent\workspace\ging_docker-inbound-agent_PR-396\build.ps1: line 176
# at <ScriptBlock>, C:\Jenkins\agent\workspace\ging_docker-inbound-agent_PR-396@tmp\durable-513b70db\powershellScript.ps1: line 1
# at <ScriptBlock>, <No file>: line 1
# at <ScriptBlock>, <No file>: line 1

# === end of error log
