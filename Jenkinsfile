pipeline {
  agent any

  parameters {
    string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region')
    string(name: 'CLUSTER_NAME', defaultValue: 'gpu-eks-demo', description: 'EKS cluster name')
  }

  environment {
    TF_IN_AUTOMATION = 'true'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Terraform Init & Plan') {
      steps {
        withAWS(credentials: 'aws-jenkins-creds', region: params.AWS_REGION) {
          dir('infra') {
            sh """
              terraform init -input=false

              terraform plan -input=false \
                -var 'aws_region=${params.AWS_REGION}' \
                -var 'cluster_name=${params.CLUSTER_NAME}'
            """
          }
        }
      }
    }

    stage('Approve Apply') {
      steps {
        script {
          input message: "Apply Terraform to create GPU-enabled EKS cluster '${params.CLUSTER_NAME}' in ${params.AWS_REGION}?"
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        withAWS(credentials: 'aws-jenkins-creds', region: params.AWS_REGION) {
          dir('infra') {
            sh """
              terraform apply -input=false -auto-approve \
                -var 'aws_region=${params.AWS_REGION}' \
                -var 'cluster_name=${params.CLUSTER_NAME}'
            """

            echo "ML IRSA Role ARN:"
            sh "terraform output -raw ml_irsa_role_arn || true"
          }
        }
      }
    }

    stage('Update kubeconfig & Verify Nodes') {
      steps {
        withAWS(credentials: 'aws-jenkins-creds', region: params.AWS_REGION) {
          sh """
            aws eks update-kubeconfig --name ${params.CLUSTER_NAME} --region ${params.AWS_REGION}
            kubectl get nodes -o wide
          """
        }
      }
    }

    stage('Install NVIDIA Device Plugin') {
      steps {
        withAWS(credentials: 'aws-jenkins-creds', region: params.AWS_REGION) {
          sh """
            # Install NVIDIA device plugin DaemonSet
            kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.16.0/nvidia-device-plugin.yml

            # Wait for DaemonSet rollout (best-effort)
            kubectl -n kube-system rollout status daemonset/nvidia-device-plugin-daemonset --timeout=300s || true

            kubectl -n kube-system get pods -l name=nvidia-device-plugin-ds || true
          """
        }
      }
    }
  }
}
