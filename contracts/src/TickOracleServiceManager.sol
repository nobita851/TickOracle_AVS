// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ECDSAServiceManagerBase} from
    "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {ITickOracleServiceManager} from "./ITickOracleServiceManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {PoolKey, IPoolManager} from "./IPoolManager.sol";

// interface IERC20 {
//     function approve(
//         address spender,
//         uint256 amount
//     ) external returns (bool);

//     function balanceOf(
//         address account
//     ) external view returns (uint256);
// }

/**
 * @title Primary entrypoint for procuring services from TickOracle.
 * @author Eigen Labs, Inc.
 */
contract TickOracleServiceManager is ECDSAServiceManagerBase, ITickOracleServiceManager {
    using ECDSAUpgradeable for bytes32;

    IPoolManager public poolManager;
    IERC20 public token0;
    IERC20 public token1;

    uint32 public latestTaskNum;

    // mapping of task indices to all tasks hashes
    // when a task is created, task hash is stored here,
    // and responses need to pass the actual task,
    // which is hashed onchain and checked against this mapping
    mapping(uint32 taskNumber => uint32 blockNumber) public allTaskBlocks;

    // mapping of task indices to hash of abi.encode(taskResponse, taskResponseMetadata)
    mapping(address => mapping(uint32 => bytes)) public allTaskResponses;

    modifier onlyOperator() {
        require(
            ECDSAStakeRegistry(stakeRegistry).operatorRegistered(msg.sender),
            "Operator must be the caller"
        );
        _;
    }

    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _rewardsCoordinator,
        address _delegationManager,
        address _poolManager,
        address _token0,
        address _token1
    )
        ECDSAServiceManagerBase(
            _avsDirectory,
            _stakeRegistry,
            _rewardsCoordinator,
            _delegationManager
        )
    {
        poolManager = IPoolManager(_poolManager);
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    /* FUNCTIONS */
    // NOTE: this function creates new task, assigns it a taskId
    function createNewTask(
    ) public {
        latestTaskNum = latestTaskNum + 1;
        emit NewTaskCreated(latestTaskNum);
    }

    function respondToTask(
        PoolKey memory key,
        IPoolManager.SwapParams calldata swapParams,
        bytes calldata hookData,
        uint32 referenceTaskIndex,
        bytes memory signature
    ) external {
        // check that the task is valid, hasn't been responsed yet, and is being responded in time
        require(
            referenceTaskIndex == latestTaskNum,
            "Task too old to respond to"
        );
        require(
            allTaskResponses[msg.sender][referenceTaskIndex].length == 0,
            "Operator has already responded to the task"
        );

        /// HOOKATHON: Removed signature verification for now
        // The message that was signed
        // bytes32 messageHash = keccak256(abi.encode(key, swapParams, hookData));
        // bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        // bytes4 magicValue = IERC1271Upgradeable.isValidSignature.selector;
        // if (!(magicValue == ECDSAStakeRegistry(stakeRegistry).isValidSignature(ethSignedMessageHash,signature))){
        //     revert();
        // }

        // approve tokens for poolManager
        // assuming the tokens are held by the contract
        if (swapParams.zeroForOne) {
            token0.approve(address(poolManager), uint256(swapParams.amountSpecified));
        } else {
            token1.approve(address(poolManager), uint256(swapParams.amountSpecified));
        }
        poolManager.swap(key, swapParams, hookData);

        // updating the storage with task responses
        allTaskResponses[msg.sender][referenceTaskIndex] = signature;

        // emitting event
        emit TaskResponded(referenceTaskIndex, msg.sender);

        // createNewTask();
    }
}
