// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import './WalletController.sol';

contract UserInteraction {
    address public walletController;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _walletController) {
        walletController = _walletController;
        owner = msg.sender;
    }

    function updateWalletController(address newController) external onlyOwner {
        walletController = newController;
    }

    function deposit(string calldata ownerId) external payable {
        WalletController(payable(walletController)).depositTo{value: msg.value}(ownerId);
    }

    function withdraw(string calldata ownerId, uint256 amount) external {
        WalletController(payable(walletController)).withdrawTo(ownerId, msg.sender, amount);
    }
}
