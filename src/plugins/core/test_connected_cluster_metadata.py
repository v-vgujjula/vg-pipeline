import pytest
import time
import constants

from kubernetes import client, config
from msrestazure import azure_cloud

from helper import get_azure_arc_agent_version, check_kubernetes_crd_status
from kubernetes_node_utility import get_kubernetes_node_count
from results_utility import append_result_output
from kubernetes_version_utility import get_kubernetes_server_version
from connected_cluster_utility import get_connected_cluster_client, get_connected_cluster
from arm_rest_utility import fetch_aad_token_credentials

pytestmark = pytest.mark.arcagentstest


def test_cluster_metadata(env_dict):
    tenant_id = env_dict.get('TENANT_ID')
    if not tenant_id:
        pytest.fail('ERROR: variable TENANT_ID is required.')

    subscription_id = env_dict.get('SUBSCRIPTION_ID')
    if not subscription_id:
        pytest.fail('ERROR: variable SUBSCRIPTION_ID is required.')

    resource_group = env_dict.get('RESOURCE_GROUP')
    if not resource_group:
        pytest.fail('ERROR: variable RESOURCE_GROUP is required.')

    cluster_name = env_dict.get('CLUSTER_NAME')
    if not cluster_name:
        pytest.fail('ERROR: variable CLUSTER_NAME is required.')

    client_id = env_dict.get('CLIENT_ID')
    if not client_id:
        pytest.fail('ERROR: variable CLIENT_ID is required.')

    client_secret = env_dict.get('CLIENT_SECRET')
    if not client_secret:
        pytest.fail('ERROR: variable CLIENT_SECRET is required.')
    
    azure_rmendpoint = env_dict.get('AZURE_RM_ENDPOINT')

    print("Starting the check for cluster metadata crd status fields.")

    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
        #config.load_kube_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))

    status_dict = {}
    api_instance = client.CoreV1Api()
    status_dict['nodeCount'] = get_kubernetes_node_count(api_instance)
    status_dict['arcAgentVersion'] = get_azure_arc_agent_version(api_instance, constants.AZURE_ARC_NAMESPACE, constants.ARC_CONFIG_NAME)
    api_instance = client.VersionApi()
    kubernetes_server_version = get_kubernetes_server_version(api_instance)
    status_dict['kubernetesAPIServerVersion'] = kubernetes_server_version[1:]
    append_result_output("Status Dict: {}\n".format(status_dict), env_dict['TEST_CONNECTED_CLUSTER_METADATA_LOG_FILE'])
    print("Generated the status fields dictionary.")

    timeout = env_dict.get('TIMEOUT')
    check_kubernetes_crd_status(constants.CLUSTER_METADATA_CRD_GROUP, constants.CLUSTER_METADATA_CRD_VERSION,
                                constants.AZURE_ARC_NAMESPACE, constants.CLUSTER_METADATA_CRD_PLURAL, 
                                constants.CLUSTER_METADATA_CRD_NAME, status_dict, env_dict['TEST_CONNECTED_CLUSTER_METADATA_LOG_FILE'], timeout)
    print("The status fields have been successfully updated in the CRD instance")

    print("Starting the check of the cluster metadata properties in the connected cluster resource.")

    # Fetch aad token credentials from spn
    cloud = azure_cloud.get_cloud_from_metadata_endpoint(azure_rmendpoint)
    credential = fetch_aad_token_credentials(tenant_id, client_id, client_secret, cloud.endpoints.active_directory)
    print("Successfully fetched credentials object.")

    # Setting a dictionary of cluster metadata fields that will be monitored for presence in the connected cluster resource
    metadata_dict = constants.CLUSTER_METADATA_DICT
    if env_dict.get('CLUSTER_METADATA_FIELDS'):  # This environment variable should be provided as comma separated metadata fields that we want to monitor for the connected cluster
        metadata_fields_list = env_dict.get('CLUSTER_METADATA_FIELDS').split(',')
        for metadata_fields in metadata_fields_list:
            metadata_dict[metadata_fields.strip()] = 0
    append_result_output("Metadata Fields: {}\n".format(list(metadata_dict.keys())), env_dict['TEST_CONNECTED_CLUSTER_METADATA_LOG_FILE'])
    print("Generated the metadata fields dictionary.")

    # Check metadata properties of the connected cluster resource
    cc_client = get_connected_cluster_client(credential, subscription_id, base_url=cloud.endpoints.resource_manager, credential_scopes=[cloud.endpoints.resource_manager + "/.default"])
    timeout_seconds = env_dict.get('TIMEOUT')
    timeout = time.time() + timeout_seconds
    while True:
        cc_object = get_connected_cluster(cc_client, resource_group, cluster_name)
        for metadata_field in metadata_dict.keys():
            try:
                metadata_field_value = getattr(cc_object, metadata_field)
            except Exception as e:
                pytest.fail("Error occured while fetching connected cluster attribute: " + str(e))
            append_result_output("{}: {}\n".format(metadata_field, metadata_field_value), env_dict['TEST_CONNECTED_CLUSTER_METADATA_LOG_FILE'])
            if metadata_field_value:
                metadata_dict[metadata_field] = 1
        if all(ele == 1 for ele in list(metadata_dict.values())):
            break
        time.sleep(10)
        if time.time() > timeout:
            pytest.fail("ERROR: Timeout. The connected cluster has not been updated with metadata properties.")
    print("The connected cluster resource was updated with metadata properties successfully.")