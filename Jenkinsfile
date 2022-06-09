// **Comment: Make groovyscript available for all stages.
def gv

currentBuild.displayName = "todo-#"+currentBuild.number

pipeline {

  agent none

  // Set pipeline parameters.
  parameters {
    // **Comment: This allows you to enter a string during a manual run.
    string(name: 'someString', defaultValue: '', description: 'a string value useful to the build; exposed as $someString')
    choice(name: 'version', choices: ['1.1', '1.2', '1.3'], description: 'choose a version')
    booleanParam(name: 'executeTests', defaultValue: true, description: '')
  }

  // Set pipeline options.
  options {
    buildDiscarder(logRotator(numToKeepStr: '3'))
    // **Comment: If you want each run to have its own workspace.
    // checkoutToSubdirectory("${env.BUILD_ID}")
  }

  // Set environment variables.
  environment {
    // **Comment: Built in variables list here http://jenkins:8080/env-vars.html.
    APP_VERSION =           "211012-1508" // **Comment: ALWAYS UPDATE THIS VERSION NUMBER TO TRACK CHANGES; THIS IS TAGGED TO THE DOCKER IMAGE.
    APP_NAME =              "todo"
    CLUSTER_NAME =          "sz-211008-0911"
    PROJECT_ID =            "devops-211008"
    CREDENTIALS_TERRAFORM = credentials('gcp-terraform')
    CREDENTIALS_MYSQL =     credentials('MYSQL_PASSWORD')
    IMAGE_TAG =             "rhod3rz/${APP_NAME}:${APP_VERSION}-${env.BRANCH_NAME}"
    LOCATION =              "europe-west1-b"
  }

  stages {

    // Initialise the pipeline.
    stage('initialise') {
      agent any
      steps {
        step([$class: 'WsCleanup']) // **Comment: Clean workspace so nothing is cached.
        checkout scm // **Comment: Checkout from git again, as previous step cleaned workspace.
        script {
          gv = load "./groovy/script.groovy" // **Comment: Load groovy script; this makes it available to all stages.
          gv.initApp()
        }
        // input "Pause for Input"
      }
    }

    // Build the apps and push to dockerhub.
    stage('docker build & publish') {
      steps {
        script {
          docker.withRegistry('https://index.docker.io/v1/', 'dockerlogin') {
            def dockerImage = docker.build("${IMAGE_TAG}", "./")
            dockerImage.push()
            if (env.BRANCH_NAME == 'prd') {
              dockerImage.push("latest")
            }
          }
        }
      }
    }

    // Terraform 'apply' the google cloud infrasturcture.
    stage('terraform') {

      parallel {

        // # Apply terraform on prd-stg.
        stage('prd-stg') {
          agent {
            docker {
              image 'hashicorp/terraform:1.0.7'
              args '--entrypoint='
            }
          }
          when {
            anyOf {
              branch 'prd'
              branch 'stg'
            }
          }
          stages {
            stage('plan') {
              steps {
                dir('terraform/env/prd') {                                                // **Comment: Change working directory to ./terraform/env/prd.
                  sh 'sed -i.bak "s#../../../secrets/##" main.tf'                         // **Comment: Update path to 'sa-terraform-211008.json' from local testing.
                  sh 'echo $CREDENTIALS_TERRAFORM | base64 -d > sa-terraform-211008.json' // **Comment: Create sa-terraform-211008.json in working directory.
                  sh 'terraform init -no-color'
                  sh 'terraform plan -no-color -out tfplan'
                  sh 'terraform show -no-color tfplan > tfplan.txt'
                  archiveArtifacts artifacts: 'tfplan.txt'
                }
              }
            }
            stage('approve') {
              steps {
                script {
                  def plan = readFile './terraform/env/prd/tfplan.txt'
                  input message: "Do you want to apply the plan?", parameters: [text(name: 'Plan', description: 'Please review the plan', defaultValue: plan)]
                }
              }
            }
            stage('apply') {
              steps {
                dir('terraform/env/prd') {
                  sh 'terraform apply -input=false -no-color tfplan'
                  archiveArtifacts artifacts: 'kubeconfig-prd'
                }
              }
            }
          }
        }

        // # Apply terraform on dev.
        stage('dev') {
          agent {
            docker {
              image 'hashicorp/terraform:1.0.7'
              args '--entrypoint='
            }
          }
          when { // **Comment: Note, adding 'when' here introduced an intermittent bug in BlueOcean showing status' as skipped, when they had run.
            not {
              anyOf {
                branch 'prd'
                branch 'stg'
              }
            }
          }
          stages {
            stage('plan') {
              steps {
                dir('terraform/env/dev') {                                                // **Comment: Change working directory to ./terraform/env/dev.
                  sh 'sed -i.bak "s#../../../secrets/##" main.tf'                         // **Comment: Update path to 'sa-terraform-211008.json' from local testing.
                  sh 'echo $CREDENTIALS_TERRAFORM | base64 -d > sa-terraform-211008.json' // **Comment: Create sa-terraform-211008.json in working directory.
                  sh 'terraform init -no-color'
                  sh 'terraform plan -no-color -out tfplan'
                  sh 'terraform show -no-color tfplan > tfplan.txt'
                  archiveArtifacts artifacts: 'tfplan.txt'
                }
              }
            }
            stage('approve') {
              steps {
                script {
                  def plan = readFile './terraform/env/dev/tfplan.txt'
                  input message: "Do you want to apply the plan?", parameters: [text(name: 'Plan', description: 'Please review the plan', defaultValue: plan)]
                }
              }
            }
            stage('apply') {
              steps {
                dir('terraform/env/dev') {
                  sh 'terraform apply -input=false -no-color tfplan'
                  archiveArtifacts artifacts: 'kubeconfig-dev'
                }
              }
            }
          }
        }
      }
    }

    // K8s deploy the apps.
    stage('kubernetes') {
      parallel {

        // Deploy app manifests to prd.
        stage('prd') {
          agent {
            dockerfile {
                filename 'dockerfile.googlesdk'
                dir 'agents'
                args '--entrypoint='
            }
          }
          when { branch 'prd' }
          environment {
            CLUSTER_NAME = "${CLUSTER_NAME}-prd"
          }
          steps {
            withCredentials([file(credentialsId: 'gcp-kubectl-cmd', variable: 'GC_KEY')]) {
              sh 'gcloud auth activate-service-account --key-file=${GC_KEY}'
              sh 'gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${LOCATION} --project ${PROJECT_ID}'
            }
            // db.yaml substitutions.
            sh "sed -i.bak 's#sub_mango#${IMAGE_TAG}#'         ./k8s/db.yaml"     // **Comment: Change 'Change Cause' meta data to build version; assists with rollback.
            sh "sed -i.bak 's#sub_apple#${CREDENTIALS_MYSQL}#' ./k8s/db.yaml"     // **Comment: Inject MySQL password from credential store.
            // todo-app.yaml substitutions.
            sh "sed -i.bak 's#sub_mango#${IMAGE_TAG}#'         ./k8s/prd/*.yaml"  // **Comment: Change 'Change Cause' meta data to build version; assists with rollback.
            sh "sed -i.bak 's#sub_apple#${CREDENTIALS_MYSQL}#' ./k8s/prd/*.yaml"  // **Comment: Inject MySQL password from credential store.
            sh "sed -i.bak 's#sub_peach#${IMAGE_TAG}#'         ./k8s/prd/*.yaml"  // **Comment: Change deployed image to the one we just built.
            // Create namespace and deploy manifests.
            sh "kubectl get ns todo || kubectl create ns todo"                    // **Comment: Create namespace if it doesn't exist.
            sh "kubectl apply -f ./k8s     --namespace=todo"                      // **Comment: Apply common yaml manifests.
            sh "kubectl apply -f ./k8s/prd --namespace=todo"                      // **Comment: Apply prd yaml manifests.
          }
        }

        // Deploy app manifests to dev.
        stage('dev') {
          agent {
            dockerfile {
                filename 'dockerfile.googlesdk'
                dir 'agents'
                args '--entrypoint='
            }
          }
          // Developer Branches
          when {
            not { branch 'stg' }
            not { branch 'prd' }
          }
          environment {
            CLUSTER_NAME = "${CLUSTER_NAME}-dev"
          }
          steps {
            withCredentials([file(credentialsId: 'gcp-kubectl-cmd', variable: 'GC_KEY')]) {
              sh 'gcloud auth activate-service-account --key-file=${GC_KEY}'
              sh 'gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${LOCATION} --project ${PROJECT_ID}'
            }
            // db.yaml substitutions.
            sh "sed -i.bak 's#sub_mango#${IMAGE_TAG}#'         ./k8s/db.yaml"     // **Comment: Change 'Change Cause' meta data to build version; assists with rollback.
            sh "sed -i.bak 's#sub_apple#${CREDENTIALS_MYSQL}#' ./k8s/db.yaml"     // **Comment: Inject MySQL password from credential store.
            // todo-app.yaml substitutions.
            sh "sed -i.bak 's#sub_mango#${IMAGE_TAG}#'         ./k8s/dev/*.yaml"  // **Comment: Change 'Change Cause' meta data to build version; assists with rollback.
            sh "sed -i.bak 's#sub_apple#${CREDENTIALS_MYSQL}#' ./k8s/dev/*.yaml"  // **Comment: Inject MySQL password from credential store.
            sh "sed -i.bak 's#sub_peach#${IMAGE_TAG}#'         ./k8s/dev/*.yaml"  // **Comment: Change deployed image to the one we just built.
            // Create namespace and deploy manifests.
            sh "kubectl get ns todo || kubectl create ns todo"                    // **Comment: Create namespace if it doesn't exist.
            sh "kubectl apply -f ./k8s     --namespace=todo"                      // **Comment: Apply common yaml manifests.
            sh "kubectl apply -f ./k8s/dev --namespace=todo"                      // **Comment: Apply dev yaml manifests.
          }
        }

        // Deploy app manifests to stg.
        stage('stg') {
          agent {
            dockerfile {
                filename 'dockerfile.googlesdk'
                dir 'agents'
                args '--entrypoint='
            }
          }
          when { branch 'stg' }
          environment {
            CLUSTER_NAME = "${CLUSTER_NAME}-prd"
          }
          steps {
            withCredentials([file(credentialsId: 'gcp-kubectl-cmd', variable: 'GC_KEY')]) {
              sh 'gcloud auth activate-service-account --key-file=${GC_KEY}'
              sh 'gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${LOCATION} --project ${PROJECT_ID}'
            }
            // todo-app.yaml substitutions.
            sh "sed -i.bak 's#sub_mango#${IMAGE_TAG}#'         ./k8s/stg/*.yaml"  // **Comment: Change 'Change Cause' meta data to build version; assists with rollback.
            sh "sed -i.bak 's#sub_apple#${CREDENTIALS_MYSQL}#' ./k8s/stg/*.yaml"  // **Comment: Inject MySQL password from credential store.
            sh "sed -i.bak 's#sub_peach#${IMAGE_TAG}#'         ./k8s/stg/*.yaml"  // **Comment: Change deployed image to the one we just built.
            // Create namespace and deploy manifests.
            sh "kubectl get ns todo || kubectl create ns todo"                    // **Comment: Create namespace if it doesn't exist.
            sh "kubectl apply -f ./k8s/stg --namespace=todo"                      // **Comment: Apply stg yaml manifests.
          }
        }

      }
    }
  }

  // post {
  //   always {
  //     echo 'This will always run'
  //   }
  //   success {
  //     echo 'This will run only if successful'
  //   }
  //   failure {
  //     echo 'This will run only if failed'
  //   }
  //   unstable {
  //     echo 'This will run only if the run was marked as unstable'
  //   }
  //   changed {
  //     echo 'This will run only if the state of the Pipeline has changed'
  //     echo 'For example, if the Pipeline was previously failing but is now successful'
  //   }
  //   cleanup {
  //     echo 'This will run after every other post condition has been evaluated, regardless of the Pipeline or stage’s status.'
  //     node(null) {
  //       deleteDir()
  //     }
  //   }
  // }
}
