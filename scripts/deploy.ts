import { run, ethers } from "hardhat";

async function main() {
  const LendingAndBorrowingFactory = await ethers.getContractFactory("LendingAndBorrowing");
  const lendingAndBorrowing = await LendingAndBorrowingFactory.deploy();

  console.log("LendingAndBorrowing deployed to:", lendingAndBorrowing.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });