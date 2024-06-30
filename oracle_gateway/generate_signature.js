const { ethers } = require('ethers');

const userPrivateKey = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';
const userWallet = new ethers.Wallet(userPrivateKey);

const domain = {
  name: 'Oracle',
  version: '1',
  chainId: 31337,
  verifyingContract: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'
};

const types = {
  ComputeRequest: [
    { name: 'logicId', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'user', type: 'address' },
    { name: 'result', type: 'uint256' }
  ]
};

const value = {
  logicId: 0,
  nonce: 0,
  user: userWallet.address,
  result: 8
};

async function sign() {
  const signature = await userWallet._signTypedData(domain, types, value);
  console.log('Signature:', signature);
}

sign();
