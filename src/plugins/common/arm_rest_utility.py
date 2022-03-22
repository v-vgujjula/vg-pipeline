import pytest
from azure.identity import ClientSecretCredential


# Function that returns aad token credentials for a given spn
def fetch_aad_token_credentials(tenant_id, client_id, client_secret, authority):
    try:
        return ClientSecretCredential(tenant_id=tenant_id, client_id=client_id, client_secret=client_secret, authority=authority)
    except Exception as e:
        pytest.fail("Error occured while fetching credentials: " + str(e))
