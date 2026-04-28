import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.20",
};

if (process.env.PRIVATE_KEY) {
  config.networks = {
    baseSepolia: {
      type: "http",
      url: "https://sepolia.base.org",
      accounts: [process.env.PRIVATE_KEY],
    },
  };
}

export default config;
