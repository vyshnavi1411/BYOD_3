pipeline {
    agent any

    environment {
        // Terraform settings
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'

        // AWS Credentials - Using individual variables to avoid plugin warnings
        AWS_ACCESS_KEY_ID     = credentials('AWS_CREDS_KEY')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_CREDS_SECRET')
        
        // SSH Credential ID from Jenkins Global Credentials
        SSH_CRED_ID = 'My_SSH'

        // Ansible settings
        ANSIBLE_HOST_KEY_CHECKING = 'False'

        // Tooling Paths
        PATH = "/Users/vyshu/Library/Python/3.12/bin:/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
    }

    stages {
        /* =========================
           Terraform Apply
           ========================= */
        stage('Terraform Apply') {
            steps {
                script {
                    sh "terraform init"
                    sh "terraform apply -auto-approve -var-file=${BRANCH_NAME}.tfvars"

                    // Capture outputs to environment variables
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
                sh '''
                aws ec2 wait instance-status-ok \
                  --instance-ids ${INSTANCE_ID} \
                  --region us-east-1
                '''
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
                  echo "Waiting for SSH port to open..."
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
                // Wrap in sshagent so Ansible can find the private key
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
                input message: "Infrastructure is ready. Approve to destroy?", ok: "Destroy"
            }
        }

        /* =========================
           Terraform Destroy
           ========================= */
        stage('Terraform Destroy') {
            steps {
                sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars"
            }
        }
    }

    post {
        always {
            // Clean up inventory file
            sh 'rm -f dynamic_inventory.ini'
        }
        failure {
            // Ensure resources are deleted if the build fails
            sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars || true"
        }
        aborted {
            sh "terraform destroy -auto-approve -var-file=${BRANCH_NAME}.tfvars || true"
        }
    }
}