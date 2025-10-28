// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IERC7265CircuitBreaker} from "../interfaces/IERC7265CircuitBreaker.sol";
import {IAssetCircuitBreaker} from "../interfaces/IAssetCircuitBreaker.sol";
import {ISettlementModule} from "../interfaces/ISettlementModule.sol";

import {CircuitBreaker} from "./CircuitBreaker.sol";

import {Limiter} from "../static/Structs.sol";
import {LimiterLib, LimitStatus} from "../utils/LimiterLib.sol";

/**
 * @title AssetCircuitBreaker
 * @notice Asset-specific circuit breaker that tracks and rate-limits token inflows/outflows
 * @dev Extends CircuitBreaker to provide asset-focused convenience functions and native token support
 */
contract AssetCircuitBreaker is CircuitBreaker, IAssetCircuitBreaker {
    using LimiterLib for Limiter;
    using SafeERC20 for IERC20;

    error TokenCirtcuitBreaker__NativeTransferFailed();

    /// @notice Size of function selector in bytes (first 4 bytes of calldata)
    uint8 private constant FUNCTION_SELECTOR_SIZE = 4;

    /// @notice Function selector for ERC20 transfer(address,uint256)
    bytes4 private constant TRANSFER_SELECTOR =
        bytes4(keccak256("transfer(address,uint256)"));

    /// @notice Proxy address representing native tokens (ETH, BNB, etc)
    /// @dev Using address(1) instead of address(0) to avoid potential issues with zero address checks
    address public immutable NATIVE_ADDRESS_PROXY = address(1);

    constructor(
        uint256 _rateLimitCooldownPeriod,
        uint256 _withdrawalPeriod,
        uint256 _liquidityTickLength,
        address _initialOwner
    ) CircuitBreaker(_rateLimitCooldownPeriod, _withdrawalPeriod, _liquidityTickLength, _initialOwner) {}

    /// @dev OWNABLE FUNCTIONS

    function registerAsset(
        address _asset,
        uint256 _minLiqRetainedBps,
        uint256 _limitBeginThreshold,
        address _settlementModule
    ) external override onlyOwner {
        _addSecurityParameter(
            getTokenIdentifier(_asset),
            _minLiqRetainedBps,
            _limitBeginThreshold,
            _settlementModule
        );
    }

    function updateAssetParams(
        address _asset,
        uint256 _minLiqRetainedBps,
        uint256 _limitBeginThreshold,
        address _settlementModule
    ) external override onlyOwner {
        _updateSecurityParameter(
            getTokenIdentifier(_asset),
            _minLiqRetainedBps,
            _limitBeginThreshold,
            _settlementModule
        );
    }

    /// @dev TOKEN FUNCTIONS

    function onTokenInflow(
        address _token,
        uint256 _amount
    ) external override onlyProtected onlyOperational {
        _increaseParameter(
            getTokenIdentifier(_token),
            _amount,
            _token,
            0,
            new bytes(0)
        );
        emit AssetDeposit(_token, msg.sender, _amount);
    }

    /**
     * @notice Handle token outflow (withdrawal) from the protected protocol
     * @dev Funds must be transferred to the circuit breaker before calling this function
     * @param _token The address of the token being withdrawn
     * @param _amount The amount being withdrawn
     * @param _recipient The address receiving the withdrawn tokens
     */
    function onTokenOutflow(
        address _token,
        uint256 _amount,
        address _recipient
    ) external override onlyProtected onlyOperational {
        // Prepare calldata for ERC20 transfer to settlement module (if needed)
        // This allows the settlement module to receive and hold the tokens
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("transfer(address,uint256)")),
            _recipient,
            _amount
        );

        // Check if this withdrawal triggers the circuit breaker
        bool firewallTriggered = _decreaseParameter(
            getTokenIdentifier(_token),
            _amount,
            _token,
            0,
            data
        );

        // If not triggered, complete the transfer to the recipient
        // If triggered, settlement module handles the tokens
        if (!firewallTriggered)
            _safeTransferIncludingNative(_token, _recipient, _amount);

        emit AssetDeposit(_token, msg.sender, _amount);
    }

    function onNativeAssetInflow(
        uint256 _amount
    ) external override onlyProtected onlyOperational {
        _increaseParameter(
            getTokenIdentifier(NATIVE_ADDRESS_PROXY),
            _amount,
            address(0),
            0,
            new bytes(0)
        );
        emit AssetDeposit(NATIVE_ADDRESS_PROXY, msg.sender, _amount);
    }

    function onNativeAssetOutflow(
        address _recipient
    ) external payable override onlyProtected onlyOperational {
        bool firewallTriggered = _decreaseParameter(
            getTokenIdentifier(NATIVE_ADDRESS_PROXY),
            msg.value,
            _recipient,
            msg.value,
            new bytes(0)
        );

        if (!firewallTriggered)
            _safeTransferIncludingNative(
                NATIVE_ADDRESS_PROXY,
                _recipient,
                msg.value
            );

        emit AssetDeposit(NATIVE_ADDRESS_PROXY, msg.sender, msg.value);
    }

    function isTokenRateLimited(address token) external view returns (bool) {
        return
            limiters[getTokenIdentifier(token)].status() ==
            LimitStatus.Triggered;
    }

    /// @dev INTERNAL FUNCTIONS

    function getTokenIdentifier(address token) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(token));
    }

    /// @dev FIREWALL TRIGGER OVERRIDE

    /**
     * @notice Override of circuit breaker trigger to handle asset-specific settlement
     * @dev Transfers tokens to settlement module and invokes settlement logic
     * @param limiter The limiter that was triggered
     * @param settlementTarget The token contract address (or recipient for native)
     * @param settlementValue The value to send (for native tokens)
     * @param settlementPayload Encoded transfer data (contains recipient and amount for ERC20)
     */
    function _onCircuitBreakerTrigger(
        Limiter storage limiter,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) internal override {
        // Check if we're dealing with an ERC20 token or native token
        // ERC20 tokens will have encoded transfer calldata, native tokens won't
        if (settlementPayload.length > 0) {
            // ERC20 token flow: decode the transfer calldata to extract the amount
            // The payload is: transfer(address recipient, uint256 amount)

            // Strip the 4-byte function selector to get the parameters
            bytes memory dataWithoutSelector = new bytes(
                settlementPayload.length - FUNCTION_SELECTOR_SIZE
            );
            for (uint256 i = 0; i < dataWithoutSelector.length; i++) {
                dataWithoutSelector[i] = settlementPayload[
                    i + FUNCTION_SELECTOR_SIZE
                ];
            }

            // Decode to get the amount (we don't need recipient here as we're sending to settlement module)
            (, uint256 amount) = abi.decode(
                dataWithoutSelector,
                (address, uint256)
            );

            // Transfer the tokens from circuit breaker to settlement module
            _safeTransferIncludingNative(
                settlementTarget,
                address(limiter.settlementModule),
                amount
            );
        } else {
            // Native token flow: transfer the value to settlement module
            _safeTransferIncludingNative(
                NATIVE_ADDRESS_PROXY,
                address(limiter.settlementModule),
                settlementValue
            );
        }

        // Notify the settlement module to handle the triggered state
        limiter.settlementModule.prevent(
            settlementTarget,
            settlementValue,
            settlementPayload
        );
    }

    /**
     * @notice Internal helper to transfer either ERC20 or native tokens
     * @dev Handles both token types in a unified interface
     * @param _token The token address (or NATIVE_ADDRESS_PROXY for native tokens)
     * @param _recipient The address receiving the tokens
     * @param _amount The amount to transfer
     */
    function _safeTransferIncludingNative(
        address _token,
        address _recipient,
        uint256 _amount
    ) internal {
        if (_token == NATIVE_ADDRESS_PROXY) {
            // Native token (ETH, BNB, etc) transfer using low-level call
            (bool success, ) = _recipient.call{value: _amount}("");
            if (!success) revert TokenCirtcuitBreaker__NativeTransferFailed();
        } else {
            // ERC20 token transfer using SafeERC20
            IERC20(_token).safeTransfer(_recipient, _amount);
        }
    }
}
