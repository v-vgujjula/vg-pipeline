#!/bin/bash
set -ex

results_dir="${RESULTS_DIR:-/tmp/results}"
proxy_cert_ns="default" 
onboarding_complete=false

# saveResults prepares the results for handoff to the Sonobuoy worker.
# See: https://github.com/vmware-tanzu/sonobuoy/blob/master/docs/plugins.md
saveResults() {
    cd ${results_dir}

    iter=1
    if [ "$onboarding_complete" == "true" ]; then
      while [ $iter -le 20 ]; do
          echo "Trying to get ClusterConnect Test results"
          if [[ -f "/tmp/results/clusterconnect.xml" && -f "/tmp/results/clusterconnectlog" ]]; then
              echo "ClusterConnect Test Execution Sucessfully Completed"
              break
          fi
          echo "ClusterConnnect Test Execution not complete. Retrying after 30 secs"
          iter=$(($iter+1))
          sleep 30s
      done
      if [ $iter -ge 20 ]; then
        echo "ClusterConnnect Test Execution timed out" > ${results_dir}/error || python3 setup_failure_handler.py
      fi
    fi

    # Sonobuoy worker expects a tar file.
	tar czf results.tar.gz *

	# Signal to the worker that we are done and where to find the results.
	printf ${results_dir}/results.tar.gz > ${results_dir}/done
}

# Ensure that we tell the Sonobuoy worker we are done regardless of results.
trap saveResults EXIT

# Onboarding the cluster to azure-arc
echo "Starting onboarding process"

if [[ -z "${TENANT_ID}" ]]; then
  echo "ERROR: parameter TENANT_ID is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  echo "ERROR: parameter SUBSCRIPTION_ID is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${RESOURCE_GROUP}" ]]; then
  echo "ERROR: parameter RESOURCE_GROUP is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "ERROR: parameter CLUSTER_NAME is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${LOCATION}" ]]; then
  echo "ERROR: parameter LOCATION is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${CLIENT_ID}" ]]; then
  echo "ERROR: parameter CLIENT_ID is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${OBJECT_ID}" ]]; then
  echo "ERROR: parameter OBJECT_ID is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${CLIENT_SECRET}" ]]; then
  echo "ERROR: parameter CLIENT_SECRET is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

APISERVER=https://kubernetes.default.svc/
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt > ca.crt

kubectl config set-cluster azure-arc-onboarding \
  --embed-certs=true \
  --server=${APISERVER} \
  --certificate-authority=./ca.crt 2> ${results_dir}/error || python3 setup_failure_handler.py

kubectl config set-credentials azure-arc-onboarding --token=${TOKEN} 2> ${results_dir}/error || python3 setup_failure_handler.py

# Delete previous rolebinding if exists. And ignore the error if not found.
kubectl delete clusterrolebinding clusterconnect-binding || true
kubectl create clusterrolebinding clusterconnect-binding --clusterrole=cluster-admin --user=${OBJECT_ID} 2> ${results_dir}/error || python3 setup_failure_handler.py

kubectl config set-context azure-arc-onboarding \
  --cluster=azure-arc-onboarding \
  --user=azure-arc-onboarding \
  --namespace=default 2> ${results_dir}/error || python3 setup_failure_handler.py

kubectl config use-context azure-arc-onboarding 2> ${results_dir}/error || python3 setup_failure_handler.py

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

mkdir /tmp/proxy 2> ${results_dir}/error || python3 setup_failure_handler.py
kubectl get secret sonobuoy-proxy-cert -n ${proxy_cert_ns} -o jsonpath='{.data.proxycert}' --ignore-not-found | base64 -d > /tmp/proxy/proxy-cert.crt 2> ${results_dir}/error || python3 setup_failure_handler.py 

# check if the proxy cert file is not empty. It will be empty if the cert secret is not present. Also this section
# add the certificate for the az cli to work under proxy so all the az commands should be below this section.
if [[ -s "/tmp/proxy/proxy-cert.crt" ]]; then
    proxy_params+=(--proxy-cert "/tmp/proxy/proxy-cert.crt" )
    cp /tmp/proxy/proxy-cert.crt /usr/local/share/ca-certificates/proxy-cert.crt 2> ${results_dir}/error || python3 setup_failure_handler.py
    update-ca-certificates 2> ${results_dir}/error || python3 setup_failure_handler.py
    echo "Ran update-ca-certificates"
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
fi

distro_infra_params=()

if [[ ! -z "${DISTRIBUTION}" ]]; then
  distro_infra_params+=(--distribution ${DISTRIBUTION})
fi
if [[ ! -z "${INFRASTRUCTURE}" ]]; then
  distro_infra_params+=(--infrastructure ${INFRASTRUCTURE})
fi

custom_location_oid_param=()
if [[ ! -z "${CUSTOM_LOCATION_OID}" ]]; then
  custom_location_oid_param+=(--custom-locations-oid ${CUSTOM_LOCATION_OID})
fi

debug_params=()
if [[ ! -z "${DEBUG_MODE}" ]]; then
  debug_params+=(--debug)
fi

echo "Azure login"

if [[ ! -z "${CLOUD_NAME}" ]]; then
  az cloud set --name ${CLOUD_NAME} 2> ${results_dir}/error || python3 setup_failure_handler.py
fi

az login --service-principal \
  -u ${CLIENT_ID} \
  -p ${CLIENT_SECRET} \
  --tenant ${TENANT_ID} 2> ${results_dir}/error || python3 setup_failure_handler.py

az account set \
  --subscription ${SUBSCRIPTION_ID} 2> ${results_dir}/error || python3 setup_failure_handler.py

echo "Creating connected cluster resource"
az connectedk8s connect \
  --name ${CLUSTER_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --location ${LOCATION} \
  --disable-auto-upgrade \
  "${proxy_params[@]}" \
  "${distro_infra_params[@]}" \
	"${debug_params[@]}" \
  "${custom_location_oid_param[@]}" 2> ${results_dir}/error || python3 setup_failure_handler.py

echo "Onboarding complete"
onboarding_complete=true

# The variable 'TEST_NAME_LIST' should be provided if we want to run specific tests. If not provided, all tests are run

NUM_PROCESS=$(pytest /conformancetests/ --collect-only  -k "$TEST_NAME_LIST" -m "$TEST_MARKER_LIST" | grep "<Function\|<Class" -c)

export NUM_TESTS="$NUM_PROCESS"

pytest /conformancetests/ --junitxml=/tmp/results/results.xml -d --tx "$NUM_PROCESS"*popen -k "$TEST_NAME_LIST" -m "$TEST_MARKER_LIST"
