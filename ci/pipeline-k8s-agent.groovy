// Runs on an ephemeral pod created by the "k8s" cloud, inside the python tool container.
node('python') {
    container('python') {
        sh 'python --version'
        sh 'python -c "import sys; assert sys.version_info >= (3, 14)"'
    }
}
