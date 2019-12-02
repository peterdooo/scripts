require 'json'

k8sContexts = ["gke_om-shopperexchange-production_us-central1-a_apps-central"]

#k8sContexts = ["gke_ops-staging-179618_us-central1_apps"] 

#k8sContexts = ["gke_ops-production_us-west1-a_tools-environment","gke_ops-production_us-west2-b_jenkins","gke_ops-staging-179618_us-central1-a_jenkins-cd"]

#k8sContexts = ["gke_om-shopperexchange-staging_us-central1-a_apps-central","gke_om-shopperexchange-production_us-central1-a_apps-central","gke_poc-tier1_us-central1_apps","gke_production-tier1_us-central1_apps","gke_sandbox-tier1_us-central1_apps","gke_staging-tier1_us-central1_apps"] 

tmp_status = `ls -ltr | grep tmp`

if tmp_status.empty?
    `mkdir tmp`
end

k8sContexts.each do | context | 
    `mkdir tmp/#{context}`
    # Get project/environment name
    puts "Connecting to #{context.split("_")[1]}"
    `kubectl config use-context #{context}`
    puts "Getting current image in deployment for certmanager..."
    # Get deployment JSON
    deployment = JSON.parse(`kubectl get deployment -n certmanager -ojson`)
    if !deployment.empty?
        puts "Current Image: #{deployment["items"][0]["spec"]["template"]["spec"]["containers"][0]["image"]}"
    else
        puts "#{context.split("_")[1]} does not have a deployment for certmanager"
    end
    deployment["items"][0].delete("status")
    puts "Exporting deployment json back to tmp directory..."
    File.open("tmp/#{context}/deployment_backup.json", 'w') do | file |
        file.puts JSON.pretty_generate(deployment)
    end
    image = deployment["items"][0]["spec"]["template"]["spec"]["containers"][0]["image"].split(':')
    image[1] = "v0.10.0"
    newImage = image.join(':')
    deployment["items"][0]["spec"]["template"]["spec"]["containers"][0].store("image",newImage)
    deployment["items"][0]["spec"]["template"]["spec"]["containers"][0]["args"][2] = "--webhook-namespace=$(POD_NAMESPACE)"
    puts "Creating deployment file with new image for certmanager"
    File.open("tmp/#{context}/new_deployment.json", 'w') do | file |
        file.puts deployment.to_json
    end

    #Backup certificates
    puts "Backing up certificates..."
    allCerts = JSON.parse(`kubectl get certificates --all-namespaces -ojson`)
    count = 0
    while count < allCerts["items"].count
        allCerts["items"][count].delete("status")
        count += 1
    end
    File.open("tmp/#{context}/certBackup.json", 'w') do | file |
        file.puts allCerts.to_json
    end

    puts
    puts "Deleting certmanager deployment..."
    `kubectl delete deployment certmanager -n certmanager`
    `kubectl delete crd certificates.certmanager.k8s.io`
    `kubectl delete crd clusterissuers.certmanager.k8s.io`
    `kubectl delete crd issuers.certmanager.k8s.io`
    `kubectl delete crd certificaterequests.certmanager.k8s.io`
    `kubectl delete crd challenges.certmanager.k8s.io`
    `kubectl delete crd orders.certmanager.k8s.io`
    `kubectl delete clusterissuer letsencrypt-staging`
    `kubectl delete clusterissuer letsencrypt-production`
    puts "Deployment deleted"
    `kubectl apply -n certmanager -f /Users/pdo/Desktop/onemarketnetwork_ghorg/omdeploy/apps/k8s/certmanager/se-production/crd-issuer.yaml`
    `kubectl apply -n certmanager -f /Users/pdo/Desktop/onemarketnetwork_ghorg/omdeploy/apps/k8s/certmanager/se-production/crd-order.yaml`
    `kubectl apply -n certmanager -f /Users/pdo/Desktop/onemarketnetwork_ghorg/omdeploy/apps/k8s/certmanager/se-production/crd-challenges.yaml`
    `kubectl apply -n certmanager -f /Users/pdo/Desktop/onemarketnetwork_ghorg/omdeploy/apps/k8s/certmanager/se-production/crd-certificaterequest.yaml`
    `kubectl apply -n certmanager -f /Users/pdo/Desktop/onemarketnetwork_ghorg/omdeploy/apps/k8s/certmanager/se-production/crd-certificate.yaml`
    `kubectl apply -n certmanager -f /Users/pdo/Desktop/onemarketnetwork_ghorg/omdeploy/apps/k8s/certmanager/se-production/crd-clusterissuer.yaml`
    `kubectl apply -n certmanager -f /Users/pdo/Desktop/onemarketnetwork_ghorg/omdeploy/apps/k8s/certmanager/se-production/crd-order.yaml`
    `kubectl apply -n certmanager -f /Users/pdo/Desktop/onemarketnetwork_ghorg/omdeploy/apps/k8s/certmanager/se-production/crd-issuer-staging.yaml`
    `kubectl apply -n certmanager -f /Users/pdo/Desktop/onemarketnetwork_ghorg/omdeploy/apps/k8s/certmanager/se-production/crd-issuer-production.yaml`
  
    puts "Applying new deployment json"
    `kubectl apply -f tmp/#{context}/new_deployment.json -n certmanager`

    puts "New deployment applied."

    #puts "Applying certs"
    #`kubectl apply -f tmp/#{context}/certBackup.json`
end

