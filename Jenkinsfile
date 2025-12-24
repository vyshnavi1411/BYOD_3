pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'

        AWS_CREDS   = credentials('AWS_CREDS')
        SSH_CRED_ID = 'My_SSH'

        // Terraform + AWS CLI + Ansible paths
        PATH = "/Users/vyshu/Library/Python/3.12/bin:/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
    }

    stages {

        /* =========================
           Terraform Apply + Outputs
           ========================= */
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

        /* =========================
           Dynamic Inventory
           ========================= */
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

        /* =========================
           Install Splunk
           ========================= */
        stage('Install Splunk') {
            steps {
                sh '''
                ansible-playbook playbooks/splunk.yml \
                  -i dynamic_inventory.ini \
                  -u ec2-user
                '''
            }
        }

        /* =========================
           Verify Splunk
           ========================= */
        stage('Verify Splunk') {
            steps {
                sh '''
                ansible-playbook playbooks/test-splunk.yml \
                  -i dynamic_inventory.ini \
                  -u ec2-user
                '''
            }
        }

        /* =========================
           Manual Destroy Approval
           ========================= */
        stage('Validate Destroy') {
            steps {
                input message: 'Do you want to destroy the infrastructure?', ok: 'Destroy'
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

    /* =========================
       Post Actions (Cleanup)
       ========================= */
    post {
    always {
        sh 'rm -f dynamic_inventory.ini'
    }
}

}
