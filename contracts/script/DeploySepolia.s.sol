// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";
import {MiddlewareShim} from "../src/MiddlewareShim.sol";
import {RegistryCoordinatorMimic} from "../src/RegistryCoordinatorMimic.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {SP1Helios} from "@sp1-helios/SP1Helios.sol";
import {BLSSignatureChecker} from "@eigenlayer-middleware/BLSSignatureChecker.sol";
import {
    BLSSigCheckOperatorStateRetriever
} from "@eigenlayer-middleware/unaudited/BLSSigCheckOperatorStateRetriever.sol";

/// @title DeploySepolia
/// @notice Deployment script for Sepolia testnet
/// @dev Requires REGISTRY_COORDINATOR_ADDRESS env var for the AVS Registry Coordinator on Sepolia
contract DeploySepolia is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address registryCoordinator = vm.envAddress("REGISTRY_COORDINATOR_ADDRESS");
        address sp1HeliosAddress = vm.envOr("SP1HELIOS_ADDRESS", address(0));
        string memory outPath = vm.envOr("OUT_PATH", string("./artifacts/sepolia-deploy.json"));

        console.log("Deploying to Sepolia...");
        console.log("Registry Coordinator:", registryCoordinator);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MiddlewareShim
        MiddlewareShim middlewareShim = new MiddlewareShim(ISlashingRegistryCoordinator(registryCoordinator));
        console.log("MiddlewareShim deployed at:", address(middlewareShim));

        // Deploy BLSSigCheckOperatorStateRetriever
        BLSSigCheckOperatorStateRetriever stateRetriever = new BLSSigCheckOperatorStateRetriever();
        console.log("BLSSigCheckOperatorStateRetriever deployed at:", address(stateRetriever));

        // Deploy RegistryCoordinatorMimic
        RegistryCoordinatorMimic registryCoordinatorMimic =
            new RegistryCoordinatorMimic(SP1Helios(sp1HeliosAddress), address(middlewareShim));
        console.log("RegistryCoordinatorMimic deployed at:", address(registryCoordinatorMimic));

        // Deploy BLSSignatureChecker
        BLSSignatureChecker blsSignatureChecker =
            new BLSSignatureChecker(ISlashingRegistryCoordinator(address(registryCoordinatorMimic)));
        console.log("BLSSignatureChecker deployed at:", address(blsSignatureChecker));

        // Update middleware data hash
        middlewareShim.updateMiddlewareDataHash();

        // Write deployment artifacts
        string memory json = vm.serializeAddress("sepolia", "middlewareShim", address(middlewareShim));
        json = vm.serializeAddress("sepolia", "stateRetriever", address(stateRetriever));
        json = vm.serializeAddress("sepolia", "registryCoordinatorMimic", address(registryCoordinatorMimic));
        json = vm.serializeAddress("sepolia", "blsSignatureChecker", address(blsSignatureChecker));
        vm.writeFile(outPath, json);
        console.log("Deployment artifacts written to:", outPath);

        vm.stopBroadcast();
    }
}
