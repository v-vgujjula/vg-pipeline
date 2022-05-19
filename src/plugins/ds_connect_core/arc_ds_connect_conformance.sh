#!/bin/bash
set -e
results_dir="${RESULTS_DIR:-/tmp/results}"
proxy_cert_ns="default"
skip_test_count=0
# saveResults prepares the results for handoff to the Sonobuoy worker.
# See: https://github.com/vmware-tanzu/sonobuoy/blob/master/docs/plugins.md
saveResults() {
    cd ${results_dir}

    # Sonobuoy worker expects a tar file.
	tar czf results.tar.gz *

	# Signal to the worker that we are done and where to find the results.
	printf ${results_dir}/results.tar.gz > ${results_dir}/done
}

# Ensure that we tell the Sonobuoy worker we are done regardless of results.
trap saveResults EXIT
echo "Upgrading Extensions"
az extension add --upgrade --name arcdata --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az extension add --upgrade --name k8s-configuration --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az extension add --upgrade --name k8s-extension --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az extension add --upgrade --name customlocation --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az extension add --upgrade --name connectedk8s --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az -v
## DS direct services onboarding
echo "Onboarding DS direct services"

if [[ -z "${CUSTOM_LOCATION_NAME}" ]]; then
  echo "ERROR: parameter CUSTOM_LOCATION_NAME is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${MEMORY}" ]]; then
  echo "ERROR: parameter MEMORY is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ ${MEMORY} == "" ]] || [[ ${MEMORY} == " " ]]; then
  echo "ERROR: parameter MEMORY is required with values." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${SERVICE_TYPE}" ]]; then
  echo "ERROR: parameter SERVICE_TYPE is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${CONFIG_PROFILE}" ]]; then
  echo "ERROR: parameter CONFIG_PROFILE is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${DATA_CONTROLLER_STORAGE_CLASS}" ]]; then
  echo "ERROR: parameter DATA_CONTROLLER_STORAGE_CLASS is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${AZDATA_USERNAME}" ]]; then
  echo "ERROR: parameter AZDATA_USERNAME is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${AZDATA_PASSWORD}" ]]; then
  echo "ERROR: parameter AZDATA_PASSWORD is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${TENANT_ID}" ]]; then
  echo "ERROR: parameter TENANT_ID is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  echo "ERROR: parameter SUBSCRIPTION_ID is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${RESOURCE_GROUP}" ]]; then
  echo "ERROR: parameter RESOURCE_GROUP is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${LOCATION}" ]]; then
  echo "ERROR: parameter LOCATION is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${CLIENT_ID}" ]]; then
  echo "ERROR: parameter CLIENT_ID is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${CLIENT_SECRET}" ]]; then
  echo "ERROR: parameter CLIENT_SECRET is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${INFRASTRUCTURE}" ]]; then
  echo "ERROR: parameter INFRASTRUCTURE is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ -z "${CONNECTIVITY_MODE}" ]]; then
  echo "ERROR: parameter CONNECTIVITY_MODE is required." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi

if [[ ${CONNECTIVITY_MODE} == "direct" ]]; then
  if [[ -z "${CLUSTER_NAME}" ]]; then
    echo "ERROR: parameter CLUSTER_NAME is required for Direct connect mode." > ${results_dir}/error
    python3 ds_setup_failure_handler.py
  fi
fi

APISERVER=https://kubernetes.default.svc/
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt > ca.crt

kubectl config set-cluster azure-arc-onboarding \
  --embed-certs=true \
  --server=${APISERVER} \
  --certificate-authority=./ca.crt 2> ${results_dir}/error || python3 ds_setup_failure_handler.py

kubectl config set-credentials azure-arc-onboarding --token=${TOKEN} 2> ${results_dir}/error || python3 ds_setup_failure_handler.py

kubectl config set-context azure-arc-onboarding \
  --cluster=azure-arc-onboarding \
  --user=azure-arc-onboarding \
  --namespace=default 2> ${results_dir}/error || python3 ds_setup_failure_handler.py

kubectl config use-context azure-arc-onboarding 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
## Update proxy
if [[ ! -z "${HTTP_PROXY}" ]]; then
  proxy_params+=(--proxy-http ${HTTP_PROXY})
