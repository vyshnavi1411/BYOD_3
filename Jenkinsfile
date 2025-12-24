pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'

        AWS_CREDS   = credentials('AWS_CREDS')
        SSH_CRED_ID = 'My_SSH'
        PATH = "/Users/vyshu/Library/Python/3.12/bin:/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
    }

    stages {
        stage('Terraform Apply') {
            steps {
                script {
                    sh "terraform init"
                    sh "terraform apply -auto-approve -var-file=${BRANCH_NAME}.tfvars"

                    env.INSTANCE_ID = sh(
                        script: 'terraform output -raw instance_id',
                        returnStdout: true
                    ).trim()

                    env.INSTANCE_IP = sh(
                        script: 'terraform output -raw instance_public_ip',
                        returnStdout: true
                    ).trim()

                    if (!env.INSTANCE_ID.startsWith("i-")) {
                        error "Invalid INSTANCE_ID captured: ${env.INSTANCE_ID}"
                    }

                    echo "EC2 INSTANCE ID: ${env.INSTANCE_ID}"
                    echo "EC2 PUBLIC IP : ${env.INSTANCE_IP}"
                }
            }
        }
        stage('Create Dynamic Inventory') {
            steps {
                sh '''
                echo "[splunk]" > dynamic_inventory.ini
                echo "${INSTANCE_IP} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/mykey.pem" >> dynamic_inventory.ini
                '''
            }
        }

        /* =========================
           AWS Health Check
           ========================= */
        stage('Wait for EC2 Health') {
            steps {
                sh '''
                aws ec2 wait instance-status-ok \
                  --instance-ids ${INSTANCE_ID} \
                  --region us-east-1
                '''
            }
        }

        stage('Validate Destroy') {
            steps {
                input message: 'Do you want to destroy the infrastructure?', ok: 'Destroy'
            }
        }
        stage('Terraform Destroy') {
            steps {
                sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars"
            }
        }
    }

    post {
        always {
            sh 'rm -f dynamic_inventory.ini'
        }
    }
}
