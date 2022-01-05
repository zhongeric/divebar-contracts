const { expect } = require("chai");
const { ethers } = require("hardhat");

function sleep(ms) {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
}

describe("Main suite", function () {
    beforeEach(async function () {
        await hre.network.provider.send("hardhat_reset")
    })

  it("Compiles, runs, and all functions work", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const depositContractFactory = await ethers.getContractFactory('Deposits');

    const depositContract = await depositContractFactory.deploy({
        value: ethers.utils.parseEther('0.5'),
    });
    await depositContract.deployed();
    

    /*
        * Get Contract balance
    */
    let contractBalance = await ethers.provider.getBalance(
        depositContract.address
    );
    expect(ethers.utils.formatEther(contractBalance)).to.equal('0.5');

    let addr1Balance = await ethers.provider.getBalance(addr1.address);
    expect(ethers.utils.formatEther(addr1Balance)).to.equal('10000.0');

    // Add a new deposit from addr1
    // Send ether to the contract
    const depositAmount = ethers.utils.parseEther('9000');
    await addr1.sendTransaction({
        to: depositContract.address,
        value: depositAmount,
    });

    let gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('9000.0');
    expect(Number(ethers.utils.formatEther(gameInfo.avg))).to.equal(ethers.utils.formatEther(gameInfo.pot) / gameInfo.playersSize.toNumber());
    expect(gameInfo.playersSize.toNumber()).to.equal(1);
    console.log("Time limit ", gameInfo.timeLimit.toNumber());
    console.log("Created At ", gameInfo.createdAt.toNumber());
    console.log("Ends At ", gameInfo.endingAt.toNumber());

    // Add a new deposit from addr2
    // Send ether to the contract
    const depositAmountAddr2 = ethers.utils.parseEther('9000');
    await addr2.sendTransaction({
        to: depositContract.address,
        value: depositAmountAddr2,
    });

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('18000.0');
    expect(Number(ethers.utils.formatEther(gameInfo.avg))).to.equal(ethers.utils.formatEther(gameInfo.pot) / gameInfo.playersSize.toNumber());
    expect(gameInfo.playersSize.toNumber()).to.equal(2);

    await sleep(5000);

    await depositContract.handleGameOver();

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('1');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('0.0');
    expect(gameInfo.playersSize.toNumber()).to.equal(0);

    // Verify the payouts have been sent correctly
    addr1Balance = await ethers.provider.getBalance(addr1.address);
    expect(Number(ethers.utils.formatEther(addr1Balance))).to.be.closeTo(10000, 10);
    console.log('addr1 balance:', ethers.utils.formatEther(addr1Balance));

    let addr2Balance = await ethers.provider.getBalance(addr2.address);
    expect(Number(ethers.utils.formatEther(addr2Balance))).to.be.closeTo(10000, 10);
    console.log('addr2 balance:', ethers.utils.formatEther(addr2Balance));
  });

  it("Can handle games with losers and winners", async function () {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const depositContractFactory = await ethers.getContractFactory('Deposits');
    const depositContract = await depositContractFactory.deploy({
        value: ethers.utils.parseEther('0.5'),
    });
    await depositContract.deployed();

    let contractBalance = await ethers.provider.getBalance(
        depositContract.address
    );
    expect(ethers.utils.formatEther(contractBalance)).to.equal('0.5');

    let addr1Balance = await ethers.provider.getBalance(addr1.address);
    expect(ethers.utils.formatEther(addr1Balance)).to.equal('10000.0');

    // Add a new deposit from addr1
    // Send ether to the contract
    const depositAmount = ethers.utils.parseEther('9000');
    await addr1.sendTransaction({
        to: depositContract.address,
        value: depositAmount,
    });

    let gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('9000.0');
    expect(Number(ethers.utils.formatEther(gameInfo.avg))).to.equal(ethers.utils.formatEther(gameInfo.pot) / gameInfo.playersSize.toNumber());
    expect(gameInfo.playersSize.toNumber()).to.equal(1);

    // Add a new deposit from addr2
    // Send ether to the contract
    const depositAmountAddr2 = ethers.utils.parseEther('3000');
    await addr2.sendTransaction({
        to: depositContract.address,
        value: depositAmountAddr2,
    });

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('12000.0');
    expect(Number(ethers.utils.formatEther(gameInfo.avg))).to.equal(ethers.utils.formatEther(gameInfo.pot) / gameInfo.playersSize.toNumber());
    expect(gameInfo.playersSize.toNumber()).to.equal(2);

    // Add a new deposit from addr3
    // Send ether to the contract
    const depositAmountAddr3 = ethers.utils.parseEther('6000');
    await addr3.sendTransaction({
        to: depositContract.address,
        value: depositAmountAddr3,
    });

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('18000.0');
    expect(Number(ethers.utils.formatEther(gameInfo.avg))).to.equal(ethers.utils.formatEther(gameInfo.pot) / gameInfo.playersSize.toNumber());
    expect(gameInfo.playersSize.toNumber()).to.equal(3);

    await sleep(5000);

    await depositContract.handleGameOver();

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('1');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('0.0');
    expect(gameInfo.playersSize.toNumber()).to.equal(0);

    // Verify the payouts have been sent correctly
    // addr1 won (9000, so 1000 + 9000)
    addr1Balance = await ethers.provider.getBalance(addr1.address);
    expect(Number(ethers.utils.formatEther(addr1Balance))).to.be.closeTo(10000, 10);
    console.log('addr1 balance:', ethers.utils.formatEther(addr1Balance));

    // addr2 lost their bet of 3000
    let addr2Balance = await ethers.provider.getBalance(addr2.address);
    expect(Number(ethers.utils.formatEther(addr2Balance))).to.be.closeTo(7000, 10);
    console.log('addr2 balance:', ethers.utils.formatEther(addr2Balance));

    // addr3 won (9000, so 4000+9000)
    let addr3Balance = await ethers.provider.getBalance(addr3.address);
    expect(Number(ethers.utils.formatEther(addr3Balance))).to.be.closeTo(13000, 10);
    console.log('addr3 balance:', ethers.utils.formatEther(addr3Balance));
  });

  it("Should not be able to payout and create new game before current is over", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const depositContractFactory = await ethers.getContractFactory('Deposits');
    const depositContract = await depositContractFactory.deploy({
        value: ethers.utils.parseEther('0.5'),
    });
    await depositContract.deployed();

    /*
        * Get Contract balance
    */
    let contractBalance = await ethers.provider.getBalance(
        depositContract.address
    );
    expect(ethers.utils.formatEther(contractBalance)).to.equal('0.5');

    let addr1Balance = await ethers.provider.getBalance(addr1.address);
    expect(ethers.utils.formatEther(addr1Balance)).to.equal('10000.0');

    // Add a new deposit from addr1
    // Send ether to the contract
    const depositAmount = ethers.utils.parseEther('9000');
    await addr1.sendTransaction({
        to: depositContract.address,
        value: depositAmount,
    });

    let gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('9000.0');
    expect(Number(ethers.utils.formatEther(gameInfo.avg))).to.equal(ethers.utils.formatEther(gameInfo.pot) / gameInfo.playersSize.toNumber());
    expect(gameInfo.playersSize.toNumber()).to.equal(1);

    // Add a new deposit from addr2
    // Send ether to the contract
    const depositAmountAddr2 = ethers.utils.parseEther('9000.0');
    await addr2.sendTransaction({
        to: depositContract.address,
        value: depositAmountAddr2,
    });

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('18000.0');
    expect(Number(ethers.utils.formatEther(gameInfo.avg))).to.equal(ethers.utils.formatEther(gameInfo.pot) / gameInfo.playersSize.toNumber());
    expect(gameInfo.playersSize.toNumber()).to.equal(2);

    const handleGameOverTxn = depositContract.handleGameOver();

    await expect(handleGameOverTxn).to.be.reverted;

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0'); // still current game
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('18000.0');
    expect(gameInfo.playersSize.toNumber()).to.equal(2);
  });
});