fi

if [[ ! -z "${HTTPS_PROXY}" ]]; then
  proxy_params+=(--proxy-https ${HTTPS_PROXY})
fi

if [[ ! -z "${NO_PROXY}" ]]; then
  proxy_params+=(--proxy-skip-range ${NO_PROXY})
fi

if [[ ! -z "${PROXY_CERT_NAMESPACE}" ]]; then
  proxy_cert_ns=${PROXY_CERT_NAMESPACE}
fi

mkdir /tmp/proxy 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
kubectl get secret sonobuoy-proxy-cert -n ${proxy_cert_ns} -o jsonpath='{.data.proxycert}' --ignore-not-found | base64 -d > /tmp/proxy/proxy-cert.crt 2> ${results_dir}/error || python3 ds_setup_failure_handler.py 

# check if the proxy cert file is not empty. It will be empty if the cert secret is not present. Also this section
# add the certificate for the az cli to work under proxy so all the az commands should be below this section.
if [[ -s "/tmp/proxy/proxy-cert.crt" ]]; then
    proxy_params+=(--proxy-cert "/tmp/proxy/proxy-cert.crt" )
    cp /tmp/proxy/proxy-cert.crt /usr/local/share/ca-certificates/proxy-cert.crt 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
    update-ca-certificates 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
    echo "Ran update-ca-certificates"
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
fi
##
echo "Azure login"
az login --service-principal \
  -u ${CLIENT_ID} \
  -p ${CLIENT_SECRET} \
  --tenant ${TENANT_ID} 2> ${results_dir}/error || python3 ds_setup_failure_handler.py

az account set \
  --subscription ${SUBSCRIPTION_ID} 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
