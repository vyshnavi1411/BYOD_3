pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
        AWS_CREDS   = credentials('AWS_CREDS')
        SSH_CRED_ID = 'My_SSH'
        PATH = "/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
    }

    stages {

        stage('Terraform Apply') {
            steps {
                script {
                    sh "terraform apply -auto-approve -var-file=${BRANCH_NAME}.tfvars"

                    env.INSTANCE_IP = sh(
                        script: 'terraform output -raw instance_public_ip',
                        returnStdout: true
                    ).trim()

                    env.INSTANCE_ID = sh(
                        script: 'terraform output -raw instance_id',
                        returnStdout: true
                    ).trim()

                    echo "EC2 IP: ${env.INSTANCE_IP}"
                    echo "EC2 ID: ${env.INSTANCE_ID}"
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

        stage('Wait for EC2 Health') {
            steps {
                sh '''
                aws ec2 wait instance-status-ok \
                  --instance-ids ${INSTANCE_ID} \
                  --region us-east-1
                '''
            }
        }

        stage('Install Splunk') {
            steps {
                ansiblePlaybook(
                    playbook: 'playbooks/splunk.yml',
                    inventory: 'dynamic_inventory.ini',
                    credentialsId: "${SSH_CRED_ID}"
                )
            }
        }

        stage('Test Splunk') {
            steps {
                ansiblePlaybook(
                    playbook: 'playbooks/test-splunk.yml',
                    inventory: 'dynamic_inventory.ini',
                    credentialsId: "${SSH_CRED_ID}"
                )
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
        failure {
            sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars || true"
        }
        aborted {
            sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars || true"
        }
    }
}
