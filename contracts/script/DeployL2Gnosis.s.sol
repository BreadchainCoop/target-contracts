// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";
import {RegistryCoordinatorMimic} from "../src/RegistryCoordinatorMimic.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {SP1Helios} from "@sp1-helios/SP1Helios.sol";
import {BLSSignatureChecker} from "@eigenlayer-middleware/BLSSignatureChecker.sol";
import {SP1HeliosMock} from "./e2e/contracts/SP1HeliosMock.sol";

/// @title DeployL2Gnosis
/// @notice Deploys L2 contracts to Gnosis Chain
/// @dev Deploys: SP1HeliosMock (optional), RegistryCoordinatorMimic, BLSSignatureChecker
contract DeployL2Gnosis is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address middlewareShimAddress = vm.envAddress("MIDDLEWARE_SHIM_ADDRESS");
        address sp1HeliosAddress = vm.envOr("SP1HELIOS_ADDRESS", address(0));
        bool useMock = vm.envOr("IS_SP1HELIOS_MOCK", true);
        string memory outPath = vm.envOr("L2_OUT_PATH", string("./artifacts/l2-gnosis-deploy.json"));

        console.log("Deploying L2 contracts to Gnosis Chain...");
        console.log("MiddlewareShim (L1):", middlewareShimAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy or use existing SP1Helios
        if (sp1HeliosAddress == address(0)) {
            if (useMock) {
                SP1HeliosMock mock = new SP1HeliosMock();
                sp1HeliosAddress = address(mock);
                console.log("SP1HeliosMock deployed at:", sp1HeliosAddress);
            } else {
                revert("SP1HELIOS_ADDRESS required when IS_SP1HELIOS_MOCK=false");
            }
        } else {
            console.log("Using existing SP1Helios at:", sp1HeliosAddress);
        }

        // Deploy RegistryCoordinatorMimic
        RegistryCoordinatorMimic registryCoordinatorMimic =
            new RegistryCoordinatorMimic(SP1Helios(sp1HeliosAddress), middlewareShimAddress);
        console.log("RegistryCoordinatorMimic deployed at:", address(registryCoordinatorMimic));

        // Deploy BLSSignatureChecker
        BLSSignatureChecker blsSignatureChecker =
            new BLSSignatureChecker(ISlashingRegistryCoordinator(address(registryCoordinatorMimic)));
        console.log("BLSSignatureChecker deployed at:", address(blsSignatureChecker));

        vm.stopBroadcast();

        // Write deployment artifacts
        string memory json = vm.serializeAddress("l2", "sp1Helios", sp1HeliosAddress);
        json = vm.serializeAddress("l2", "registryCoordinatorMimic", address(registryCoordinatorMimic));
        json = vm.serializeAddress("l2", "blsSignatureChecker", address(blsSignatureChecker));
        json = vm.serializeAddress("l2", "middlewareShim", middlewareShimAddress);
        json = vm.serializeBool("l2", "isMock", useMock);
        vm.writeFile(outPath, json);
        console.log("L2 deployment artifacts written to:", outPath);
    }
}