##
export ACCEPT_EULA="yes"
if [[ ${CONNECTIVITY_MODE} == "direct" ]]
then
  echo "Data services direct connect mode initiated"
  azlogs_cmd="az arcdata dc debug copy-logs --k8s-namespace ${CUSTOM_LOCATION_NAME} --use-k8s --exclude-dumps --skip-compress --target-folder /tmp/results/"
  # Cleanup azure arc data service artifacts
  ./ds_pre_cleanup.sh ${CUSTOM_LOCATION_NAME}
  #Polling on azure-arc-platform plugin for connected cluster
  sonobuoy_namespace_present="false"
  status_check_complete="true"
  if [[ -z $(kubectl get ns) ]]
  then
    echo "Please check the Kubernetes cluster configuration, Not found initial namespaces  " > ${results_dir}/error && python3 ds_setup_failure_handler.py
  fi
  namespace_list=$(kubectl get ns)
  if [[ $namespace_list =~ "sonobuoy" ]]
  then
    sonobuoy_namespace_present="true"
  fi
  ##################################################
  #### Deployment 'arc-ds-controller' cleanup
  ##################################################
  echo "Deployment cleanup initiated..."
  if [[ $(az deployment group list -g ${RESOURCE_GROUP} | jq .[].name | grep "arc-ds-controller" | xargs) ]]
  then 
    az deployment group delete -g ${RESOURCE_GROUP} -n "arc-ds-controller" 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
  fi
  ###################################################
  ## Polling on the azure-arc-platform plugin status.
  ###################################################
  ## testing variable sonobuoy_namespace_present = "false" remove this below at final version
  #sonobuoy_namespace_present="false" ## VG
  if [[ $sonobuoy_namespace_present == "true" ]]
  then
    ## 60minutes
    TIMEOUT=3600
    ## 2 minutes
    RETRY_INTERVAL=120
    while [ True ]
    do
      if [ "$TIMEOUT" -le 0 ]; then
        echo "time out at azure-arc-platform plugin status..." > ${results_dir}/error && python3 ds_setup_failure_handler.py
      fi
      echo "Polling on the azure-arc-platform plugin status."
      cmd_sonobuoy_status=$(sonobuoy status --json)
      if [[ -z "${cmd_sonobuoy_status}" ]]; then
        echo "ERROR: Unable to fetch sonobuoy plugin status" > ${results_dir}/error
        python3 ds_setup_failure_handler.py
      fi
      plugin_list=$(echo $cmd_sonobuoy_status | jq .plugins)
      echo $plugin_list
      for plugin in $(echo $plugin_list | jq -c '.[]');do
        plugin_name=$(echo $plugin | jq .plugin | xargs)
        plugin_status=$(echo $plugin | jq .status | xargs)
        if [[ "$plugin_name" == "azure-arc-platform"  ]] && [[ "$plugin_name" != "azure-arc-ds-connect-platform" ]] && [[ "$plugin_status" != "complete" ]]
        then
          echo "Polling on the azure-arc-platform plugin status."
          status_check_complete="false"
          break
        fi
      done
      # Checking exit condition
      if [[ $status_check_complete == "true" ]]
      then
        sleep 2m ## let connected cluster get ready
        break
      fi
      # Checking cleanup timeout need to add
      # Sleep for 2mins
      status_check_complete="true"
      sleep "$RETRY_INTERVAL"
      TIMEOUT=$(($TIMEOUT-$RETRY_INTERVAL))
      printf "\nPolling on the azure-arc-platform plugin status.\n"
    done
  fi
  echo "Checking connected cluster availability"
  arc_connected_cluster=$(az connectedk8s list  -g ${RESOURCE_GROUP} -o tsv -o json | jq .[].name | grep $CLUSTER_NAME | xargs)
  if [[ -z "${arc_connected_cluster}" ]]; then
    echo "ERROR: Connected cluster is required. Please enable azure-arc-platform plugin at properties fils as azure-arc-platform.enable=true " > ${results_dir}/error && python3 ds_setup_failure_handler.py
  fi
  echo "Checking connected cluster status"
  connected_cluster_status=$(az connectedk8s show -g ${RESOURCE_GROUP} -n ${CLUSTER_NAME} --query connectivityStatus 2> ${results_dir}/error || python3 ds_setup_failure_handler.py)
  if [[ $connected_cluster_status && $(echo $connected_cluster_status | xargs) != "Connected" ]]; then
    echo "ERROR: given cluster is not connected." > ${results_dir}/error && python3 ds_setup_failure_handler.py
  fi
  ## Read this variable at python
  export CONNECTED_CLUSTER_NAME=${CLUSTER_NAME}
  if [[ -z $(kubectl get ns) ]]
  then
    echo "Please check the Kubernetes cluster configuration, Not found initial namespaces  " > ${results_dir}/error && python3 ds_setup_failure_handler.py
  fi
  for each_namespace in $(kubectl get ns)
  do
    if [ $each_namespace == ${CUSTOM_LOCATION_NAME} ]
    then
      echo "Namespace : ${CUSTOM_LOCATION_NAME}  already exists. Please specify a different name." > ${results_dir}/error && python3 ds_setup_failure_handler.py
    fi
  done
###################################
## Log analytics workspace creation
###################################
  echo "Log analytics workspace initiated"
  WORKSPACE_ID=$(az monitor log-analytics workspace create -g $RESOURCE_GROUP -n $CUSTOM_LOCATION_NAME -l $LOCATION | jq .customerId | xargs)
  if [ -z "$WORKSPACE_ID" ]
  then
    echo "Unable to create log-analytics workspace ." > ${results_dir}/error
    python3 ds_setup_failure_handler.py
  fi
  export WORKSPACE_ID
  WORKSPACE_SHARED_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group $RESOURCE_GROUP --workspace-name $CUSTOM_LOCATION_NAME | jq .primarySharedKey | xargs)
  if [ -z "$WORKSPACE_SHARED_KEY" ]
  then
    echo "Unable to get primary key from log-analytics workspace" > ${results_dir}/error
    python3 ds_setup_failure_handler.py
  fi
  export WORKSPACE_SHARED_KEY
