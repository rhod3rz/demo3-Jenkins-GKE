## A Jenkins and Google Kubernetes Engine demo pipeline.

### Summary
This repo demonstrates a deployment pipeline using a Jenkinsfile, deploying to Google Kubernetes Engine.

The core application components are:

- A 'todo' list app
- A MySQL database

In addition it demonstrates the use of several other technologies and concepts:

- Git and git branching strategy ( prd | dev | stg )
- Jenkins and Jenkinsfile declarative pipeline
- Maven/Java demo application
- Docker application build with a DockerHub repo
- Terraform provision of 'dev' or 'prd' Google Kubernetes Engine (GKE) environments based on branch name
- Authorisation gate to control and review terraform code changes
- Kubernetes application deployment
- Canary updates utilising the 'stg' branch
- Emergency rollback using kubectl & previous versions

### Pipeline Overview
![Pipeline Overview](https://raw.githubusercontent.com/rhod3rz/demo3-Jenkins-GKE/prd/screenshots/pipeline-overview.png "Pipeline Overview")

### Pipeline
![Pipeline](https://raw.githubusercontent.com/rhod3rz/demo3-Jenkins-GKE/prd/screenshots/pipeline.png "Pipeline")

### K8s Diagram
![K8s Diagram](https://raw.githubusercontent.com/rhod3rz/demo3-Jenkins-GKE/prd/screenshots/k8s.png "K8s Diagram")

### Branching Strategy
![Branching Strategy](https://raw.githubusercontent.com/rhod3rz/demo3-Jenkins-GKE/prd/screenshots/branching-strategy.png "Branching Strategy")

### Pre-Requisites
The pipeline relies on the following components:

- Jenkins Server + BlueOcean Plugins
- Jenkins Server Locally Installed Packages:
  - Docker CLI
  - Kubectl
  - GCP SDK
  - Terraform
- Jenkins Global Credentials:
  - dockerlogin      >  Username with Password                   >  Required for stage 'docker build & publish'
  - gcp-terraform    >  Secret Text                              >  Required for env var 'CREDENTIALS_TERRAFORM = credentials('gcp-terraform')'
  - gcp-kubectl-cmd  >  Secret File                              >  Required for stage 'kubernetes' to run 'gcloud' cli
  - MYSQL_PASSWORD   >  Secret Text                              >  Required for stage 'kubernetes' to set MySQL admin password

### Workflow

---
#### 1. Build the 'prd' branch.
---
Instructions:

a. Update line 11 in src\web\src\static\index.html with a new timestamp.  
`<title>Todo App - 211012-1127</title>`  
b. Update line 28 in Jenkinsfile with a new timestamp. This is used to tag the docker image with a version.  
`APP_VERSION = "211012-1127"`  
c. Push the 'prd' branch to github using the version number as a commit message.  
`git add .`  
`git commit -m "211012-1127"`  
`git push -u origin prd`  
d. Create a Jenkins Multibranch Pipeline, pointing to https://github.com/rhod3rz/demo2-Jenkins-GKE.git (there is only a 'prd' branch at this stage).  
e. Manually approve the stage 'terraform\stg-prd\approve' via Jenkins.  
f. Update the external DNS record with the ip of the static ip / ingress reource once created.

Pipeline Actions:

- Compile the code, create docker image and push to DockerHub (the 'prd' branch creates two tags e.g. 211012-1127-prd and latest)
- Evaluate the branch name and Terraform provision the 'prd' environment (inc. manual approval gate)
- Evaluate the branch name and deploy the app to the 'prd' cluster

Output:

You now have a single 'prd' branch deployed and can test the app is running e.g. https://prd.rhod3rz.com/.  
When running the app, notice the version number is as you set in step 1a. Run the following command to see the image used is the one set in step 1b:  
`kubectl describe deployment todo-app -n todo`

NOTE: It can take 10-20 minutes for the certificate provisioning to complete. Check the status of cert creation with the following command:  
`kubectl describe managedcertificate todo-app -n todo`  
You are looking for the 'Certificate Status' and 'Domain Status' to change from 'Provisioning' to 'Active'.  

The completed pipeline will look like the pipeline image above.

---
#### 2. Build the 'dev' branch.
---
Instructions:

It's time to simulate a change ...

a. Create a new branch 'dev', and switch to it e.g.  
`git checkout -b dev`  
b. Update line 11 in src\web\src\static\index.html with a new timestamp.  
`<title>Todo App - 211012-1508</title>`  
c. Update line 28 in Jenkinsfile with a new timestamp. This is used to tag the docker image with a version.  
`APP_VERSION = "211012-1508"`  
d. Push the 'prd' branch to github using the version number as a commit message.  
`git add .`  
`git commit -m "211012-1508"`  
`git push -u origin dev`  
e. Manually approve stage 'terraform\dev\approve' via Jenkins.

Pipeline Actions:

- Compile the code, create docker images and push to DockerHub (the 'dev' branch creates one tag e.g. 211012-1508-dev)
- Evaluate the branch name and Terraform provision the 'dev' environment (inc. manual approval gate)
- Evaluate the branch name and deploy the app to the 'dev' cluster

Output:

You now have two branches, 'dev' and 'prd'. To save on cost, the 'dev' deployment doesn't create an ingress. Test using the following steps:

a. Update kubeconfig and confirm cluster is online.  
`gcloud container clusters get-credentials sz-211008-0911-dev --zone europe-west1-b`  
`kubectl get nodes`  
b. Get the todo-app node port.  
`kubectl get service -n todo`  
c. Map the 'node port' e.g.  
`kubectl port-forward service/todo-app 31323:5000 -n=todo`  
d. Test the app by browsing to http://localhost:31323/ and confirm the version has changed to the new one you entered e.g. 211012-1508.

---
#### 3. Merge the 'dev' Branch to 'stg' Branch (Canary Deployment).
---
Instructions:

It's time to merge the 'dev' changes into the 'stg' branch; this simulates a canary deployment.  

Why? Well the 'prd' and 'stg' deployments use a label called 'voting-app'. The service that fronts the app uses that label to locate the pods. When the 'stg' deployment is deployed it will start to receive requests from the 'prd' service.

a. Create a new branch 'stg', and switch to it. This is now a copy of 'dev' e.g.  
`git checkout -b stg`  
b. Commit changes e.g.  
`git push -u origin stg`  
c. Manually approve stage 'terraform\stg-prd\approve' via Jenkins.

Pipeline Actions:

- Compile the code, create docker images and push to DockerHub (the 'stg' branch creates one tag e.g. 211012-1508-stg)
- Evaluate the branch name and Terraform provision the 'prd' environment (inc. manual approval gate); as this already exists there will be no changes.
- Evaluate the branch name and deploy the app to the 'prd' cluster

Output:

You now have three branches, 'dev', 'prd' and 'stg. The 'stg' deployment has created a new kubernetes deployment called 'todo-app-stg'. The 'prd' deployment is called 'todo-app'. The service is now load balancing traffic between the 'stg' and 'prd' apps. Test using the following steps:

a. Browse to the URL e.g. https://prd.rhod3rz.com/  
b. Press Shift + F5 repeatedly and you should see the version changing as you are load balanced between 'prd' and 'stg'.

---
#### 4. Merge the 'stg' Branch to 'prd' Branch.
---
Instructions:

Assuming there were no issues with the 'stg' deployment it's time to merge those changes into 'prd' ...

a. Create a 'Pull Request' to merge 'stg' into 'prd' and delete the 'stg' branch from GitHub.  
b. Delete the 'dev' branch from GitHub.  
c. Delete the 'dev' and 'stg' branch from local Git e.g.  
`(git checkout prd) -and (git branch -d dev) -and (git branch -d stg) -and (git remote prune origin) -and (git pull)`  
d. Delete the 'dev' kubernetes namespace e.g.  
`gcloud container clusters get-credentials sz-211008-0911-dev --zone europe-west1-b`  
`kubectl delete ns todo`  
e. Delete the 'stg' kubernetes deployment e.g.  
`gcloud container clusters get-credentials sz-211008-0911-prd --zone europe-west1-b`  
`kubectl delete deploy todo-app-stg -n todo`  

Pipeline Actions:

- Compile the code, create docker image and push to DockerHub (the 'prd' branch creates two tags e.g. 211012-1127-prd and latest)
- Evaluate the branch name and Terraform provision the 'prd' environment (inc. manual approval gate)
- Evaluate the branch name and deploy the app to the 'prd' cluster

Output:

You're now back to a single 'prd' branch with the new changes applied. Test using the following steps:

a. Browse to the URL e.g. https://prd.rhod3rz.com/  
b. Press Shift + F5 repeatedly and you'll see the older version is no longer available.

---
#### 5. Emergency Rollback.
---
Instructions:

Aargh something has gone wrong and been missed in testing! You need to rollback to the previous version asap ...

a. View the rollout history to see previous versions.  
NOTE: To make it easy to identify the version to rollback to, 'Change-Cause' has been populated in the deployment yaml file, and is updated to the correct version via the Jenkinsfile.  
`kubectl rollout history --namespace=todo deploy/todo-app`  
b. Drill into a version e.g. to confirm which image it's using:  
`kubectl rollout history --namespace=todo deploy/todo-app --revision=1`  
c. Rollback:  
`kubectl rollout undo --namespace=todo deploy/todo-app --to-revision=1`  
