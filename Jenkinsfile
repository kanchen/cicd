
properties([
  [$class: 'ParametersDefinitionProperty', parameterDefinitions: [
    [$class: 'ChoiceParameterDefinition', choices: 'Java-SpringBoot\nNodeJS\nRails\nGo', description: 'The application type', name: 'APP_TYPE'],
    [$class: 'StringParameterDefinition', defaultValue: 'myservice', description: 'The application and docker image name', name: 'APP_NAME'],
    [$class: 'StringParameterDefinition', defaultValue: '9000', description: 'The TCP port application running', name: 'APP_PORT'],
    [$class: 'StringParameterDefinition', defaultValue: '512Mi', description: 'The memory limit allocated to the running application', name: 'MEMORY_LIMIT'],
    [$class: 'StringParameterDefinition', defaultValue: '/myservice', description: 'The path to check for application liveness', name: 'LIVENESS_PATH'],
    [$class: 'StringParameterDefinition', defaultValue: '/myservice', description: 'The path to check application readiness', name: 'READINESS_PATH'],
    [$class: 'StringParameterDefinition', defaultValue: 'nexus.gitook.com:8447', description: 'The docker registry URL', name: 'DOCKER_REGISTRY_URL'],
    [$class: 'StringParameterDefinition', defaultValue: 'demouser', description: 'The docker repo', name: 'DOCKER_REGISTRY_REPO']
//    [$class: 'StringParameterDefinition', defaultValue: '1.0', description: 'The default docker image tag', name: 'IMAGE_TAG'],
  ]]
])

node('master') {
  currentBuild.displayName = "${BUILD_NUMBER}-${APP_NAME}"
  currentBuild.description = "Aceinfo Automation: Self CICD Pipeline"
  def gitUrl = 'github.com/AceInfoSolutions/DHS-TICSII-TechChallenge.git'
  def gitCredentialId = 'jenkinsGithubCredentialId'

  stage ('Pull template from repo') {
    step([$class: 'WsCleanup', notFailBuild: true])
    checkout([$class: 'GitSCM',
      branches: [[name: '*/master']],
      doGenerateSubmoduleConfigurations: false,
      extensions: [],
      submoduleCfg: [],
      userRemoteConfigs: [[credentialsId: gitCredentialId, url: "https://${gitUrl}"]]
    ])
  }

  stage ('Create new app in GIT repo') {
    withCredentials([
      [$class: 'UsernamePasswordMultiBinding', credentialsId: gitCredentialId, usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD']
    ]) {
      def args = "app_name=${APP_NAME} docker_registry_url=${DOCKER_REGISTRY_URL} docker_registry_repo=${DOCKER_REGISTRY_REPO}\
      app_port=${APP_PORT} git_organization=${env.GIT_USERNAME} memory_limit=${MEMORY_LIMIT} liveness_path=${LIVENESS_PATH} readiness_path=${READINESS_PATH}"

      dir("${env.WORKSPACE}") {
        sh """
          curl https://api.github.com/repos/aceinfo-jenkins/${APP_NAME} | grep  "Not Found" || (echo "Github repo: ${APP_NAME} exists" && exit 1)
          mkdir -p generated
          ruby ${env.WORKSPACE}copy.rb repo-template.erb generated/${APP_NAME}-repo.json ${args}
          curl -u "${env.GIT_USERNAME}:${env.GIT_PASSWORD}" https://api.github.com/user/repos -d @"generated/${APP_NAME}-repo.json"
        """
      }

      dir("${env.WORKSPACE}") {
        sh """
          mkdir ${APP_NAME}-repo
          cd ${APP_NAME}-repo
          git clone https://${env.GIT_USERNAME}:${env.GIT_PASSWORD}@github.com/${env.GIT_USERNAME}/${APP_NAME}.git

          ruby ${env.WORKSPACE}copy.rb ${env.WORKSPACE}/sample-app ${APP_NAME} ${args}
          chmod 755 ${APP_NAME}/gradle ${APP_NAME}/gradlew

          ruby ${env.WORKSPACE}copy.rb ${env.WORKSPACE}/templates/ocpc-template.yaml ${APP_NAME}/templates/testing-template.yaml ${args} environment=dev
          ruby ${env.WORKSPACE}copy.rb ${env.WORKSPACE}/templates/ocpc-template.yaml ${APP_NAME}/templates/staging-template.yaml ${args} environment=testing
          ruby ${env.WORKSPACE}copy.rb ${env.WORKSPACE}/templates/ocpc-template.yaml ${APP_NAME}/templates/staging-template.yaml ${args} environment=staging
          ruby ${env.WORKSPACE}copy.rb ${env.WORKSPACE}/templates/ab-template.yaml ${APP_NAME}/templates/production-template.yaml ${args} environment=production

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

  stage ('PrepareCICD Pipelines') {
    jobDsl scriptText: """
      pipelineJob("${APP_NAME}-Development") {
        definition {
          cpsScm {
            scriptPath("Jenkinsfile")
            scm {
              git {
                remote {
                  url("https://github.com/aceinfo-jenkins/${APP_NAME}.git")
                  credentials("${gitCredentialId}")
                  branch("CI-${APP_NAME}")
                }
              }
            }
          }
        }
        scm {
          git {
            remote {
                name('origin')
                url("https://github.com/aceinfo-jenkins/${APP_NAME}.git")
                credentials("${gitCredentialId}")
            }
            branch("CI-${APP_NAME}")
          }
        }
        triggers {
          cron('* * * * *')
        }
      }
    """

    jobDsl scriptText: """
      pipelineJob("${APP_NAME}-Development") {
        definition {
          cpsScm {
            scriptPath("Jenkinsfile")
            scm {
              git {
                remote {
                  url("https://github.com/aceinfo-jenkins/${APP_NAME}.git")
                  credentials("${gitCredentialId}")
                  branch("CI-${APP_NAME}")
                }
              }
            }
          }
        }
        scm {
          git {
            remote {
                name('origin')
                url("https://github.com/aceinfo-jenkins/${APP_NAME}.git")
                credentials("${gitCredentialId}")
            }
            branch("CI-${APP_NAME}")
          }
        }
        triggers {
          cron('* * * * *')
        }
      }
    """
  }

  stage ('Create CICD Pipeline') {
    sleep 10;
    try {
      // load the parameteres
      build job: "${APP_NAME}-Development"
    } catch (Exception e) {
      sleep 5;
      build job: "${APP_NAME}-Development", parameters: [[$class: 'StringParameterValue', name: 'GIT_BRANCH', value: "CI-${APP_NAME}"]]
      echo "Developer's application pipeline: ${APP_NAME}-Development created."
    }
  }


/*
  stage ('Build Application Pipeline') {
    sleep 10;
    try {
      // load the parameteres
      build job: "${APP_NAME}-Development"
    } catch (Exception e) {
      sleep 5;
      //starts the build
      build job: "${APP_NAME}-Development"
    }
  }
*/
}
