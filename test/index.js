const { expect } = require("chai");
const { ethers } = require("hardhat");

async function fastForward(duration) {
    await hre.ethers.provider.send('evm_increaseTime', [duration]);
}

const SIGNER_INITIAL_BALANCE = "10000.0";
const INTIAL_GAME_ID = '0';
const DEFAULT_GAME_TIME = 5 * 60 * 1000; // 5 minutes

describe("Main suite", function () {
    async function setUpGame(config) {
        const [owner] = await ethers.getSigners();
        const depositContractFactory = await ethers.getContractFactory('DiveBar');
        const depositContract = await depositContractFactory.deploy({
            value: ethers.utils.parseEther('0.5'),
        });
        await depositContract.deployed();
    
        let contractBalance = await ethers.provider.getBalance(
            depositContract.address
        );
        expect(ethers.utils.formatEther(contractBalance)).to.equal('0.5');
    
        await config.players.reduce(async (memo, player) => {
            await memo;
            // Add a new deposit from addr1
            // Send ether to the contract
            let initialGameInfo = await depositContract.getGameInfo();
            expect(initialGameInfo.id.toString()).to.equal(INTIAL_GAME_ID);

            let signerBalance = await ethers.provider.getBalance(player.signer.address);
            expect(ethers.utils.formatEther(signerBalance)).to.equal(SIGNER_INITIAL_BALANCE);
            const depositAmount = ethers.utils.parseEther(player.bet);
            await player.signer.sendTransaction({
                    to: depositContract.address,
                    value: depositAmount,
            });

            let gameInfo = await depositContract.getGameInfo();
            // console.log(gameInfo);
            expect(gameInfo.id.toString()).to.equal(INTIAL_GAME_ID);
            expect(gameInfo.pot).to.equal(initialGameInfo.pot.add(depositAmount));
            const bnAvg = ethers.BigNumber.from(gameInfo.avg.value);
            expect(Number(ethers.utils.formatEther(bnAvg))).to.equal(ethers.utils.formatEther(gameInfo.pot) / gameInfo.playersSize.toNumber());
            expect(gameInfo.playersSize.toNumber()).to.equal(player.id); // since indx is 0-based
        }, Promise.resolve())   
        return [depositContract];
    }

    beforeEach(async function () {
        await hre.network.provider.send("hardhat_reset")
    })

  it("Compiles, runs, and all functions work", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const [depositContract] = await setUpGame({
        numPlayers: 2,
        timeLimit: 5000,
        players: [
            {
                id: 1,
                signer: addr1,
                bet: '100',
            },
            // {
            //     id: 2,
            //     signer: addr2,
            //     bet: '9000',
            // },
        ]
    });
    
    await fastForward(DEFAULT_GAME_TIME);

    await depositContract.adminCallHandleGameOver();

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('1');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('0.0');
    expect(gameInfo.playersSize.toNumber()).to.equal(0);

    await depositContract.connect(addr1).getPayout();
    let addr1Balance = await ethers.provider.getBalance(addr1.address);
    expect(Number(ethers.utils.formatEther(addr1Balance))).to.be.closeTo(10000, 10);
    console.log('addr1 balance:', ethers.utils.formatEther(addr1Balance));
  });
  it('Correctly handles games with only one player', async function () {
    const [owner, addr1] = await ethers.getSigners();
    const [depositContract] = await setUpGame({
        numPlayers: 1,
        timeLimit: 5000,
        players: [
            {
                id: 1,
                signer: addr1,
                bet: '9000',
            }
        ]
    });
    
    await fastForward(DEFAULT_GAME_TIME);

    await depositContract.adminCallHandleGameOver();

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('1');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('0.0');
    expect(gameInfo.playersSize.toNumber()).to.equal(0);
    // Verify the payouts have been sent correctly
    // addr1 wins, regains bet of 9000 + % of winners pot of 0
    await depositContract.connect(addr1).getPayout();
    addr1Balance = await ethers.provider.getBalance(addr1.address);
    expect(Number(ethers.utils.formatEther(addr1Balance))).to.be.closeTo(10000, 10);
    console.log('addr1 balance:', ethers.utils.formatEther(addr1Balance));
  })

  it("Can handle games with losers and winners", async function () {
    const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
    const [depositContract] = await setUpGame({
        numPlayers: 4,
        timeLimit: 5000,
        players: [
            {
                id: 1,
                signer: addr1,
                bet: '9000',
            },
            {
                id: 2,
                signer: addr2,
                bet: '6000',
            },
            {
                id: 3,
                signer: addr3,
                bet: '6000',
            },
            {
                id: 4,
                signer: addr4,
                bet: '3000',
            },
        ]
    });
    
    await fastForward(DEFAULT_GAME_TIME);

    await depositContract.adminCallHandleGameOver();

    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('1');
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('0.0');
    expect(gameInfo.playersSize.toNumber()).to.equal(0);

    // Verify the payouts have been sent correctly
    // addr1 wins, regains bet of 9000 + % of winners pot of 1199
    await depositContract.connect(addr1).getPayout();
    addr1Balance = await ethers.provider.getBalance(addr1.address);
    expect(Number(ethers.utils.formatEther(addr1Balance))).to.be.closeTo(11199, 20);
    console.log('addr1 balance:', ethers.utils.formatEther(addr1Balance));

    // addr2 wins, regains bet of 6000 + % of winners pot of 1066
    await depositContract.connect(addr2).getPayout();
    let addr2Balance = await ethers.provider.getBalance(addr2.address);
    expect(Number(ethers.utils.formatEther(addr2Balance))).to.be.closeTo(11066, 20);
    console.log('addr2 balance:', ethers.utils.formatEther(addr2Balance));

    // addr3 wins, regains bet of 6000 + % of winners pot of 704
    await depositContract.connect(addr3).getPayout();
    let addr3Balance = await ethers.provider.getBalance(addr3.address);
    expect(Number(ethers.utils.formatEther(addr3Balance))).to.be.closeTo(10700, 20);
    console.log('addr3 balance:', ethers.utils.formatEther(addr3Balance));

    // addr4 loses bet of 3000
    const failedBalanceWithdrawTxn = depositContract.connect(addr4).getPayout();
    expect(failedBalanceWithdrawTxn).to.be.reverted;
    let addr4Balance = await ethers.provider.getBalance(addr4.address);
    expect(Number(ethers.utils.formatEther(addr4Balance))).to.be.closeTo(7000, 10);
    console.log('addr4 balance:', ethers.utils.formatEther(addr4Balance));
  });

  it("Should not be able to payout and create new game before current is over", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const [depositContract] = await setUpGame({
        numPlayers: 2,
        timeLimit: 5000,
        players: [
            {
                id: 1,
                signer: addr1,
                bet: '9000',
            },
            {
                id: 2,
                signer: addr2,
                bet: '9000',
            },
        ]
    });

    const handleGameOverTxn = depositContract.adminCallHandleGameOver();
    await expect(handleGameOverTxn).to.be.reverted;
    gameInfo = await depositContract.getGameInfo();
    expect(gameInfo.id.toString()).to.equal('0'); // still current game
    expect(ethers.utils.formatEther(gameInfo.pot)).to.equal('18000.0');
    expect(gameInfo.playersSize.toNumber()).to.equal(2);

    await fastForward(DEFAULT_GAME_TIME);

    // const checkUpkeep = await depositContract.checkUpkeep(0x12);
    // console.log('checkUpkeep:', checkUpkeep);

    const anonAdminCallHandleGameOverTxn = depositContract.connect(addr1).adminCallHandleGameOver();
    await expect(anonAdminCallHandleGameOverTxn).to.be.reverted;

  });
});
