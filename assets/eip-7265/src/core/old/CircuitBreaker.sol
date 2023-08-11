// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IERC173, IERC7265CircuitBreaker} from "../interfaces/IERC7265CircuitBreaker.sol";
import {IDelayedSettlementModule} from "../interfaces/IDelayedSettlementModule.sol";

import {Limiter, LiqChangeNode} from "../static/Structs.sol";
import {LimiterLib, LimitStatus} from "../utils/LimiterLib.sol";

contract CircuitBreaker is IERC7265CircuitBreaker, Ownable {
    using SafeERC20 for IERC20;
    using LimiterLib for Limiter;

    ////////////////////////////////////////////////////////////////
    //                      STATE VARIABLES                       //
    ////////////////////////////////////////////////////////////////

    mapping(address => Limiter limiter) public tokenLimiters;

    mapping(address account => bool protectionActive) public isProtectedContract;

    // Using address(1) as a proxy for native token (ETH, BNB, etc), address(0) could be problematic
    address public immutable NATIVE_ADDRESS_PROXY = address(1);

    uint256 public immutable WITHDRAWAL_PERIOD;

    uint256 public immutable TICK_LENGTH;

    IDelayedSettlementModule public timelock;

    bool public isOperational = true;

    ////////////////////////////////////////////////////////////////
    //                           ERRORS                           //
    ////////////////////////////////////////////////////////////////

    error CirtcuitBreaker__NotAProtectedContract();
    error CirtcuitBreaker__NativeTransferFailed();
    error CirtcuitBreaker__ProtocolHasBeenExploited();
    error CircuitBreaker__RateLimited();

    ////////////////////////////////////////////////////////////////
    //                         MODIFIERS                          //
    ////////////////////////////////////////////////////////////////

    modifier onlyProtected() {
        if (!isProtectedContract[msg.sender]) revert CirtcuitBreaker__NotAProtectedContract();
        _;
    }

    /**
     * @notice When the isOperational flag is set to false, the protocol is considered locked and will
     * revert all future deposits, withdrawals, and claims to locked funds.
     * The admin should migrate the funds from the underlying protocol and what is remaining
     * in the CircuitBreaker contract to a multisig. This multisig should then be used to refund users pro-rata.
     * (Social Consensus)
     */
    modifier onlyOperational() {
        if (!isOperational) revert CirtcuitBreaker__ProtocolHasBeenExploited();
        _;
    }

    constructor(IDelayedSettlementModule _timelock, uint256 _withdrawalPeriod, uint256 _liquidityTickLength)
        Ownable()
    {
        timelock = _timelock;
        WITHDRAWAL_PERIOD = _withdrawalPeriod;
        TICK_LENGTH = _liquidityTickLength;
    }

    /// @dev OWNER FUNCTIONS

    function addProtectedContracts(address[] calldata _ProtectedContracts) external onlyOwner {
        for (uint256 i = 0; i < _ProtectedContracts.length; i++) {
            isProtectedContract[_ProtectedContracts[i]] = true;
        }
    }

    function removeProtectedContracts(address[] calldata _ProtectedContracts) external onlyOwner {
        for (uint256 i = 0; i < _ProtectedContracts.length; i++) {
            isProtectedContract[_ProtectedContracts[i]] = false;
        }
    }

    /// @dev function pauses the protocol and prevents any further deposits, withdrawals
    function markAsNotOperational() external onlyOwner {
        isOperational = false;
    }

    /**
     * @dev Give protected contracts one function to call for convenience
     */
    function onTokenInflow(address _token, uint256 _amount) external onlyProtected onlyOperational {
        _onTokenInflow(_token, _amount);
    }

    function onTokenOutflow(address _token, uint256 _amount, address _recipient, bool _revertOnRateLimit)
        external
        onlyProtected
        onlyOperational
    {
        _onTokenOutflow(_token, _amount, _recipient, _revertOnRateLimit);
    }

    function onNativeAssetInflow(uint256 _amount) external onlyProtected onlyOperational {
        _onTokenInflow(NATIVE_ADDRESS_PROXY, _amount);
    }

    function onNativeAssetOutflow(address _recipient, bool _revertOnRateLimit)
        external
        payable
        onlyProtected
        onlyOperational
    {
        _onTokenOutflow(NATIVE_ADDRESS_PROXY, msg.value, _recipient, _revertOnRateLimit);
    }

    /// @dev INTERNAL FUNCTIONS

    function _onTokenInflow(address _token, uint256 _amount) internal {
        /// @dev uint256 could overflow into negative
        Limiter storage limiter = tokenLimiters[_token];

        limiter.recordChange(int256(_amount), WITHDRAWAL_PERIOD, TICK_LENGTH);
        emit AssetDeposit(_token, msg.sender, _amount);
    }

    function _onTokenOutflow(address _token, uint256 _amount, address _recipient, bool _revertOnRateLimit) internal {
        Limiter storage limiter = tokenLimiters[_token];
        // Check if the token has enforced rate limited
        if (!limiter.initialized()) {
            // if it is not rate limited, just transfer the tokens
            _safeTransferIncludingNative(_token, _recipient, _amount);
            return;
        }
        limiter.recordChange(-int256(_amount), WITHDRAWAL_PERIOD, TICK_LENGTH);

        // Check if rate limit is triggered after withdrawal
        if (limiter.status() == LimitStatus.Triggered) {
            if (_revertOnRateLimit) {
                revert CircuitBreaker__RateLimited();
            }

            // lock funds to DSM here
            _safeTransferIncludingNative(_token, address(timelock), _amount);

            emit AssetsLocked(_token, _amount, msg.sender);
            return;
        }

        // if everything is good, transfer the tokens
        _safeTransferIncludingNative(_token, _recipient, _amount);

        emit AssetWithdraw(_token, _recipient, _amount);
    }

    function _safeTransferIncludingNative(address _token, address _recipient, uint256 _amount) internal {
        if (_token == NATIVE_ADDRESS_PROXY) {
            (bool success,) = _recipient.call{value: _amount}("");
            if (!success) revert CirtcuitBreaker__NativeTransferFailed();
        } else {
            IERC20(_token).safeTransfer(_recipient, _amount);
        }
    }

    /// @dev ERC173 OVERRIDES

    function owner() public view override(IERC173, Ownable) returns (address) {
        super.owner();
    }

    function transferOwnership(address _newOwner) public override(IERC173, Ownable) {
        super.transferOwnership(_newOwner);
    }
}
