import { ethers } from "ethers";
import * as dotenv from "dotenv";
const fs = require('fs');
const path = require('path');
dotenv.config();

const { getPrice } = require('./price.js');

// Check if the process.env object is empty
if (!Object.keys(process.env).length) {
    throw new Error("process.env object is empty");
}

// Setup env variables
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
/// TODO: Hack
let chainId = 31337;

const avsDeploymentData = JSON.parse(fs.readFileSync(path.resolve(__dirname, `../contracts/deployments/hello-world/${chainId}.json`), 'utf8'));
// Load core deployment data
const coreDeploymentData = JSON.parse(fs.readFileSync(path.resolve(__dirname, `../contracts/deployments/core/${chainId}.json`), 'utf8'));

const delegationManagerAddress = coreDeploymentData.addresses.delegation; // todo: reminder to fix the naming of this contract in the deployment file, change to delegationManager
const avsDirectoryAddress = coreDeploymentData.addresses.avsDirectory;
const tickOracleServiceManagerAddress = avsDeploymentData.addresses.tickOracleServiceManager;
const ecdsaStakeRegistryAddress = avsDeploymentData.addresses.stakeRegistry;

// Load ABIs
const delegationManagerABI = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../abis/IDelegationManager.json'), 'utf8'));
const ecdsaRegistryABI = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../abis/ECDSAStakeRegistry.json'), 'utf8'));
const tickOracleServiceManagerABI = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../abis/TickOracleServiceManager.json'), 'utf8'));
const avsDirectoryABI = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../abis/IAVSDirectory.json'), 'utf8'));

// Initialize contract objects from ABIs
const delegationManager = new ethers.Contract(delegationManagerAddress, delegationManagerABI, wallet);
const tickOracleServiceManager = new ethers.Contract(tickOracleServiceManagerAddress, tickOracleServiceManagerABI, wallet);
const ecdsaRegistryContract = new ethers.Contract(ecdsaStakeRegistryAddress, ecdsaRegistryABI, wallet);
const avsDirectory = new ethers.Contract(avsDirectoryAddress, avsDirectoryABI, wallet);

