pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
    }

    stages {
        stage('Terraform Apply') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'AWS_CREDS']
                ]) {
                    sh 'terraform init'
                    sh "terraform apply -auto-approve -var-file=${BRANCH_NAME}.tfvars"

                    script {
                        INSTANCE_ID = sh(
                            script: 'terraform output -raw instance_id',
                            returnStdout: true
                        ).trim()

                        INSTANCE_IP = sh(
                            script: 'terraform output -raw instance_public_ip',
                            returnStdout: true
                        ).trim()

                        echo "INSTANCE ID: ${INSTANCE_ID}"
                        echo "INSTANCE IP: ${INSTANCE_IP}"
                    }
                }
            }
        }

        /* Task 2: Dynamic Inventory */
        stage('Create Dynamic Inventory') {
            steps {
                sh '''
                echo "[ec2]" > dynamic_inventory.ini
                echo "${INSTANCE_IP} ansible_user=ec2-user" >> dynamic_inventory.ini
                '''
            }
        }

        /* Task 3: AWS Health Check */
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
        /* Task 5: Destroy */
        stage('Validate Destroy') {
            steps {
                input message: 'Destroy infrastructure?', ok: 'Destroy'
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
    }
}