###########################
## create k8s extension
###########################
  if [[ -z $(kubectl get ns) ]]
  then
    echo "Please check the Kubernetes cluster configuration, Not found initial namespaces  " > ${results_dir}/error && python3 ds_setup_failure_handler.py
  fi
  for each_namespace in $(kubectl get ns)
  do
    if [ $each_namespace == ${CUSTOM_LOCATION_NAME} ]
    then
      echo "Namespace : ${CUSTOM_LOCATION_NAME}  already exists. Please specify a different name." > ${results_dir}/error && python3 ds_setup_failure_handler.py
    fi
  done
  echo "k8s extension initiated"
  K8S_EXTN_NAME=${CUSTOM_LOCATION_NAME}"-ext"
  az k8s-extension create -c ${CLUSTER_NAME} -g ${RESOURCE_GROUP} --name ${K8S_EXTN_NAME} \
    --cluster-type connectedClusters --extension-type microsoft.arcdataservices --auto-upgrade false \
    --scope cluster --release-namespace ${CUSTOM_LOCATION_NAME} --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
  while [ $(az k8s-extension show --name ${K8S_EXTN_NAME} --cluster-type connectedClusters -c ${CLUSTER_NAME} -g ${RESOURCE_GROUP} --query provisioningState | xargs) != "Succeeded" ]
  do
    echo "k8s extension status check"
    sleep 2m
  done
  export K8S_EXTN_NAME
#################################
## create role assigments for MSI
#################################
  echo "role assigments for MSI initiated"
  RESPONSE=$(az k8s-extension show --resource-group ${RESOURCE_GROUP} --cluster-name ${CLUSTER_NAME} --cluster-type connectedClusters --name ${K8S_EXTN_NAME})
  MSI_OBJECT_ID=$(az k8s-extension show --resource-group ${RESOURCE_GROUP}  --cluster-name ${CLUSTER_NAME} --cluster-type connectedClusters --name ${K8S_EXTN_NAME} | jq .identity.principalId | xargs)
  
  #az role assignment create --assignee ${MSI_OBJECT_ID} --role "Contributor" --scope "/subscriptions/${subscription}/resourceGroups/${RESOURCE_GROUP}"
  #az role assignment create --assignee ${MSI_OBJECT_ID} --role "Monitoring Metrics Publisher" --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

  az role assignment create --assignee-principal-type "ServicePrincipal" --assignee-object-id ${MSI_OBJECT_ID} --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
  az role assignment create --assignee-principal-type "ServicePrincipal" --assignee-object-id ${MSI_OBJECT_ID} --role 'Monitoring Metrics Publisher' --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
  if [ $? -ne 0 ]
  then
      echo "Role assigment for MSI failed. k8s-extension: $RESPONSE objectId: $MSI_OBJECT_ID" > ${results_dir}/error
  fi
  connectedClusterId=$(az connectedk8s show -n ${CLUSTER_NAME} -g ${RESOURCE_GROUP}  --query id -o tsv)
  extensionId=$(az k8s-extension show --name ${K8S_EXTN_NAME} --cluster-type connectedClusters -c ${CLUSTER_NAME} -g ${RESOURCE_GROUP} --query id -o tsv)
  sleep 1m
#################################
## create custom location
#################################
  echo "Custom location initiated"
  az customlocation create -n ${CUSTOM_LOCATION_NAME} -g ${RESOURCE_GROUP} --namespace ${CUSTOM_LOCATION_NAME} \
    --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --location ${LOCATION} 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
  sleep 1m
  ## validation custom location with requested namespace
  c_locations=$(az customlocation list -g ${RESOURCE_GROUP} | jq .[].name | xargs)
  if [[ ! $(echo $c_locations | grep -w ${CUSTOM_LOCATION_NAME}) ]]
  then
    echo "ERROR: CUSTOM_LOCATION is not found at specfied Resource Group for Direct connect mode." > ${results_dir}/error
    python3 ds_setup_failure_handler.py
  fi
  cl_namespace=$(az customlocation show -n ${CUSTOM_LOCATION_NAME} -g ${RESOURCE_GROUP} | jq .namespace | xargs)
  if [[ ! $(kubectl get ns ${cl_namespace}) ]]
  then
    echo "ERROR: CUSTOM_LOCATION namespace is not found at cluster." > ${results_dir}/error
    python3 ds_setup_failure_handler.py
  fi
  if [[ $cl_namespace != ${CUSTOM_LOCATION_NAME}  ]]
  then
    echo "ERROR: CUSTOM_LOCATION namespace is not matching with the provided namespace from cluster." > ${results_dir}/error
    python3 ds_setup_failure_handler.py
  fi
