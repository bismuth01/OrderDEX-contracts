# On-chain order book contracts
This repository contains the contracts to create an _almost on-chain_ order book trading platform using Chainlink CCIP.

## High level overview
Trades are submitted to an off-chain server, where orders are matched. If orders are cancelled, they are removed from the server causing no loss in fees.
Every user is identified with a unique string ID. This ID is used on all chains required for creating a smart contract wallet.
Once orders are matched, every block time, they are batched and sent on-chain to the EntryPoint.

The EntryPoint checks the matched orders, calculates the tokens to be transfered and the spread profit gained, then sends out messages using Chainlink CCIP to the required chain's WalletController.
The WalletController contract takes care of the token swapping.

To deposit or withdraw their tokens, users can use the UserInteraction contract.

## Architecture
![Screenshot_20250629_132641](https://github.com/user-attachments/assets/033e0969-5059-4b0d-9016-8a9e67236df6)


## How to setup the contracts
1. Choose all the chains you want to deploy. Use CCIP directory to find the router and chain selector.
EntryPoint is meant to be on a single chain. While UserInteraction & WalletController are to be deployed in each chain.
2. In every chain, deploy UserInteraction first, take that address and deploy WalletController with it, then send it native fees for CCIP Transactions.
Make sure to record them somewhere as changing chains in metamask will cause losing that data in Remix IDE.
3. Now, deploy your EntryPoint at your choice of chain. Use `setProfitWalletId` to set an user id to whom the spread profit will be transferred.
Use the `setRoute` function, where t is token route name, sel is chain selector, ctl is wallet controller addresss for that chain and denom is denom of the token.
4. All set !! To start trading, use the UserInteraction contract of the token you want to use, to deposit it in your wallet.
