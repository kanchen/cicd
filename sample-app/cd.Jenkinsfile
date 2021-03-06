
properties([
  [$class: 'ParametersDefinitionProperty', parameterDefinitions: [
    [$class: 'StringParameterDefinition', defaultValue: '<%= @image_tag %>', description: 'The docker image tag', name: 'IMAGE_TAG'],
  ]]
])

node('master') {
  def oc = "oc"
  def osHost = "ocpc.gitook.com:8443"
  def osCredentialId = 'OpenshiftCredentialId'
  def gitUrl = 'https://github.com/aceinfo-jenkins/<%= @app_name %>.git'
  def gitCredentialId = 'jenkinsGithubCredentialId'
  def dockerRegistry = "<%= @docker_registry_url %>/<%= @docker_registry_repo %>"
  def nexusCredentialId = '41aebb46-b195-4957-bae0-78376aa149b0'
  def stagingProject = "staging"
  def productionProject = "production"
  def stagingTemplate = "templates/staging-template.yaml"
  def productionTemplate = "templates/production-template.yaml"
  def green = "a"
  def blue = "b"
  def userInput
  def blueWeight
  def greenWeight
  def canaryDeployment = false

  try {
    notifyStarted()

    stage ('Preparation') {
      checkout([$class: 'GitSCM',
        branches: [[name: '*/master']],
        doGenerateSubmoduleConfigurations: false,
        extensions: [],
        submoduleCfg: [],
        userRemoteConfigs: [[credentialsId: gitCredentialId, url: gitUrl]]
      ])
    }

    stage ('Initializing OCP PAAS') {
      withCredentials([
        [$class: 'UsernamePasswordMultiBinding', credentialsId: osCredentialId, usernameVariable: 'OS_USERNAME', passwordVariable: 'OS_PASSWORD'],
        [$class: 'UsernamePasswordMultiBinding', credentialsId: nexusCredentialId, usernameVariable: 'NEXUS_USERNAME', passwordVariable: 'NEXUS_PASSWORD']
      ]) {
        sh """
          ${oc} login ${osHost} --username=${env.OS_USERNAME} --password=${env.OS_PASSWORD} --insecure-skip-tls-verify
        """
        try {
          sh """
            ${oc} project ${stagingProject}
          """         
        } catch (Exception e) {
          sh """
            ${oc} new-project ${stagingProject} --display-name="Staging Environment"
            ${oc} secrets new-dockercfg "nexus-${stagingProject}" --docker-server=${dockerRegistry} \
              --docker-username="${env.NEXUS_USERNAME}" --docker-password="${env.NEXUS_PASSWORD}" --docker-email="docker@gitook.com"
            ${oc} secrets link default "nexus-${stagingProject}" --for=pull
            ${oc} secrets link builder "nexus-${stagingProject}" --for=pull
            ${oc} secrets link deployer "nexus-${stagingProject}" --for=pull
          """                
        }

        try {
          sh """
            ${oc} project ${productionProject}
          """         
        } catch (Exception e) {
          sh """
            ${oc} new-project ${productionProject} --display-name="Production Environment"
            ${oc} secrets new-dockercfg "nexus-${productionProject}" --docker-server=${dockerRegistry} \
              --docker-username="${env.NEXUS_USERNAME}" --docker-password="${env.NEXUS_PASSWORD}" --docker-email="docker@gitook.com"
            ${oc} secrets link default "nexus-${productionProject}" --for=pull
            ${oc} secrets link builder "nexus-${productionProject}" --for=pull
            ${oc} secrets link deployer "nexus-${productionProject}" --for=pull
          """                
        }
      }
    }
    
    stage ('Staging Deployment') {
      withCredentials([
        [$class: 'UsernamePasswordMultiBinding', credentialsId: osCredentialId, usernameVariable: 'OS_USERNAME', passwordVariable: 'OS_PASSWORD'],
      ]) {
        sh """
          ${oc} login ${osHost} -n ${stagingProject} --username=${env.OS_USERNAME} --password=${env.OS_PASSWORD} --insecure-skip-tls-verify
          ${oc} process -f ${stagingTemplate} | ${oc} create -f - -n ${stagingProject} || true

          ${oc} tag --source=docker ${dockerRegistry}/<%= @app_name %>:${IMAGE_TAG} ${stagingProject}/<%= @app_name %>-is:latest --insecure
          sleep 5
          ${oc} import-image <%= @app_name %>-is --confirm --insecure | grep -i "successfully"

          echo "Liveness check URL: http://`oc get route <%= @app_name %>-rt -n ${stagingProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
        """
      }
    }

    stage('Staging Deployment Health Check') {
      def retstat = 1
      timeout (time: 5, unit: 'MINUTES') {
        for (;retstat != 0;) {
          retstat = sh(
            script: """
              curl -I "http://`oc get route <%= @app_name %>-rt -n ${stagingProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>" | grep "HTTP/1.1 200"
            """,
            returnStatus: true)

          if (retstat != 0) {
            sleep 10
          }
        }
      }

      if (retstat != 0) {
        echo "Health check to http://`oc get route <%= @app_name %>-rt -n ${stagingProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %> failed."
        sh exit ${retstat}
      }
    }

    stage ('ZDD Production Deployment') {
      userInput = input(
         id: 'userInput', message: 'ZDD Canary deployment or ZDD Rolling deployment?', parameters: [
          [$class: 'ChoiceParameterDefinition', choices: 'ZDD Canary deployment\nZDD Rolling Deployment', description: 'ZDD Canary Deployment or ZDD Rolling Deployment', name: 'DEPLOYMENT_TYPE'],
         ])
      withCredentials([
        [$class: 'UsernamePasswordMultiBinding', credentialsId: osCredentialId, usernameVariable: 'OS_USERNAME', passwordVariable: 'OS_PASSWORD']
      ]) {
        sh """
          ${oc} login ${osHost} -n ${productionProject} --username=${env.OS_USERNAME} --password=${env.OS_PASSWORD} --insecure-skip-tls-verify
          ${oc} process -f ${productionTemplate} | oc create -f - -n ${productionProject} || true

          ${oc} get route ab-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.to.name }' > active_service.txt
          cat active_service.txt
        """
        activeService = readFile('active_service.txt').trim()
        if (activeService == "a-<%= @app_name %>-svc") {
          blue = "a"
          green = "b"
        }

        if (userInput == "ZDD Rolling Deployment") {
          sh """
            ${oc} tag --source=docker ${dockerRegistry}/<%= @app_name %>:${IMAGE_TAG} ${productionProject}/${blue}-<%= @app_name %>-is:latest --insecure
            sleep 5
            ${oc} import-image ${blue}-<%= @app_name %>-is --confirm --insecure -n ${productionProject} | grep -i "successfully"
            ${oc} set -n ${productionProject} route-backends ab-<%= @app_name %>-rt ${blue}-<%= @app_name %>-svc=100 ${green}-<%= @app_name %>-svc=0
            echo "Application liveness check URL: http://`oc get route ab-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
          """
        } else {
          canaryDeployment = true
          sh """
            ${oc} tag --source=docker ${dockerRegistry}/<%= @app_name %>:${IMAGE_TAG} ${productionProject}/${green}-<%= @app_name %>-is:latest --insecure
            sleep 5
            ${oc} import-image ${green}-<%= @app_name %>-is --confirm --insecure -n ${productionProject} | grep -i "successfully"
            echo "Green liveness check URL: http://`oc get route ${green}-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
          """
        }
      }
    }

    stage('Production Deployment Health Check') {
      def retstat = 1
      def healthCheckUrl = "http://`oc get route ab-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
      if (canaryDeployment) {
         healthCheckUrl = "http://`oc get route ${green}-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
      }
      echo "Health chech URL: ${healthCheckUrl}"
      timeout (time: 5, unit: 'MINUTES') {
        for (;retstat != 0;) {
          retstat = sh(script: "curl -I ${healthCheckUrl} | grep \"HTTP/1.1 200\"", returnStatus: true)

          if (retstat != 0) {
            sleep 10
          }
        }
      }

      if (retstat != 0) {
        echo "Health check to ${healthCheckUrl} failed."
        sh exit ${retstat}
      }
    }


    if (canaryDeployment) {
      stage ('Production ZDD Canary Deployment') {
        userInput = input(
         id: 'userInput', message: 'Production ZDD Canary Deployment?', parameters: [
            [$class: 'StringParameterDefinition', defaultValue: '10', description: 'New deployment weight', name: 'NEW_WEIGHT'],
            [$class: 'StringParameterDefinition', defaultValue: '90', description: 'Existing deployment weight', name: 'EXISTING_WEIGHT'],
           ])
        blueWeight = userInput['EXISTING_WEIGHT']
        greenWeight = userInput['NEW_WEIGHT']
        withCredentials([
          [$class: 'UsernamePasswordMultiBinding', credentialsId: osCredentialId, usernameVariable: 'OS_USERNAME', passwordVariable: 'OS_PASSWORD']
        ]) {
          sh """
            ${oc} login ${osHost} -n ${productionProject} --username=${env.OS_USERNAME} --password=${env.OS_PASSWORD} --insecure-skip-tls-verify
            ${oc} set -n ${productionProject} route-backends ab-<%= @app_name %>-rt ${green}-<%= @app_name %>-svc=${greenWeight} ${blue}-<%= @app_name %>-svc=${blueWeight}
            echo "New deployment URL: http://`oc get route ${green}-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
            echo "Existing deployment URL: http://`oc get route ${blue}-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
            echo "Application advised URL: http://`oc get route ab-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
          """
        }
      }

      stage ('Production ZDD Go Live or Rollback') {
        userInput = input(
           id: 'userInput', message: 'Production ZDD Go Live or ZDD Rollback?', parameters: [
            [$class: 'ChoiceParameterDefinition', choices: 'ZDD Go Live\nZDD Rollback', description: 'ZDD Go Live to new deployment or ZDD Rollback to existing deployment', name: 'GO_LIVE_OR_ROLLBACK'],
           ])
        withCredentials([
          [$class: 'UsernamePasswordMultiBinding', credentialsId: osCredentialId, usernameVariable: 'OS_USERNAME', passwordVariable: 'OS_PASSWORD']
        ]) {
          sh """
            ${oc} login ${osHost} -n ${productionProject} --username=${env.OS_USERNAME} --password=${env.OS_PASSWORD} --insecure-skip-tls-verify
          """

          if (userInput == "ZDD Rollback") {
            sh """
              ${oc} set -n ${productionProject} route-backends ab-<%= @app_name %>-rt ${blue}-<%= @app_name %>-svc=100 ${green}-<%= @app_name %>-svc=0
            """              
          } else {
            sh """
              ${oc} set -n ${productionProject} route-backends ab-<%= @app_name %>-rt ${green}-<%= @app_name %>-svc=100 ${blue}-<%= @app_name %>-svc=0
            """                            
          }
        }
      }
    }

    notifySuccessful()

  } catch (e) {
    currentBuild.result = "FAILED"
    notifyFailed()
    throw e
  }
}

