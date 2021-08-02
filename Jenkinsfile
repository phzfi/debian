def CHANGELOG
def PROJECT_NAME = "ubuntu32"
def SLACK_CHANNEL = "#infra"
pipeline {
  agent {
    label 'vagrant'
  }

  environment {
    BRANCH_NAME = "${GIT_BRANCH}"
    BUILD_ENV = [master: 'prod', develop: 'stg'].get(GIT_BRANCH, 'dev')
    VERSION = "${currentBuild.number}"
    SERVICE_NAME = "${PROJECT_NAME}-${BUILD_ENV}"
  }

  options {
    ansiColor('xterm')
    gitLabConnection('ubuntu32')
    //skipDefaultCheckout(true)
  }

  triggers {
    gitlab(triggerOnPush: true, triggerOnMergeRequest: true, branchFilterType: 'All')
  }

  stages {
    stage("Clean") {
      steps {
        step([$class: 'GameDescriptor'])
        script {
          echo "Parse changelog"
/*
          def changeLogSets = currentBuild.rawBuild.changeSets
          CHANGELOG = ""
          for (int i = 0; i < changeLogSets.size(); i++) {
            def entries = changeLogSets[i].items
            for (int j = 0; j < entries.length; j++) {
              def entry = entries[j]
              CHANGELOG = CHANGELOG + "${entry.author}: ${entry.msg}\n"
            }
          }

          //prevent Jenkins double builds, check if changelog is empty, skip
          if (CHANGELOG && CHANGELOG.trim().length() == 0) {
            currentBuild.result = 'SUCCESS'
            return
          }
*/
        }
        echo "Changelog:\n${CHANGELOG}"
        sh "./down.sh || true"
        sh "./clean.sh"
        sh "sudo chown -R jenkins:jenkins ."

        echo "Debug branch name"
        echo "env.gitlabBranch: " + env.gitlabBranch
        echo "scm.branches[0].name: " + scm.branches[0].name
        echo "{GIT_BRANCH}: " + "${GIT_BRANCH}"
        echo "BRANCH_NAME is set to: " + "${BRANCH_NAME}"

        checkout scm
        updateGitlabCommitStatus name: 'Clean', state: 'success'
      }
    }

    stage("Provision") {
      steps {
        echo "Provision Branch ${BRANCH_NAME} with Env ${BUILD_ENV}"
        timeout(30) {
          sh "./up.sh"
        }

        updateGitlabCommitStatus name: 'Provision', state: 'success'
      }
    }

    stage("Build & Publish") {
      when {
        expression {[master: true, develop: true].get(BRANCH_NAME, false)}
      }
      steps {
        withCredentials([
          [$class: 'UsernamePasswordMultiBinding', credentialsId: 'DOCKER_HUB', usernameVariable: 'DOCKER_HUB_USERNAME', passwordVariable: 'DOCKER_HUB_PASSWORD']
        ]) {
          timeout(400) {
            sh script:"vagrant ssh -c 'sudo /vagrant/docker/build.sh bionic ${VERSION} ${DOCKER_HUB_USERNAME} ${DOCKER_HUB_PASSWORD}'", returnStatus:true
          }
        }

        updateGitlabCommitStatus name: 'Build & Publish', state: 'success'
      }
    }

    stage("Quality") {
      steps {
        echo "Running Code Quality checks"
        timeout(15) {
          sh script:"docker-compose up", returnStatus:true
          //sh script:"docker-compose run web syntax-check.sh", returnStatus:true
        }

        updateGitlabCommitStatus name: 'Quality', state: 'success'
      }
    }

    stage("Unit Test") {
      steps {
        echo "Running unit tests"       
        timeout(15) {
          //Suppress the exit code so that Jenkins can report the number of failures or mark the build unstable
          sh "docker-compose run app /tmp/test.sh2ju || true"
          junit 'reports/TEST-default.xml'
        }

        updateGitlabCommitStatus name: 'Unit Test', state: 'success'
      }
    }

    stage("Acceptance Test") {
      when {
        expression {[master: true, develop: true].get(BRANCH_NAME, false)}
      }
      steps {
        echo "Running Acceptance Tests"
//        build job: 'another-job', propagate: false

        updateGitlabCommitStatus name: 'Acceptance Test', state: 'success'
      }
    }


  }

  post {
    always {
      script {
        //sh "./down.sh || true"
        sh "sudo chown -R jenkins:jenkins ."
      }
    }
    success {
      script {
        if ([master: true, develop: true].get(BRANCH_NAME, false)) {
          //TODO fatal: could not read Username for 'http://git.in.phz.fi': No such device or address
          //sh "git tag -a -m \"${env.BUILD_ENV}-${env.BUILD_NUMBER}\" ${env.BUILD_ENV}-${env.BUILD_NUMBER}"
          //sh "git push --tags"

          //slackSend channel: "${SLACK_CHANNEL}", color: "green", message: "${PROJECT_NAME} ${env.BUILD_ENV}-${env.BUILD_NUMBER} build succeeded! Please download container for Smoke Testing: ${PROJECT_LOCATION}). After Smoke Tests (see README.md #4.1), please Add Reaction thumbsup or thumbsdown depending whether Smoke Test cases pass or not.\n${CHANGELOG}", notifyCommitters: true
        }
      }
    }
    unstable {
        slackSend channel: "${SLACK_CHANNEL}", color: "yellow", message: "UNSTABLE: ${PROJECT_NAME} ${env.BUILD_ENV}-${env.BUILD_NUMBER} See (${env.RUN_DISPLAY_URL}) - more unit tests and code coverage needed for branch ${BRANCH_NAME}", notifyCommitters: true

        emailext (
          subject: "Unstable: ${PROJECT_NAME} ${env.BUILD_ENV}-${env.BUILD_NUMBER}",
          body: """${PROJECT_NAME} build become unstable (test coverage is not enough): '${env.BUILD_ENV}-${env.BUILD_NUMBER}':
            Check console output at &QUOT;<a href='${env.BUILD_URL}'>${env.BUILD_ENV}-${env.BUILD_NUMBER}</a>&QUOT;""",
          recipientProviders: [[$class: 'DevelopersRecipientProvider']]
        )
    }
    failure {
        slackSend channel: "${SLACK_CHANNEL}", color: "red", message: "FAIL: ${PROJECT_NAME} ${env.BUILD_ENV}-${env.BUILD_NUMBER} See (${env.RUN_DISPLAY_URL}) for the reason and please fix the branch ${BRANCH_NAME} and code to pass again", notifyCommitters: true

        emailext (
          subject: "FAIL: ${PROJECT_NAME} ${env.BUILD_ENV}-${env.BUILD_NUMBER}",
          body: """${PROJECT_NAME} build failed: '${env.JOB_NAME} [${env.BUILD_NUMBER}]':
            Check console output at &QUOT;<a href='${env.BUILD_URL}'>${env.BUILD_ENV}-${env.BUILD_NUMBER}</a>&QUOT;""",
          recipientProviders: [[$class: 'DevelopersRecipientProvider']]
        )
    }
  }
}

