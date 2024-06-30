// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Oracle.sol";
import "../src/libraries/AstNode.sol";
import "../src/libraries/Signature.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract OracleTest is Test {
    Oracle oracle;
    address admin;
    address user1;
    address user2;

    function setUp() public {
        admin = vm.addr(0xA);
        user1 = vm.addr(1);
        user2 = vm.addr(2);

        vm.deal(admin, 100 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        vm.prank(admin);
        oracle = new Oracle();
    }

    function testDeposit() public {
        vm.prank(user1);
        oracle.deposit{value: 1 ether}();
        assertEq(oracle.balances(user1), 1 ether);
    }

    function testRegisterLogic() public {
        AstNode.Info[] memory astnodes = new AstNode.Info[](3);
        astnodes[0] = AstNode.Info(AstNode.NodeType.OPERATION, "+", 1, 2);
        astnodes[1] = AstNode.Info(AstNode.NodeType.NUMBER, "3", 0, 0);
        astnodes[2] = AstNode.Info(AstNode.NodeType.NUMBER, "5", 0, 0);

        vm.prank(user1);
        uint256 logicId = oracle.registerLogic(astnodes);
        assertEq(logicId, 0);
    }

    function testCompute() public {
        AstNode.Info[] memory astnodes = new AstNode.Info[](3);
        astnodes[0] = AstNode.Info(AstNode.NodeType.OPERATION, "+", 1, 2);
        astnodes[1] = AstNode.Info(AstNode.NodeType.NUMBER, "3", 0, 0);
        astnodes[2] = AstNode.Info(AstNode.NodeType.NUMBER, "5", 0, 0);

        vm.prank(user1);
        uint256 logicId = oracle.registerLogic(astnodes);

        vm.prank(user1);
        oracle.deposit{value: 0.02 ether}();
        vm.prank(user1);
        uint256 result = oracle.compute(logicId);
        assertEq(result, 8);
        assertEq(oracle.balances(user1), 0.01 ether); // 0.02 ether - 0.01 ether (FEE)
    }

    function testCallback() public {
        AstNode.Info[] memory astnodes = new AstNode.Info[](3);
        astnodes[0] = AstNode.Info(AstNode.NodeType.OPERATION, "+", 1, 2);
        astnodes[1] = AstNode.Info(AstNode.NodeType.NUMBER, "3", 0, 0);
        astnodes[2] = AstNode.Info(AstNode.NodeType.NUMBER, "5", 0, 0);

        vm.prank(user1);
        uint256 logicId = oracle.registerLogic(astnodes);

        // Admin calls callback
        vm.prank(admin);
        oracle.callback(logicId);
        uint256 adminResult = oracle.adminComputeResult(0);
        assertEq(adminResult, 8);
    }

    function testVerifyAndWithdraw() public {
        AstNode.Info[] memory astnodes = new AstNode.Info[](3);
        astnodes[0] = AstNode.Info(AstNode.NodeType.OPERATION, "+", 1, 2);
        astnodes[1] = AstNode.Info(AstNode.NodeType.NUMBER, "3", 0, 0);
        astnodes[2] = AstNode.Info(AstNode.NodeType.NUMBER, "5", 0, 0);

        vm.prank(user1);
        uint256 logicId = oracle.registerLogic(astnodes);

        vm.prank(user1);
        oracle.deposit{value: 1 ether}();
        assertEq(oracle.balances(user1), 1 ether);

        uint256 nonce = 0;
        uint256 result = 8;
        uint256 amount = 0.5 ether;

        bytes32 structHash = keccak256(abi.encode(
            keccak256("ComputeRequest(uint256 logicId,uint256 nonce,address user,uint256 result)"),
            logicId,
            nonce,
            user1,
            result
        ));
        bytes32 domainSeparator = oracle.getDomainSeparator();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        emit log_named_bytes32("Domain Separator", domainSeparator);
        emit log_named_bytes32("Struct Hash", structHash);
        emit log_named_bytes32("Digest", digest);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user1);
        oracle.verifyAndWithdraw(logicId, nonce, result, signature, amount);

        assertEq(oracle.balances(user1), 0.5 ether); // 1 ether - 0.5 ether
        assertEq(user1.balance, 9.5 ether); // 10 ether initial balance - 1 ehter deposited + 0.5 ether withdrawn
    }

    function testWithdrawAdminBalance() public {
        vm.prank(user1);
        oracle.deposit{value: 1 ether}();
        assertEq(oracle.balances(user1), 1 ether);

        AstNode.Info[] memory astnodes = new AstNode.Info[](3);
        astnodes[0] = AstNode.Info(AstNode.NodeType.OPERATION, "+", 1, 2);
        astnodes[1] = AstNode.Info(AstNode.NodeType.NUMBER, "3", 0, 0);
        astnodes[2] = AstNode.Info(AstNode.NodeType.NUMBER, "5", 0, 0);

        vm.prank(user1);
        uint256 logicId = oracle.registerLogic(astnodes);

        vm.prank(user1);
        oracle.compute(logicId);
        assertEq(oracle.withdrawableBalance(), 0.01 ether);

        uint256 initialAdminBalance = admin.balance;
        vm.prank(admin);
        oracle.withdrawAdminBalance();
        assertEq(admin.balance, initialAdminBalance + 0.01 ether);
    }
}
