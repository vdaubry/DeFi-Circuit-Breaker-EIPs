// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IAssetCircuitBreaker} from "../interfaces/IAssetCircuitBreaker.sol";

/**
 * @title ProtectedContract
 * @notice Base contract for DeFi protocols that want to integrate circuit breaker protection
 * @dev Inherit from this contract and use the cb* helper functions for deposits and withdrawals
 */
contract ProtectedContract {
    using SafeERC20 for IERC20;

    /// @notice The circuit breaker instance protecting this contract
    IAssetCircuitBreaker public circuitBreaker;

    /**
     * @notice Initialize the protected contract with a circuit breaker
     * @param _circuitBreaker Address of the AssetCircuitBreaker contract
     */
    constructor(address _circuitBreaker) {
        circuitBreaker = IAssetCircuitBreaker(_circuitBreaker);
    }

    /**
     * @notice Internal helper for ERC20 token deposits (inflow) with circuit breaker protection
     * @dev Use this instead of safeTransferFrom when accepting deposits in your protocol
     * @param _token The token contract address
     * @param _sender The address sending tokens (typically user)
     * @param _recipient The address receiving tokens (typically this contract)
     * @param _amount The amount of tokens to transfer
     */
    function cbInflowSafeTransferFrom(address _token, address _sender, address _recipient, uint256 _amount) internal {
        // Transfer the tokens from sender to recipient (typically this contract)
        IERC20(_token).safeTransferFrom(_sender, _recipient, _amount);

        // Notify circuit breaker of the inflow to track liquidity
        circuitBreaker.onTokenInflow(_token, _amount);
    }

    /**
     * @notice Internal helper for ERC20 token withdrawals (outflow) with circuit breaker protection
     * @dev Use this instead of safeTransfer when processing withdrawals in your protocol
     *      Tokens are first sent to the circuit breaker, which decides whether to forward them
     * @param _token The token contract address
     * @param _recipient The address that should receive tokens (if not rate limited)
     * @param _amount The amount of tokens to transfer
     */
    function cbOutflowSafeTransfer(address _token, address _recipient, uint256 _amount) internal {
        // Transfer tokens to circuit breaker (which holds them during check)
        IERC20(_token).safeTransfer(address(circuitBreaker), _amount);

        // Circuit breaker checks rate limits and either:
        // 1. Forwards tokens to recipient if OK
        // 2. Sends tokens to settlement module if triggered
        circuitBreaker.onTokenOutflow(_token, _amount, _recipient);
    }

    /**
     * @notice Internal helper for native token deposits (inflow) with circuit breaker protection
     * @dev Call this when receiving native tokens (ETH/BNB/etc) in your protocol
     */
    function cbInflowNative() internal {
        // Notify circuit breaker of native token inflow
        circuitBreaker.onNativeAssetInflow(msg.value);
    }

    /**
     * @notice Internal helper for native token withdrawals (outflow) with circuit breaker protection
     * @dev Use this when sending native tokens to users
     * @param _recipient The address that should receive native tokens (if not rate limited)
     * @param _amount The amount of native tokens to send
     */
    function cbOutflowNative(address _recipient, uint256 _amount) internal {
        // Circuit breaker checks rate limits and either:
        // 1. Forwards native tokens to recipient if OK
        // 2. Sends native tokens to settlement module if triggered
        circuitBreaker.onNativeAssetOutflow{value: _amount}(_recipient);
    }
}
