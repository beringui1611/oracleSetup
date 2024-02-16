import dotenv from 'dotenv';
dotenv.config();
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    bsctest:{
      url: process.env.RPC_URL,
      chainId: parseInt(`${process.env.CHAIN_ID}`),
      accounts:{
        mnemonic: process.env.SECRET
      }
    }
  }, 
  etherscan:{
    apiKey: process.env.API_KEY
  }
};

export default config;
