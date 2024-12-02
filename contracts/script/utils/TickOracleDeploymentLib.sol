// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {TickOracleServiceManager} from "../../src/TickOracleServiceManager.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {Quorum} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";
import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";
import {CoreDeploymentLib} from "./CoreDeploymentLib.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library TickOracleDeploymentLib {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    Vm internal constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DeploymentData {
        address tickOracleServiceManager;
        address stakeRegistry;
        address strategy;
        address token;
    }

    function deployContracts(
        address proxyAdmin,
        CoreDeploymentLib.DeploymentData memory core,
        Quorum memory quorum
    ) internal returns (DeploymentData memory) {
        DeploymentData memory result;

        // First, deploy upgradeable proxy contracts that will point to the implementations.
        result.tickOracleServiceManager = UpgradeableProxyLib.setUpEmptyProxy(
            proxyAdmin
        );
        result.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        // Deploy the implementation contracts, using the proxy contracts as inputs
        address stakeRegistryImpl = address(
            new ECDSAStakeRegistry(IDelegationManager(core.delegationManager))
        );
        address tickOracleServiceManagerImpl = address(
            new TickOracleServiceManager(
                core.avsDirectory,
                result.stakeRegistry,
                core.rewardsCoordinator,
                core.delegationManager,
                address(0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A), // pool manager sepolia deployment
                address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238), // USDC on sepolia
                address(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0) // USDT on sepolia
            )
        );
        // Upgrade contracts
        bytes memory upgradeCall = abi.encodeCall(
            ECDSAStakeRegistry.initialize,
            (result.tickOracleServiceManager, 0, quorum)
        );
        UpgradeableProxyLib.upgradeAndCall(
            result.stakeRegistry,
            stakeRegistryImpl,
            upgradeCall
        );
        UpgradeableProxyLib.upgrade(
            result.tickOracleServiceManager,
            tickOracleServiceManagerImpl
        );

        return result;
    }

    function readDeploymentJson(
        uint256 chainId
    ) internal returns (DeploymentData memory) {
        return readDeploymentJson("deployments/", chainId);
    }

    function readDeploymentJson(
        string memory directoryPath,
        uint256 chainId
    ) internal returns (DeploymentData memory) {
        string memory fileName = string.concat(
            directoryPath,
            vm.toString(chainId),
            ".json"
        );

        require(vm.exists(fileName), "Deployment file does not exist");

        string memory json = vm.readFile(fileName);

        DeploymentData memory data;
        /// TODO: 2 Step for reading deployment json.  Read to the core and the AVS data
        data.tickOracleServiceManager = json.readAddress(
            ".contracts.tickOracleServiceManager"
        );
        data.stakeRegistry = json.readAddress(".contracts.stakeRegistry");
        data.strategy = json.readAddress(".contracts.strategy");
        data.token = json.readAddress(".contracts.token");

        return data;
    }

    /// write to default output path
    function writeDeploymentJson(DeploymentData memory data) internal {
        writeDeploymentJson("deployments/hello-world/", block.chainid, data);
    }

    function writeDeploymentJson(
        string memory outputPath,
        uint256 chainId,
        DeploymentData memory data
    ) internal {
        address proxyAdmin = address(
            UpgradeableProxyLib.getProxyAdmin(data.tickOracleServiceManager)
        );

        string memory deploymentData = _generateDeploymentJson(
            data,
            proxyAdmin
        );

        string memory fileName = string.concat(
            outputPath,
            vm.toString(chainId),
            ".json"
        );
        if (!vm.exists(outputPath)) {
            vm.createDir(outputPath, true);
        }

        vm.writeFile(fileName, deploymentData);
        console2.log("Deployment artifacts written to:", fileName);
    }

    function _generateDeploymentJson(
        DeploymentData memory data,
        address proxyAdmin
    ) private view returns (string memory) {
        return
            string.concat(
                '{"lastUpdate":{"timestamp":"',
                vm.toString(block.timestamp),
                '","block_number":"',
                vm.toString(block.number),
                '"},"addresses":',
                _generateContractsJson(data, proxyAdmin),
                "}"
            );
    }

    function _generateContractsJson(
        DeploymentData memory data,
        address proxyAdmin
    ) private view returns (string memory) {
        return
            string.concat(
                '{"proxyAdmin":"',
                proxyAdmin.toHexString(),
                '","tickOracleServiceManager":"',
                data.tickOracleServiceManager.toHexString(),
                '","tickOracleServiceManagerImpl":"',
                data.tickOracleServiceManager.getImplementation().toHexString(),
                '","stakeRegistry":"',
                data.stakeRegistry.toHexString(),
                '","stakeRegistryImpl":"',
                data.stakeRegistry.getImplementation().toHexString(),
                '","strategy":"',
                data.strategy.toHexString(),
                '","token":"',
                data.token.toHexString(),
                '"}'
            );
    }
}
