import requests
import argparse
import json
from hyperliquid.utils import constants
from hyperliquid.utils.signing import get_timestamp_ms
from ledger_utils import ledger_sign_l1_action
from ledgereth import accounts
from web3 import Web3
import os
from dotenv import load_dotenv
from writeToDeployments import get_spot_meta

# Load environment variables from .env file
load_dotenv()

CORE_SPOT_TOKEN_ID = int(os.getenv("CORE_SPOT_TOKEN_ID", 0))
if CORE_SPOT_TOKEN_ID == 0:
    raise ValueError("CORE_SPOT_TOKEN_ID is not set")
print(f"CORE_SPOT_TOKEN_ID: {CORE_SPOT_TOKEN_ID}")

# get ledger index from command line
parser = argparse.ArgumentParser(description='Deploy spot with Ledger')
parser.add_argument('--ledger-index', type=int, default=9, help='Ledger account index to use')
parser.add_argument('--testnet', action='store_true', help='Use testnet API and deployment (default: mainnet)')
args = parser.parse_args()
derivation_path = f"44'/60'/{args.ledger_index}'/0/0"

# get account from ledger
# account = accounts.get_account_by_path(derivation_path)
# print(f"Running with address {account.address} (Ledger index {args.ledger_index})")

# Read contract address from deployment JSON file
def get_contract_address_from_deployment(is_testnet: bool = False) -> str:
    """Read contract address from the deployment JSON file and return as Web3 address"""
    try:
        deployment_file = "scripts/foundry/oft.deployment.json"
        
        with open(deployment_file, 'r') as f:
            deployment_data = json.load(f)
        
        # Extract contract address based on network
        if is_testnet:
            contract_address = deployment_data.get("oft", {}).get("hyper", {}).get("testnet")
        else:
            contract_address = deployment_data.get("oft", {}).get("hyper", {}).get("mainnet")
        
        if not contract_address:
            raise ValueError(f"Contract address not found in {deployment_file} for {'testnet' if is_testnet else 'mainnet'}")
        
        # Convert to Web3 address
        web3_address = Web3.to_checksum_address(contract_address)
        
        # Sanity check: no zero address
        if web3_address == "0x0000000000000000000000000000000000000000":
            raise ValueError(f"Zero address not allowed: {web3_address}")
        
        return web3_address
        
    except FileNotFoundError:
        raise ValueError(f"Deployment file not found: {deployment_file}")
    except json.JSONDecodeError:
        raise ValueError(f"Invalid JSON in deployment file: {deployment_file}")
    except Exception as e:
        raise ValueError(f"Error reading deployment file: {e}")

# Get contract address from deployment file
try:
    contract_address = get_contract_address_from_deployment(is_testnet=args.testnet)
    print(f"Retrieved contract address from deployment file: {contract_address}")
except Exception as e:
    raise ValueError(f"Failed to read contract address from deployment file: {e}")

assert contract_address is not None

# Get spot metadata to retrieve weiDecimals
try:
    spot_meta = get_spot_meta(CORE_SPOT_TOKEN_ID, is_testnet=args.testnet)
    wei_decimals = spot_meta.weiDecimals
    evm_extra_wei_decimals = 18 - wei_decimals
    print(f"Retrieved weiDecimals: {wei_decimals}")
    print(f"Calculated evmExtraWeiDecimals: {evm_extra_wei_decimals}")
except Exception as e:
    raise ValueError(f"Failed to get spot metadata for token {CORE_SPOT_TOKEN_ID}: {e}")

action = {
    "type": "spotDeploy",
    "requestEvmContract": {
        "token": CORE_SPOT_TOKEN_ID,
        "address": contract_address.lower(),
        "evmExtraWeiDecimals": evm_extra_wei_decimals,
    },
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
# Choose API URL based on testnet flag
api_url = constants.TESTNET_API_URL if args.testnet else constants.MAINNET_API_URL
response = requests.post(api_url + "/exchange", json=payload)
print(response.json())