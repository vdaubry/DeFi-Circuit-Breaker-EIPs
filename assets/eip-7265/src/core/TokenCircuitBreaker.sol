// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IERC7265CircuitBreaker} from "../interfaces/IERC7265CircuitBreaker.sol";
import {ITokenCircuitBreaker} from "../interfaces/ITokenCircuitBreaker.sol";

import {CircuitBreaker} from "./CircuitBreaker.sol";

contract TokenCircuitBreaker is CircuitBreaker, ITokenCircuitBreaker {
    constructor(uint256 _withdrawalPeriod, uint256 _liquidityTickLength)
        CircuitBreaker(_withdrawalPeriod, _liquidityTickLength)
    {}

    /// @dev TOKEN FUNCTIONS

    function onTokenInflow(address _token, uint256 _amount) external override onlyOperational {
        _increaseParameter(keccak256(abi.encode(_token)), _amount, _token, 0, new bytes(0));
        emit AssetDeposit(_token, msg.sender, _amount);
    }

    // @dev Funds have been transferred to the circuit breaker before calling onTokenOutflow
    function onTokenOutflow(address _token, uint256 _amount, address _recipient) external override onlyOperational {
        // compute calldata to call the erc20 contract and transfer funds to _recipient
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), _recipient, _amount);

        bool firewallTriggered = _decreaseParameter(keccak256(abi.encode(_token)), _amount, _token, 0, data);
        if (firewallTriggered) {
            
        }
        else {
            // Perform transfert of ERC20
        }
        emit AssetDeposit(_token, msg.sender, _amount);
    }

    function onNativeAssetInflow(uint256 _amount) external override onlyOperational {
        _increaseParameter(keccak256(abi.encode(address(0))), _amount, address(0), 0, new bytes(0));
        emit AssetDeposit(address(0), msg.sender, _amount);
    }

    function onNativeAssetOutflow(address _recipient) external payable override onlyOperational {
        _decreaseParameter(keccak256(abi.encode(address(0))), msg.value, _recipient, msg.value, new bytes(0));
        emit AssetDeposit(address(0), msg.sender, msg.value);
    }

     function _onFirewallTriggered() internal {
        // transfer tokens to the timelock

        // Need to discuss on_tokenOutflow refactor
        super()
    }

}
