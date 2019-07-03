if([System.String]::IsNullOrWhiteSpace($env:IMAGE_NAME)) {
    $env:IMAGE_NAME='jenkins4eval/jnlp-agent-windows:test'
}

& docker build -f Dockerfile-windows -t $env:IMAGE_NAME .