// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {IPoolManager, PoolKey, BalanceDelta} from "../IPoolManager.sol";

contract MockPoolManager {
    event SwapExecuted();
    
    function swap(
        PoolKey memory,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external returns (BalanceDelta delta) {
        emit SwapExecuted();
        return delta;
    }
}