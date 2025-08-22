import requests
import argparse
import json
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
import os

@dataclass
class EvmContract:
    address: str
    evm_extra_wei_decimals: int

@dataclass
class CoreSpotMetaData:
    name: str
    szDecimals: int
    weiDecimals: int
    index: int
    tokenId: str
    isCanonical: bool
    evmContract: Optional[EvmContract]
    fullName: Optional[str]
    deployerTradingFeeShare: str

@dataclass
class SpotMeta:
    tokens: List[CoreSpotMetaData]

class HyperliquidClient:
    def __init__(self, is_testnet: bool = False, log_level: str = "info"):
        self.is_testnet = is_testnet
        self.log_level = log_level
        self.base_url = "https://api.hyperliquid-testnet.xyz" if is_testnet else "https://api.hyperliquid.xyz"
    
    def submit_hyperliquid_action(self, endpoint: str, action: Dict[str, Any]) -> Dict[str, Any]:
        """Submit an action to Hyperliquid API"""
        url = f"{self.base_url}{endpoint}"
        response = requests.post(url, json=action)
        response.raise_for_status()
        return response.json()

def get_spot_meta(token_index: int, is_testnet: bool = False, log_level: str = "info") -> CoreSpotMetaData:
    """
    Fetch spot metadata from Hyperliquid and find a specific token by index.
    
    Args:
        is_testnet: Whether to use testnet API
        log_level: Log level (not used in this implementation)
        token_index: Token index to find
    
    Returns:
        CoreSpotMetaData for the specified token
    """
    action = {
        "type": "spotMeta"
    }
    
    try:
        hyperliquid_client = HyperliquidClient(is_testnet, log_level)
        response = hyperliquid_client.submit_hyperliquid_action("/info", action)
        
        # Parse the response into our data structures
        tokens_data = response.get("tokens", [])
        
        # Find specific token by index
        token_data = next((token for token in tokens_data if token["index"] == token_index), None)
        if not token_data:
            raise ValueError(f"Token {token_index} not found")
        
        evm_contract = None
        if token_data.get("evmContract"):
            evm_contract = EvmContract(
                address=token_data["evmContract"]["address"],
                evm_extra_wei_decimals=token_data["evmContract"]["evm_extra_wei_decimals"]
            )
        
        token = CoreSpotMetaData(
            name=token_data["name"],
            szDecimals=token_data["szDecimals"],
            weiDecimals=token_data["weiDecimals"],
            index=token_data["index"],
            tokenId=token_data["tokenId"],
            isCanonical=token_data["isCanonical"],
            evmContract=evm_contract,
            fullName=token_data.get("fullName"),
            deployerTradingFeeShare=token_data["deployerTradingFeeShare"]
        )
        
        return token
        
    except requests.exceptions.RequestException as e:
        print(f"Error making request to Hyperliquid API: {e}")
        raise
    except Exception as e:
        print(f"Error processing response: {e}")
        raise


def get_hip_token_info(token_id: str, is_testnet: bool = False, log_level: str = "info") -> Dict[str, Any]:
    """
    Fetch token genesis information from Hyperliquid using tokenId.
    
    Args:
        token_id: Token ID from spot info
        is_testnet: Whether to use testnet API
        log_level: Log level (not used in this implementation)
    
    Returns:
        Token genesis information as dictionary
    """
    action = {
        "type": "tokenDetails",
        "tokenId": token_id
    }
    
    try:
        hyperliquid_client = HyperliquidClient(is_testnet, log_level)
        response = hyperliquid_client.submit_hyperliquid_action("/info", action)
        
        # Return the raw response as it contains the token genesis information
        return response
        
    except requests.exceptions.RequestException as e:
        print(f"Error making request to Hyperliquid API: {e}")
        raise
    except Exception as e:
        print(f"Error processing response: {e}")
        raise

def main():
    parser = argparse.ArgumentParser(description='Fetch Hyperliquid spot metadata and token genesis information')
    parser.add_argument('token_index', type=int, help='Token index to fetch spot metadata and genesis info')
    parser.add_argument('--testnet', action='store_true', help='Use testnet API (default: mainnet)')
    parser.add_argument('--write', nargs='?', const='', metavar='PATH', help='Write to file. If no path given, uses default location. If path given, uses that location.')
    parser.add_argument('--pretty', action='store_true', help='Pretty print JSON output')
    
    args = parser.parse_args()
    
    try:
        # Fetch spot metadata first
        spot_result = get_spot_meta(
            token_index=args.token_index,
            is_testnet=args.testnet
        )
        
        # Convert spot metadata to dict
        spot_data = {
            "name": spot_result.name,
            "szDecimals": spot_result.szDecimals,
            "weiDecimals": spot_result.weiDecimals,
            "index": spot_result.index,
            "tokenId": spot_result.tokenId,
            "isCanonical": spot_result.isCanonical,
            "evmContract": {
                "address": spot_result.evmContract.address,
                "evm_extra_wei_decimals": spot_result.evmContract.evm_extra_wei_decimals
            } if spot_result.evmContract else None,
            "fullName": spot_result.fullName,
            "deployerTradingFeeShare": spot_result.deployerTradingFeeShare
        }
        
        # Try to fetch token genesis information using the tokenId from spot info
        genesis_data = {}
        try:
            genesis_result = get_hip_token_info(
                token_id=spot_result.tokenId,
                is_testnet=args.testnet
            )
            
            # Extract only the internal genesis field from the response
            genesis_data = genesis_result.get("genesis", {})
            print(f"Successfully fetched genesis info for token {args.token_index}")
        except Exception as e:
            print(f"Warning: Failed to fetch genesis info for token {args.token_index}: {e}")
            print("Continuing with spot metadata only...")
        
        # Combine spot metadata and genesis info
        output_data = {
            "coreSpot": spot_data,
            "genesis": genesis_data
        }
        
        # Output to terminal by default
        if args.pretty:
            print(json.dumps(output_data, indent=2))
        else:
            print(json.dumps(output_data))
        
        # Write to file if --write flag is provided
        if args.write is not None:
            # Determine file path
            if args.write == '':  # No explicit path given, use default
                if args.testnet:
                    output_path = f"deployments/hypercore-testnet/{args.token_index}.json"
                else:
                    output_path = f"deployments/hypercore-mainnet/{args.token_index}.json"
            else:  # Explicit path given, use it
                output_path = args.write
            
            # Ensure directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            # Write to file
            with open(output_path, 'w') as f:
                json.dump(output_data, f, indent=2 if args.pretty else None)
            print(f"\nSpot metadata and genesis info for token {args.token_index} also written to {output_path}")
                
    except Exception as e:
        print(f"Error: {e}")
        exit(1)

if __name__ == "__main__":
    main()
