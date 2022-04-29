import pytest
import os
import pickle
import subprocess
import constants
from filelock import FileLock
from pathlib import Path
from kubernetes import client, config
from kubernetes_namespace_utility import list_namespace, delete_namespace
from kubernetes_deployment_utility import list_deployment, delete_deployment
from kubernetes_service_utility import list_service, delete_service

pytestmark = pytest.mark.dsarcagentstest

# Fixture to collect all the environment variables. It will be run before the tests.
@pytest.fixture(scope='session', autouse=True)
def env_dict():
    my_file = Path("env.pkl")  # File to store the environment variables.
    with FileLock(str(my_file) + ".lock"):  # Locking the file since each test will be run in parallel as separate subprocesses and may try to access the file simultaneously.
        env_dict = {}
        if not my_file.is_file():
            # Collecting DS environment variables.
            env_dict['NUM_TESTS_COMPLETED'] = 0
            env_dict['CONNECTIVITY_MODE'] = os.getenv('CONNECTIVITY_MODE')
            env_dict['SERVICE_TYPE'] = os.getenv('SERVICE_TYPE')
            env_dict['LOCATION'] = os.getenv('LOCATION')
            env_dict['NAMESPACE'] = os.getenv('NAMESPACE')
            env_dict['CONFIG_PROFILE'] = os.getenv('CONFIG_PROFILE')
            env_dict['DATA_CONTROLLER_STORAGE_CLASS'] = os.getenv('DATA_CONTROLLER_STORAGE_CLASS')
            env_dict['SQL_MI_STORAGE_CLASS'] = os.getenv('SQL_MI_STORAGE_CLASS')
            env_dict['PSQL_STORAGE_CLASS'] = os.getenv('PSQL_STORAGE_CLASS')
            env_dict['AZDATA_USERNAME'] = os.getenv('AZDATA_USERNAME')
            env_dict['AZDATA_PASSWORD'] = os.getenv('AZDATA_PASSWORD')
            env_dict['SQL_INSTANCE_NAME'] = os.getenv('SQL_INSTANCE_NAME')
            env_dict['PSQL_SERVERGROUP_NAME'] = os.getenv('PSQL_SERVERGROUP_NAME')
            env_dict['TENANT_ID'] = os.getenv('TENANT_ID')
            env_dict['SUBSCRIPTION_ID'] = os.getenv('SUBSCRIPTION_ID')
            env_dict['RESOURCE_GROUP'] = os.getenv('RESOURCE_GROUP')
            env_dict['CLIENT_ID'] = os.getenv('CLIENT_ID')
            env_dict['CLIENT_SECRET'] = os.getenv('CLIENT_SECRET')
            env_dict['INFRASTRUCTURE'] = os.getenv('INFRASTRUCTURE')

            with Path.open(my_file, "wb") as f:
                pickle.dump(env_dict, f, pickle.HIGHEST_PROTOCOL)
        else:
            with Path.open(my_file, "rb") as f:
                env_dict = pickle.load(f)
        
    yield env_dict
