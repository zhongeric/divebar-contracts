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

  it("Should accept multiple deposits and correctly initialize a new game", async function () {
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

    await depositContract.handleGameOver({
        value: gameInfo.avg, 
    });

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('1');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('0.0');
    expect(gameInfo.playersSize.toNumber()).to.equal(0);
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

    const handleGameOverTxn = depositContract.handleGameOver({
        value: gameInfo.avg, 
    });

    await expect(handleGameOverTxn).to.be.reverted;

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0'); // still current game
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('18000.0');
    expect(gameInfo.playersSize.toNumber()).to.equal(2);
  });
});
