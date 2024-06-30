# Option Task 2

## Contract

- Designed a `deposit` function to receive user deposits.
- Modified the `compute` function to check if the user has sufficient balance in their deposits. If the balance is insufficient, the calculation cannot proceed; if sufficient, the corresponding balance is deducted.
- Added a `withdrawAdminBalance` function for the admin to withdraw the contract balance.
- Added a `verifyAndWithdraw`function to verify users off-chain using EIP712 signatures. Upon successful verification, the user is allowed to withdraw.
  - The verification information includes `logicId`, `nonce`, `userAddress`, and `result`.
- Run the test script `forge test -vvvv`.
- Run `anvil` to start location client.
- Deploy the script `forge script ./script/Oracle.s.sol:DeployOracle --broadcast --fork-url http://127.0.0.1:8545 --private-key $PrivateKey`.

## Gateway

- Modified the `/compute` function to require the user address parameter.

- Added 

  ```
  /verifyAndWithdraw
  ```

   for user withdrawals.

  - Withdrawals require the user's address parameter and an off-chain signature.

- Added `generate_signature.js` to compute the off-chain signature.

- Added `/withdrawAdminBalance` for the admin to withdraw deposits.

- Modified other corresponding logic.

- Run the gateway with `node server.js`.

### Test Script

1. Register Logic

```bash

curl -X POST http://localhost:3000/registerLogic -H "Content-Type: application/json" -d '{
  "astNodes": [
    { "nodeType": 2, "value": "+", "left": 1, "right": 2 },
    { "nodeType": 0, "value": "3", "left": 0, "right": 0 },
    { "nodeType": 0, "value": "5", "left": 0, "right": 0 }
  ]
}'
```

2. User Compute

```bash

curl -X POST http://localhost:3000/compute -H "Content-Type: application/json" -d '{
  "logicId": 0,
  "userAddress": "USER_ADDRESS"
}'
```

3. Admin Callback

```bash

curl -X POST http://localhost:3000/callback -H "Content-Type: application/json" -d '{
  "logicId": 0
}'
```

4. User Deposit

```bash

curl -X POST http://localhost:3000/deposit -H "Content-Type: application/json" -d '{
  "amount": "1.0",
  "userAddress": "USER_ADDRESS"
}'
```

5. User Withdraw

```bash

curl -X POST http://localhost:3000/verifyAndWithdraw -H "Content-Type: application/json" -d '{
  "logicId": 0,
  "nonce": 0,
  "result": 8,
  "signature": "YOUR_GENERATED_SIGNATURE",
  "amount": "0.5",
  "userAddress": "USER_ADDRESS"
}'
```

6. Admin Withdraw Balance

```bash

curl -X POST http://localhost:3000/withdrawAdminBalance -H "Content-Type: application/json"
```

### Testing Procedure

1. Start the gateway with `node server.js`.
2. Test the register logic.
3. Test user deposit.
4. Test user compute.
5. Generate the signature with `node generate_signature.js`.
6. Test user withdrawal.
7. Test callback computation.
8. Test admin withdrawal.

**Note: Ensure all parameters are correct at each step, such as contract address, user public key, and user private key for successful operations.**
