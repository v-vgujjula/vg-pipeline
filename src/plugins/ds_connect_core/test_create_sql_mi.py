import pytest
import constants
import subprocess, os
from kubernetes import client, config
pytestmark = pytest.mark.dsarcagentstest

@pytest.mark.skipif(not os.getenv('SQL_INSTANCE_NAME'), reason="SQL_INSTANCE_NAME not found")
def test_create_sql_mi(env_dict):
    namespace = env_dict.get('CUSTOM_LOCATION_NAME')
    if not namespace:
        pytest.fail('ERROR: variable CUSTOM_LOCATION_NAME is required.')
    
    if env_dict.get('SQL_INSTANCE_NAME'):
        sql_name = env_dict.get('SQL_INSTANCE_NAME')
        # Loading in-cluster kube-config
        try:
            config.load_incluster_config()
        except Exception as e:
            pytest.fail("Error loading the in-cluster config: " + str(e))
        
        try:
            api_instance = client.CustomObjectsApi()
            sql_status = api_instance.get_namespaced_custom_object_status(group="sql.arcdata.microsoft.com", version="v1", plural="sqlmanagedinstances", namespace=namespace, name=sql_name)
            if sql_status['status']['state'] != 'Ready':
                pytest.fail('ERROR: SQL managed instance readiness failed')
        except Exception as e:
            pytest.fail("ERROR: SQL managed instance readiness failed: " + str(e))
    else:
        pytest.fail('WARNING: You have not choosen to create SQL server ')
    