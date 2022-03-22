import pytest
import constants

from kubernetes import config
from msrestazure import azure_cloud

from arm_rest_utility import fetch_aad_token_credentials
from results_utility import append_result_output
from kubernetes_configuration_utility import get_source_control_configuration_client
from kubernetes_configuration_utility import create_kubernetes_configuration
from helper import check_kubernetes_pods_status, check_kubernetes_configuration_state

pytestmark = pytest.mark.arcagentstest


def test_kubernetes_configuration_helm_operator(env_dict):
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
    repository_url = constants.REPOSITORY_URL_HOP
    configuration_name = constants.CONFIGURATION_NAME_HOP
    operator_scope = constants.OPERATOR_SCOPE_HOP
    operator_namespace = constants.OPERATOR_NAMESPACE_HOP
    operator_instance_name = constants.OPERATOR_INSTANCE_NAME_HOP
    operator_params = constants.OPERATOR_PARAMS_HOP
    operator_type = constants.OPERATOR_TYPE
    enable_helm_operator = True
    helm_operator_version = constants.HELM_OPERATOR_VERSION
    helm_operator_params = constants.HELM_OPERATOR_PARAMS_HOP

    custom_configuration = False

    if (env_dict.get('REPOSITORY_URL_HOP') or env_dict.get('CONFIGURATION_NAME_HOP') or env_dict.get('OPERATOR_SCOPE_HOP')):
        print("Custom configuration provided by the user.")
        custom_configuration = True

        repository_url = env_dict.get('REPOSITORY_URL_HOP')
        if not repository_url:
            pytest.fail('ERROR: variable REPOSITORY_URL_HOP is required.')

        configuration_name = env_dict.get('CONFIGURATION_NAME_HOP')
        if not configuration_name:
            pytest.fail('ERROR: variable CONFIGURATION_NAME_HOP is required.')

        operator_scope = env_dict.get('OPERATOR_SCOPE_HOP')
        if not operator_scope:
            pytest.fail('ERROR: variable OPERATOR_SCOPE_HOP is required.')

        operator_namespace = env_dict.get('OPERATOR_NAMESPACE_HOP') if env_dict.get('OPERATOR_NAMESPACE_HOP') else constants.OPERATOR_NAMESPACE_HOP_DEFAULT
        operator_instance_name = env_dict.get('OPERATOR_INSTANCE_NAME_HOP')
        operator_type = env_dict.get('OPERATOR_TYPE_HOP') if env_dict.get('OPERATOR_TYPE_HOP') else constants.OPERATOR_TYPE 
        operator_params = env_dict.get('OPERATOR_PARAMS_HOP') if env_dict.get('OPERATOR_PARAMS_HOP') else ''
        helm_operator_version = env_dict.get('HELM_OPERATOR_VERSION_HOP') if env_dict.get('HELM_OPERATOR_VERSION_HOP') else constants.HELM_OPERATOR_VERSION
        helm_operator_params = env_dict.get('HELM_OPERATOR_PARAMS_HOP') if env_dict.get('HELM_OPERATOR_PARAMS_HOP') else ''
    

    # Fetch aad token credentials from spn
    cloud = azure_cloud.get_cloud_from_metadata_endpoint(azure_rmendpoint)
    credential = fetch_aad_token_credentials(tenant_id, client_id, client_secret, cloud.endpoints.active_directory)
    print("Successfully fetched credentials object.")

    kc_client = get_source_control_configuration_client(credential, subscription_id, base_url=cloud.endpoints.resource_manager, credential_scopes=[cloud.endpoints.resource_manager + "/.default"])
    put_kc_response = create_kubernetes_configuration(kc_client, resource_group, repository_url, cluster_rp, cluster_type, cluster_name,
                                                      configuration_name, operator_scope, operator_namespace, operator_instance_name,
                                                      operator_type, operator_params, enable_helm_operator, helm_operator_version,
                                                      helm_operator_params)
    append_result_output("Create config response: {}\n".format(put_kc_response), env_dict['TEST_KUBERNETES_CONFIG_HOP_LOG_FILE'])
    print("Successfully requested the creation of kubernetes configuration resource.")

    # Checking the compliance of kubernetes configuration resource
    timeout_seconds = env_dict.get('TIMEOUT')
    check_kubernetes_configuration_state(kc_client, resource_group, cluster_rp, cluster_type, cluster_name, configuration_name, env_dict['TEST_KUBERNETES_CONFIG_HOP_LOG_FILE'], timeout_seconds)
    print("The kubernetes configuration resource was created successfully.")

    if not custom_configuration:
        # Loading in-cluster kube-config
        try:
            config.load_incluster_config()
            #config.load_kube_config()
        except Exception as e:
            pytest.fail("Error loading the in-cluster config: " + str(e))

        # Checking the status of pods created by the helm operator
        check_kubernetes_pods_status(constants.OPERATOR_NAMESPACE_HOP, env_dict['TEST_KUBERNETES_CONFIG_HOP_LOG_FILE'], constants.HELM_OPERATOR_POD_LABEL_LIST, timeout_seconds)
        print("Successfully checked pod status of the helm operator and resources created by it.")