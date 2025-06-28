// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip@1.6.0/contracts/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts@1.4.0/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip@1.6.0/contracts/libraries/Client.sol";

contract EntryPoint {
    struct ChainRoute { uint64 chainSelector; address walletController; uint256 denom; }
    struct MatchedOrder {
        string baseToken; string quoteToken;
        string makerOwnerId; string takerOwnerId;
        uint256 baseAmount; uint256 priceAsk; uint256 priceBid;
    }
    struct TradeDetails {
        string sourceOwnerId;
        string destinationOwnerId;
        uint256 amount;
    }

    mapping(string => ChainRoute) public tokenRoutes;
    string public profitWalletId;
    address public owner;
    uint256 public batchCounter;
    address routerAddress;

    event TokenRouteSet(string indexed token, ChainRoute route);
    event ProfitWalletIdSet(string walletId);
    event BatchExecuted(uint256 indexed batchId, uint256 ordersProcessed);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }

    constructor(address _router) {
        owner = msg.sender;
        routerAddress = _router;
    }

    function setRoute(string calldata t, uint64 sel, address ctl, uint256 denom) external onlyOwner {
        tokenRoutes[t] = ChainRoute(sel, ctl, denom);
        emit TokenRouteSet(t, tokenRoutes[t]);
    }
    function setProfitWalletId(string calldata id) external onlyOwner {
        profitWalletId = id;
        emit ProfitWalletIdSet(id);
    }

    function executeBatch(MatchedOrder[] calldata orders) external payable {
        uint256 bId = ++batchCounter;

        for (uint i = 0; i < orders.length; i++) {
            MatchedOrder calldata o = orders[i];

            ChainRoute memory br = tokenRoutes[o.baseToken];
            ChainRoute memory qr = tokenRoutes[o.quoteToken];
            require(br.walletController != address(0) && qr.walletController != address(0), "Missing route");

            // Helper for sending CCIP action
            ccipWithdraw(br, o.makerOwnerId, o.takerOwnerId, o.baseAmount);
            uint256 qAmt = (o.baseAmount * o.priceAsk) * qr.denom / br.denom;
            ccipWithdraw(qr, o.takerOwnerId, o.makerOwnerId, qAmt);

            if (o.priceBid > o.priceAsk) {
                uint256 spread = (o.baseAmount * (o.priceBid - o.priceAsk)) * qr.denom / br.denom;
                ccipProfitWithdraw(qr, o.takerOwnerId, profitWalletId, spread);
            }
        }

        emit BatchExecuted(bId, orders.length);
    }

    function _buildCCIPMessage(
        address _receiver,
        TradeDetails memory _trade,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver),
                data: abi.encode(_trade),
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: Client._argsToBytes(
                    Client.GenericExtraArgsV2({
                        gasLimit: 200_000,
                        allowOutOfOrderExecution: false
                    })
                ),
                feeToken: _feeTokenAddress
            });
    }

    function ccipWithdraw(ChainRoute memory tokenRoute, string calldata sourceOwnerId, string calldata destinationOwnerId, uint256 amount) internal {
        TradeDetails memory trade = TradeDetails(sourceOwnerId, destinationOwnerId, amount);
        Client.EVM2AnyMessage memory ccipmsg = _buildCCIPMessage(tokenRoute.walletController, trade, address(0));

        IRouterClient router = IRouterClient(routerAddress);

        uint256 fees = router.getFee(tokenRoute.chainSelector, ccipmsg);

        router.ccipSend{value: fees}(
            tokenRoute.chainSelector,
            ccipmsg
        );
    }

    function ccipProfitWithdraw(ChainRoute memory tokenRoute, string calldata sourceOwnerId, string storage destinationOwnerId, uint256 amount) internal {
        TradeDetails memory trade = TradeDetails(sourceOwnerId, destinationOwnerId, amount);
        Client.EVM2AnyMessage memory ccipmsg = _buildCCIPMessage(tokenRoute.walletController, trade, address(0));

        IRouterClient router = IRouterClient(routerAddress);

        uint256 fees = router.getFee(tokenRoute.chainSelector, ccipmsg);

        router.ccipSend{value: fees}(
            tokenRoute.chainSelector,
            ccipmsg
        );
    }
}
