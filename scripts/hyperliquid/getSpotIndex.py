import requests
import argparse
import json
from hyperliquid.utils import constants

def get_spot_index_and_name(token_id: str, is_testnet: bool = False) -> tuple[int, str]:
    """
    Get the spot index and name for a specific token ID.
    
    Args:
        token_id: The token ID to search for
        is_testnet: Whether to use testnet API
    
    Returns:
        Tuple of (spot_index, token_name)
    """
    payload = {
        "type": "spotMeta",
    }
    
    # Choose API URL based on testnet flag
    api_url = constants.TESTNET_API_URL if is_testnet else constants.MAINNET_API_URL
    
    try:
        response = requests.post(api_url + "/info", json=payload)
        response.raise_for_status()
        data = response.json()
        
        # The response has a 'universe' field containing an array of spot structures
        universe = data.get("universe", [])
        
        # Search for the token ID in the universe to get the spot index
        spot_index = None
        for spot in universe:
            if spot.get("tokens") and len(spot["tokens"]) >= 2:
                # Check if the first token matches our token ID
                if str(spot["tokens"][0]) == token_id and str(spot["tokens"][1]) == "0":
                    spot_index = spot["index"]
                    break
        
        if spot_index is None:
            raise ValueError(f"Token ID {token_id} not found in universe")

        # Get the token name from the tokens field
        tokens_data = data.get("tokens", [])
        
        # Find specific token by index to get the name
        token_data = next((token for token in tokens_data if token["index"] == int(token_id)), None)
        if not token_data:
            raise ValueError(f"Token with index {token_id} not found in tokens")
        
        return spot_index, token_data["name"]
        
    except requests.exceptions.RequestException as e:
        print(f"Error making request to Hyperliquid API: {e}")
        raise
    except Exception as e:
        print(f"Error processing response: {e}")
        raise

def main():
    parser = argparse.ArgumentParser(description='Get spot index for a specific token ID')
    parser.add_argument('token_id', type=str, help='Token ID to search for')
    parser.add_argument('--testnet', action='store_true', help='Use testnet API (default: mainnet)')
    
    args = parser.parse_args()
    
    try:
        spot_index, token_name = get_spot_index_and_name(args.token_id, args.testnet)
        print(f"{spot_index} {token_name}")
            
    except Exception as e:
        print(f"Error: {e}")
        exit(1)

if __name__ == "__main__":
    main()