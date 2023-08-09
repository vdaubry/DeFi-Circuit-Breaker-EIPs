// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IERC7265CircuitBreaker} from "../interfaces/IERC7265CircuitBreaker.sol";
import {IDelayedSettlementModule} from "../interfaces/IDelayedSettlementModule.sol";

import {IFreezeCircuitBreaker} from "../interfaces/IFreezeCircuitBreaker.sol";

contract FreezeCircuitBreaker is IFreezeCircuitBreaker, Ownable {
    using SafeERC20 for IERC20;

    error FreezeCirtcuitBreaker__NativeTransferFailed();

    ////////////////////////////////////////////////////////////////
    //                      STATE VARIABLES                       //
    ////////////////////////////////////////////////////////////////

    // Using address(1) as a proxy for native token (ETH, BNB, etc), address(0) could be problematic
    address public immutable NATIVE_ADDRESS_PROXY = address(1);

    IDelayedSettlementModule public timelock;
    IERC7265CircuitBreaker public coreCircuitBreaker;

    constructor(
        IDelayedSettlementModule _timelock,
        IERC7265CircuitBreaker _coreCircuitBreaker
    ) Ownable() {
        timelock = _timelock;
        coreCircuitBreaker = _coreCircuitBreaker;
    }

    /// @dev OWNER FUNCTIONS

    function addProtectedContracts(address[] calldata _protectedContracts) external onlyOwner {
        coreCircuitBreaker.addProtectedContracts(_protectedContracts);
    }

    function removeProtectedContracts(address[] calldata _protectedContracts) external onlyOwner {
        coreCircuitBreaker.removeProtectedContracts(_protectedContracts);
    }

    /// @dev function pauses the protocol and prevents any further deposits, withdrawals
    function markAsNotOperational() external onlyOwner {
        coreCircuitBreaker.markAsNotOperational();
    }

    // TODO: include setParameter function

    function increaseParameter(address asset, uint256 amount, bool revertOnRateLimit) external onlyOwner {
        bytes32 identifier = keccak256(abi.encode(asset));
        bool triggered = coreCircuitBreaker.increaseParameter(identifier, amount, revertOnRateLimit);

        if (triggered) {
            emit AssetFrozen(asset, amount);
            _safeTransferIncludingNative(asset, address(timelock), amount);
        }
    }

    function decreaseParameter(address asset, uint256 amount, bool revertOnRateLimit) external onlyOwner {
        bytes32 identifier = keccak256(abi.encode(asset));
        bool triggered = coreCircuitBreaker.decreaseParameter(identifier, amount, revertOnRateLimit);

        if (triggered) {
            emit AssetFrozen(asset, amount);
            _safeTransferIncludingNative(asset, address(timelock), amount);
        }
    }

    function _safeTransferIncludingNative(
        address _token,
        address _recipient,
        uint256 _amount
    ) internal {
        if (_token == NATIVE_ADDRESS_PROXY) {
            (bool success, ) = _recipient.call{value: _amount}("");
            if (!success) revert FreezeCirtcuitBreaker__NativeTransferFailed();
        } else {
            IERC20(_token).safeTransfer(_recipient, _amount);
        }
    }
}