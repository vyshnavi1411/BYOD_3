pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
        
        // REVERTED: Using the single credential ID you confirmed worked before
        // This will automatically populate AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
        AWS_CREDS   = credentials('AWS_CREDS')
        
        SSH_CRED_ID = 'My_SSH'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        PATH = "/Users/vyshu/Library/Python/3.12/bin:/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
    }

    stages {
        stage('Terraform Apply') {
            steps {
                script {
                    sh "terraform init"
                    sh "terraform apply -auto-approve -var-file=${BRANCH_NAME}.tfvars"

                    env.INSTANCE_ID = sh(script: 'terraform output -raw instance_id', returnStdout: true).trim()
                    env.INSTANCE_IP = sh(script: 'terraform output -raw instance_public_ip', returnStdout: true).trim()

                    echo "EC2 INSTANCE ID : ${env.INSTANCE_ID}"
                    echo "EC2 PUBLIC IP  : ${env.INSTANCE_IP}"
                }
            }
        }

        stage('Create Dynamic Inventory') {
            steps {
                sh '''
                echo "[splunk]" > dynamic_inventory.ini
                echo "${INSTANCE_IP} ansible_user=ec2-user" >> dynamic_inventory.ini
                '''
            }
        }

        stage('Wait for EC2 Health') {
            steps {
                sh "aws ec2 wait instance-status-ok --instance-ids ${INSTANCE_ID} --region us-east-1"
            }
        }

        stage('Wait for SSH') {
            steps {
                sh '''
                for i in {1..10}; do
                  nc -z ${INSTANCE_IP} 22 && exit 0
                  echo "Waiting for SSH..."
                  sleep 15
                done
                exit 1
                '''
            }
        }

        stage('Install Splunk') {
            steps {
                sshagent([SSH_CRED_ID]) {
                    sh "ansible-playbook playbooks/splunk.yml -i dynamic_inventory.ini -u ec2-user --ssh-common-args='-o StrictHostKeyChecking=no'"
                }
            }
        }

        stage('Verify Splunk') {
            steps {
                sshagent([SSH_CRED_ID]) {
                    sh "ansible-playbook playbooks/test-splunk.yml -i dynamic_inventory.ini -u ec2-user --ssh-common-args='-o StrictHostKeyChecking=no'"
                }
            }
        }

        stage('Validate Destroy') {
            steps {
                input message: 'Do you want to destroy?', ok: 'Destroy'
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
            // Explicitly wrapping in node{} to fix the FilePath/Context error
            node {
                sh 'rm -f dynamic_inventory.ini'
            }
        }
        failure {
            node {
                // The '|| true' ensures the pipeline finishes even if destroy fails
                sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars || true"
            }
        }
    }
}