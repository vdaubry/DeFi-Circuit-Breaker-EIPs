// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

import { IERC173 } from "./IERC173.sol";

/// @title Circuit Breaker
/// @dev See https://eips.ethereum.org/EIPS/eip-7265
interface IERC7265CircuitBreaker is IERC173 {
    /// @dev MUST be emitted in `onTokenInflow` and `onNativeAssetInflow` when an asset is successfully deposited
    /// @param asset MUST be the address of the asset withdrawn.
    /// For any EIP-20 token, MUST be an EIP-20 token contract.
    /// For the native asset (ETH on mainnet), MUST be address 0x0000000000000000000000000000000000000001 equivalent to address(1).
    /// @param from MUST be the address from which the assets originated
    /// @param amount MUST be the amount of assets being withdrawn
    event AssetDeposit(address indexed asset, address indexed from, uint256 amount);

    /// @dev MUST be emitted in `onTokenOutflow` and `onNativeAssetOutflow` when an asset is successfully withdrawn
    /// @param asset MUST be the address of the asset withdrawn.
    /// For any EIP-20 token, MUST be an EIP-20 token contract.
    /// For the native asset (ETH on mainnet), MUST be address 0x0000000000000000000000000000000000000001 equivalent to address(1).
    /// @param recipient MUST be the address of the recipient withdrawing the assets
    /// @param amount MUST be the amount of assets being withdrawn
    event AssetWithdraw(address indexed asset, address indexed recipient, uint256 amount);

    /**
     * @dev MUST be emitted in `onTokenOutflow` and `onNativeAssetOutflow` when the amount exdeeds the rate limit
     * @param asset MUST be the address of the asset withdrawn.
     * For any EIP-20 token, MUST be an EIP-20 token contract.
     * For the native asset (ETH on mainnet), MUST be address 0x0000000000000000000000000000000000000001 equivalent to address(1).
     * @param timestamp MUST be the timestamp at which the rate limit was breached
     */
    event AssetRateLimitBreached(address indexed asset, uint256 indexed timestamp);

    /**
     * @dev MAY be called by admin to add protected contracts
     */
    function addProtectedContracts(address[] calldata _protectedContracts) external;

    /**
     * @dev MAY be called by admin to add protected contracts
     */
    function removeProtectedContracts(address[] calldata _protectedContracts) external;

    /// @notice Lock the circuit breaker
    /// @dev MAY be called by admin to lock the circuit breaker
    /// While the protocol is not operational: inflows, outflows, and claiming locked funds MUST revert
    function markAsNotOperational() external;
}