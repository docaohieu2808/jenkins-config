# Jenkins controller, built from code: pinned LTS core + pinned plugins + JCasC baked in.
# Jenkins LTS 2.580.1 is the current LTS line (updates.jenkins.io, 2026-10-26).
FROM jenkins/jenkins:2.580.1-lts-jdk21

# No setup wizard: the admin user and every setting come from casc.yaml.
ENV JAVA_OPTS="-Xmx2g -Xms512m -Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc.yaml

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins:jenkins casc.yaml /usr/share/jenkins/casc.yaml
