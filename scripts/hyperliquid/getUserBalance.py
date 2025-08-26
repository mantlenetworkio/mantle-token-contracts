import requests
from hyperliquid.utils import constants

payload = {
    "type": "spotClearinghouseState",
    "user": "0x427deF1c9d4a067cf7A2e0a1bd3b6280a6bC2bE5"
}
response = requests.post(constants.MAINNET_API_URL + "/info", json=payload)
print(response.json())