###########################
## Data controller creation
###########################
  echo "Data controller initiated"
  az login --service-principal \
    -u ${CLIENT_ID} \
    -p ${CLIENT_SECRET} \
    --tenant ${TENANT_ID} 2> ${results_dir}/error || python3 ds_setup_failure_handler.py

  az account set \
    --subscription ${SUBSCRIPTION_ID} 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
  
  check_dsconfigmap=$(kubectl -n arc-ds-config get configmap arc-ds-config -o jsonpath='{.data.control\.json}' --ignore-not-found)
  if [[ "${check_dsconfigmap}" ]]
  then
    printf "\nData controller creating from 'arc-ds-config' configmap\n"
    config_profile_path="/tmp/control.json"
    kubectl -n arc-ds-config get configmap arc-ds-config -o jsonpath='{.data.control\.json}' >$config_profile_path 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
    ## check service type
    dc_servicetype=$(more $config_profile_path | grep "serviceType" | awk -F':' '{print $2}' | awk -F',' '{print $1}' | xargs)
    if [[ $dc_servicetype != ${SERVICE_TYPE}  ]]
    then
      echo "service type mismatch with arc ds config profile" > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    fi
    #az arcdata dc create --name "arc-ds-controller" --path "/tmp" --connectivity-mode "direct" --cluster-name ${arc_connected_cluster} --infrastructure ${INFRASTRUCTURE} --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} --custom-location ${CUSTOM_LOCATION_NAME} 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    az arcdata dc create --name "arc-ds-controller" --path "/tmp" --connectivity-mode "direct" --cluster-name ${CLUSTER_NAME} --infrastructure ${INFRASTRUCTURE} --resource-group ${RESOURCE_GROUP} --custom-location ${CUSTOM_LOCATION_NAME} --auto-upload-logs true --auto-upload-metrics true  2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    ## 30minutes
    TIMEOUT=1800
    ## 2 minutes
    RETRY_INTERVAL=120
    while [ True ]
    do
      if [ "$TIMEOUT" -le 0 ]; then
        echo "time out at Data controller creation..." > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      fi
      controller_status=$(kubectl get datacontroller -n ${CUSTOM_LOCATION_NAME})
      if [[ $(echo $controller_status | grep "Ready") ]]
      then
        printf "\nController Ready\n"
        break
      fi
      sleep "$RETRY_INTERVAL"
      TIMEOUT=$(($TIMEOUT-$RETRY_INTERVAL))
      printf "\nWaiting for Data controller to get it Ready\n"
    done
  else
    if [[ ${DATA_CONTROLLER_STORAGE_CLASS} == "" || ${DATA_CONTROLLER_STORAGE_CLASS} == "default" ]]
    then
      az arcdata dc config init -s ${CONFIG_PROFILE} -p .
      sed -i 's/\"className\":.*/\"className\": '"\"${DATA_CONTROLLER_STORAGE_CLASS}\"",'/g' "control.json"
      sed -i 's/\"serviceType\":.*/\"serviceType\": '"\"${SERVICE_TYPE}\"",'/g' "control.json"
      #az arcdata dc create --name "arc-ds-controller" --path . --connectivity-mode "direct" --cluster-name ${arc_connected_cluster} --infrastructure ${INFRASTRUCTURE} --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} --custom-location ${CUSTOM_LOCATION_NAME} 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      az arcdata dc create --name "arc-ds-controller" --path . --connectivity-mode "direct" --cluster-name ${CLUSTER_NAME} --infrastructure ${INFRASTRUCTURE} --resource-group ${RESOURCE_GROUP} --custom-location ${CUSTOM_LOCATION_NAME} --auto-upload-logs true --auto-upload-metrics true  2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      ## 30minutes
      TIMEOUT=1800
      ## 2 minutes
      RETRY_INTERVAL=120
      while [ True ]
      do
        if [ "$TIMEOUT" -le 0 ]; then
          echo "time out at Data controller creation..." > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
        fi
        controller_status=$(kubectl get datacontroller -n ${CUSTOM_LOCATION_NAME})
        if [[ $(echo $controller_status | grep "Ready") ]]
        then
          printf "\nController Ready\n"
          break
        fi
        sleep "$RETRY_INTERVAL"
        TIMEOUT=$(($TIMEOUT-$RETRY_INTERVAL))
        printf "\nWaiting for Data controller to get it Ready\n"
      done
      export K8S_EXTN_NAME=${CUSTOM_LOCATION_NAME}"-ext"
    else
      sc_info=$(kubectl get sc)
      echo $sc_info
      echo ${DATA_CONTROLLER_STORAGE_CLASS}
      if [[ ! $sc_info =~ ${DATA_CONTROLLER_STORAGE_CLASS} ]]
      then
        echo "Storage class : ${DATA_CONTROLLER_STORAGE_CLASS}  not exists. Please specify a valid name." > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      else
        az arcdata dc config init -s ${CONFIG_PROFILE} -p .
        sed -i 's/\"serviceType\":.*/\"serviceType\": '"\"${SERVICE_TYPE}\"",'/g' "control.json"
        sed -i 's/\"className\":.*/\"className\": '"\"${DATA_CONTROLLER_STORAGE_CLASS}\"",'/g' "control.json"
        #az arcdata dc create --name "arc-ds-controller" --path . --connectivity-mode "direct" --cluster-name ${arc_connected_cluster} --infrastructure ${INFRASTRUCTURE} --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} --custom-location ${CUSTOM_LOCATION_NAME} 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
        az arcdata dc create --name "arc-ds-controller" --path . --connectivity-mode "direct" --cluster-name ${CLUSTER_NAME} --infrastructure ${INFRASTRUCTURE} --resource-group ${RESOURCE_GROUP} --custom-location ${CUSTOM_LOCATION_NAME} --auto-upload-logs true --auto-upload-metrics true  2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      fi
      ## 30minutes
      TIMEOUT=1800
      ## 2 minutes
      RETRY_INTERVAL=120
      while [ True ]
      do
        if [ "$TIMEOUT" -le 0 ]; then
          echo "time out at Data controller creation..." > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
        fi
        controller_status=$(kubectl get datacontroller -n ${CUSTOM_LOCATION_NAME})
        if [[ $(echo $controller_status | grep "Ready") ]]
        then
          printf "\nController Ready\n"
          break
        fi
        sleep "$RETRY_INTERVAL"
        TIMEOUT=$(($TIMEOUT-$RETRY_INTERVAL))
        printf "\nWaiting for Data controller to get it Ready\n"
      done
      export K8S_EXTN_NAME=${CUSTOM_LOCATION_NAME}"-ext"
    fi
  fi
  ###################
  ## sql mi creation
  ###################
  echo "SQL MI initiated"
  if [ -z "${SQL_INSTANCE_NAME}" ]
  then
    echo "You have not choosen to create SQL server"
    skip_test_count=$((skip_test_count+1))
  else
    ## Checking for SQLMI is already exist or not.
    pre_sql_status=$(kubectl get sqlmi -n ${CUSTOM_LOCATION_NAME} --ignore-not-found)
    if [[ $(echo $pre_sql_status | grep "Ready") ]]
    then
      echo "SQLMI is already exist with specified name : ${SQL_INSTANCE_NAME}" > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    fi
    if [[ ${SQL_MI_STORAGE_CLASS} == "" || ${SQL_MI_STORAGE_CLASS} == "default" ]]
    then
      #az sql mi-arc create --name ${SQL_INSTANCE_NAME} --resource-group ${RESOURCE_GROUP} --location ${LOCATION}  --custom-location ${CUSTOM_LOCATION_NAME} --subscription ${SUBSCRIPTION_ID} --storage-class-data "default" --storage-class-datalogs "default" --storage-class-logs "default" --dev 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      az sql mi-arc create --name ${SQL_INSTANCE_NAME} --resource-group ${RESOURCE_GROUP} --location ${LOCATION} --custom-location ${CUSTOM_LOCATION_NAME} --storage-class-data "default" --storage-class-datalogs "default" --storage-class-logs "default" --memory-request ${MEMORY}  --memory-limit ${MEMORY} --dev 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    else
      sc_info=$(kubectl get sc)
      echo $sc_info
      echo ${SQL_MI_STORAGE_CLASS}
      if [[ ! $sc_info =~ ${SQL_MI_STORAGE_CLASS} ]]
      then
        echo "Storage class : ${SQL_MI_STORAGE_CLASS}  not exists. Please specify a valid name." > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      else
        #az sql mi-arc create --name ${SQL_INSTANCE_NAME} --resource-group ${RESOURCE_GROUP} --location ${LOCATION}  --custom-location ${CUSTOM_LOCATION_NAME} --subscription ${SUBSCRIPTION_ID} --storage-class-data ${SQL_MI_STORAGE_CLASS} --storage-class-datalogs ${SQL_MI_STORAGE_CLASS} --storage-class-logs ${SQL_MI_STORAGE_CLASS} --dev 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
        az sql mi-arc create --name ${SQL_INSTANCE_NAME} --resource-group ${RESOURCE_GROUP} --location ${LOCATION} --custom-location ${CUSTOM_LOCATION_NAME} --storage-class-data ${SQL_MI_STORAGE_CLASS} --storage-class-datalogs ${SQL_MI_STORAGE_CLASS} --storage-class-logs ${SQL_MI_STORAGE_CLASS} --memory-request ${MEMORY}  --memory-limit ${MEMORY} --dev 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      fi
    fi
    ## 30minutes
    TIMEOUT=1800
    ## 2 minutes
    RETRY_INTERVAL=120
    while [ True ]
    do
      if [ "$TIMEOUT" -le 0 ]; then
        echo "time out at SQLMI creation..." > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      fi
      sql_status=$(kubectl get sqlmi -n ${CUSTOM_LOCATION_NAME})
      if [[ $(echo $sql_status | grep "Ready") ]]
      then
        printf "\nSQL Ready\n"
        break
      fi
      sleep "$RETRY_INTERVAL"
      TIMEOUT=$(($TIMEOUT-$RETRY_INTERVAL))
      printf "\nWaiting for SQL server to get it Ready\n"
    done
  fi
  #############################
  ## TODO Postgres sql creation
  #############################
