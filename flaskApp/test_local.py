#!/usr/bin/env python3
"""
Simple test script to verify the Flask application endpoints
"""

import requests
import time
import sys

def test_endpoint(url, description):
    """Test an endpoint and print the result"""
    try:
        print(f"\nTesting {description}...")
        print(f"URL: {url}")
        
        response = requests.get(url, timeout=10)
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
        return response.status_code == 200
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        return False
    except Exception as e:
        print(f"Unexpected error: {e}")
        return False

def main():
    """Main test function"""
    base_url = "http://localhost:80"
    
    print("Flask App Test Script")
    print("=" * 50)
    print("Make sure the Flask app is running on localhost:80")
    print("You can start it with: python app.py")
    print()
    
    # Wait a moment for user to read
    time.sleep(2)
    
    # Test health check
    health_success = test_endpoint(f"{base_url}/", "Health Check")
    
    # Test status endpoint
    status_success = test_endpoint(f"{base_url}/api/status", "Status Check")
    
    # Test secret endpoint
    secret_success = test_endpoint(f"{base_url}/api/secret", "Secret Retrieval")
    
    # Summary
    print("\n" + "=" * 50)
    print("Test Summary:")
    print(f"Health Check: {'✓ PASS' if health_success else '✗ FAIL'}")
    print(f"Status Check: {'✓ PASS' if status_success else '✗ FAIL'}")
    print(f"Secret Retrieval: {'✓ PASS' if secret_success else '✗ FAIL'}")
    
    if all([health_success, status_success, secret_success]):
        print("\n🎉 All tests passed!")
        return 0
    else:
        print("\n❌ Some tests failed. Check the output above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