const ERC20ABI = [
    {
      "constant": true,
      "inputs": [],
      "name": "decimals",
      "outputs": [
        {
          "name": "",
          "type": "uint8"
        }
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    },
    {
      "constant": false,
      "inputs": [
        {
          "name": "spender",
          "type": "address"
        },
        {
          "name": "amount",
          "type": "uint256"
        }
      ],
      "name": "approve",
      "outputs": [
        {
          "name": "success",
          "type": "bool"
        }
      ],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    }
];  


/// HOOKATHON: Update the function
const signAndRespondToTask = async (taskIndex: number) => {
    /// HOOKATHON: Update the message for signature ?
    const message = ``;
    const messageHash = ethers.solidityPackedKeccak256(["string"], [message]);
    const messageBytes = ethers.getBytes(messageHash);
    const signature = await wallet.signMessage(messageBytes);

    console.log(`Signing and responding to task ${taskIndex}`);

    const operators = [await wallet.getAddress()];
    const signatures = [signature];

    /// HOOKATHON: Update the symbols for the tokens
    const symbol0 = 'USDCUSDT';
    const symbol1 = 'ETHUSDT';

    const token0Address = avsDeploymentData.addresses.token0;
    const token1Address = avsDeploymentData.addresses.token1;

    const price0 = await getPrice(symbol0);
    const price1 = await getPrice(symbol1);

    const token0 = new ethers.Contract(token0Address, ERC20ABI, wallet);
    const token1 = new ethers.Contract(token1Address, ERC20ABI, wallet);

    // assuming decimals to even number
    const decimals0 = await token0.decimals();
    const decimals1 = await token1.decimals();
    const multiplier = (decimals0 - decimals1) / 2 - 18;
    
    var sqrtPriceX96;
    if(multiplier > 0)
        sqrtPriceX96 = ethers.parseEther(`${Math.sqrt(price0 / price1)}`) * (2n ** 96n) * (10n ** BigInt(multiplier));
    else
        sqrtPriceX96 = ethers.parseEther(`${Math.sqrt(price0 / price1)}`) * (2n ** 96n) / (10n ** BigInt(-multiplier));

    const calculatedCurrentTick = Math.floor((Math.log(price0) - Math.log(price1) + Math.log(10) * (decimals1 - decimals0)) / Math.log(1.0001));
    // +- 5% price range
    const tickUpper = calculatedCurrentTick + 500;
    const tickLower = calculatedCurrentTick - 500;

    /// HOOKATHON: const currentTickOnPool = How to read from pool manager contract ?;

    /// HOOKATHON: Update the ABI encoding ?
    // const signedTask = ethers.AbiCoder.defaultAbiCoder().encode(
    //     ["address[]", "bytes[]", "uint32"],
    //     [operators, signatures, ethers.toBigInt(await provider.getBlockNumber()-1)]
    // );

    /// HOOKATHON: Implement the respondToTask function
    const tx = await tickOracleServiceManager.respondToTask(
        {
            currency0: token0Address,
            currency1: token1Address,
            fee: 3000,
            tickSpacing: 60,
            hooks: ethers.ZeroAddress
        }, // poolKey
        {
            zeroForOne: true, /// HOOKATHON: Update the value currentTickOnPool > calculatedCurrentTick ? true : false
            amountSpecified: -ethers.parseEther("0.00001"),
            sqrtPriceX96: sqrtPriceX96
        }, // swapParams
        ethers.AbiCoder.defaultAbiCoder().encode(["int24", "int24"],[tickLower, tickUpper]),
        taskIndex,
        ""
    );
    await tx.wait();
    console.log(`Responded to task.`);
};

const registerOperator = async () => {
    
    // Registers as an Operator in EigenLayer.
    try {
        const tx1 = await delegationManager.registerAsOperator({
            __deprecated_earningsReceiver: await wallet.address,
            delegationApprover: "0x0000000000000000000000000000000000000000",
            stakerOptOutWindowBlocks: 0
        }, "");
        await tx1.wait();
        console.log("Operator registered to Core EigenLayer contracts");
    } catch (error) {
        console.error("Error in registering as operator:", error);
    }
    
    const salt = ethers.hexlify(ethers.randomBytes(32));
    const expiry = Math.floor(Date.now() / 1000) + 3600; // Example expiry, 1 hour from now

    // Define the output structure
    let operatorSignatureWithSaltAndExpiry = {
        signature: "",
        salt: salt,
        expiry: expiry
    };

    // Calculate the digest hash, which is a unique value representing the operator, avs, unique value (salt) and expiration date.
    const operatorDigestHash = await avsDirectory.calculateOperatorAVSRegistrationDigestHash(
        wallet.address, 
        await tickOracleServiceManager.getAddress(), 
        salt, 
        expiry
    );
    console.log(operatorDigestHash);
    
    // Sign the digest hash with the operator's private key
    console.log("Signing digest hash with operator's private key");
    const operatorSigningKey = new ethers.SigningKey(process.env.PRIVATE_KEY!);
    const operatorSignedDigestHash = operatorSigningKey.sign(operatorDigestHash);

    // Encode the signature in the required format
    operatorSignatureWithSaltAndExpiry.signature = ethers.Signature.from(operatorSignedDigestHash).serialized;

    console.log("Registering Operator to AVS Registry contract");

    
    // Register Operator to AVS
    // Per release here: https://github.com/Layr-Labs/eigenlayer-middleware/blob/v0.2.1-mainnet-rewards/src/unaudited/ECDSAStakeRegistry.sol#L49
    const tx2 = await ecdsaRegistryContract.registerOperatorWithSignature(
        operatorSignatureWithSaltAndExpiry,
        wallet.address
    );
    await tx2.wait();
    console.log("Operator registered on AVS successfully");
};

const monitorNewTasks = async () => {
    //console.log(`Creating new task "EigenWorld"`);
    //await tickOracleServiceManager.createNewTask("EigenWorld");

    tickOracleServiceManager.on("NewTaskCreated", async (taskIndex) => {
        console.log(`New task detected:`);
        await signAndRespondToTask(taskIndex);
    });

    console.log("Monitoring for new tasks...");
};

const main = async () => {
    await registerOperator();
    monitorNewTasks().catch((error) => {
        console.error("Error monitoring tasks:", error);
    });
};

main().catch((error) => {
    console.error("Error in main function:", error);
});