else
  ########################### indirect mode
  echo "you must choose direct mode for this plugin." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi
# end of resources creation
echo "We are waiting for resources availability followed by collecting logs and about to execute test cases"
sleep 1m
## Collecting logs from az arcdata
$azlogs_cmd
## Collecting and Displaying the resources version info
printf "\n####################################################################################################################\n"
printf "Azure arc data services validation date: $(date)\n"
printf "\nKubernetes Version\n"
kubectl version --short
printf "\nAzure Arc data services Release Version\n"
az arcdata dc config show --k8s-namespace ${CUSTOM_LOCATION_NAME} --use-k8s | grep "imageTag" | awk 'NR==2' | awk -F':' '{print $2}' | awk -F',' '{print $1}'
echo "Arcdata Extension version: $(az extension show -n arcdata 2> null | jq .version)"
if [[ "${SQL_INSTANCE_NAME}" ]]
then
  grep -rh "Microsoft (R) SQLServerAgent" /tmp/results | awk 'NR==1'
fi
if [[ "${PSQL_SERVERGROUP_NAME}" ]]
then
  grep -rh "starting PostgreSQL" /tmp/results | awk 'NR==1'| awk -F'starting' '{print $2}'
fi
printf "\nCSI Drivers information\n"
kubectl get csidrivers

printf "\n####################################################################################################################\n"
##
# The variable 'TEST_NAME_LIST' should be provided if we want to run specific tests. If not provided, all tests are run
NUM_PROCESS=$(pytest /conformancetests/ --collect-only  -k "$TEST_NAME_LIST" -m "$TEST_MARKER_LIST" | grep "<Function\|<Class" -c)

if [ $skip_test_count -gt 0 ]
then
  NUM_PROCESS=$((NUM_PROCESS-skip_test_count))
  echo "number of process $NUM_PROCESS"
  if [[ $NUM_PROCESS -le 0 ]] 
  then
    ## Issue with arguments not matched with criteria
    echo "Number of tests mismatched. Please check arguments" > ${results_dir}/error && $azlogs_cmd && python3 ds_setup_failure_handler.py
  fi
fi

export NUM_TESTS="$NUM_PROCESS"
## VG
#sleep 6000m ##
pytest /conformancetests/ --junitxml=/tmp/results/results.xml -d --tx "$NUM_PROCESS"*popen -k "$TEST_NAME_LIST" -m "$TEST_MARKER_LIST"
