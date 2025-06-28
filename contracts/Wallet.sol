// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract Wallet {
    error Unauthorized(address expected, address actual);
    error InsufficientFunds(uint256 available, uint256 needed);

    address public controller;
    string public ownerId;
    uint256 public balance;

    modifier onlyController() {
        if (msg.sender != controller) {
            revert Unauthorized(controller, msg.sender);
        }
        _;
    }

    constructor(address _controller, string memory _ownerId) {
        controller = _controller;
        ownerId = _ownerId;
    }

    function deposit() external payable onlyController {
        balance += msg.value;
    }

    function withdraw(address to, uint256 amount) external onlyController {
        if (amount > balance) revert InsufficientFunds(balance, amount);
        balance -= amount;
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Transfer failed");
    }

    function checkBalance() external view returns (uint256) {
        return balance;
    }

    receive() external payable {
        balance += msg.value;
    }
}
