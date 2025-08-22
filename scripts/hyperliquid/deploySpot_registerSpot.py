import requests
import argparse
from hyperliquid.utils import constants
from hyperliquid.utils.signing import get_timestamp_ms
from ledger_utils import ledger_sign_l1_action
from ledgereth import accounts
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Read CORE_SPOT_TOKEN_ID from .env file
CORE_SPOT_TOKEN_ID = int(os.getenv("CORE_SPOT_TOKEN_ID", 0))
if CORE_SPOT_TOKEN_ID == 0:
    raise ValueError("CORE_SPOT_TOKEN_ID is not set")
print(f"CORE_SPOT_TOKEN_ID: {CORE_SPOT_TOKEN_ID}")

# get ledger index from command line
parser = argparse.ArgumentParser(description='Deploy spot with Ledger')
parser.add_argument('--ledger-index', type=int, default=9, help='Ledger account index to use')
args = parser.parse_args()
derivation_path = f"44'/60'/{args.ledger_index}'/0/0"

# get account from ledger
account = accounts.get_account_by_path(derivation_path)
print(f"Running with address {account.address} (Ledger index {args.ledger_index})")

registerSpot_action = {
    "type": "spotDeploy",
    "registerSpot": {
        "tokens": [CORE_SPOT_TOKEN_ID,0],
    }
}
print(registerSpot_action)
nonce = get_timestamp_ms()
signature = ledger_sign_l1_action(registerSpot_action, None, nonce, None, True, derivation_path)
payload = {
    "action": registerSpot_action,
    "nonce": nonce,
    "signature": signature,
    "vaultAddress": None,
}
print(f"payload: {payload}")
response = requests.post(constants.MAINNET_API_URL + "/exchange", json=payload)
print(response.json())