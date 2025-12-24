pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
        ANSIBLE_HOST_KEY_CHECKING = 'False'

        PATH = "/Users/vyshu/Library/Python/3.12/bin:/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
    }

    stages {

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

        stage('Create Dynamic Inventory') {
            steps {
                sh '''
                echo "[splunk]" > dynamic_inventory.ini
                echo "${INSTANCE_IP} ansible_user=ec2-user ansible_ssh_private_key_file=/Users/vyshu/.ssh/My_Ecommerce.pem" >> dynamic_inventory.ini
                '''
            }
        }

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
                sh '''
                ansible-playbook playbooks/splunk.yml \
                  -i dynamic_inventory.ini \
                  -u ec2-user \
                  --ssh-extra-args="-o StrictHostKeyChecking=no"
                '''
            }
        }

        stage('Verify Splunk') {
            steps {
                sh '''
                ansible-playbook playbooks/test-splunk.yml \
                  -i dynamic_inventory.ini \
                  -u ec2-user \
                  --ssh-extra-args="-o StrictHostKeyChecking=no"
                '''
            }
        }

        stage('Validate Destroy') {
            steps {
                input message: "Destroy infrastructure?", ok: "Destroy"
            }
        }

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
    }
}
