
properties([
  [$class: 'ParametersDefinitionProperty', parameterDefinitions: [
    [$class: 'ChoiceParameterDefinition', choices: 'Java-SpringBoot\nNodeJS\nRails\nGo', description: 'The application type', name: 'APP_TYPE'],
    [$class: 'StringParameterDefinition', defaultValue: 'myservice', description: 'The application and docker image name', name: 'APP_NAME'],
    [$class: 'StringParameterDefinition', defaultValue: '9000', description: 'The TCP port application running', name: 'APP_PORT'],
    [$class: 'StringParameterDefinition', defaultValue: '512Mi', description: 'The memory limit allocated to the running application', name: 'MEMORY_LIMIT'],
    [$class: 'StringParameterDefinition', defaultValue: '/myservice', description: 'The application health check URL', name: 'HEALTH_CHECK_URL'],
    [$class: 'StringParameterDefinition', defaultValue: 'latest', description: 'The default docker image tag', name: 'IMAGE_TAG'],
  ]]
])

//    [$class: 'StringParameterDefinition', defaultValue: '/myservice', description: 'The path to check for application liveness', name: 'f'],
//    [$class: 'StringParameterDefinition', defaultValue: '/myservice', description: 'The path to check application readiness', name: 'READINESS_PATH'],

node('master') {
  currentBuild.displayName = "${BUILD_NUMBER}-${APP_NAME}"
  currentBuild.description = "Aceinfo Automation: Self CICD Pipeline"
  def gitUrl = 'https://github.com/aceinfo-jenkins/CicdSelfService.git'
  def gitCredentialId = 'jenkinsGithubCredentialId'
  def dockerUrl = "nexus.gitook.com:8447"
  def dockerRepo = "demouser"

  stage ('Pull template from repo') {
    step([$class: 'WsCleanup', notFailBuild: true])
    checkout([$class: 'GitSCM',
      branches: [[name: '*/master']],
      doGenerateSubmoduleConfigurations: false,
      extensions: [],
      submoduleCfg: [],
      userRemoteConfigs: [[credentialsId: gitCredentialId, url: "${gitUrl}"]]
    ])
  }

  stage ('Create new app in GIT repo') {
    withCredentials([
      [$class: 'UsernamePasswordMultiBinding', credentialsId: gitCredentialId, usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD']
    ]) {
      def args = "app_name=${APP_NAME} docker_registry_url=${dockerUrl} docker_registry_repo=${dockerRepo} \
      app_port=${APP_PORT} git_organization=${env.GIT_USERNAME} memory_limit=${MEMORY_LIMIT} liveness_path=${HEALTH_CHECK_URL} readiness_path=${HEALTH_CHECK_URL} image_tag=${IMAGE_TAG}"

      dir("${env.WORKSPACE}") {
        sh """
          curl https://api.github.com/repos/aceinfo-jenkins/${APP_NAME} | grep  "Not Found" || (echo "Github repo: ${APP_NAME} exists" && exit 1)
          mkdir -p generated
          ruby ${env.WORKSPACE}/copy.rb repo-template.erb generated/${APP_NAME}-repo.json ${args}
          curl -u "${env.GIT_USERNAME}:${env.GIT_PASSWORD}" https://api.github.com/user/repos -d @"generated/${APP_NAME}-repo.json"
        """
      }

      dir("${env.WORKSPACE}") {
        sh """
          mkdir ${APP_NAME}-repo
          cd ${APP_NAME}-repo
          git clone https://${env.GIT_USERNAME}:${env.GIT_PASSWORD}@github.com/${env.GIT_USERNAME}/${APP_NAME}.git

          ruby ${env.WORKSPACE}/copy.rb ${env.WORKSPACE}/sample-app ${APP_NAME} ${args}
          chmod 755 ${APP_NAME}/gradle ${APP_NAME}/gradlew

          ruby ${env.WORKSPACE}/copy.rb ${env.WORKSPACE}/templates/ocpc-template.yaml ${APP_NAME}/templates/testing-template.yaml ${args} environment=testing
          ruby ${env.WORKSPACE}/copy.rb ${env.WORKSPACE}/templates/ocpc-template.yaml ${APP_NAME}/templates/staging-template.yaml ${args} environment=staging
          ruby ${env.WORKSPACE}/copy.rb ${env.WORKSPACE}/templates/ab-template.yaml ${APP_NAME}/templates/production-template.yaml ${args} environment=production
          ruby ${env.WORKSPACE}/copy.rb ${env.WORKSPACE}/sample-app/ci.Jenkinsfile ${APP_NAME}/ci.Jenkinsfile ${args}
          ruby ${env.WORKSPACE}/copy.rb ${env.WORKSPACE}/sample-app/cd.Jenkinsfile ${APP_NAME}/cd.Jenkinsfile ${args}

          cd ${APP_NAME}
          git add --all ./*
          git diff --quiet --exit-code --cached || git commit -m "AceInfozen Automation"
          #git remote rm origin
          #git remote add origin "https://${env.GIT_USERNAME}:${env.GIT_PASSWORD}@github.com/${env.GIT_USERNAME}/${APP_NAME}.git"
          git push origin master
          git checkout -b CI-${APP_NAME}
          git push origin CI-${APP_NAME}
        """
      }
    }
  }

  stage ('Create CICD Pipelines') {
    jobDsl scriptText: """
      pipelineJob("${APP_NAME}-Continuous-Integration(CI)") {
        definition {
          cpsScm {
            scriptPath("ci.Jenkinsfile")
            scm {
              git {
                remote {
                  url("https://github.com/aceinfo-jenkins/${APP_NAME}.git")
                  credentials("${gitCredentialId}")
                  branch("master")
                }
              }
            }
          }
        }
      }
    """

    jobDsl scriptText: """
      pipelineJob("${APP_NAME}-Continuous-Delivery(CD)") {
        definition {
          cpsScm {
            scriptPath("cd.Jenkinsfile")
            scm {
              git {
                remote {
                  url("https://github.com/aceinfo-jenkins/${APP_NAME}.git")
                  credentials("${gitCredentialId}")
                  branch("master")
                }
              }
            }
          }
        }
      }
    """
  }

  stage ('Invoke CICD Pipelines') {
    sleep 10;
    try {
      // load the parameteres
      build job: "${APP_NAME}-Continuous-Integration(CI)"
    } catch (Exception e) {
      sleep 5;
      build job: "${APP_NAME}-Continuous-Integration(CI)", parameters: [[$class: 'StringParameterValue', name: 'GIT_BRANCH', value: "CI-${APP_NAME}"]], wait: false
      echo "${APP_NAME} CI pipeline: ${APP_NAME}-Continuous-Integration(CI) created."
    }

    try {
      // load the parameteres
      build job: "${APP_NAME}-Continuous-Delivery(CD)"
    } catch (Exception e) {
      sleep 5;
      echo "${APP_NAME} CD pipeline: ${APP_NAME}-Continuous-Delivery(CD) created."
    }
  }

}
