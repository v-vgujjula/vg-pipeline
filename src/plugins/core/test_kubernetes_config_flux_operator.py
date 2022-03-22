import pytest
import constants

from kubernetes import config
from msrestazure import azure_cloud

from arm_rest_utility import fetch_aad_token_credentials
from results_utility import append_result_output
from kubernetes_configuration_utility import get_source_control_configuration_client
from kubernetes_configuration_utility import create_kubernetes_configuration
from helper import check_kubernetes_pods_status, check_kubernetes_configuration_state, check_namespace_status

pytestmark = pytest.mark.arcagentstest


def test_kubernetes_configuration_flux_operator(env_dict):
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

    cluster_rp = constants.CLUSTER_RP
    cluster_type = constants.CLUSTER_TYPE
    repository_url = constants.REPOSITORY_URL_FOP
    configuration_name = constants.CONFIGURATION_NAME_FOP
    operator_scope = constants.OPERATOR_SCOPE_FOP
    operator_namespace = constants.OPERATOR_NAMESPACE_FOP
    operator_instance_name = constants.OPERATOR_INSTANCE_NAME_FOP
    operator_params = constants.OPERATOR_PARAMS_FOP
    operator_type = constants.OPERATOR_TYPE
    enable_helm_operator = False
    
    custom_configuration = False

    if (env_dict.get('REPOSITORY_URL_FOP') or env_dict.get('CONFIGURATION_NAME_FOP') or env_dict.get('OPERATOR_SCOPE_FOP')):
        print("Custom configuration provided by the user.")
        custom_configuration = True

        repository_url = env_dict.get('REPOSITORY_URL_FOP')
        if not repository_url:
            pytest.fail('ERROR: variable REPOSITORY_URL_FOP is required.')

        configuration_name = env_dict.get('CONFIGURATION_NAME_FOP')
        if not configuration_name:
            pytest.fail('ERROR: variable CONFIGURATION_NAME_FOP is required.')

        operator_scope = env_dict.get('OPERATOR_SCOPE_FOP')
        if not operator_scope:
            pytest.fail('ERROR: variable OPERATOR_SCOPE_FOP is required.')

        operator_namespace = env_dict.get('OPERATOR_NAMESPACE_FOP') if env_dict.get('OPERATOR_NAMESPACE_FOP') else constants.OPERATOR_NAMESPACE_FOP_DEFAULT
        operator_instance_name = env_dict.get('OPERATOR_INSTANCE_NAME_FOP')
        operator_type = operator_type = env_dict.get('OPERATOR_TYPE_FOP') if env_dict.get('OPERATOR_TYPE_FOP') else constants.OPERATOR_TYPE
        operator_params = env_dict.get('OPERATOR_PARAMS_FOP') if env_dict.get('OPERATOR_PARAMS_FOP') else ''

    # Fetch aad token credentials from spn
    cloud = azure_cloud.get_cloud_from_metadata_endpoint(azure_rmendpoint)
    credential = fetch_aad_token_credentials(tenant_id, client_id, client_secret, cloud.endpoints.active_directory)
    print("Successfully fetched credentials object.")

    kc_client = get_source_control_configuration_client(credential, subscription_id, base_url=cloud.endpoints.resource_manager, credential_scopes=[cloud.endpoints.resource_manager + "/.default"])
    put_kc_response = create_kubernetes_configuration(kc_client, resource_group, repository_url, cluster_rp, cluster_type, cluster_name,
                                                      configuration_name, operator_scope, operator_namespace, operator_instance_name,
                                                      operator_type, operator_params, enable_helm_operator, None, None)
    append_result_output("Create config response: {}\n".format(put_kc_response), env_dict['TEST_KUBERNETES_CONFIG_FOP_LOG_FILE'])
    print("Successfully requested the creation of kubernetes configuration resource.")

    # Checking the compliance of kubernetes configuration resource
    timeout_seconds = env_dict.get('TIMEOUT')
    check_kubernetes_configuration_state(kc_client, resource_group, cluster_rp, cluster_type, cluster_name, configuration_name, env_dict['TEST_KUBERNETES_CONFIG_FOP_LOG_FILE'], timeout_seconds)
    print("The kubernetes configuration resource was created successfully.")

    if not custom_configuration:
        # Loading in-cluster kube-config
        try:
            config.load_incluster_config()
            #config.load_kube_config()
        except Exception as e:
            pytest.fail("Error loading the in-cluster config: " + str(e))

        # Checking the status of namespaces created by the flux operator
        check_namespace_status(env_dict['TEST_KUBERNETES_CONFIG_FOP_LOG_FILE'], constants.FLUX_OPERATOR_NAMESPACE_RESOURCE_LIST, timeout_seconds)

        # Checking the status of pods created by the flux operator
        check_kubernetes_pods_status(constants.OPERATOR_NAMESPACE_FOP, env_dict['TEST_KUBERNETES_CONFIG_FOP_LOG_FILE'], constants.FLUX_OPERATOR_POD_LABEL_LIST, timeout_seconds)
        check_kubernetes_pods_status(constants.FLUX_OPERATOR_RESOURCE_NAMESPACE, env_dict['TEST_KUBERNETES_CONFIG_FOP_LOG_FILE'], constants.FLUX_OPERATOR_RESOURCES_POD_LABEL_LIST, timeout_seconds)
        print("Successfully checked pod status of the flux operator and resources created by it.")