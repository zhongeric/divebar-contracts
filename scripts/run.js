const { ethers } = require("hardhat");

const main = async () => {
    const [owner, addr1] = await ethers.getSigners();
    const depositContractFactory = await ethers.getContractFactory('Deposits');
    const depositContract = await depositContractFactory.deploy({
        value: ethers.utils.parseEther('0.5'),
    });
    await depositContract.deployed();

    console.log("Contract deployed to:", depositContract.address);
    console.log("Contract deployed by:", owner.address);

    /*
        * Get Contract balance
    */
    let contractBalance = await ethers.provider.getBalance(
        depositContract.address
    );
    console.log(
        'Contract balance:',
        ethers.utils.formatEther(contractBalance)
    );

    let addr1Balance = await ethers.provider.getBalance(addr1.address);
    console.log('addr1 balance:', ethers.utils.formatEther(addr1Balance));

    // Add a new deposit
    // Send ether to the contract
    const depositAmount = ethers.utils.parseEther('0.5');
    await addr1.sendTransaction({
        to: depositContract.address,
        value: depositAmount,
    });
    console.log(`Sent ${ethers.utils.formatEther(depositAmount)} to depositContract from addr1`);
    /*
        * Get Game info
    */
    let gamePot = await depositContract.getGamePot();
    console.log('Game pot:', ethers.utils.formatEther(gamePot));
  };
  
  const runMain = async () => {
    try {
      await main();
      process.exit(0);
    } catch (error) {
      console.log(error);
      process.exit(1);
    }
  };
  
  runMain();