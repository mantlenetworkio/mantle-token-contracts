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

# Read USER_AND_WEI from .env file
USER_AND_WEI_STR = os.getenv("USER_AND_WEI", "")
if not USER_AND_WEI_STR:
    raise ValueError("USER_AND_WEI is not set in .env file")

# Parse USER_AND_WEI from string format: "address:amount,address2:amount2"
try:
    user_and_wei = []
    uint64_max = 18446744073709551615  # 2^64 - 1
    
    for pair in USER_AND_WEI_STR.split(','):
        if ':' in pair:
            address, amount = pair.strip().split(':', 1)
            address = address.strip().lower()
            amount = amount.strip()
            
            # Sanity check: no zero address
            if address == "0x0000000000000000000000000000000000000000" or address == "0x0":
                raise ValueError(f"Zero address not allowed: {address}")
            
            # Sanity check: amount must be a valid number
            try:
                amount_int = int(amount)
                if amount_int <= 0:
                    raise ValueError(f"Amount must be positive: {amount}")
                if amount_int > uint64_max:
                    raise ValueError(f"Amount exceeds uint64.max ({uint64_max}): {amount}")
            except ValueError as e:
                if "exceeds uint64.max" in str(e):
                    raise e
                raise ValueError(f"Invalid amount format: {amount}")
            
            user_and_wei.append([address, amount])
        else:
            raise ValueError(f"Invalid USER_AND_WEI format: {pair}")
    
    if not user_and_wei:
        raise ValueError("USER_AND_WEI must contain at least one address:amount pair")
    
    # Print parsed user and wei data for verification
    print("Parsed USER_AND_WEI:")
    for i, (address, amount) in enumerate(user_and_wei):
        print(f"  User {i+1}: {address} -> {amount}")
    print()
        
except Exception as e:
    raise ValueError(f"Failed to parse USER_AND_WEI: {e}")

# get ledger index from command line
parser = argparse.ArgumentParser(description='Deploy spot with Ledger')
parser.add_argument('--ledger-index', type=int, default=9, help='Ledger account index to use')
args = parser.parse_args()
derivation_path = f"44'/60'/{args.ledger_index}'/0/0"

# get account from ledger
account = accounts.get_account_by_path(derivation_path)
print(f"Running with address {account.address} (Ledger index {args.ledger_index})")

# User Genesis
action = {
    "type": "spotDeploy",
    "userGenesis": {
        "token": CORE_SPOT_TOKEN_ID,
        "userAndWei": user_and_wei,
        "existingTokenAndWei": [],
    }
}
print(action)
nonce = get_timestamp_ms()
signature = ledger_sign_l1_action(action, None, nonce, None, True, derivation_path)
payload = {
    "action": action,
    "nonce": nonce,
    "signature": signature,
    "vaultAddress": None,
}
print(f"payload: {payload}")
response = requests.post(constants.MAINNET_API_URL + "/exchange", json=payload)
print(response.json())
