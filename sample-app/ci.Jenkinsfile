
properties([
  [$class: 'ParametersDefinitionProperty', parameterDefinitions: [
    [$class: 'StringParameterDefinition', defaultValue: '', description: 'The git branch to build', name: 'GIT_BRANCH'],
    [$class: 'StringParameterDefinition', defaultValue: 'latest', description: 'The docker image tag', name: 'IMAGE_TAG']
  ]]
])

node('master') {
  currentBuild.displayName = "${BUILD_NUMBER}-<%= @app_name %>"
  currentBuild.description = "Aceinfo Automation"
  wrap([$class: 'BuildUser']) {
    def oc = "oc"
    def osHost = "ocpc.gitook.com:8443"
    def osCredentialId = 'OpenshiftCredentialId'
    def gitUrl = 'https://github.com/aceinfo-jenkins/<%= @app_name %>.git'
    def gitCredentialId = 'jenkinsGithubCredentialId'
    def nexusRegistry = "<%= @docker_registry_url %>/<%= @docker_registry_repo %>"
    def nexusCredentialId = '41aebb46-b195-4957-bae0-78376aa149b0'
    def devTemplate = "osTemplate.yaml"

    stage ('Preparation') {
      checkout([$class: 'GitSCM',
        branches: [[name: "${GIT_BRANCH}"]],
        doGenerateSubmoduleConfigurations: false,
        extensions: [],
        submoduleCfg: [],
        userRemoteConfigs: [[credentialsId: gitCredentialId, url: gitUrl]],
	poll: true
      ])
      dir("${env.WORKSPACE}") {
        sh """
          ./gradlew clean
        """
      }
    }

    stage('Build') {
      hygieiaBuildPublishStep buildStatus: 'InProgress'
      dir("${env.WORKSPACE}") {
        sh """
          ./gradlew build
        """
      }
      slackSend (color: '#FFFF00', message: "BUILD STARTED : Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
    }

    stage('Unit Testing') {
       sh """
        ./gradlew clean test
        #hygieiaTestPublishStep buildStatus: 'Success', testApplicationName: '<%= @app_name %>', testEnvironmentName: 'CI', testFileNamePattern: '*.html', testResultsDirectory: '/src/cheersApp/build/reports/tests/test/', testType: 'Unit'
       """
    }

    stage('Static Code Analysis - findBugs') {
      dir("${env.WORKSPACE}") {
        sh """
          ./gradlew check
        """
      }
    }

    stage('Code Quality - SonarQube') {
      dir("${env.WORKSPACE}") {
        sh """
          ./gradlew sonarqube -Dsonar.host.url=http://sonar.gitook.com:9000
        """
       hygieiaSonarPublishStep ceQueryIntervalInSeconds: '10', ceQueryMaxAttempts: '30'
      }
    }

    stage ('Compose Docker Image') {
      //input message: "Continue Build Docker Image?", ok: "Build"
      dir("${env.WORKSPACE}") {
        sh """
           ./gradlew buildDocker
        """
      }
    }

    stage('Publish Docker Image') {
      step([$class:'FindBugsPublisher', canComputeNew:false, pattern:'**/findbugs/*.xml'])
      archiveArtifacts artifacts: 'build/libs/*.jar', onlyIfSuccessful: true
      archiveArtifacts artifacts: 'build/test-results/**/*', onlyIfSuccessful: false
      step([$class: 'JUnitResultArchiver', testResults: 'build/test-results/test/TEST-*.xml'])

      withCredentials([
        [$class: 'UsernamePasswordMultiBinding', credentialsId: nexusCredentialId, usernameVariable: 'NEXUS_USERNAME', passwordVariable: 'NEXUS_PASSWORD']
      ]) {
        dir("${env.WORKSPACE}") {
          sh """
             docker login <%= @docker_registry_url %> --username ${env.NEXUS_USERNAME} --password ${env.NEXUS_PASSWORD}
             docker tag <%= @docker_registry_repo %>/<%= @app_name %>:latest <%= @docker_registry_url %>/<%= @docker_registry_repo %>/<%= @app_name %>:${IMAGE_TAG}
             docker push <%= @docker_registry_url %>/<%= @docker_registry_repo %>/<%= @app_name %>:${IMAGE_TAG}
             docker rmi <%= @docker_registry_repo %>/<%= @app_name %>:latest
          """
        }
      }
    }

   stage ('Deploy to FT Environment in Openshift') {
      //input message: "Deploy Image to Openshift?", ok: "Deploy"
      withCredentials([
        [$class: 'UsernamePasswordMultiBinding', credentialsId: osCredentialId, usernameVariable: 'OS_USERNAME', passwordVariable: 'OS_PASSWORD'],
        [$class: 'UsernamePasswordMultiBinding', credentialsId: nexusCredentialId, usernameVariable: 'NEXUS_USERNAME', passwordVariable: 'NEXUS_PASSWORD']
      ]) {
        sh """
          ${oc} login ${osHost} --username=${env.OS_USERNAME} --password=${env.OS_PASSWORD} --insecure-skip-tls-verify
        """

        try {
          sh """
            ${oc} project ${env.BUILD_USER_ID}
          """         
        } catch (Exception e) {
          sh """
            ${oc} new-project ${env.BUILD_USER_ID} --display-name="${env.BUILD_USER_ID}'s Development Environment"
            ${oc} secrets new-dockercfg "nexus-${env.BUILD_USER_ID}" --docker-server=${nexusRegistry} \
              --docker-username="${env.NEXUS_USERNAME}" --docker-password="${env.NEXUS_PASSWORD}" --docker-email="docker@gitook.com"
            ${oc} secrets link default "nexus-${env.BUILD_USER_ID}" --for=pull
            ${oc} secrets link builder "nexus-${env.BUILD_USER_ID}" --for=pull
            ${oc} secrets link deployer "nexus-${env.BUILD_USER_ID}" --for=pull
          """                
        }
        sh """
          ${oc} process -f ${devTemplate} | ${oc} create -f - -n ${env.BUILD_USER_ID} || true
          ${oc} tag --source=docker ${nexusRegistry}/<%= @app_name %>:${IMAGE_TAG} ${env.BUILD_USER_ID}/<%= @app_name %>-is:latest --insecure
          sleep 5
          ${oc} import-image <%= @app_name %>-is --confirm --insecure | grep -i "successfully"

          echo "Liveness check URL: http://`${oc} get route <%= @app_name %>-rt -n ${env.BUILD_USER_ID} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
        """
      }
    }

    stage('API/Intgration Testing') {
/*    
      timeout (time: 5, unit: 'MINUTES') {
        sh """
          REVAL=1
          while [ \$REVAL ]
          do
            sleep 10
            curl -I "http://`${oc} get route hello10-rt -n ${env.BUILD_USER_ID} -o jsonpath='{ .spec.host }'`/hello-world" | grep "HTTP/1.1 200"
            REVAL=\$?
          done
        """
      }
*/
    }

    stage('Performance Testing - jMeter') {
      dir("${env.WORKSPACE}") {
        echo "jMeter..."
      }
    }

    stage ('Destroy FT Environment in Openshift') {
      //input message: "Delete Openshift Environment(Cleanup)?", ok: "Delete"

      withCredentials([
        [$class: 'UsernamePasswordMultiBinding', credentialsId: osCredentialId, usernameVariable: 'OS_USERNAME', passwordVariable: 'OS_PASSWORD']
      ]) {
        sh """
          ${oc} login ${osHost} --username=${env.OS_USERNAME} --password=${env.OS_PASSWORD} --insecure-skip-tls-verify
          ${oc} delete project ${env.BUILD_USER_ID}
          ${oc} logout
        """
      }
    }

    stage('Merge CI Branch to Master') {
       withCredentials([
        [$class: 'UsernamePasswordMultiBinding', credentialsId: gitCredentialId, usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD']
      ]) {
        dir("${env.WORKSPACE}") {
          sh """
            git remote set-url origin "https://${env.GIT_USERNAME}:${env.GIT_PASSWORD}@github.com/${env.GIT_USERNAME}/<%= @app_name %>.git"
            git push origin HEAD:master
          """
        }
      }
    }

  }
}
