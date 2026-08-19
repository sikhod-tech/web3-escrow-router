// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title EscrowRouter
 * @author Amantlane core engineering
 * @notice Secure three-party cryptographic escrow routing protocol for commercial settlement.
 */
contract EscrowRouter {
    using SafeERC20 for IERC20;

    enum TransactionStatus { Initialized, Resolved, Disputed, Refunded }

    struct EscrowTransaction {
        address buyer;
        address seller;
        address arbitrator;
        IERC20 tokenAddress;
        uint256 allocationAmount;
        TransactionStatus status;
    }

    error UnauthorizedOperator();
    error InvalidStateTransition();
    error ZeroAllocation();

    mapping(uint256 => EscrowTransaction) public database;
    uint256 public totalEscrowDeals;

    /**
     * @notice Initializes a secure commercial trade escrow instance inside the protocol database.
     */
    function createEscrow(
        address _seller,
        address _arbitrator,
        IERC20 _token,
        uint256 _amount
    ) external returns (uint256 dealId) {
        if (_amount == 0) revert ZeroAllocation();

        dealId = totalEscrowDeals;
        
        database[dealId] = EscrowTransaction({
            buyer: msg.sender,
            seller: _seller,
            arbitrator: _arbitrator,
            tokenAddress: _token,
            allocationAmount: _amount,
            status: TransactionStatus.Initialized
        });

        unchecked {
            totalEscrowDeals++;
        }

        _token.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice Releases locked escrow funds directly to the designated seller party.
     */
    function releaseFunds(uint256 _dealId) external {
        EscrowTransaction storage deal = database[_dealId];
        
        if (msg.sender != deal.arbitrator) revert UnauthorizedOperator();
        if (deal.status != TransactionStatus.Initialized) revert InvalidStateTransition();

        deal.status = TransactionStatus.Resolved;

        deal.tokenAddress.safeTransfer(deal.seller, deal.allocationAmount);
    }

    /**
     * @notice Reverts state and issues a total allocation refund back to the buyer party.
     */
    function refundBuyer(uint256 _dealId) external {
        EscrowTransaction storage deal = database[_dealId];
        
        if (msg.sender != deal.arbitrator) revert UnauthorizedOperator();
        if (deal.status != TransactionStatus.Initialized) revert InvalidStateTransition();

        deal.status = TransactionStatus.Refunded;

        deal.tokenAddress.safeTransfer(deal.buyer, deal.allocationAmount);
    }
}
