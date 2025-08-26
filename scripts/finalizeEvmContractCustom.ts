import { Wallet } from 'ethers'
import { HyperliquidClient } from '@layerzerolabs/hyperliquid-composer'
import dotenv from 'dotenv'

// Load environment variables from .env file
dotenv.config()

export async function setFinalizeEvmContractCustom(
    wallet: Wallet,
    isTestnet: boolean,
    coreSpotTokenId: number,
    logLevel: string
) {
    const action = {
        type: 'finalizeEvmContract',
        token: coreSpotTokenId,
        input: "customStorageSlot",
    }

    const hyperliquidClient = new HyperliquidClient(isTestnet, logLevel)

    const response = await hyperliquidClient.submitHyperliquidAction('/exchange', wallet, action)
    if (response.status === 'err') {
        throw new Error(response.response)
    }
    return response
}

// Example usage function
export async function main() {
    // You would need to provide these values
    const privateKey = process.env.PRIVATE_KEY || ''
    const isTestnet = process.env.IS_TESTNET === 'true'
    const coreSpotTokenId = parseInt(process.env.CORE_SPOT_TOKEN_ID || '0')
    const logLevel = process.env.LOG_LEVEL || 'info'

    if (!privateKey) {
        throw new Error('PRIVATE_KEY environment variable is required')
    }

    const wallet = new Wallet(privateKey)

    try {
        const response = await setFinalizeEvmContractCustom(
            wallet,
            isTestnet,
            coreSpotTokenId,
            logLevel
        )
        console.log('Success:', response)
        return response
    } catch (error) {
        console.error('Error:', error)
        throw error
    }
}

// Run the script if called directly
// use: npx ts-node scripts/finalizeEvmContractCustom.ts
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error)
            process.exit(1)
        })
} 