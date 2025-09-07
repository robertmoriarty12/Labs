const express = require('express');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Azure Key Vault configuration
const keyVaultUrl = process.env.KEY_VAULT_URL || 'https://your-keyvault.vault.azure.net/';
const credential = new DefaultAzureCredential();
const secretClient = new SecretClient(keyVaultUrl, credential);

// Routes
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.post('/api/check-secret', async (req, res) => {
    try {
        const { input } = req.body;
        
        if (!input) {
            return res.status(400).json({ 
                error: 'Input is required',
                message: 'Please provide some text to check'
            });
        }

        // If user enters "secret", retrieve the actual secret from Key Vault
        if (input.toLowerCase() === 'secret') {
            try {
                const secretName = 'demo-secret';
                const secret = await secretClient.getSecret(secretName);
                
                res.json({
                    success: true,
                    input: input,
                    secretValue: secret.value,
                    message: 'Secret retrieved successfully from Key Vault!',
                    timestamp: new Date().toISOString()
                });
            } catch (keyVaultError) {
                console.error('Key Vault error:', keyVaultError);
                res.status(500).json({
                    error: 'Failed to retrieve secret',
                    message: 'Could not access Key Vault. Check managed identity permissions.',
                    details: keyVaultError.message
                });
            }
        } else {
            // For any other input, just echo it back
            res.json({
                success: true,
                input: input,
                message: `You entered: "${input}". Try entering "secret" to see the Key Vault integration!`,
                timestamp: new Date().toISOString()
            });
        }
    } catch (error) {
        console.error('Server error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: 'Something went wrong on the server',
            details: error.message
        });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development'
    });
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Key Vault URL: ${keyVaultUrl}`);
    console.log('App is ready for WAF and Private Endpoint testing!');
});
