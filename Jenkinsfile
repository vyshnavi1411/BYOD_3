pipeline {
    agent any
    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'

        AWS_CREDS   = credentials('AWS_CREDS')
        SSH_CRED_ID = 'My_SSH'
    }
    triggers {
        githubPush()
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Terraform Init') {
            steps {
                echo "Initializing Terraform..."
                sh 'terraform init'

                echo "Displaying variable file for branch: ${BRANCH_NAME}"
                sh 'cat ${BRANCH_NAME}.tfvars'
            }
        }
        stage('Terraform Plan') {
            steps {
                echo "Running Terraform plan for branch: ${BRANCH_NAME}"
                sh "terraform plan -var-file=${BRANCH_NAME}.tfvars"
            }
        }
        stage('Validate Apply') {
            when {
                branch 'dev'
            }
            steps {
                input message: 'Do you want to apply this Terraform plan to DEV?', ok: 'Apply'
            }
        }
    }
}
