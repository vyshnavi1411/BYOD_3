pipeline {
    agent any

    environment {
        // Terraform
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'

        // Disable SSH host key checking for automation
        ANSIBLE_HOST_KEY_CHECKING = 'False'

        // SSH credential ID
        SSH_CRED_ID = 'My_SSH'

        // Tool paths
        PATH = "/Users/vyshu/Library/Python/3.12/bin:/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
    }

    stages {

        /* =========================
           Terraform Apply
           ========================= */
        stage('Terraform Apply') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'AWS_CREDS']
                ]) {
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

                        echo "EC2 INSTANCE ID : ${env.INSTANCE_ID}"
                        echo "EC2 PUBLIC IP  : ${env.INSTANCE_IP}"
                    }
                }
            }
        }

        /* =========================
           Dynamic Inventory
           ========================= */
        stage('Create Dynamic Inventory') {
            steps {
                sh '''
                echo "[splunk]" > dynamic_inventory.ini
                echo "${INSTANCE_IP} ansible_user=ec2-user" >> dynamic_inventory.ini
                '''
            }
        }

        /* =========================
           Wait for EC2 Health
           ========================= */
        stage('Wait for EC2 Health') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'AWS_CREDS']
                ]) {
                    sh '''
                    aws ec2 wait instance-status-ok \
                      --instance-ids ${INSTANCE_ID} \
                      --region us-east-1
                    '''
                }
            }
        }

        /* =========================
           Wait for SSH
           ========================= */
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

        /* =========================
           Install Splunk
           ========================= */
        stage('Install Splunk') {
            steps {
                sshagent([SSH_CRED_ID]) {
                    sh '''
                    ansible-playbook playbooks/splunk.yml \
                      -i dynamic_inventory.ini \
                      -u ec2-user \
                      --ssh-common-args="-o StrictHostKeyChecking=no"
                    '''
                }
            }
        }

        /* =========================
           Verify Splunk
           ========================= */
        stage('Verify Splunk') {
            steps {
                sshagent([SSH_CRED_ID]) {
                    sh '''
                    ansible-playbook playbooks/test-splunk.yml \
                      -i dynamic_inventory.ini \
                      -u ec2-user \
                      --ssh-common-args="-o StrictHostKeyChecking=no"
                    '''
                }
            }
        }

        /* =========================
           Manual Destroy Approval
           ========================= */
        stage('Validate Destroy') {
            steps {
                input message: "Infrastructure ready. Destroy now?", ok: "Destroy"
            }
        }

        /* =========================
           Terraform Destroy
           ========================= */
        stage('Terraform Destroy') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'AWS_CREDS']
                ]) {
                    sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars"
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f dynamic_inventory.ini'
        }
        failure {
            withCredentials([
                [$class: 'AmazonWebServicesCredentialsBinding',
                 credentialsId: 'AWS_CREDS']
            ]) {
                sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars || true"
            }
        }
        aborted {
            withCredentials([
                [$class: 'AmazonWebServicesCredentialsBinding',
                 credentialsId: 'AWS_CREDS']
            ]) {
                sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars || true"
            }
        }
    }
}
