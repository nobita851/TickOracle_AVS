// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {PoolKey, IPoolManager} from "./IPoolManager.sol";

interface ITickOracleServiceManager {
    event NewTaskCreated(uint32 indexed taskIndex);

    event TaskResponded(uint32 indexed taskIndex, address operator);

    function latestTaskNum() external view returns (uint32);

    function allTaskBlocks(
        uint32 taskIndex
    ) external view returns (uint32 blockNumber);

    function allTaskResponses(
        address operator,
        uint32 taskIndex
    ) external view returns (bytes memory);

    function createNewTask(
    ) external;

    function respondToTask(
        PoolKey memory key,
        IPoolManager.SwapParams calldata swapParams,
        bytes calldata hookData,
        uint32 referenceTaskIndex,
        bytes calldata signature
    ) external;
}
