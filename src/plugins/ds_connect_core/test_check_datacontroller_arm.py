import pytest
import ds_connect_constants
import subprocess, os
from subprocess import Popen, PIPE, STDOUT
from kubernetes import client, config
from azure.mgmt.resource import ResourceManagementClient
from azure.identity import AzureCliCredential

pytestmark = pytest.mark.dsarcagentstest

def test_check_datacontroller_arm(env_dict):
    namespace = env_dict.get('CUSTOM_LOCATION_NAME')
    if not namespace:
        pytest.fail('ERROR: variable CUSTOM_LOCATION_NAME is required.')
    
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
        resource_uri = '/subscriptions/{}/resourcegroups/{}/providers/Microsoft.AzureArcData/{}/{}'.format(subscription_id,resource_group,"dataControllers","arc-ds-controller")
        resource_client = ResourceManagementClient(credential, subscription_id)
        shadow_resource = resource_client.resources.get_by_id(resource_uri,ds_connect_constants.DATA_CONTROLLER_API_VERSION)
        if shadow_resource.properties["provisioningState"] != "Succeeded":
            pytest.fail('ERROR: Data controller arm status.')
    except Exception as e:
        pytest.fail("Data controller arm status : " + str(e))


    