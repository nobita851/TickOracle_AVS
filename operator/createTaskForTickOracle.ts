import { ethers } from "ethers";
import * as dotenv from "dotenv";
const fs = require('fs');
const path = require('path');
dotenv.config();

// Setup env variables
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
/// TODO: Hack
let chainId = 31337;

const avsDeploymentData = JSON.parse(fs.readFileSync(path.resolve(__dirname, `../contracts/deployments/hello-world/${chainId}.json`), 'utf8'));
const tickOracleServiceManagerAddress = avsDeploymentData.addresses.tickOracleServiceManager;
const tickOracleServiceManagerABI = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../abis/TickOracleServiceManager.json'), 'utf8'));
// Initialize contract objects from ABIs
const tickOracleServiceManager = new ethers.Contract(tickOracleServiceManagerAddress, tickOracleServiceManagerABI, wallet);


async function createNewTask() {
  try {
    // Send a transaction to the createNewTask function
    const tx = await tickOracleServiceManager.createNewTask();
    
    // Wait for the transaction to be mined
    const receipt = await tx.wait();
    
    console.log(`Transaction successful with hash: ${receipt.hash}`);
  } catch (error) {
    console.error('Error sending transaction:', error);
  }
}

createNewTask();