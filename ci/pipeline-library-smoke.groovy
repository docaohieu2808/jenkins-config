// Loads the shared library registered by JCasC and calls one of its steps.
@Library('auto-pipeline') _
node {
    greet('jcasc')
}
