// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vaultopia
 * @dev Simple multi-user ETH vault with deposit/withdraw and optional time-lock per deposit
 * @notice Users can create locked or unlocked deposits and withdraw once unlocked
 */
contract Vaultopia {
    address public owner;

    struct DepositInfo {
        uint256 amount;
        uint256 unlockTime;
        bool    exists;
    }

    // user => depositId => DepositInfo
    mapping(address => mapping(uint256 => DepositInfo)) public userDeposits;
    // user => number of deposits
    mapping(address => uint256) public depositCountOf;

    uint256 public totalLocked;
    uint256 public totalWithdrawn;

    event Deposited(
        address indexed user,
        uint256 indexed depositId,
        uint256 amount,
        uint256 unlockTime,
        uint256 timestamp
    );

    event Withdrawn(
        address indexed user,
        uint256 indexed depositId,
        uint256 amount,
        uint256 timestamp
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Deposit ETH with an optional lock duration
     * @param lockDuration Seconds to lock the funds (0 = no lock)
     */
    function deposit(uint256 lockDuration) external payable {
        require(msg.value > 0, "Amount = 0");

        uint256 id = depositCountOf[msg.sender];
        depositCountOf[msg.sender] = id + 1;

        uint256 unlockTime = block.timestamp + lockDuration;

        userDeposits[msg.sender][id] = DepositInfo({
            amount: msg.value,
            unlockTime: unlockTime,
            exists: true
        });

        totalLocked += msg.value;

        emit Deposited(msg.sender, id, msg.value, unlockTime, block.timestamp);
    }

    /**
     * @dev Withdraw a specific deposit after it has unlocked
     * @param depositId User-specific deposit id
     */
    function withdraw(uint256 depositId) external {
        DepositInfo storage dep = userDeposits[msg.sender][depositId];
        require(dep.exists, "No deposit");
        require(dep.amount > 0, "Already withdrawn");
        require(block.timestamp >= dep.unlockTime, "Still locked");

        uint256 amount = dep.amount;
        dep.amount = 0;
        totalLocked -= amount;
        totalWithdrawn += amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdrawn(msg.sender, depositId, amount, block.timestamp);
    }

    /**
     * @dev View helper for a user's deposit
     */
    function getDeposit(address user, uint256 depositId)
        external
        view
        returns (uint256 amount, uint256 unlockTime, bool exists)
    {
        DepositInfo memory dep = userDeposits[user][depositId];
        return (dep.amount, dep.unlockTime, dep.exists);
    }

    /**
     * @dev Get how many deposits a user has created
     */
    function getDepositCount(address user) external view returns (uint256) {
        return depositCountOf[user];
    }

    /**
     * @dev Get vault ETH balance
     */
    function getVaultBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Transfer ownership of the vault
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}
