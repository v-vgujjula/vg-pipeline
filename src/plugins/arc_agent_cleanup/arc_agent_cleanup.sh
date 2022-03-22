#!/bin/bash
set -e

results_dir="${RESULTS_DIR:-/tmp/results}"
proxy_cert_ns="default"

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

if [[ ! -z "${PROXY_CERT_NAMESPACE}" ]]; then
  proxy_cert_ns=${PROXY_CERT_NAMESPACE}
fi

mkdir /tmp/proxy 2> ${results_dir}/error || python3 setup_failure_handler.py
kubectl get secret sonobuoy-proxy-cert -n ${proxy_cert_ns} -o jsonpath='{.data.proxycert}' --ignore-not-found | base64 -d > /tmp/proxy/proxy-cert.crt 2> ${results_dir}/error || python3 setup_failure_handler.py

# check if the proxy cert file is not empty. It will be empty if the cert secret is not present.
if [[ -s "/tmp/proxy/proxy-cert.crt" ]]; then
    cp /tmp/proxy/proxy-cert.crt /usr/local/share/ca-certificates/proxy-cert.crt 2> ${results_dir}/error || python3 setup_failure_handler.py
    update-ca-certificates 2> ${results_dir}/error || python3 setup_failure_handler.py
    echo "Ran update-ca-certificates"
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
fi

pytest cleanup.py --junitxml=/tmp/results/results.xml
