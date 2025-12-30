// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";
import {MiddlewareShim} from "../src/MiddlewareShim.sol";
import {RegistryCoordinatorMimic} from "../src/RegistryCoordinatorMimic.sol";
import {Strings} from "@openzeppelin-utils/Strings.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {SP1Helios} from "@sp1-helios/SP1Helios.sol";

contract DeployEnvironment is Script {
    function setUp() public {}

    function run() public {
        address registryCoordinator = vm.envAddress("REGISTRY_COORDINATOR");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MiddlewareShim middlewareShim =
            new MiddlewareShim(ISlashingRegistryCoordinator(OPACITY_REGISTRY_COORDINATOR_ADDRESS_SEPOLIA));
        console.log("MiddlewareShim deployed at:", address(middlewareShim));

        RegistryCoordinatorMimic registryCoordinatorMimic =
            new RegistryCoordinatorMimic(SP1Helios(address(0)), address(middlewareShim));
        console.log("RegistryCoordinatorMimic deployed at:", address(registryCoordinatorMimic));

        middlewareShim.updateMiddlewareDataHash();

        vm.stopBroadcast();
    }
}
