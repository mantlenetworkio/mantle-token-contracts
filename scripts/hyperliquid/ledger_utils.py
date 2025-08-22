from hyperliquid.utils.signing import action_hash, construct_phantom_agent, l1_payload
from eth_account.messages import encode_typed_data
from ledgereth.messages import sign_typed_data_draft
from eth_utils import to_hex

def ledger_sign_l1_action(action, active_pool, nonce, expires_after, is_mainnet, derivation_path="44'/60'/0'/0/0"):
    """
    Sign L1 transaction using Ledger device
    
    :param action: Action object
    :param vault_address: Vault address, usually None
    :param nonce: Timestamp nonce
    :param use_hl_signature: Whether to use HL signature
    :param derivation_path: Derivation path on Ledger
    :return: Signature string
    """
    hash = action_hash(action, active_pool, nonce, expires_after)
    phantom_agent = construct_phantom_agent(hash, is_mainnet)
    data = l1_payload(phantom_agent)
    signable = encode_typed_data(full_message=data)
    domain_hash = signable.header
    message_hash = signable.body
    signed = sign_typed_data_draft(
        domain_hash, message_hash, derivation_path
    )
    return {"r": to_hex(signed.r), "s": to_hex(signed.s), "v": signed.v}