# parentChildAkvSample.py
# Sample: Copy a secret from one Azure Key Vault (Parent) to another (Child)
# using an App Registration (client credentials).
#
# Requires:
#   pip install azure-identity azure-keyvault-secrets
#
# Usage:
#   python parentChildAkvSample.py
#
# Notes:
# - Replace the placeholder values below with your actual tenant ID, client ID, etc.
# - The service principal must have 'get' permission on the Parent vault and
#   'set' permission on the Child vault.

import sys
import time
from typing import Optional, Dict
from azure.identity import ClientSecretCredential
from azure.keyvault.secrets import SecretClient
from azure.core.exceptions import HttpResponseError, ClientAuthenticationError, ResourceNotFoundError

# ---------- CONFIG ----------
TENANT_ID     = "Enter tenant ID"
CLIENT_ID     = "Enter client ID"
CLIENT_SECRET = "Enter client secret"

PARENT_VAULT_URL = "https://<parent-key-vault-name>.vault.azure.net/"
CHILD_VAULT_URL  = "https://<child-key-vault-name>.vault.azure.net/"

SOURCE_SECRET_NAME = "Enter source secret name"
TARGET_SECRET_NAME = "Enter target secret name"  # Can match source or differ

COPY_TAGS = True
COPY_CONTENTTYPE = True
# -----------------------------

def backoff(attempt: int, base: float = 0.8, cap: float = 8.0):
    """Simple exponential backoff."""
    time.sleep(min(cap, base * (2 ** (attempt - 1))))

def get_secret_retry(client: SecretClient, name: str, max_attempts: int = 5):
    """Retrieve secret with retries for transient errors."""
    attempt = 1
    while True:
        try:
            return client.get_secret(name)
        except ResourceNotFoundError:
            raise
        except (HttpResponseError, ClientAuthenticationError) as e:
            status = getattr(e, "status_code", None) or getattr(getattr(e, "response", None), "status_code", None)
            if status in (429, 500, 502, 503, 504) and attempt < max_attempts:
                backoff(attempt)
                attempt += 1
                continue
            raise

def set_secret_retry(client: SecretClient, name: str, value: str,
                     content_type: Optional[str] = None, tags: Optional[Dict[str, str]] = None,
                     max_attempts: int = 5):
    """Write secret with retries for transient errors."""
    attempt = 1
    while True:
        try:
            return client.set_secret(name=name, value=value, content_type=content_type, tags=tags)
        except (HttpResponseError, ClientAuthenticationError) as e:
            status = getattr(e, "status_code", None) or getattr(getattr(e, "response", None), "status_code", None)
            if status in (429, 500, 502, 503, 504) and attempt < max_attempts:
                backoff(attempt)
                attempt += 1
                continue
            raise

def main():
    """Main logic: copy secret from Parent to Child vault."""
    cred = ClientSecretCredential(tenant_id=TENANT_ID, client_id=CLIENT_ID, client_secret=CLIENT_SECRET)

    parent_client = SecretClient(vault_url=PARENT_VAULT_URL, credential=cred)
    child_client  = SecretClient(vault_url=CHILD_VAULT_URL,  credential=cred)

    try:
        src = get_secret_retry(parent_client, SOURCE_SECRET_NAME)
        value = src.value
        ctype = src.properties.content_type if COPY_CONTENTTYPE else None
        tags  = src.properties.tags if (COPY_TAGS and src.properties and src.properties.tags) else None
        print(f"[info] Retrieved '{SOURCE_SECRET_NAME}' from Parent vault.")
    except ResourceNotFoundError:
        print(f"[error] Secret '{SOURCE_SECRET_NAME}' not found in Parent vault.", file=sys.stderr)
        sys.exit(1)

    try:
        set_secret_retry(child_client, TARGET_SECRET_NAME, value, content_type=ctype, tags=tags)
        print(f"[ok] Secret '{TARGET_SECRET_NAME}' successfully written to Child vault.")
    except Exception as e:
        print(f"[error] Failed writing to Child vault: {e}", file=sys.stderr)
        sys.exit(2)

if __name__ == "__main__":
    main()
