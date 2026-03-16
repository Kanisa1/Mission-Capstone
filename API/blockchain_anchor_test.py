import argparse
import hashlib
import os
import sys
from datetime import datetime, timezone

from dotenv import load_dotenv
from eth_account import Account
from web3 import Web3


def _require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def _build_data_payload(text: str) -> tuple[str, str]:
    digest_hex = hashlib.sha256(text.encode("utf-8")).hexdigest()
    # Store only hash + lightweight metadata on chain.
    payload_text = f"mission-capstone|sha256|{digest_hex}|{datetime.now(timezone.utc).isoformat()}"
    payload_hex = payload_text.encode("utf-8").hex()
    return digest_hex, "0x" + payload_hex


def _decode_hex_payload(payload_hex: str) -> str:
    if not payload_hex:
        return ""
    clean_hex = payload_hex[2:] if payload_hex.startswith("0x") else payload_hex
    if not clean_hex:
        return ""
    return bytes.fromhex(clean_hex).decode("utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Send one Polygon transaction anchoring a SHA-256 digest in tx input data."
    )
    parser.add_argument(
        "--message",
        default="mission-capstone-anchor-test",
        help="Text to hash and anchor (default: mission-capstone-anchor-test)",
    )
    parser.add_argument(
        "--gas",
        type=int,
        default=100000,
        help="Gas limit to use for the anchor tx (default: 100000)",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Wait for confirmation, decode tx input, and verify the anchored hash",
    )
    parser.add_argument(
        "--verify-timeout",
        type=int,
        default=120,
        help="Seconds to wait for confirmation when --verify is used (default: 120)",
    )
    args = parser.parse_args()

    load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"), override=False)

    try:
        enabled = os.getenv("BLOCKCHAIN_ANCHOR_ENABLED", "false").strip().lower()
        if enabled not in {"1", "true", "yes", "on"}:
            raise ValueError(
                "BLOCKCHAIN_ANCHOR_ENABLED is false. Set it to true in API/.env before running."
            )

        rpc_url = _require_env("BLOCKCHAIN_RPC_URL")
        private_key = _require_env("BLOCKCHAIN_PRIVATE_KEY")
        from_address = _require_env("BLOCKCHAIN_FROM_ADDRESS")
        explorer_base = os.getenv("BLOCKCHAIN_EXPLORER_BASE", "https://amoy.polygonscan.com/tx/").strip()

        w3 = Web3(Web3.HTTPProvider(rpc_url, request_kwargs={"timeout": 30}))
        if not w3.is_connected():
            raise RuntimeError("Could not connect to RPC provider. Check BLOCKCHAIN_RPC_URL.")

        sender = Account.from_key(private_key).address
        if sender.lower() != from_address.lower():
            raise ValueError(
                "BLOCKCHAIN_FROM_ADDRESS does not match BLOCKCHAIN_PRIVATE_KEY derived address."
            )

        chain_id = int(w3.eth.chain_id)
        digest_hex, data_payload = _build_data_payload(args.message)

        nonce = w3.eth.get_transaction_count(sender)
        gas_price = w3.eth.gas_price

        tx = {
            "chainId": chain_id,
            "nonce": nonce,
            "to": sender,  # self-transfer with data payload
            "value": 0,
            "gas": int(args.gas),
            "gasPrice": int(gas_price),
            "data": data_payload,
        }

        signed = w3.eth.account.sign_transaction(tx, private_key=private_key)
        tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
        tx_hash_hex = tx_hash.hex()

        print("Anchor submitted successfully")
        print(f"network_chain_id: {chain_id}")
        print(f"anchored_sha256: {digest_hex}")
        print(f"tx_hash: {tx_hash_hex}")
        print(f"explorer: {explorer_base}{tx_hash_hex}")
        print("status: pending (wait for confirmations in explorer)")

        if args.verify:
            receipt = w3.eth.wait_for_transaction_receipt(
                tx_hash,
                timeout=int(args.verify_timeout),
                poll_latency=2,
            )
            if int(receipt.status) != 1:
                raise RuntimeError("Transaction was mined but failed (status=0).")

            onchain_tx = w3.eth.get_transaction(tx_hash)
            onchain_input = onchain_tx.get("input", "0x")
            decoded_payload = _decode_hex_payload(onchain_input)
            hash_match = digest_hex in decoded_payload

            print("verification: confirmed")
            print(f"mined_block: {receipt.blockNumber}")
            print(f"decoded_payload: {decoded_payload}")
            print(f"hash_match: {hash_match}")

            if not hash_match:
                raise RuntimeError("On-chain payload does not contain the expected SHA-256 digest.")

        return 0

    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
