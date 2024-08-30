// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26 <0.9.0;

import {Voucher} from "../src/Voucher.sol";

import {BaseScript} from "./Base.s.sol";

import {console2} from "forge-std/console2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcast returns (address) {
        address voucherAddress = Upgrades.deployUUPSProxy(
            "Voucher.sol:Voucher",
            abi.encodeCall(Voucher.initialize, ())
        );

        console2.log("Voucher deployed at", voucherAddress);

        return voucherAddress;
    }
}