def notifyStarted() {
  // send to Slack
  slackSend (color: '#FFFF00', message: "STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")

  // send to HipChat
  //hipchatSend (color: 'YELLOW', notify: true,
  //    message: "STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
  //  )

  // send to email
  emailext (
      subject: "STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
      body: """<p>STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p>
        <p>Check console output at &QUOT;<a href='${env.BUILD_URL}'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>&QUOT;</p>""",
      recipientProviders: [[$class: 'DevelopersRecipientProvider']]
    )
}
def notifySuccessful() {
  slackSend (color: '#00FF00', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")

  //hipchatSend (color: 'GREEN', notify: true,
  //    message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
  //  )

  emailext (
      subject: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
      body: """<p>SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p>
        <p>Check console output at &QUOT;<a href='${env.BUILD_URL}'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>&QUOT;</p>""",
      recipientProviders: [[$class: 'DevelopersRecipientProvider']]
    )
}

def notifyFailed() {
  slackSend (color: '#FF0000', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")

  //hipchatSend (color: 'RED', notify: true,
  //    message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
  //  )

  emailext (
      subject: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
      body: """<p>FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p>
        <p>Check console output at &QUOT;<a href='${env.BUILD_URL}'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>&QUOT;</p>""",
      recipientProviders: [[$class: 'DevelopersRecipientProvider']]
    )
}
