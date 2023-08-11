// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

import {IERC7265CircuitBreaker} from "./IERC7265CircuitBreaker.sol";

/// @title ITokenCircuitBreaker
/// @dev This interface defines the methods for the TokenCircuitBreaker
interface ITokenCircuitBreaker is IERC7265CircuitBreaker {
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

    /// @notice Record EIP-20 token inflow into a protected contract
    /// @dev This method MUST be called from all protected contract methods where an EIP-20 token is transferred in from a user.
    /// MUST revert if caller is not a protected contract.
    /// MUST revert if circuit breaker is not operational.
    /// @param _token MUST be an EIP-20 token contract
    /// @param _amount MUST equal the amount of token transferred into the protected contract
    function onTokenInflow(address _token, uint256 _amount) external;

    /// @notice Record EIP-20 token outflow from a protected contract and transfer tokens to recipient if rate limit is not triggered
    /// @dev This method MUST be called from all protected contract methods where an EIP-20 token is transferred out to a user.
    /// Before calling this method, the protected contract MUST transfer the EIP-20 tokens to the circuit breaker contract.
    /// For an example, see ProtectedContract.sol in the reference implementation.
    /// MUST revert if caller is not a protected contract.
    /// MUST revert if circuit breaker is not operational.
    /// If the token is not registered, this method MUST NOT revert and MUST transfer the tokens to the recipient.
    /// @param _token MUST be an EIP-20 token contract
    /// @param _amount MUST equal the amount of tokens transferred out of the protected contract
    /// @param _recipient MUST be the address of the recipient of the transferred tokens from the protected contract
    function onTokenOutflow(address _token, uint256 _amount, address _recipient) external;

    /// @notice Record native asset (ETH on mainnet) inflow into a protected contract
    /// @dev This method MUST be called from all protected contract methods where native asset is transferred in from a user.
    /// MUST revert if caller is not a protected contract.
    /// MUST revert if circuit breaker is not operational.
    /// @param _amount MUST equal the amount of native asset transferred into the protected contract
    function onNativeAssetInflow(uint256 _amount) external;

    /// @notice Record native asset (ETH on mainnet) outflow from a protected contract and transfer native asset to recipient if rate limit is not triggered
    /// @dev This method MUST be called from all protected contract methods where native asset is transferred out to a user.
    /// When calling this method, the protected contract MUST send the native asset to the circuit breaker contract in the same call.
    /// For an example, see ProtectedContract.sol in the reference implementation.
    /// MUST revert if caller is not a protected contract.
    /// MUST revert if circuit breaker is not operational.
    /// If native asset is not registered, this method MUST NOT revert and MUST transfer the native asset to the recipient.
    /// If a rate limit is not triggered or the circuit breaker is in grace period, this method MUST NOT revert and MUST transfer the native asset to the recipient.
    /// If a rate limit is triggered and the circuit breaker is not in grace period and `_revertOnRateLimit` is TRUE, this method MUST revert.
    /// If a rate limit is triggered and the circuit breaker is not in grace period and `_revertOnRateLimit` is FALSE and caller is a protected contract, this method MUST NOT revert.
    /// If a rate limit is triggered and the circuit breaker is not in grace period, this method MUST record the locked funds in the internal accounting of the circuit breaker implementation.
    /// @param _recipient MUST be the address of the recipient of the transferred native asset from the protected contract
    function onNativeAssetOutflow(address _recipient) external payable;
}
