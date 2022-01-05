const { ethers } = require("hardhat");

function sleep(ms) {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
}

const main = async () => {
    const [owner, addr1, addr2] = await ethers.getSigners();
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

    // Add a new deposit from addr1
    // Send ether to the contract
    const depositAmount = ethers.utils.parseEther('9000');
    await addr1.sendTransaction({
        to: depositContract.address,
        value: depositAmount,
    });
    console.log(`Sent ${ethers.utils.formatEther(depositAmount)} to depositContract from addr1`);
    /*
        * Get Game info
    */
    let gameInfo = await depositContract.getGameInfo();
    console.log('Game info:', gameInfo);

    // Add a new deposit from addr2
    // Send ether to the contract
    const depositAmountAddr2 = ethers.utils.parseEther('9000');
    await addr2.sendTransaction({
        to: depositContract.address,
        value: depositAmountAddr2,
    });
    console.log(`Sent ${ethers.utils.formatEther(depositAmountAddr2)} to depositContract from addr2`);
    /*
        * Get Game info
    */
    gameInfo = await depositContract.getGameInfo();
    console.log('Game info:', gameInfo);

    await sleep(5000);

    // game should be over now, call handleGameOver
    await depositContract.handleGameOver();
    console.log('Game over');

    // Verify new game has been created
    gameInfo = await depositContract.getGameInfo();
    console.log('Game info:', gameInfo);

    // // Payout winnings
    // const payoutAmount = ethers.utils.parseEther('420');
    // await depositContract.payoutWinnings({
    //     value: payoutAmount,
    // });
    // console.log('Paid out winnings');

    // // get balances of addr1 and addr2
    // addr1Balance = await ethers.provider.getBalance(addr1.address);
    // console.log('addr1 balance:', ethers.utils.formatEther(addr1Balance));

    // addr2Balance = await ethers.provider.getBalance(addr2.address);
    // console.log('addr2 balance:', ethers.utils.formatEther(addr2Balance));
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