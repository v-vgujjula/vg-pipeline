from azure.mgmt.resource import ResourceManagementClient
from azure.identity import AzureCliCredential
import os
import ds_connect_constants
import pytest
import time
from kubernetes import client,config
### sleep for 2mins
sleep_time = 120
pytestmark = pytest.mark.dsarcagentstest    
@pytest.mark.trylast
@pytest.mark.skipif(os.getenv('SKIP_CLEANUP') == "true", reason="Clean up not requested")
def test_ds_direct_cleanup(env_dict):
    namespace = env_dict.get('NAMESPACE')
    if not namespace:
        pytest.fail('ERROR: variable NAMESPACE is required.')

    subscription_id = env_dict.get('SUBSCRIPTION_ID')
    if not subscription_id:
        pytest.fail('ERROR: variable SUBSCRIPTION_ID is required.')

    resource_group = env_dict.get('RESOURCE_GROUP')
    if not resource_group:
        pytest.fail('ERROR: variable RESOURCE_GROUP is required.')
    
    try:
        credential = AzureCliCredential()
    except Exception as e:
        pytest.fail("AzureCliCredentials failed : " + str(e))

    try:
        resource_client = ResourceManagementClient(credential, subscription_id)
        ## Delete resources in sequential order
        ## postgresql delete
        resource_list = resource_client.resources.list_by_resource_group(resource_group, expand = "createdTime,changedTime")
        for resource in list(resource_list):
            if env_dict.get('PSQL_SERVERGROUP_NAME') and resource.type == ds_connect_constants.POSTGRES_TYPE and  resource.name == env_dict.get('PSQL_SERVERGROUP_NAME'):
                print(f"{resource.name}  {resource.type} ")
                time.sleep(sleep_time)
                resource_client.resources.begin_delete_by_id(resource.id, ds_connect_constants.POSTGRES_API_VERSION)
        ## sql mi delete
        resource_list = resource_client.resources.list_by_resource_group(resource_group, expand = "createdTime,changedTime")
        for resource in list(resource_list):
            if env_dict.get('SQL_INSTANCE_NAME') and resource.type == ds_connect_constants.SQL_MI_TYPE and  resource.name == env_dict.get('SQL_INSTANCE_NAME'):
                print(f"{resource.name}  {resource.type} ")
                time.sleep(sleep_time)
                resource_client.resources.begin_delete_by_id(resource.id, ds_connect_constants.SQL_MI_API_VERSION)
        ## data controller arm delete
        resource_uri = '/subscriptions/{}/resourcegroups/{}/providers/Microsoft.AzureArcData/{}/{}'.format(subscription_id,resource_group,"dataControllers",namespace)
        dc_shadow_resource = resource_client.resources.get_by_id(resource_uri,ds_connect_constants.DATA_CONTROLLER_API_VERSION)
        if dc_shadow_resource and dc_shadow_resource.name == namespace:
            time.sleep(sleep_time)
            resource_client.resources.begin_delete_by_id(dc_shadow_resource.id,ds_connect_constants.DATA_CONTROLLER_API_VERSION)
        ## custom location delete
        resource_uri = '/subscriptions/{}/resourcegroups/{}/providers/Microsoft.ExtendedLocation/{}/{}'.format(subscription_id,resource_group,"customLocations",os.environ['CUSTOM_LOCATION_NAME'])  
        cl_shadow_resource = resource_client.resources.get_by_id(resource_uri,ds_connect_constants.CUSTOM_LOCAION_API_VERSION)
        if cl_shadow_resource and cl_shadow_resource.name == os.environ['CUSTOM_LOCATION_NAME']:
            time.sleep(sleep_time)
            resource_client.resources.begin_delete_by_id(cl_shadow_resource.id,ds_connect_constants.CUSTOM_LOCAION_API_VERSION)
        ## k8 extension delete
        resource_uri = '/subscriptions/{}/resourcegroups/{}/providers/Microsoft.Kubernetes/connectedClusters/{}/providers/Microsoft.KubernetesConfiguration/{}/{}'.format(subscription_id,resource_group,os.environ['K8S_EXTN_NAME'],"extensions",os.environ['K8S_EXTN_NAME'])
        shadow_resource = resource_client.resources.get_by_id(resource_uri,ds_connect_constants.CONNECTED_CLUSTER_EXTENSION_API_VERSION)
        if shadow_resource and shadow_resource.name == os.environ['K8S_EXTN_NAME']:
            time.sleep(sleep_time)
            resource_client.resources.begin_delete_by_id(shadow_resource.id,ds_connect_constants.CONNECTED_CLUSTER_EXTENSION_API_VERSION)

        ## Delete namespace
        try:
            config.load_incluster_config()
        except Exception as e:
            pytest.fail("Error loading the in-cluster config: " + str(e))
    
        v1 = client.CoreV1Api()
        try:
            for ns in v1.list_namespace().items:
                if ns.metadata.name == namespace:
                    time.sleep(sleep_time)
                    print(ns.metadata.name)
                    ns_status=v1.delete_namespace(namespace)
                    time.sleep(sleep_time)
                    break
        except Exception as e:
            pytest.fail("Unable to delete the requested namespace : " + str(e))

    except Exception as e:
        pytest.fail("deleting resources failed : " + str(e))

    
    
