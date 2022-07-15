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
## DS onboarding
echo "Onboarding Data services"
echo "Upgrading azure cli"
pip install --upgrade azure-cli
#az upgrade --yes
echo "Upgrading Extensions"
az extension add --upgrade --name arcdata --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az extension add --upgrade --name k8s-configuration --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az extension add --upgrade --name k8s-extension --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az extension add --upgrade --name customlocation --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az extension add --upgrade --name connectedk8s --yes 2> ${results_dir}/error || python3 ds_setup_failure_handler.py
az -v
##
echo "Checking release type request"
if [[ ! ${RELEASE_TYPE} ]]; then
  RELEASE_TYPE="PROD"
  echo $RELEASE_TYPE
else
  echo $RELEASE_TYPE
  if [[ ! ${REPOSITORY} ]] || [[ ! ${IMAGE_TAG} ]]; then
    echo "ERROR: parameter REPOSITORY or IMAGE_TAG are missing." > ${results_dir}/error
    python3 ds_setup_failure_handler.py
  fi
fi
##
echo "Onboarding DS indirect services"
if [[ -z "${NAMESPACE}" ]]; then
  echo "ERROR: parameter NAMESPACE is required." > ${results_dir}/error
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
export ACCEPT_EULA="yes"
if [[ ${CONNECTIVITY_MODE} == "indirect" ]]
then
  if [[ -z $(kubectl get ns) ]]
  then
    echo "Please check the Kubernetes cluster configuration, Not found initial namespaces  " > ${results_dir}/error && python3 ds_setup_failure_handler.py
  fi
  for each_namespace in $(kubectl get ns)
  do
    if [ $each_namespace == ${NAMESPACE} ]
    then
      echo "Namespace : ${NAMESPACE}  already exists. Please specify a different name." > ${results_dir}/error && python3 ds_setup_failure_handler.py
    fi
  done
  # Cleanup azure arc data service artifacts
  ./ds_pre_cleanup.sh ${NAMESPACE}
  kubectl create namespace ${NAMESPACE}
  azlogs_cmd="az arcdata dc debug copy-logs --k8s-namespace ${NAMESPACE} --use-k8s --exclude-dumps --skip-compress --target-folder /tmp/results/"
  ## password encoding
  encoded_username=$(echo -n ${AZDATA_USERNAME} | base64)
  encoded_password=$(echo -n ${AZDATA_PASSWORD} | base64)
  ###########################
  ## Data controller creation
  ###########################
  ## TODO: data controller creation is not supporting fully with k8 native files use case while using config profile, so here we are now using az arcdata 
  ## Need to wait for official release.
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
    if [[ ${RELEASE_TYPE} != "PROD" ]]
    then
      printf "\nData controller creation initiated for PRE-RELEASE version\n"
      sed -i 's+\"repository\":.*+\"repository\": '"\"${REPOSITORY}\"",'+g' "/tmp/control.json"
      sed -i 's/\"imageTag\":.*/\"imageTag\": '"\"${IMAGE_TAG}\"",'/g' "/tmp/control.json"
      az arcdata dc create --name ${NAMESPACE} --path "/tmp" --k8s-namespace ${NAMESPACE} --use-k8s --connectivity-mode indirect --infrastructure ${INFRASTRUCTURE} --location ${LOCATION} --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    else
      printf "\nData controller creation initiated for PROD version\n"
      az arcdata dc create --name ${NAMESPACE} --path "/tmp" --k8s-namespace ${NAMESPACE} --use-k8s --connectivity-mode indirect --infrastructure ${INFRASTRUCTURE} --location ${LOCATION} --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
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
      controller_status=$(kubectl get datacontroller -n ${NAMESPACE})
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
      sed -i 's/\"serviceType\":.*/\"serviceType\": '"\"${SERVICE_TYPE}\"",'/g' "control.json"
      if [[ ${RELEASE_TYPE} != "PROD" ]]
      then 
        printf "\nData controller creation initiated for PRE-RELEASE version\n"
        sed -i 's+\"repository\":.*+\"repository\": '"\"${REPOSITORY}\"",'+g' "control.json"
        sed -i 's/\"imageTag\":.*/\"imageTag\": '"\"${IMAGE_TAG}\"",'/g' "control.json"
        az arcdata dc create --name ${NAMESPACE} --path . --k8s-namespace ${NAMESPACE} --use-k8s --storage-class "default" --connectivity-mode indirect --infrastructure ${INFRASTRUCTURE} --location ${LOCATION} --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      else
        printf "\nData controller creation initiated for PROD version\n"
        az arcdata dc create --name ${NAMESPACE} --path . --k8s-namespace ${NAMESPACE} --use-k8s --storage-class "default" --connectivity-mode indirect --infrastructure ${INFRASTRUCTURE} --location ${LOCATION} --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      fi
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
        if [[ ${RELEASE_TYPE} != "PROD" ]]
        then
          sed -i 's+\"repository\":.*+\"repository\": '"\"${REPOSITORY}\"",'+g' "control.json"
          sed -i 's/\"imageTag\":.*/\"imageTag\": '"\"${IMAGE_TAG}\"",'/g' "control.json"
          printf "\nData controller creation initiated for PRE-RELEASE version\n"
          az arcdata dc create --name ${NAMESPACE} --path . --k8s-namespace ${NAMESPACE} --use-k8s --storage-class ${DATA_CONTROLLER_STORAGE_CLASS} --connectivity-mode indirect --infrastructure ${INFRASTRUCTURE} --location ${LOCATION} --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
        else
          printf "\nData controller creation initiated for PROD version\n"
          az arcdata dc create --name ${NAMESPACE} --path . --k8s-namespace ${NAMESPACE} --use-k8s --storage-class ${DATA_CONTROLLER_STORAGE_CLASS} --connectivity-mode indirect --infrastructure ${INFRASTRUCTURE} --location ${LOCATION} --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
        fi
      fi
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
      controller_status=$(kubectl get datacontroller -n ${NAMESPACE})
      if [[ $(echo $controller_status | grep "Ready") ]]
      then
        printf "\nController Ready\n"
        break
      fi

      sleep "$RETRY_INTERVAL"
      TIMEOUT=$(($TIMEOUT-$RETRY_INTERVAL))
      printf "\nWaiting for Data controller to get it Ready\n"
    done
  fi
  ##################
  ## sql mi creation
  ##################
  if [ -z "${SQL_INSTANCE_NAME}" ]
  then
    echo "You have not choosen to create SQL server"
    skip_test_count=$((skip_test_count+1))
  else
    wget https://raw.githubusercontent.com/microsoft/azure_arc/main/arc_data_services/deploy/yaml/sqlmi.yaml
    if [ $? -ne 0 ]; then
        echo "Unable to load sqlmi.yaml " > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    fi
    sed -i 's|password: <your base64 encoded password>|'"password: $encoded_password"'|g' sqlmi.yaml
    sed -i 's|username: <your base64 encoded username>|'"username: $encoded_username"'|g' sqlmi.yaml
    sed -i 's|sql1|'${SQL_INSTANCE_NAME}'|g' sqlmi.yaml
    sql_servicetype=$(more sqlmi.yaml | grep type: | awk NR==2 | awk -F':' '{print $2}' | xargs)
    ## Updating memory
    sed -i 's|memory:.*|'"memory: ${MEMORY}"'|g' sqlmi.yaml
    if [[ $sql_servicetype != ${SERVICE_TYPE}  ]]
    then
      sed -i 's|'"type: ${sql_servicetype}"'|'"type: ${SERVICE_TYPE}"'|g' sqlmi.yaml
    fi
    if [[ ${SQL_MI_STORAGE_CLASS} == "" || ${SQL_MI_STORAGE_CLASS} == "default" ]]
    then
      sed -i 's|className: default|'"className: ${SQL_MI_STORAGE_CLASS}"'|g' sqlmi.yaml
      kubectl -n ${NAMESPACE} create -f sqlmi.yaml 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    else
      sc_info=$(kubectl get sc)
      echo $sc_info
      echo ${SQL_MI_STORAGE_CLASS}
      if [[ ! $sc_info =~ ${SQL_MI_STORAGE_CLASS} ]]
      then
        echo "Storage class : ${SQL_MI_STORAGE_CLASS}  not exists. Please specify a valid name." > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      else
        sed -i 's|className: default|'"className: ${SQL_MI_STORAGE_CLASS}"'|g' sqlmi.yaml
        kubectl -n ${NAMESPACE} create -f sqlmi.yaml 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
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
      sql_status=$(kubectl get sqlmi -n ${NAMESPACE})
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
  ########################
  ## Postgres SQL creation
  ########################
  if [ -z "${PSQL_SERVERGROUP_NAME}" ]
  then
    echo "You have not choosen to create Postgres SQL"
    skip_test_count=$((skip_test_count+1))
  else
    wget https://raw.githubusercontent.com/microsoft/azure_arc/main/arc_data_services/deploy/yaml/postgresql.yaml
    if [ $? -ne 0 ]; then
        echo "Unable to load postgresql.yaml " > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    fi
    sed -i 's|password: <your base64 encoded password>|'"password: $encoded_password"'|g' postgresql.yaml
    sed -i 's|pg1|'${PSQL_SERVERGROUP_NAME}'|g' postgresql.yaml
    pg_servicetype=$(more postgresql.yaml | grep type: | awk NR==2 | awk -F':' '{print $2}' | awk -F'#' '{print $1}' | xargs)
    ## Updating memory
    sed -i 's|memory:.*|'"memory: ${MEMORY}"'|g' postgresql.yaml
    if [[ $pg_servicetype != ${SERVICE_TYPE}  ]]
    then
      sed -i 's|'"type: ${pg_servicetype}"'|'"type: ${SERVICE_TYPE}"'|g' postgresql.yaml
    fi
    if [[ ${PSQL_STORAGE_CLASS} == "" || ${PSQL_STORAGE_CLASS} == "default" ]]
    then
      sed -i 's|className: default|'"className: ${PSQL_STORAGE_CLASS}"'|g' postgresql.yaml
      kubectl -n ${NAMESPACE} create -f postgresql.yaml 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
    else
      sc_info=$(kubectl get sc)
      echo $sc_info
      echo ${PSQL_STORAGE_CLASS}
      if [[ ! $sc_info =~ ${PSQL_STORAGE_CLASS} ]]
      then
        echo "Storage class : ${PSQL_STORAGE_CLASS}  not exists. Please specify a valid name." > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      else
        sed -i 's|className: default|'"className: ${PSQL_STORAGE_CLASS}"'|g' postgresql.yaml
        kubectl -n ${NAMESPACE} create -f postgresql.yaml 2> ${results_dir}/error || { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      fi
    fi
    ## 30minutes
    TIMEOUT=1800
    ## 2 minutes
    RETRY_INTERVAL=120
    while [ True ]
    do
      if [ "$TIMEOUT" -le 0 ]; then
        echo "time out at PostgresSQL creation..." > ${results_dir}/error && { $azlogs_cmd; python3 ds_setup_failure_handler.py; }
      fi
      psql_status=$(kubectl get postgresqls -n ${NAMESPACE})
      if [[ $(echo $psql_status | grep "Ready") ]]
      then
        printf "\nPostgresSQL Ready\n"
        break
      fi
      sleep "$RETRY_INTERVAL"
      TIMEOUT=$(($TIMEOUT-$RETRY_INTERVAL))
      printf "\nWaiting for PostgresSQL server to get it Ready\n"
    done
  fi
else
  echo "you must choose indirect mode for this plugin." > ${results_dir}/error
  python3 ds_setup_failure_handler.py
fi
## end of resources creation
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
az arcdata dc config show --k8s-namespace ${NAMESPACE} --use-k8s | grep "imageTag" | awk 'NR==2' | awk -F':' '{print $2}' | awk -F',' '{print $1}'
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

pytest /conformancetests/ --junitxml=/tmp/results/results.xml -d --tx "$NUM_PROCESS"*popen -k "$TEST_NAME_LIST" -m "$TEST_MARKER_LIST"
