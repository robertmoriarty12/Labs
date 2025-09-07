from flask import Flask, jsonify
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Azure Key Vault configuration
VAULT_URL = os.getenv('AZURE_KEY_VAULT_URL', 'https://your-keyvault-name.vault.azure.net/')
SECRET_NAME = os.getenv('SECRET_NAME', 'success-code')

def get_secret_from_keyvault():
    """Retrieve secret from Azure Key Vault"""
    try:
        logger.info(f"Starting Key Vault authentication process...")
        logger.info(f"Vault URL: {VAULT_URL}")
        logger.info(f"Secret name: {SECRET_NAME}")
        
        # Use DefaultAzureCredential for authentication
        logger.info("Creating DefaultAzureCredential...")
        credential = DefaultAzureCredential()
        logger.info("DefaultAzureCredential created successfully")
        
        logger.info("Creating SecretClient...")
        client = SecretClient(vault_url=VAULT_URL, credential=credential)
        logger.info("SecretClient created successfully")
        
        # Get the secret
        logger.info(f"Attempting to retrieve secret: {SECRET_NAME}")
        secret = client.get_secret(SECRET_NAME)
        logger.info(f"Successfully retrieved secret: {SECRET_NAME}")
        return secret.value
    except Exception as e:
        logger.error(f"Failed to retrieve secret from Key Vault: {str(e)}")
        logger.error(f"Exception type: {type(e).__name__}")
        logger.error(f"Exception details: {repr(e)}")
        return None

@app.route('/')
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "message": "Flask app is running successfully"
    })

@app.route('/api/secret')
def get_secret():
    """Endpoint to retrieve and return the secret from Azure Key Vault"""
    try:
        secret_value = get_secret_from_keyvault()
        
        if secret_value:
            return jsonify({
                "status": "success",
                "message": "You are successful - here's the code.",
                "code": secret_value
            }), 200
        else:
            return jsonify({
                "status": "failure",
                "message": "Failed to retrieve secret from Azure Key Vault",
                "error": "Secret not found or access denied"
            }), 500
            
    except Exception as e:
        logger.error(f"Error in get_secret endpoint: {str(e)}")
        return jsonify({
            "status": "failure",
            "message": "An error occurred while processing your request",
            "error": str(e)
        }), 500

@app.route('/api/status')
def status():
    """Status endpoint to check if the app can connect to Key Vault"""
    try:
        secret_value = get_secret_from_keyvault()
        if secret_value:
            return jsonify({
                "status": "success",
                "message": "Successfully connected to Azure Key Vault",
                "secret_retrieved": True
            }), 200
        else:
            return jsonify({
                "status": "failure",
                "message": "Failed to connect to Azure Key Vault",
                "secret_retrieved": False
            }), 500
    except Exception as e:
        return jsonify({
            "status": "failure",
            "message": "Error connecting to Azure Key Vault",
            "error": str(e)
        }), 500

if __name__ == '__main__':
    # Get port from environment variable or default to 8080
    port = int(os.getenv('PORT', 8080))
    
    logger.info(f"Starting Flask app on port {port}")
    logger.info(f"Key Vault URL: {VAULT_URL}")
    logger.info(f"Secret name: {SECRET_NAME}")
    
    app.run(host='0.0.0.0', port=port, debug=False)
