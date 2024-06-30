use actix_web::{post, web, App, HttpServer, Responder};
use ethers::prelude::*;
use ethers::contract::abigen;
use serde::Deserialize;
use std::sync::Arc;

// 使用 JSON 格式的 ABI
abigen!(
    Oracle,
    r#"[
        {
            "type": "constructor",
            "inputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "FEE",
            "inputs": [],
            "outputs": [
                {
                    "name": "",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "admin",
            "inputs": [],
            "outputs": [
                {
                    "name": "",
                    "type": "address",
                    "internalType": "address"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "adminComputeResult",
            "inputs": [
                {
                    "name": "computeId",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [
                {
                    "name": "result",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "callback",
            "inputs": [
                {
                    "name": "astnodes",
                    "type": "tuple[]",
                    "internalType": "struct AstNode.Info[]",
                    "components": [
                        {
                            "name": "nodeType",
                            "type": "uint8",
                            "internalType": "enum AstNode.NodeType"
                        },
                        {
                            "name": "value",
                            "type": "string",
                            "internalType": "string"
                        },
                        {
                            "name": "left",
                            "type": "uint256",
                            "internalType": "uint256"
                        },
                        {
                            "name": "right",
                            "type": "uint256",
                            "internalType": "uint256"
                        }
                    ]
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "compute",
            "inputs": [
                {
                    "name": "astnodes",
                    "type": "tuple[]",
                    "internalType": "struct AstNode.Info[]",
                    "components": [
                        {
                            "name": "nodeType",
                            "type": "uint8",
                            "internalType": "enum AstNode.NodeType"
                        },
                        {
                            "name": "value",
                            "type": "string",
                            "internalType": "string"
                        },
                        {
                            "name": "left",
                            "type": "uint256",
                            "internalType": "uint256"
                        },
                        {
                            "name": "right",
                            "type": "uint256",
                            "internalType": "uint256"
                        }
                    ]
                }
            ],
            "outputs": [
                {
                    "name": "result",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "payable"
        },
        {
            "type": "function",
            "name": "computeId",
            "inputs": [],
            "outputs": [
                {
                    "name": "",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "event",
            "name": "AdminCompute",
            "inputs": [
                {
                    "name": "computeId",
                    "type": "uint256",
                    "indexed": true,
                    "internalType": "uint256"
                },
                {
                    "name": "result",
                    "type": "uint256",
                    "indexed": false,
                    "internalType": "uint256"
                }
            ],
            "anonymous": false
        },
        {
            "type": "event",
            "name": "UserCompute",
            "inputs": [
                {
                    "name": "userAddress",
                    "type": "address",
                    "indexed": true,
                    "internalType": "address"
                },
                {
                    "name": "result",
                    "type": "uint256",
                    "indexed": false,
                    "internalType": "uint256"
                }
            ],
            "anonymous": false
        }
    ]"#
);

const ORACLE_CONTRACT_ADDRESS: &str = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";

#[derive(Deserialize)]
struct ComputeRequest {
    ast_nodes: Vec<AstNode>,
}

#[derive(Deserialize)]
struct AstNode {
    node_type: u8,
    value: String,
    left: u64,
    right: u64,
}

#[post("/compute")]
async fn compute(data: web::Json<ComputeRequest>) -> impl Responder {
    let provider = Provider::<Http>::try_from("http://localhost:8545").unwrap();
    let wallet: LocalWallet = "YOUR_PRIVATE_KEY".parse().unwrap();
    let client = Arc::new(SignerMiddleware::new(provider, wallet));

    let contract_address: Address = ORACLE_CONTRACT_ADDRESS.parse().unwrap();
    let contract = Oracle::<SignerMiddleware<Provider<Http>>, SignerMiddleware<Provider<Http>>>::new(contract_address, client.clone());

    // Convert AST nodes to the correct type
    let ast_nodes: Vec<Oracle::AstNodeInfo> = data
        .ast_nodes
        .iter()
        .map(|node| Oracle::AstNodeInfo {
            nodeType: node.node_type,
            value: node.value.clone(),
            left: U256::from(node.left),
            right: U256::from(node.right),
        })
        .collect();

    // Call compute method
    let tx = contract
        .compute(ast_nodes)
        .value(U256::exp10(16)) // 0.01 ether
        .send()
        .await
        .unwrap();

    let receipt = tx.await.unwrap().unwrap();
    format!("Transaction successful with hash: {:?}", receipt.transaction_hash)
}

#[post("/callback")]
async fn callback(data: web::Json<ComputeRequest>) -> impl Responder {
    let provider = Provider::<Http>::try_from("http://localhost:8545").unwrap();
    let wallet: LocalWallet = "YOUR_PRIVATE_KEY".parse().unwrap();
    let client = Arc::new(SignerMiddleware::new(provider, wallet));

    let contract_address: Address = ORACLE_CONTRACT_ADDRESS.parse().unwrap();
    let contract = Oracle::<SignerMiddleware<Provider<Http>>, SignerMiddleware<Provider<Http>>>::new(contract_address, client.clone());

    // Convert AST nodes to the correct type
    let ast_nodes: Vec<Oracle::AstNodeInfo> = data
        .ast_nodes
        .iter()
        .map(|node| Oracle::AstNodeInfo {
            nodeType: node.node_type,
            value: node.value.clone(),
            left: U256::from(node.left),
            right: U256::from(node.right),
        })
        .collect();

    // Call callback method
    let tx = contract
        .callback(ast_nodes)
        .send()
        .await
        .unwrap();

    let receipt = tx.await.unwrap().unwrap();
    format!("Callback successful with hash: {:?}", receipt.transaction_hash)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    HttpServer::new(|| {
        App::new()
            .service(compute)
            .service(callback)
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
}