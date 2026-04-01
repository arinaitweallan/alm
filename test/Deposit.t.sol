// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {Deposit} from "src/Deposit.sol";

contract Deposit is Test {
    Deposit depositContract;
    address owner = address(0x290);

    // eth mainnet
    address NFPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address factory = ;

    function setUp() external {
        string memory ANKR_RPC = string.concat("https://rpc.ankr.com/eth/", vm.envString("ANKR_API_KEY"));
        mainnetFork = vm.createFork(ANKR_RPC, 24_700_000);
        vm.selectFork(mainnetFork);

        vm.prank(owner);
        depositContract = new Deposit(NFPM, );
    }
}