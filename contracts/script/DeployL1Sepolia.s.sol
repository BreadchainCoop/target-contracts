// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";
import {MiddlewareShim} from "../src/MiddlewareShim.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {
    BLSSigCheckOperatorStateRetriever
} from "@eigenlayer-middleware/unaudited/BLSSigCheckOperatorStateRetriever.sol";

/// @title DeployL1Sepolia
/// @notice Deploys L1 contracts to Sepolia
/// @dev Deploys: MiddlewareShim, BLSSigCheckOperatorStateRetriever
contract DeployL1Sepolia is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address registryCoordinator = vm.envAddress("REGISTRY_COORDINATOR_ADDRESS");
        string memory outPath = vm.envOr("L1_OUT_PATH", string("./artifacts/l1-sepolia-deploy.json"));

        console.log("Deploying L1 contracts to Sepolia...");
        console.log("Registry Coordinator:", registryCoordinator);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MiddlewareShim
        MiddlewareShim middlewareShim = new MiddlewareShim(ISlashingRegistryCoordinator(registryCoordinator));
        console.log("MiddlewareShim deployed at:", address(middlewareShim));

        // Deploy BLSSigCheckOperatorStateRetriever
        BLSSigCheckOperatorStateRetriever stateRetriever = new BLSSigCheckOperatorStateRetriever();
        console.log("BLSSigCheckOperatorStateRetriever deployed at:", address(stateRetriever));

        // Update middleware data hash
        middlewareShim.updateMiddlewareDataHash();
        console.log("MiddlewareDataHash updated");

        vm.stopBroadcast();

        // Write deployment artifacts
        string memory json = vm.serializeAddress("l1", "middlewareShim", address(middlewareShim));
        json = vm.serializeAddress("l1", "stateRetriever", address(stateRetriever));
        json = vm.serializeAddress("l1", "registryCoordinator", registryCoordinator);
        vm.writeFile(outPath, json);
        console.log("L1 deployment artifacts written to:", outPath);
    }
}
