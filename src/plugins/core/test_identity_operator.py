import pytest
import constants

from kubernetes import config
from results_utility import append_result_output
from helper import check_kubernetes_crd_status, check_kubernetes_secret

pytestmark = pytest.mark.arcagentstest


def test_identity_operator(env_dict):
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))
    
    timeout_seconds = env_dict.get('TIMEOUT')

    # Checking identity certificate secret
    print("Checking the azure identity certificate secret.")
    check_kubernetes_secret(constants.AZURE_ARC_NAMESPACE, constants.AZURE_IDENTITY_CERTIFICATE_SECRET, timeout_seconds)
    print("The azure identity certificate secret data was retrieved successfully.")

    # Checking if the crd instance has been updated with token reference
    print("Checking if the crd instance has been updated with token reference.")
    status_dict = {}
    status_dict['tokenReference'] = constants.IDENTITY_TOKEN_REFERENCE_DICTIONARY
    append_result_output("Status Dict: {}\n".format(status_dict), env_dict['TEST_IDENTITY_OPERATOR_LOG_FILE'])
    print("Generated the status fields dictionary.")

    check_kubernetes_crd_status(constants.CLUSTER_IDENTITY_CRD_GROUP, constants.CLUSTER_IDENTITY_CRD_VERSION,
                                constants.AZURE_ARC_NAMESPACE, constants.CLUSTER_IDENTITY_CRD_PLURAL, 
                                constants.CLUSTER_IDENTITY_CRD_NAME, status_dict, env_dict['TEST_IDENTITY_OPERATOR_LOG_FILE'], timeout_seconds)
    print("The status fields have been successfully updated in the CRD instance")

    # Checking identity token secret
    print("Checking the azure identity token secret.")
    check_kubernetes_secret(constants.AZURE_ARC_NAMESPACE, constants.AZURE_IDENTITY_TOKEN_SECRET, timeout_seconds)
    print("The azure identity token secret data was retrieved successfully.")