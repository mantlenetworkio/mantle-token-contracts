# STEPS

## 0. Environment Configuration
Before running the deployment scripts, create a `.env` file in the `scripts/hyperliquid/` directory with the following configuration:

```bash
# Hyperliquid Spot Token Configuration
CORE_SPOT_TOKEN_ID=242

# User Genesis Configuration
# Format: "address:amount,address2:amount2"
# Multiple users can be specified by separating with commas

# Example 1: Single user with uint64.max amount
USER_AND_WEI=0x1234567890123456789012345678901234567890:18446744073709551615

# Example 2: Multiple users with different amounts
USER_AND_WEI=0x1234567890123456789012345678901234567890:1000000000000000000,0x0987654321098765432109876543210987654321:2000000000000000000

```

### 1.1 Genesis
```bash
python deploySpot_userGenesis.py --ledger-index $index
```

### 1.2 Genesis
```bash
python deploySpot_genesis.py --ledger-index $index
```

### 1.3 Register spot
```bash
python deploySpot_registerSpot.py --ledger-index $index
```

### 1.4 Get Spot Index by Token ID (optional)
```bash
# Get spot index for a specific token ID from mainnet
python getSpotIndex.py 242

# Get spot index from testnet
python getSpotIndex.py 242 --testnet
```

### 1.5 Register Hyperliquidity
```bash
python deploySpot_registerHyperliquidity.py --ledger-index $index
```

## 2. Linking with evm
### 2.1 Request evm contract
```bash
python linking_requestEvmContract.py --ledger-index $index
```

### 2.2 Finalize evm contract
```bash
python linking_finalizeEvmContract.py --ledger-index $index
```

### 3. Fetch and write Spot Metadata and Token Genesis
```bash
# Fetch spot metadata and genesis info for token index 242 from mainnet (terminal output only)
python writeToDeployments.py 242

# Fetch spot metadata and genesis info for token index 242 from testnet (terminal output only)
python writeToDeployments.py 242 --testnet

# Fetch and write to default location (mainnet: deployments/hypercore-mainnet/242.json)
python writeToDeployments.py 242 --write

# Fetch and write to default location (testnet: deployments/hypercore-testnet/242.json)
python writeToDeployments.py 242 --testnet --write

# Fetch and write to custom location
python writeToDeployments.py 242 --write custom_path.json --pretty
```
