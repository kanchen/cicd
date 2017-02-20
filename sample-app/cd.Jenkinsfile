
properties([
  [$class: 'ParametersDefinitionProperty', parameterDefinitions: [
    [$class: 'StringParameterDefinition', defaultValue: '<%= @image_tag %>', description: 'The docker image tag', name: 'IMAGE_TAG'],
  ]]
])

node('master') {
  def oc = "oc"
  def osHost = "ocpc.gitook.com:8443"
  def osCredentialId = 'OpenshiftCredentialId'
  def gitUrl = 'https://github.com/AceInfoSolutions/DHS-TICSII-TechChallenge.git'
  def gitCredentialId = 'jenkinsGithubCredentialId'
  def nexusRegistry = "<%= @docker_registry %>"
  def nexusCredentialId = '41aebb46-b195-4957-bae0-78376aa149b0'
  def stagingProject = "staging"
  def productionProject = "production"
  def stagingTemplate = "CD/pipelines/<%= @app_name %>/staging-template.yaml"
  def productionTemplate = "CD/pipelines/<%= @app_name %>/prod-template.yaml"
  def green = "a"
  def blue = "b"
  def userInput
  def blueWeight
  def greenWeight
  def abDeployment = false

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
          ${oc} secrets new-dockercfg "nexus-${stagingProject}" --docker-server=${nexusRegistry} \
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
          ${oc} secrets new-dockercfg "nexus-${productionProject}" --docker-server=${nexusRegistry} \
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

        ${oc} tag --source=docker <%= @docker_registry%>/<%= @app_name %>:${IMAGE_TAG} ${stagingProject}/<%= @app_name %>-is:latest --insecure
        sleep 5
        ${oc} import-image <%= @app_name %>-is --confirm --insecure | grep -i "successfully"

        echo "Liveness check URL: http://`oc get route <%= @app_name %>-rt -n ${stagingProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
      """
    }
  }

  stage ('ZDD Production Deployment') {
    userInput = input(
       id: 'userInput', message: 'ZDD A/B deployment or ZDD Rolling deployment?', parameters: [
        [$class: 'ChoiceParameterDefinition', choices: 'ZDD A/B deployment\nZDD Rolling Deployment', description: 'ZDD A/B(inlcuding Blue/Green) Deployment or ZDD Rolling Deployment', name: 'DEPLOYMENT_TYPE'],
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
          ${oc} tag --source=docker <%= @docker_registry%>/<%= @app_name %>:${IMAGE_TAG} ${productionProject}/${blue}-<%= @app_name %>-is:latest --insecure
          sleep 5
          ${oc} import-image ${blue}-<%= @app_name %>-is --confirm --insecure -n ${productionProject} | grep -i "successfully"
          ${oc} set -n ${productionProject} route-backends ab-<%= @app_name %>-rt ${blue}-<%= @app_name %>-svc=100 ${green}-<%= @app_name %>-svc=0
          echo "Application liveness check URL: http://`oc get route ab-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
        """
      } else {
        abDeployment = true
        sh """
          ${oc} tag --source=docker <%= @docker_registry%>/<%= @app_name %>:${IMAGE_TAG} ${productionProject}/${green}-<%= @app_name %>-is:latest --insecure
          sleep 5
          ${oc} import-image ${green}-<%= @app_name %>-is --confirm --insecure -n ${productionProject} | grep -i "successfully"
          echo "Green liveness check URL: http://`oc get route ${green}-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
        """
      }
    }
  }
  if (abDeployment) {
    stage ('Production ZDD Canary Deployment') {
      userInput = input(
       id: 'userInput', message: 'Production ZDD Canary Deployment?', parameters: [
          [$class: 'StringParameterDefinition', defaultValue: '10', description: 'Green(Newly deployed) weight', name: 'GREEN_WEIGHT'],
          [$class: 'StringParameterDefinition', defaultValue: '90', description: 'Blue(Existing deployment) weight', name: 'BLUE_WEIGHT'],
         ])
      blueWeight = userInput['BLUE_WEIGHT']
      greenWeight = userInput['GREEN_WEIGHT']
      withCredentials([
        [$class: 'UsernamePasswordMultiBinding', credentialsId: osCredentialId, usernameVariable: 'OS_USERNAME', passwordVariable: 'OS_PASSWORD']
      ]) {
        sh """
          ${oc} login ${osHost} -n ${productionProject} --username=${env.OS_USERNAME} --password=${env.OS_PASSWORD} --insecure-skip-tls-verify
          ${oc} set -n ${productionProject} route-backends ab-<%= @app_name %>-rt ${green}-<%= @app_name %>-svc=${greenWeight} ${blue}-<%= @app_name %>-svc=${blueWeight}
          echo "Green liveness check URL: http://`oc get route ${green}-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
          echo "Blue liveness check URL: http://`oc get route ${blue}-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
          echo "Application liveness check URL: http://`oc get route ab-<%= @app_name %>-rt -n ${productionProject} -o jsonpath='{ .spec.host }'`<%= @liveness_path %>"
        """
      }
    }

    stage ('Production ZDD Go Live or Rollback') {
      userInput = input(
         id: 'userInput', message: 'Production ZDD Go Live or ZDD Rollback?', parameters: [
          [$class: 'ChoiceParameterDefinition', choices: 'ZDD Go Live\nZDD Rollback', description: 'ZDD Go Live to Green or ZDD Rollback to Blue', name: 'GO_LIVE_OR_ROLLBACK'],
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
}
