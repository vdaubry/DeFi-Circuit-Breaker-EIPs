// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {IDelayedSettlementModule} from "../interfaces/IDelayedSettlementModule.sol";

/**
 * @title DelayedSettlementModule: a timelock to schedule transactions
 * @dev This contract combines the IDelayedSettlementModule interface with the TimelockController implementation.
 */
contract DelayedSettlementModule is
    IDelayedSettlementModule,
    TimelockController
{
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}

    function prevent(
        address target,
        uint256 value,
        bytes calldata innerPayload
    ) external payable override returns (bytes32 newEffectID) {
        newEffectID = keccak256(abi.encode(target, value, innerPayload));

        if (innerPayload.length > 0) {
            // ERC20 transfer
            super.schedule(
                target, // Token address
                0, // No ETH transfert Value for ERC20 transfers
                innerPayload, // ERC20 transfer payload
                bytes32(0),
                bytes32(0),
                getMinDelay()
            );
        } else {
            // Native transfer
            super.schedule(
                target, // Wallet address
                value, // ETH transfert Value for native transfers
                bytes(0), // No payload for native transfers
                bytes32(0),
                bytes32(0),
                getMinDelay()
            );
        }
        return newEffectID;
    }

    function execute(bytes calldata extendedPayload) external override {
        (address target, uint256 value, bytes memory innerPayload) = abi.decode(
            extendedPayload,
            (address, uint256, bytes)
        );
        super.execute(target, value, extendedPayload, bytes32(0), bytes32(0));
    }

    function pausedTill()
        external
        view
        override
        returns (uint256 pauseTimestamp)
    {
        // TODO: Implement the pausing mechanism
        return 0;
    }
}
