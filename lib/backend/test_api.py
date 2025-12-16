"""
Test script to verify the API server is working correctly
"""
import requests
import json
from pathlib import Path

BASE_URL = "http://localhost:8000"

def test_health_check():
    """Test the health check endpoint"""
    print("Testing health check...")
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        print(f"✓ Status Code: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print(f"✓ Response: {json.dumps(data, indent=2)}")
            return True
        else:
            print(f"✗ Unexpected status code: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("✗ Could not connect to server. Is it running?")
        print("  Run: python api_server.py")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


def test_analyze_audio(audio_file="a0001.wav", gestation_period="24 weeks"):
    """Test the audio analysis endpoint"""
    print(f"\nTesting audio analysis with {audio_file}...")

    # Check if audio file exists
    audio_path = Path(audio_file)
    if not audio_path.exists():
        print(f"✗ Audio file not found: {audio_file}")
        print("  Please provide a valid WAV file for testing")
        return False

    try:
        with open(audio_path, 'rb') as f:
            files = {'audio_file': (audio_file, f, 'audio/wav')}
            data = {'gestation_period': gestation_period}

            response = requests.post(
                f"{BASE_URL}/analyze",
                files=files,
                data=data,
                timeout=30
            )

        print(f"✓ Status Code: {response.status_code}")

        if response.status_code == 200:
            result = response.json()
            print("\n" + "="*60)
            print("ANALYSIS RESULT")
            print("="*60)
            print(f"Prediction: {result['predicted_label']}")
            print(f"Confidence: {result['confidence']:.2%}")
            print(f"Status: {result['status']}")
            print(f"\nMessage: {result['message']}")
            print(f"\nRecommendation: {result['recommendation']}")
            print(f"\nProbabilities:")
            for label, prob in result['probabilities'].items():
                print(f"  {label}: {prob:.2%}")
            print(f"\nGestation Period: {result['gestation_period']}")
            print("="*60)
            return True
        else:
            print(f"✗ Error response: {response.text}")
            return False

    except requests.exceptions.Timeout:
        print("✗ Request timed out (30s). Server might be processing...")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


def main():
    print("="*60)
    print("GarbhSuraksha API Test Suite")
    print("="*60)
    print()

    # Test 1: Health check
    health_ok = test_health_check()

    if not health_ok:
        print("\n❌ Health check failed. Cannot proceed with further tests.")
        print("\nMake sure the server is running:")
        print("  cd lib/backend")
        print("  python api_server.py")
        return

    # Test 2: Audio analysis
    print()
    analyze_ok = test_analyze_audio()

    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    print(f"Health Check: {'✓ PASS' if health_ok else '✗ FAIL'}")
    print(f"Audio Analysis: {'✓ PASS' if analyze_ok else '✗ FAIL'}")
    print("="*60)

    if health_ok and analyze_ok:
        print("\n🎉 All tests passed! The backend is working correctly.")
        print("\nYou can now:")
        print("  1. Run the Flutter app: flutter run")
        print("  2. Enter gestation period and record/upload audio")
        print("  3. Click 'Analyze' to get predictions")
    else:
        print("\n⚠️  Some tests failed. Please check the errors above.")


if __name__ == "__main__":
    main()

