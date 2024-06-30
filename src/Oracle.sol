// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import "./libraries/Signature.sol";
import "./libraries/AstNode.sol";
import "./interfaces/IOracle.sol";

contract Oracle is IOracle, EIP712 {
    using Strings for uint256;
    using ECDSA for bytes32;

    uint256 public constant FEE = 0.01 ether;
    address public admin;
    uint256 public computeId;
    uint256 public logicId;

    mapping(uint256 => uint256) public adminComputeResult;
    mapping(uint256 => AstNode.Info[]) public logicStore;
    mapping(address => uint256) public balances;
    uint256 public withdrawableBalance;

    event UserCompute(address indexed userAddress, uint256 result);
    event AdminCompute(uint256 indexed computeId, uint256 result);
    event LogicRegistered(uint256 indexed logicId, address indexed user);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    constructor() EIP712("Oracle", "1") {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    struct ComputeRequest {
        uint256 logicId;
        uint256 nonce;
        address user;
        uint256 result;
    }

    bytes32 private constant COMPUTE_REQUEST_TYPEHASH = keccak256(
        "ComputeRequest(uint256 logicId,uint256 nonce,address user,uint256 result)"
    );

    function registerLogic(AstNode.Info[] memory astnodes) public returns (uint256) {
        uint256 currentLogicId = logicId++;
        AstNode.Info[] storage storageAstnodes = logicStore[currentLogicId];
        for (uint256 i = 0; i < astnodes.length; i++) {
            storageAstnodes.push(astnodes[i]);
        }
        emit LogicRegistered(currentLogicId, msg.sender);
        return currentLogicId;
    }

    function compute(uint256 _logicId) public returns (uint256 result) {
        require(balances[msg.sender] >= FEE, "Insufficient balance");
        balances[msg.sender] -= FEE;
        withdrawableBalance += FEE;

        result = evaluate(logicStore[_logicId], logicStore[_logicId][0]);
        emit UserCompute(msg.sender, result);
    }

    function callback(uint256 _logicId) public onlyAdmin {
        uint256 result = evaluate(logicStore[_logicId], logicStore[_logicId][0]);
        emit AdminCompute(computeId, result);
        adminComputeResult[computeId++] = result;
    }

    function evaluate(AstNode.Info[] memory astnodes, AstNode.Info memory rootAstNode) internal returns (uint256) {
        if (rootAstNode.nodeType == AstNode.NodeType.OPERATION) {
            if (astnodes[rootAstNode.left].nodeType == AstNode.NodeType.OPERATION) {
                astnodes[rootAstNode.left].value = evaluate(astnodes, astnodes[rootAstNode.left]).toString();
                astnodes[rootAstNode.left].nodeType = AstNode.NodeType.NUMBER;
            }
            if (astnodes[rootAstNode.right].nodeType == AstNode.NodeType.OPERATION) {
                astnodes[rootAstNode.right].value = evaluate(astnodes, astnodes[rootAstNode.right]).toString();
                astnodes[rootAstNode.right].nodeType = AstNode.NodeType.NUMBER;
            }

            return performOperation(
                rootAstNode.value,
                parseNumber(astnodes[rootAstNode.left].value),
                parseNumber(astnodes[rootAstNode.right].value)
            );
        } else {
            return parseNumber(rootAstNode.value);
        }
    }

    function performOperation(string memory operation, uint256 left, uint256 right) internal pure returns (uint256) {
        if (keccak256(bytes(operation)) == keccak256(bytes("+"))) {
            return left + right;
        } else if (keccak256(bytes(operation)) == keccak256(bytes("-"))) {
            return left - right;
        } else if (keccak256(bytes(operation)) == keccak256(bytes("*"))) {
            return left * right;
        } else if (keccak256(bytes(operation)) == keccak256(bytes("/"))) {
            require(right != 0, "Division by zero is not allowed");
            return left / right;
        } else {
            revert("Invalid operation");
        }
    }

    function parseNumber(string memory value) internal pure returns (uint256) {
        bytes memory b = bytes(value);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] >= 0x30 && b[i] <= 0x39) {
                result = result * 10 + (uint256(uint8(b[i])) - 48);
            } else {
                revert("Invalid number");
            }
        }
        return result;
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function verifyAndWithdraw(
        uint256 _logicId,
        uint256 nonce,
        uint256 result,
        bytes memory signature,
        uint256 amount
    ) public {
        ComputeRequest memory req = ComputeRequest({
            logicId: _logicId,
            nonce: nonce,
            user: msg.sender,
            result: result
        });

        bytes32 hashStruct = _hashTypedDataV4(keccak256(abi.encode(
            COMPUTE_REQUEST_TYPEHASH,
            req.logicId,
            req.nonce,
            req.user,
            req.result
        )));

        address signer = hashStruct.recover(signature);
        require(signer == msg.sender, "Invalid signature");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    function withdrawAdminBalance() public onlyAdmin {
        uint256 amount = withdrawableBalance;
        withdrawableBalance = 0;
        payable(admin).transfer(amount);
    }

    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
