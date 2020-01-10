# The MIT License
#
#  Copyright (c) 2020, Alex Earl
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
	$Url = '',
	$Secret = '',
	$Name = '',
	$Tunnel = '',
	$WorkDir = 'C:/Users/jenkins/Agent',
	$JavaHome = $env:JAVA_HOME
)

# Usage jenkins-agent.ps1 [options] -Url http://jenkins -Secret [SECRET] -Name [AGENT_NAME]
# Optional environment variables :
# * JENKINS_TUNNEL : HOST:PORT for a tunnel to route TCP traffic to jenkins host, when jenkins can't be directly accessed over network
# * JENKINS_URL : alternate jenkins URL
# * JENKINS_SECRET : agent secret, if not set as an argument
# * JENKINS_AGENT_NAME : agent name, if not set as an argument
# * JENKINS_AGENT_WORKDIR : agent work directory, if not set by optional parameter -workDir

if(![System.String]::IsNullOrWhiteSpace($Cmd)) {
	# if `docker run` only has one arguments, we assume user is running alternate command like `bash` to inspect the image
	Invoke-Expression "$Cmd"
} else {
	# if -Tunnel is not provided, try env vars
	if(![System.String]::IsNullOrWhiteSpace($env:JENKINS_TUNNEL)) {
		if(![System.String]::IsNullOrWhiteSpace($Tunnel)) {
			Write-Warning "Tunnel is defined twice; in command-line arguments and the environment variable"
		}
		$Tunnel = $($env:JENKINS_TUNNEL).Trim()
	}
	$Tunnel = $Tunnel.Trim()
	if(![System.String]::IsNullOrWhiteSpace($Tunnel)) {
		$Tunnel = " -tunnel `"$Tunnel`""
	}

	# if -WorkDir is not provided, try env vars
	if(![System.String]::IsNullOrWhiteSpace($env:JENKINS_AGENT_WORKDIR)) {
		if(![System.String]::IsNullOrWhiteSpace($WorkDir)) {
			Write-Warning "Work directory is defined twice; in command-line arguments and the environment variable"
		}
		$WorkDir = $env:JENKINS_AGENT_WORKDIR
	}
	$WorkDir = $WorkDir.Trim()
	if(![System.String]::IsNullOrWhiteSpace($WorkDir)) {
		$WorkDir = " -workDir `"$WorkDir`""
	}

	# if -Url is not provided, try env vars
	if(![System.String]::IsNullOrWhiteSpace($env:JENKINS_URL)) {
		if(![System.String]::IsNullOrWhiteSpace($Url)) {
			Write-Warning "Url is defined twice; in command-line arguments and the environment variable"
		}
		$Url = $($env:JENKINS_URL).Trim()
	}
	$Url = $Url.Trim()
	if(![System.String]::IsNullOrWhiteSpace($Url)) {
		$Url = " -url `"$Url`""
	}

	# if -Name is not provided, try env vars
	if(![System.String]::IsNullOrWhiteSpace($env:JENKINS_NAME)) {
		if(![System.String]::IsNullOrWhiteSpace($Name)) {
			Write-Warning "Name is defined twice; in command-line arguments and the environment variable"
		}
		$Name = $env:JENKINS_NAME
	}
	$Name = $Name.Trim()

	# if java home is defined, use it
	$JAVA_BIN="java.exe"
	if(![System.String]::IsNullOrWhiteSpace($JavaHome)) {
		$JAVA_BIN="$JavaHome/bin/java.exe"
	}

	# if -Url is not provided, try env vars
	if(![System.String]::IsNullOrWhiteSpace($env:JENKINS_SECRET)) {
		if(![System.String]::IsNullOrWhiteSpace($Secret)) {
			Write-Warning "Secret is defined twice; in command-line arguments and the environment variable"
		}
		$Secret = $env:JENKINS_SECRET
	}
	$Secret = $Secret.Trim()
	if(![System.String]::IsNullOrWhiteSpace($Secret)) {
		$Secret = " $Secret"
	}

	#TODO: Handle the case when the command-line and Environment variable contain different values.
	#It is fine it blows up for now since it should lead to an error anyway.
	Start-Process -FilePath $JAVA_BIN -Wait -NoNewWindow -ArgumentList $("-cp C:/ProgramData/Jenkins/agent.jar hudson.remoting.jnlp.Main -headless$Tunnel$Url$WorkDir$Secret $Name")
}
