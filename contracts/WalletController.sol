// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import {CCIPReceiver} from "@chainlink/contracts-ccip@1.6.0/contracts/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip@1.6.0/contracts/libraries/Client.sol";
import "./Wallet.sol";

contract WalletController is CCIPReceiver {
    struct TradeDetails {
        string sourceOwnerId;
        string destinationOwnerId;
        uint256 amount;
    }

    mapping(string => address) public walletOwnership;

    address public entrypointAddress;
    address public userInteractionAddress;
    uint64 public entrypointChainSelector;

    event WalletCreated(string ownerId, address wallet);

    modifier onlyAuthorized() {
        require(
            msg.sender == entrypointAddress || msg.sender == userInteractionAddress,
            "Unauthorized sender"
        );
        _;
    }

    constructor(
        address _router,
        address _entrypoint,
        address _userInteraction,
        uint64 _entrypointselector
    )
        CCIPReceiver(_router)
    {
        require(_entrypoint != address(0), "Invalid entrypoint");
        require(_userInteraction != address(0), "Invalid userInteraction");
        entrypointAddress = _entrypoint;
        userInteractionAddress = _userInteraction;
        entrypointChainSelector = _entrypointselector;
    }

    function _getOrCreateWallet(string memory ownerId) internal returns (address wallet) {
        wallet = walletOwnership[ownerId];
        if (wallet == address(0)) {
            wallet = address(new Wallet(address(this), ownerId));
            walletOwnership[ownerId] = wallet;
            emit WalletCreated(ownerId, wallet);
        }
    }

    function depositTo(string calldata ownerId) external payable onlyAuthorized {
        address wallet = _getOrCreateWallet(ownerId);
        (bool success, ) = wallet.call{value: msg.value}(abi.encodeWithSignature("deposit()"));
        require(success, "Deposit failed");
    }

    function withdrawTo(string calldata ownerId, address to, uint256 amount) external onlyAuthorized {
        address wallet = walletOwnership[ownerId];
        require(wallet != address(0), "Wallet not found");

        Wallet(payable(wallet)).withdraw(to, amount);
    }

    function transferTo(string memory sourceOwnerId, string memory destinationOwnerId, uint256 amount) internal onlyAuthorized{
        address sourceAddress = _getOrCreateWallet(sourceOwnerId);
        address destinationAddress = _getOrCreateWallet(destinationOwnerId);

        Wallet(payable(sourceAddress)).withdraw(destinationAddress, amount);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        TradeDetails memory txData = abi.decode(message.data, (TradeDetails));
        transferTo(txData.sourceOwnerId, txData.destinationOwnerId, txData.amount);
    }
}
