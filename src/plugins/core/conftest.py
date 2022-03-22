import pytest
import os
import pickle

import constants

from msrestazure import azure_cloud
from filelock import FileLock
from pathlib import Path
from kubernetes import client, config
from arm_rest_utility import fetch_aad_token_credentials
from results_utility import append_result_output
from kubernetes_namespace_utility import list_namespace, delete_namespace
from kubernetes_deployment_utility import list_deployment, delete_deployment
from kubernetes_service_utility import list_service, delete_service
from kubernetes_configuration_utility import delete_kubernetes_configuration, get_source_control_configuration_client


pytestmark = pytest.mark.arcagentstest

# Fixture to collect all the environment variables, install the helm charts and check the status of azure arc pods. It will be run before the tests.
@pytest.fixture(scope='session', autouse=True)
def env_dict():
    my_file = Path("env.pkl")  # File to store the environment variables.
    with FileLock(str(my_file) + ".lock"):  # Locking the file since each test will be run in parallel as separate subprocesses and may try to access the file simultaneously.
        env_dict = {}
        if not my_file.is_file():

            # Setting some environment variables
            env_dict['TEST_CONNECTED_CLUSTER_METADATA_LOG_FILE'] = '/tmp/results/testccmetadata'
            env_dict['TEST_IDENTITY_OPERATOR_LOG_FILE'] = '/tmp/results/identityop'
            env_dict['TEST_METRICS_AND_LOGGING_AGENT_LOG_FILE'] = '/tmp/results/metricsandlogs'
            env_dict['TEST_KUBERNETES_CONFIG_FOP_LOG_FILE'] = '/tmp/results/k8sconfigfop'
            env_dict['TEST_KUBERNETES_CONFIG_HOP_LOG_FILE'] = '/tmp/results/k8sconfighop'
            env_dict['FIXTURE_LOG_FILE'] = '/tmp/results/fixture'
            env_dict['NUM_TESTS_COMPLETED'] = 0

            # Collecting environment variables
            env_dict['TENANT_ID'] = os.getenv('TENANT_ID')
            env_dict['SUBSCRIPTION_ID'] = os.getenv('SUBSCRIPTION_ID')
            env_dict['RESOURCE_GROUP'] = os.getenv('RESOURCE_GROUP')
            env_dict['CLUSTER_NAME'] = os.getenv('CLUSTER_NAME')
            env_dict['CLIENT_ID'] = os.getenv('CLIENT_ID')
            env_dict['CLIENT_SECRET'] = os.getenv('CLIENT_SECRET')

            env_dict['AZURE_RM_ENDPOINT'] = os.getenv('AZURE_RM_ENDPOINT') if os.getenv('AZURE_RM_ENDPOINT') else constants.DEFAULT_AZURE_RMENDPOINT

            env_dict['TIMEOUT'] = int(os.getenv('TIMEOUT')) if os.getenv('TIMEOUT') else constants.TIMEOUT

            env_dict['CLUSTER_METADATA_FIELDS'] = os.getenv('CLUSTER_METADATA_FIELDS')

            env_dict['METRICS_AGENT_LOG_LIST'] = os.getenv('METRICS_AGENT_LOG_LIST')
            env_dict['FLUENT_BIT_LOG_LIST'] = os.getenv('FLUENT_BIT_LOG_LIST')

            env_dict['CLUSTER_TYPE'] = os.getenv('CLUSTER_TYPE')
            env_dict['CLUSTER_RP'] = os.getenv('CLUSTER_RP')
            env_dict['CONFIGURATION_NAME_HOP'] = os.getenv('CONFIGURATION_NAME_HOP')
            env_dict['REPOSITORY_URL_HOP'] = os.getenv('REPOSITORY_URL_HOP')
            env_dict['OPERATOR_SCOPE_HOP'] = os.getenv('OPERATOR_SCOPE_HOP')
            env_dict['OPERATOR_NAMESPACE_HOP'] = os.getenv('OPERATOR_NAMESPACE_HOP')
            env_dict['OPERATOR_INSTANCE_NAME_HOP'] = os.getenv('OPERATOR_INSTANCE_NAME_HOP')
            env_dict['OPERATOR_TYPE_HOP'] = os.getenv('OPERATOR_TYPE_HOP')
            env_dict['OPERATOR_PARAMS_HOP'] = os.getenv('OPERATOR_PARAMS_HOP')
            env_dict['HELM_OPERATOR_VERSION_HOP'] = os.getenv('HELM_OPERATOR_VERSION_HOP')
            env_dict['HELM_OPERATOR_PARAMS_HOP'] = os.getenv('HELM_OPERATOR_PARAMS_HOP')

            env_dict['CONFIGURATION_NAME_FOP'] = os.getenv('CONFIGURATION_NAME_FOP')
            env_dict['REPOSITORY_URL_FOP'] = os.getenv('REPOSITORY_URL_FOP')
            env_dict['OPERATOR_SCOPE_FOP'] = os.getenv('OPERATOR_SCOPE_FOP')
            env_dict['OPERATOR_NAMESPACE_FOP'] = os.getenv('OPERATOR_NAMESPACE_FOP')
            env_dict['OPERATOR_INSTANCE_NAME_FOP'] = os.getenv('OPERATOR_INSTANCE_NAME_FOP')
            env_dict['OPERATOR_TYPE_FOP'] = os.getenv('OPERATOR_TYPE_FOP')
            env_dict['OPERATOR_PARAMS_FOP'] = os.getenv('OPERATOR_PARAMS_FOP')

            with Path.open(my_file, "wb") as f:
                pickle.dump(env_dict, f, pickle.HIGHEST_PROTOCOL)
        else:
            with Path.open(my_file, "rb") as f:
                env_dict = pickle.load(f)
        
    yield env_dict
    
    my_file = Path("env.pkl")
    with FileLock(str(my_file) + ".lock"):
        with Path.open(my_file, "rb") as f:
            env_dict = pickle.load(f)

        env_dict['NUM_TESTS_COMPLETED'] = 1 + env_dict.get('NUM_TESTS_COMPLETED')
        if env_dict['NUM_TESTS_COMPLETED'] == int(os.getenv('NUM_TESTS')):
            # Checking if cleanup is required.
            if os.getenv('SKIP_CLEANUP'):
                return
            print('Starting cleanup...')


            # Loading in-cluster kube config
            try:
                config.load_incluster_config()
            except Exception as e:
                pytest.fail("Error loading the in-cluster config: " + str(e))
            api_instance = client.CoreV1Api()
            
            # Cleaning up resources created by default configurations
            print("Cleaning up the resources create by the flux operators")
            append_result_output("Cleaning up the resources create by the flux operators\n", env_dict['FIXTURE_LOG_FILE'])
            cleanup_namespace_list = constants.CLEANUP_NAMESPACE_LIST
            namespace_list = list_namespace(api_instance)
            for ns in namespace_list.items:
                namespace_name = ns.metadata.name
                if namespace_name in cleanup_namespace_list:
                    delete_namespace(api_instance, namespace_name)
            
            api_instance = client.AppsV1Api()
            cleanup_deployment_list = constants.CLEANUP_DEPLOYMENT_LIST
            deployment_list = list_deployment(api_instance, constants.FLUX_OPERATOR_RESOURCE_NAMESPACE)
            for deployment in deployment_list.items:
                deployment_name = deployment.metadata.name
                if deployment_name in cleanup_deployment_list:
                    delete_deployment(api_instance, constants.FLUX_OPERATOR_RESOURCE_NAMESPACE, deployment_name)

            api_instance = client.CoreV1Api()
            cleanup_service_list = constants.CLEANUP_SERVICE_LIST
            service_list = list_service(api_instance, constants.FLUX_OPERATOR_RESOURCE_NAMESPACE)
            for service in service_list.items:
                service_name = service.metadata.name
                if service_name in cleanup_service_list:
                    delete_service(api_instance, constants.FLUX_OPERATOR_RESOURCE_NAMESPACE, service_name)

            # We do our best to try to delete the configurations here
            append_result_output("Force Deleting the source control configurations from the cluster\n", env_dict['FIXTURE_LOG_FILE'])
            try:
                force_delete_configurations(
                    env_dict["AZURE_RM_ENDPOINT"],
                    env_dict["SUBSCRIPTION_ID"],
                    env_dict["TENANT_ID"],
                    env_dict["CLIENT_ID"],
                    env_dict["CLIENT_SECRET"],
                    env_dict["RESOURCE_GROUP"],
                    env_dict["CLUSTER_NAME"],
                    [constants.CONFIGURATION_NAME_HOP, constants.CONFIGURATION_NAME_FOP],
                )
            except Exception as e:
                append_result_output("Failed to force delete the configurations with {}\n".format(e), env_dict['FIXTURE_LOG_FILE'])
                pass
                
            print("Cleanup Complete.")
            return

        with Path.open(my_file, "wb") as f:
            pickle.dump(env_dict, f, pickle.HIGHEST_PROTOCOL)
            

# Force delete the sourceContorlConfigurations from the cluster
# so that we are cleaned-up for subsequent runs
def force_delete_configurations(
    azure_rmendpoint,
    subscription_id,
    tenant_id,
    client_id,
    client_secret,
    resource_group,
    cluster_name,
    configuration_names,
):
    # Fetch aad token credentials from spn
    cloud = azure_cloud.get_cloud_from_metadata_endpoint(azure_rmendpoint)
    credential = fetch_aad_token_credentials(
        tenant_id, client_id, client_secret, cloud.endpoints.active_directory
    )
    kc_client = get_source_control_configuration_client(credential, subscription_id, base_url=cloud.endpoints.resource_manager, credential_scopes=[cloud.endpoints.resource_manager + "/.default"])

    for configuration_name in configuration_names:
        try:
            delete_kubernetes_configuration(
                kc_client,
                resource_group,
                constants.CLUSTER_RP,
                constants.CLUSTER_TYPE,
                cluster_name,
                configuration_name,
            ).result()
        except Exception as e:
            append_result_output("Failed to delete the configuration {} with the error {}\n".format(configuration_name, e), env_dict['FIXTURE_LOG_FILE'])
            pass