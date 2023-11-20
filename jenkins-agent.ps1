# The MIT License
#
#  Copyright (c) 2019-2020, Alex Earl
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

[CmdletBinding()]
Param(
    $Cmd = '', # this must be specified explicitly
    $Url = $( if([System.String]::IsNullOrWhiteSpace($Cmd) -and [System.String]::IsNullOrWhiteSpace($env:JENKINS_URL) -and [System.String]::IsNullOrWhiteSpace($env:JENKINS_DIRECT_CONNECTION)) { throw ("Url is required") } else { '' } ),
    [Parameter(Position=0)]$Secret = $( if([System.String]::IsNullOrWhiteSpace($Cmd) -and [System.String]::IsNullOrWhiteSpace($env:JENKINS_SECRET)) { throw ("Secret is required") } else { '' } ),
    [Parameter(Position=1)]$Name = $( if([System.String]::IsNullOrWhiteSpace($Cmd) -and [System.String]::IsNullOrWhiteSpace($env:JENKINS_AGENT_NAME)) { throw ("Name is required") } else { '' } ),
    $Tunnel = '',
    $WorkDir = '',
    [switch] $WebSocket = $false,
    $DirectConnection = '',
    $InstanceIdentity = '',
    $Protocols = '',
    $JenkinsJavaBin = '',
    $JavaHome = $env:JAVA_HOME,
    $JenkinsJavaOpts = ''
)

# Usage jenkins-agent.ps1 [options] -Url http://jenkins -Secret [SECRET] -Name [AGENT_NAME]
# Optional environment variables :
# * JENKINS_JAVA_BIN : Java executable to use instead of the default in PATH or obtained from JAVA_HOME
# * JENKINS_JAVA_OPTS : Java Options to use for the remoting process, otherwise obtained from JAVA_OPTS
# * JENKINS_TUNNEL : HOST:PORT for a tunnel to route TCP traffic to jenkins host, when jenkins can't be directly accessed over network
# * JENKINS_URL : alternate jenkins URL
# * JENKINS_SECRET : agent secret, if not set as an argument
# * JENKINS_AGENT_NAME : agent name, if not set as an argument
# * JENKINS_AGENT_WORKDIR : agent work directory, if not set by optional parameter -workDir
# * JENKINS_WEB_SOCKET : true if the connection should be made via WebSocket rather than TCP
# * JENKINS_DIRECT_CONNECTION: Connect directly to this TCP agent port, skipping the HTTP(S) connection parameter download.
#                              Value: "<HOST>:<PORT>"
# * JENKINS_INSTANCE_IDENTITY: The base64 encoded InstanceIdentity byte array of the Jenkins controller. When this is set,
#                              the agent skips connecting to an HTTP(S) port for connection info.
# * JENKINS_PROTOCOLS:         Specify the remoting protocols to attempt when instanceIdentity is provided.

if(![System.String]::IsNullOrWhiteSpace($Cmd)) {
	Invoke-Expression "$Cmd"
} else {

    # this maps the variable name from the CmdletBinding to environment variables
    $ParamMap = @{
        'JenkinsJavaBin' = 'JENKINS_JAVA_BIN';
        'JenkinsJavaOpts' = 'JENKINS_JAVA_OPTS';
        'Tunnel' = 'JENKINS_TUNNEL';
        'Url' = 'JENKINS_URL';
        'Secret' = 'JENKINS_SECRET';
        'Name' = 'JENKINS_AGENT_NAME';
        'WorkDir' = 'JENKINS_AGENT_WORKDIR';
        'WebSocket' = 'JENKINS_WEB_SOCKET';
        'DirectConnection' = 'JENKINS_DIRECT_CONNECTION';
        'InstanceIdentity' = 'JENKINS_INSTANCE_IDENTITY';
        'Protocols' = 'JENKINS_PROTOCOLS';
    }

    # this does some trickery to update the variable from the CmdletBinding
    # with the value of the
    foreach($p in $ParamMap.Keys) {
        $var = Get-Variable $p
        $envVar = Get-ChildItem -Path "env:$($ParamMap[$p])" -ErrorAction 'SilentlyContinue'

        if(($null -ne $envVar) -and ((($envVar.Value -is [System.String]) -and (![System.String]::IsNullOrWhiteSpace($envVar.Value))) -or ($null -ne $envVar.Value))) {
            if(($null -ne $var) -and ((($var.Value -is [System.String]) -and (![System.String]::IsNullOrWhiteSpace($var.Value))))) {
                Write-Warning "${p} is defined twice; in command-line arguments (-${p}) and in the environment variable ${envVar.Name}"
            }
            if($var.Value -is [System.String]) {
                $var.Value = $envVar.Value
            } elseif($var.Value -is [System.Management.Automation.SwitchParameter]) {
                $var.Value = [bool]$envVar.Value
            }
        }
        if($var.Value -is [System.String]) {
            $var.Value = $var.Value.Trim()
        }
    }

    $AgentArguments = @()

    if(![System.String]::IsNullOrWhiteSpace($JenkinsJavaOpts)) {
        # this magic will basically process the $JenkinsJavaOpts like a command line
        # and split into an array, the command line processing follows the PowerShell
        # commnd line processing, which means for things like -Dsomething.something=something,
        # you need to quote the string like this: "-Dsomething.something=something" or else it
        # will get parsed incorrectly.
        $AgentArguments += Invoke-Expression "echo $JenkinsJavaOpts"
    }

    $AgentArguments += @("-jar", "C:/ProgramData/Jenkins/agent.jar")
    $AgentArguments += @("-secret", $Secret)
    $AgentArguments += @("-name", $Name)

    if(![System.String]::IsNullOrWhiteSpace($Tunnel)) {
        $AgentArguments += @("-tunnel", "`"$Tunnel`"")
    }

    if(![System.String]::IsNullOrWhiteSpace($WorkDir)) {
        $AgentArguments += @("-workDir", "`"$WorkDir`"")
    } else {
        $AgentArguments += @("-workDir", "`"C:/Users/jenkins/Work`"")
    }

    if($WebSocket) {
        $AgentArguments += @("-webSocket")
    }

    if(![System.String]::IsNullOrWhiteSpace($Url)) {
        $AgentArguments += @("-url", "`"$Url`"")
    }

    if(![System.String]::IsNullOrWhiteSpace($DirectConnection)) {
        $AgentArguments += @('-direct', $DirectConnection)
    }

    if(![System.String]::IsNullOrWhiteSpace($InstanceIdentity)) {
        $AgentArguments += @('-instanceIdentity', $InstanceIdentity)
    }

    if(![System.String]::IsNullOrWhiteSpace($Protocols)) {
        $AgentArguments += @('-protocols', $Protocols)
    }

    if(![System.String]::IsNullOrWhiteSpace($JenkinsJavaBin)) {
        $JAVA_BIN = $JenkinsJavaBin
    } else {
        # if java home is defined, use it
        $JAVA_BIN = "java.exe"
        if (![System.String]::IsNullOrWhiteSpace($JavaHome)) {
            $JAVA_BIN = "$JavaHome/bin/java.exe"
        }
    }

    #TODO: Handle the case when the command-line and Environment variable contain different values.
    #It is fine it blows up for now since it should lead to an error anyway.
    Start-Process -FilePath $JAVA_BIN -Wait -NoNewWindow -ArgumentList $AgentArguments
}
