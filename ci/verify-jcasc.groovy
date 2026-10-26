// Run against a live controller (jenkins-cli groovy =): proves casc.yaml was applied, not just parsed.
// Any failed check throws, which makes the CLI exit non-zero.
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.common.StandardCredentials
import org.csanchez.jenkins.plugins.kubernetes.KubernetesCloud
import org.jenkinsci.plugins.workflow.libs.GlobalLibraries

def jenkins = Jenkins.get()
def check = { boolean ok, String what ->
    if (!ok) { throw new IllegalStateException("JCasC check failed: ${what}") }
    println "ok   ${what}"
}

// security
check(jenkins.securityRealm.class.simpleName == 'HudsonPrivateSecurityRealm', 'local security realm')
check(!jenkins.securityRealm.allowsSignup(), 'sign-up disabled')
check(jenkins.getUser(System.getenv('JENKINS_ADMIN_USER') ?: 'admin', false, [:]) != null, 'admin user exists')
check(jenkins.slaveAgentPort == 50000, 'agent port 50000')

// kubernetes cloud
def cloud = jenkins.clouds.getByName('k8s')
check(cloud instanceof KubernetesCloud, 'kubernetes cloud "k8s" exists')
check(cloud.credentialsId == 'k8s-token', 'cloud uses credential k8s-token')
check(!cloud.skipTlsVerify, 'TLS verification is on')
check(cloud.serverCertificate?.startsWith('-----BEGIN CERTIFICATE-----'), 'cluster CA decoded to PEM')
check(cloud.namespace == 'jenkins', 'namespace jenkins')
check(cloud.serverUrl == System.getenv('K8S_SERVER_URL'), 'server URL from env')
check(cloud.jenkinsTunnel == System.getenv('JENKINS_TUNNEL'), 'tunnel from env')
def labels = cloud.templates*.label.toSet()
check(labels == ['node', 'java maven', 'python', 'go golang', 'docker'].toSet(), "five agent templates (${labels})")
def images = cloud.templates*.containers*.image.flatten()
check(images.every { !it.endsWith(':latest') && it.contains(':') }, 'no agent image uses :latest or an untagged image')

// credentials
def creds = CredentialsProvider.lookupCredentials(StandardCredentials, jenkins, null, null)*.id
check(creds.containsAll(['k8s-token', 'gitlab-creds']), "credentials present (${creds})")

// shared library
def libs = GlobalLibraries.get().libraries*.name
check(libs == ['auto-pipeline'], "shared library registered (${libs})")
check(GlobalLibraries.get().libraries[0].defaultVersion == 'master', 'library default version master')

// mail
def mailer = jenkins.getDescriptor('hudson.tasks.Mailer')
check(mailer.smtpHost == (System.getenv('SMTP_HOST') ?: 'smtp.resend.com'), 'mailer host')
check(jenkins.rootUrl == System.getenv('JENKINS_PUBLIC_URL'), 'Jenkins URL from env')
