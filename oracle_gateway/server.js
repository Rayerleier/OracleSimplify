const express = require('express');
const { ethers } = require('ethers');
const bodyParser = require('body-parser');
const app = express();
const PORT = 3000;

// ABI 和合约地址
const oracleABI = require('./OracleABI.json')
const ORACLE_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';
const ADMIN_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

const ANVIL_URL = 'http://127.0.0.1:8545'; // Anvil（或其他本地节点）的 URL
const provider = new ethers.providers.JsonRpcProvider(ANVIL_URL);
const adminWallet = new ethers.Wallet(ADMIN_PRIVATE_KEY, provider);
const oracleContract = new ethers.Contract(ORACLE_ADDRESS, oracleABI, adminWallet);

app.use(bodyParser.json());

app.post('/registerLogic', async (req, res) => {
  try {
      const { astNodes } = req.body;

      if (!astNodes || !Array.isArray(astNodes) || astNodes.length === 0) {
          return res.status(400).send('Invalid astNodes');
      }

      console.log('Received AST nodes for registration:', astNodes);
      
      const tx = await oracleContract.registerLogic(astNodes);
      await tx.wait();

      res.send('Logic registered successfully');
  } catch (error) {
      console.error('Error in /registerLogic:', error);
      res.status(500).send(`Error in /registerLogic: ${error.message}`);
  }
});

// 用户计算
app.post('/compute', async (req, res) => {
    try {
        const { logicId, userAddress } = req.body;
        const userWallet = provider.getSigner(userAddress);
        const userOracleContract = new ethers.Contract(ORACLE_ADDRESS, oracleABI, userWallet);

        const tx = await userOracleContract.compute(logicId);
        await tx.wait();
        res.status(200).send({ message: 'Computation successful', tx });
    } catch (error) {
        console.error('Error in /compute:', error);
        res.status(500).send({ error: 'Failed to compute' });
    }
});

// 管理员回调
app.post('/callback', async (req, res) => {
    try {
        const { logicId } = req.body;
        const tx = await oracleContract.callback(logicId);
        await tx.wait();
        res.status(200).send({ message: 'Callback successful', tx });
    } catch (error) {
        console.error('Error in /callback:', error);
        res.status(500).send({ error: 'Failed to execute callback' });
    }
});

// 用户存款
app.post('/deposit', async (req, res) => {
    try {
        const { amount, userAddress } = req.body;
        const userWallet = provider.getSigner(userAddress);
        const userOracleContract = new ethers.Contract(ORACLE_ADDRESS, oracleABI, userWallet);

        const tx = await userOracleContract.deposit({ value: ethers.utils.parseEther(amount) });
        await tx.wait();
        res.status(200).send({ message: 'Deposit successful', tx });
    } catch (error) {
        console.error('Error in /deposit:', error);
        res.status(500).send({ error: 'Failed to deposit' });
    }
});

// 用户验证和提取
app.post('/verifyAndWithdraw', async (req, res) => {
    try {
        const { logicId, nonce, result, signature, amount, userAddress } = req.body;
        const userWallet = provider.getSigner(userAddress);
        const userOracleContract = new ethers.Contract(ORACLE_ADDRESS, oracleABI, userWallet);

        const tx = await userOracleContract.verifyAndWithdraw(logicId, nonce, result, signature, ethers.utils.parseEther(amount));
        await tx.wait();
        res.status(200).send({ message: 'Withdrawal successful', tx });
    } catch (error) {
        console.error('Error in /verifyAndWithdraw:', error);
        res.status(500).send({ error: 'Failed to verify and withdraw' });
    }
});

// 管理员提取余额
app.post('/withdrawAdminBalance', async (req, res) => {
    try {
        const tx = await oracleContract.withdrawAdminBalance();
        await tx.wait();
        res.status(200).send({ message: 'Admin withdrawal successful', tx });
    } catch (error) {
        console.error('Error in /withdrawAdminBalance:', error);
        res.status(500).send({ error: 'Failed to withdraw admin balance' });
    }
});

app.listen(PORT, () => {
    console.log(`Oracle Gateway listening on port ${PORT}`);
});
