import requests
import time

count = 0
while count < 1:
    response = requests.post(
        "http://127.0.0.1:8080/completion",
        headers={"Content-Type": "application/json"},
        json={"prompt": "Building a website can be done in 10 simple steps:", "n_predict": 128}
    )

    if response.status_code == 200:
        print("Request successful.")
        print(response.json())  # Assuming the response is JSON and you want to print it
    else:
        print(f"Request failed with status code: {response.status_code}")
    
    count = count + 1

    # Optional: Sleep for a specified time before making the next request
    # time.sleep(1)
