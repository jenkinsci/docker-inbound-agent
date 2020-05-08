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
    $Cmd = '', # this is only used when docker run has one arg positional arg
    $Url = $( if([System.String]::IsNullOrWhiteSpace($Cmd) -and [System.String]::IsNullOrWhiteSpace($env:JENKINS_URL)) { throw ("Url is required") } else { '' } ),
    $Secret = $( if([System.String]::IsNullOrWhiteSpace($Cmd) -and [System.String]::IsNullOrWhiteSpace($env:JENKINS_SECRET)) { throw ("Secret is required") } else { '' } ),
    $Name = $( if([System.String]::IsNullOrWhiteSpace($Cmd) -and [System.String]::IsNullOrWhiteSpace($env:JENKINS_AGENT_NAME)) { throw ("Name is required") } else { '' } ),
    $Tunnel = '',
    $WorkDir = '',
    [switch] $WebSocket = $false,
    $DirectConnection = '',
    $InstanceIdentity = '',
    $Protocols = '',
    $JavaHome = $env:JAVA_HOME
)

# Usage jenkins-agent.ps1 [options] -Url http://jenkins -Secret [SECRET] -Name [AGENT_NAME]
# Optional environment variables :
# * JENKINS_TUNNEL : HOST:PORT for a tunnel to route TCP traffic to jenkins host, when jenkins can't be directly accessed over network
# * JENKINS_URL : alternate jenkins URL
# * JENKINS_SECRET : agent secret, if not set as an argument
# * JENKINS_AGENT_NAME : agent name, if not set as an argument
# * JENKINS_AGENT_WORKDIR : agent work directory, if not set by optional parameter -workDir
# * JENKINS_WEB_SOCKET : true if the connection should be made via WebSocket rather than TCP
# * JENKINS_DIRECT_CONNECTION: Connect directly to this TCP agent port, skipping the HTTP(S) connection parameter download.
#                              Value: "<HOST>:<PORT>"
# * JENKINS_INSTANCE_IDENTITY: The base64 encoded InstanceIdentity byte array of the Jenkins master. When this is set,
#                              the agent skips connecting to an HTTP(S) port for connection info.
# * JENKINS_PROTOCOLS:         Specify the remoting protocols to attempt when instanceIdentity is provided.

if(![System.String]::IsNullOrWhiteSpace($Cmd)) {
	# if `docker run` only has one argument, we assume user is running alternate command like `powershell` or `pwsh` to inspect the image
	Invoke-Expression "$Cmd"
} else {
    $AgentArguments = @("-cp", "C:/ProgramData/Jenkins/agent.jar", "hudson.remoting.jnlp.Main", "-headless")

    # this maps the variable name from th CmdletBinding to environment variables
    $ParamMap = @{
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

    # these need to be the last things added since they are positional
    # parameters to agent.jar
    $AgentArguments += @($Secret, $Name)

    # if java home is defined, use it
    $JAVA_BIN="java.exe"
    if(![System.String]::IsNullOrWhiteSpace($JavaHome)) {
        $JAVA_BIN="$JavaHome/bin/java.exe"
    }

    #TODO: Handle the case when the command-line and Environment variable contain different values.
    #It is fine it blows up for now since it should lead to an error anyway.
    Start-Process -FilePath $JAVA_BIN -Wait -NoNewWindow -ArgumentList $AgentArguments
}
