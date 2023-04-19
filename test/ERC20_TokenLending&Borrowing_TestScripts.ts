import { ethers } from "hardhat";
import type { Signer } from "ethers";
import { expect } from "chai";
import { Contract } from "ethers";


describe("LendingAndBorrowing", () => {
  let LendingAndBorrowing, lendingAndBorrowing: Contract;
  let owner: Signer, lender: Signer, borrower: Signer, other: Signer;
  let TokenA, tokenA: Contract;
  let TokenB, tokenB: Contract;
  let CollateralToken, collateralToken: Contract;

  beforeEach(async () => {
    [owner, lender, borrower, other] = await ethers.getSigners();

    // Deploy ERC20 tokens for testing
    const TokenFactory = await ethers.getContractFactory("ERC20");
    tokenA = await TokenFactory.deploy("Token A", "TKA", 18);
    tokenB = await TokenFactory.deploy("Token B", "TKB", 18);
    collateralToken = await TokenFactory.deploy("Collateral Token", "CLT", 18);

    // Deploy the LendingAndBorrowing contract
    const LendingAndBorrowingFactory = await ethers.getContractFactory("LendingAndBorrowing");
    lendingAndBorrowing = await LendingAndBorrowingFactory.deploy();

    // Add tokens for lending and borrowing
    await lendingAndBorrowing.addTokensForLending("Token A", tokenA.address);
    await lendingAndBorrowing.addTokensForBorrowing("Token B", tokenB.address);

    // Set the collateral token
    await lendingAndBorrowing.tokenCollateral(collateralToken.address);

    // Transfer tokens to lender and borrower for testing
    await tokenA.transfer(lender.getAddress(), ethers.utils.parseUnits("1000"));
    await tokenB.transfer(lender.getAddress(), ethers.utils.parseUnits("1000"));
    await collateralToken.transfer(borrower.getAddress(), ethers.utils.parseUnits("1000"));
    });

  it("should allow the owner to add tokens for lending", async () => {
    // Add Token B for lending
    await lendingAndBorrowing.connect(owner).addTokensForLending("Token B", tokenB.address);

    // Check if Token B is added to the lending list
    const lendingTokens = await lendingAndBorrowing.getTokensForLendingArray();
    expect(lendingTokens[1].tokenAddress).to.equal(tokenB.address);
    });

  it("should allow the owner to add tokens for borrowing", async () => {
    // Add Token A for borrowing
    await lendingAndBorrowing.connect(owner).addTokensForBorrowing("Token A", tokenA.address);

    // Check if Token A is added to the borrowing list
    const borrowingTokens = await lendingAndBorrowing.getTokensForBorrowingArray();
    expect(borrowingTokens[1].tokenAddress).to.equal(tokenA.address);
    });

  it("should allow lenders to lend tokens", async () => {
    // Approve lending contract to spend tokens
    await tokenA.connect(lender).approve(lendingAndBorrowing.address, ethers.utils.parseUnits("100"));

    // Lend tokens
    await lendingAndBorrowing.connect(lender).toLend(tokenA.address, ethers.utils.parseUnits("100"));

    // Check if the tokens are lent
    const lentAmount = await lendingAndBorrowing.tokensLentAmount(tokenA.address, lender.getAddress());
    expect(lentAmount).to.equal(ethers.utils.parseUnits("100"));
    });

  it("should allow lenders to withdraw lent tokens", async () => {
    // Approve lending contract to spend tokens
    await tokenA.connect(lender).approve(lendingAndBorrowing.address, ethers.utils.parseUnits("100"));
    // Lend tokens
    await lendingAndBorrowing.connect(lender).toLend(tokenA.address, ethers.utils.parseUnits("100"));

    // Withdraw lent tokens
    await lendingAndBorrowing.connect(lender).toWithdrawLentTokens(tokenA.address, ethers.utils.parseUnits("50"));

    // Check if the tokens are withdrawn
    const lentAmount = await lendingAndBorrowing.tokensLentAmount(tokenA.address, lender.getAddress());
    expect(lentAmount).to.equal(ethers.utils.parseUnits("50"));
    });

  it("should allow borrowers to deposit collateral", async () => {
    // Approve lending contract to spend collateral tokens
    await collateralToken.connect(borrower).approve(lendingAndBorrowing.address, ethers.utils.parseUnits("100"));
    // Deposit collateral
    await lendingAndBorrowing.connect(borrower).depositCollateral(ethers.utils.parseUnits("100"));

    // Check if the collateral is deposited
    const collateralAmountt = await lendingAndBorrowing.tokensCollateralAmount(borrower.getAddress());
    expect(collateralAmountt).to.equal(ethers.utils.parseUnits("100"));
    // Deposit collateral
    await lendingAndBorrowing.connect(borrower).depositCollateral(ethers.utils.parseUnits("100"));

    // Check if the collateral is deposited
    const collateralAmount = await lendingAndBorrowing.tokensCollateralAmount(borrower.getAddress());
    expect(collateralAmount).to.equal(ethers.utils.parseUnits("100"));
    });

  it("should allow borrowers to borrow tokens", async () => {
    // Approve lending contract to spend collateral tokens
    await collateralToken.connect(borrower).approve(lendingAndBorrowing.address, ethers.utils.parseUnits("100"));
    // Deposit collateral
    await lendingAndBorrowing.connect(borrower).depositCollateral(ethers.utils.parseUnits("100"));

    // Borrow tokens
    await lendingAndBorrowing.connect(borrower).borrow(tokenB.address, ethers.utils.parseUnits("50"));

    // Check if the tokens are borrowed
    const borrowedAmount = await lendingAndBorrowing.tokensBorrowedAmount(tokenB.address, borrower.getAddress());
    expect(borrowedAmount).to.equal(ethers.utils.parseUnits("50"));
    });

  it("should allow borrowers to pay back debt", async () => {
    // Approve lending contract to spend collateral tokens
    await collateralToken.connect(borrower).approve(lendingAndBorrowing.address, ethers.utils.parseUnits("100"));
    // Deposit collateral
    await lendingAndBorrowing.connect(borrower).depositCollateral(ethers.utils.parseUnits("100"));

    // Borrow tokens
    await lendingAndBorrowing.connect(borrower).borrow(tokenB.address, ethers.utils.parseUnits("50"));

    // Approve lending contract to spend borrowed tokens
    await tokenB.connect(borrower).approve(lendingAndBorrowing.address, ethers.utils.parseUnits("50"));

    // Pay back debt
    await lendingAndBorrowing.connect(borrower).payDebt(tokenB.address, ethers.utils.parseUnits("50"));

    // Check if the debt is paid
    const borrowedAmount = await lendingAndBorrowing.tokensBorrowedAmount(tokenB.address, borrower.getAddress());
    expect(borrowedAmount).to.equal(ethers.utils.parseUnits("0"));
    });

  it("should allow borrowers to release collateral", async () => {
    // Approve lending contract to spend collateral tokens
    await collateralToken.connect(borrower).approve(lendingAndBorrowing.address, ethers.utils.parseUnits("100"));
    // Deposit collateral
    await lendingAndBorrowing.connect(borrower).depositCollateral(ethers.utils.parseUnits("100"));
    // Release collateral
    await lendingAndBorrowing.connect(borrower).releaseCollateral(ethers.utils.parseUnits("50"));

    // Check if the collateral is released
    const collateralAmount = await lendingAndBorrowing.tokensCollateralAmount(borrower.getAddress());
    expect(collateralAmount).to.equal(ethers.utils.parseUnits("50"));
    });
});